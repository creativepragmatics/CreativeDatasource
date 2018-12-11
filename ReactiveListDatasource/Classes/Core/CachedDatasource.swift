import Foundation
import ReactiveSwift
import Result

/// Maintains state coming from multiple sources (primary and cache).
/// It is able to support pagination, live feeds, etc in the primary datasource (yet to be implemented).
/// State coming from the primary datasource is treated as preferential over state from
/// the cache datasource. You can think of the cache datasource as cache.
public struct CachedDatasource<SubDatasourceState: StateProtocol>: DatasourceProtocol {
    public typealias State = CompositeState<SubDatasourceState.Value, P, LIT, E>
    public typealias P = SubDatasourceState.P
    public typealias LIT = SubDatasourceState.LIT
    public typealias E = SubDatasourceState.E
    
    public typealias SubDatasource = AnyDatasource<SubDatasourceState>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P, LIT>
    public typealias StatePersisterConcrete = AnyStatePersister<SubDatasourceState>
    
    private let loadImpulseEmitter: LoadImpulseEmitterConcrete
    public let loadsSynchronously = true
    
    private let stateProperty: Property<State>
    public var state: SignalProducer<State, NoError> {
        return stateProperty.producer
    }
    
    public init(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                primaryDatasource: SubDatasource,
                cacheDatasource: SubDatasource,
                persister: StatePersisterConcrete?) {
        self.loadImpulseEmitter = loadImpulseEmitter
        let stateProducer = CachedDatasource.cachedStatesProducer(loadImpulseEmitter: loadImpulseEmitter, primaryDatasource: primaryDatasource, cacheDatasource: cacheDatasource, persister: persister)
        self.stateProperty = Property(initial: State.datasourceNotReady, then: stateProducer)
    }
    
    @discardableResult
    public func load(_ loadImpulse: LoadImpulse<P, LIT>) -> LoadingStarted {
        
        guard !shouldSkipLoad(for: loadImpulse) else {
            return false
        }
        
        loadImpulseEmitter.emit(loadImpulse)
        return true
    }
    
    /// Defers loading until returned SignalProducer is subscribed to.
    /// Once loading is done, returned SignalProducer sends the new
    /// state and completes.
    public func loadDeferred(_ loadImpulse: LoadImpulse<P, LIT>) -> SignalProducer<State, NoError> {
        return SignalProducer.init({ (observer, lifetime) in
            self.stateProperty.producer
                .skip(first: 1) // skip first (= current) value
                .filter({ fetchState -> Bool in // only allow end-states (error, success)
                    switch fetchState {
                    case .error, .success:
                        return true
                    case .datasourceNotReady, .loading:
                        return false
                    }
                })
                .startWithValues({ cachedState in
                    observer.send(value: cachedState)
                    observer.sendCompleted()
                })
            self.load(loadImpulse)
        })
    }
    
    /// Should be subscribed to BEFORE a load is performed.
    public var loadingEnded: SignalProducer<Void, NoError> {
        return stateProperty.producer
            .skip(first: 1) // skip first (= current) value
            .filter({ fetchState -> Bool in // only allow end-states (error, success)
                switch fetchState {
                case .error, .success:
                    return true
                case .datasourceNotReady, .loading:
                    return false
                }
            })
            .map({ _ in () })
    }
    
    private func shouldSkipLoad(for loadImpulse: LoadImpulse<P, LIT>) -> Bool {
        return loadImpulse.skipIfResultAvailable && stateProperty.value.hasLoadedSuccessfully != nil
    }
    
    private static func cachedStatesProducer(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                                             primaryDatasource: SubDatasource,
                                             cacheDatasource: SubDatasource,
                                             persister: StatePersisterConcrete? = nil)
        -> SignalProducer<State, NoError> {
            
            let initialState = SignalProducer(value: SubDatasourceState(notReadyProvisioningState: .notReady))

            let primaryStates = primaryDatasource.stateWithSynchronousInitial
            let cachedStates = cacheDatasource.stateWithSynchronousInitial
            let loadImpulse = loadImpulseEmitter.loadImpulses.skipRepeats()
            
            return SignalProducer
                // All these signals will send .datasourceNotReady or a
                // cached state immediately on subscription:
                .combineLatest(cachedStates, primaryStates)
                .combineLatest(with: loadImpulse)
                .map({ arg -> State in
                    
                    let ((cache, primary), loadImpulse) = arg
                    let currentParameters = loadImpulse.parameters
                    
                    switch primary.provisioningState {
                    case .notReady, .loading:
                        
                        if let primaryValue = primary.cacheCompatibleValue(for: loadImpulse) {
                            return State.loading(fallbackValue: primaryValue, fallbackError: primary.error, loadImpulse: loadImpulse)
                        } else if let cacheValue = cache.cacheCompatibleValue(for: loadImpulse) {
                            return State.loading(fallbackValue: cacheValue, fallbackError: cache.error, loadImpulse: loadImpulse)
                        } else {
                            // Neither remote success nor cachely cached value
                            switch primary.provisioningState {
                            case .notReady, .result: return State.datasourceNotReady
                                // Add primary as fallback so any errors are added
                            case .loading: return State.loading(fallbackValue: nil, fallbackError: primary.error, loadImpulse: loadImpulse)
                            }
                        }
                    case .result:
                        if primary.hasLoadedSuccessfully {
                            persister?.persist(primary)
                        }
                        
                        if let primaryValue = primary.cacheCompatibleValue(for: loadImpulse) {
                            if let error = primary.error {
                                return State.error(error: error, fallbackValue: primaryValue, loadImpulse: loadImpulse)
                            } else {
                                return State.success(valueBox: primaryValue, loadImpulse: loadImpulse)
                            }
                        } else if let error = primary.error {
                            if let cachedValue = cache.cacheCompatibleValue(for: loadImpulse) {
                                return State.error(error: error, fallbackValue: cachedValue, loadImpulse: loadImpulse)
                            } else {
                                return State.error(error: error, fallbackValue: nil, loadImpulse: loadImpulse)
                            }
                        } else {
                            // Remote state might not match current parameters - return .datasourceNotReady
                            // so all cached data is purged. This can happen if e.g. an authenticated API
                            // request has been made, but the user has logged out in the meantime. The result
                            // must be discarded or the next logged in user might see the previous user's data.
                            return State.datasourceNotReady
                        }
                    }
                })
    }
    
}

public typealias LoadingStarted = Bool

//public extension DatasourceProtocol {
//
//    public func cached(with cacheDatasource: AnyDatasource<State>, loadImpulseEmitter: AnyLoadImpulseEmitter<State.P, State.LIT>, persister: AnyStatePersister<State>?) -> CachedDatasource<State> {
//        return CachedDatasource<State>.init(loadImpulseEmitter: loadImpulseEmitter, primaryDatasource: self.any, cacheDatasource: cacheDatasource, persister: persister)
//    }
//}
