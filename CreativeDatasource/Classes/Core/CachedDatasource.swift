import Foundation
import ReactiveSwift
import Result

/// Maintains state coming from multiple sources (primary and cache).
/// It is able to support pagination, live feeds, etc in the primary datasource (yet to be implemented).
/// State coming from the primary datasource is treated as preferential over state from
/// the cache datasource. You can think of the cache datasource as cache.
public struct CachedDatasource<SubDatasourceState: StateProtocol>: DatasourceProtocol {
    public typealias State = CachedState<SubDatasourceState.Value, P, LIT, E>
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
                persister: StatePersisterConcrete? = nil) {
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
                                             primaryDatasource: SubDatasource? = nil,
                                             cacheDatasource: SubDatasource? = nil,
                                             persister: StatePersisterConcrete? = nil)
        -> SignalProducer<State, NoError> {
            
            let initialStateProducer = SignalProducer(value: SubDatasourceState(notReadyProvisioningState: .notReady))
            
            // In order to start sending states immediately, .combineLatest requires all
            // datasources to send values synchronously on subscription.
            func synchronouslySentState(_ subDatasource: SubDatasource?) -> SignalProducer<SubDatasourceState, NoError> {
                let initialState = SubDatasourceState.init(notReadyProvisioningState: .notReady)
                let initialStateProducer = SignalProducer<SubDatasourceState, NoError>(value: initialState)
                guard let subDatasource = subDatasource else { return initialStateProducer }
                
                if subDatasource.loadsSynchronously {
                    return subDatasource.state
                } else {
                    return initialStateProducer.concat(subDatasource.state)
                }
            }
            
            SubDatasourceState.init(notReadyProvisioningState: .notReady)
            let primaryState: SignalProducer<SubDatasourceState, NoError> = synchronouslySentState(primaryDatasource)
                .replayLazily(upTo: 1) // replay because primarySuccess also subscribes
            let cachedState: SignalProducer<SubDatasourceState, NoError> = synchronouslySentState(cacheDatasource)
            
            // Last primary success state. Sends intial state (.datasourceNotReady)
            // immediately on subscription.
            let primarySuccess = initialStateProducer
                .concat(primaryState.filter({ $0.hasLoadedSuccessfully }))
            
            let loadImpulse = loadImpulseEmitter.loadImpulses.skipRepeats()
            
            return SignalProducer
                // All these signals will send .datasourceNotReady or a
                // cached state immediately on subscription:
                .combineLatest(cachedState, primaryState, primarySuccess)
                .combineLatest(with: loadImpulse)
                .map({ arg -> State in
                    
                    let ((cache, primary, primarySuccess), loadImpulse) = arg
                    let currentParameters = loadImpulse.parameters
                    
                    switch primary.provisioningState {
                    case .notReady, .loading:
                        if let lastPrimarySuccessValueBox = cacheCompatibleResult(state: primarySuccess, loadImpulse: loadImpulse) {
                            return State.loading(cached: lastPrimarySuccessValueBox, loadImpulse: loadImpulse)
                        } else if let cachedValueBox = cacheCompatibleResult(state: cache, loadImpulse: loadImpulse) {
                            return State.loading(cached: cachedValueBox, loadImpulse: loadImpulse)
                        } else {
                            // Neither remote success nor cachely cached value
                            switch primary.provisioningState {
                            case .notReady, .result: return State.datasourceNotReady
                            case .loading: return State.loading(cached: nil, loadImpulse: loadImpulse)
                            }
                        }
                    case .result:
                        if let primaryValue = cacheCompatibleResult(state: primary, loadImpulse: loadImpulse) {
                            persister?.persist(primary)
                            return State.success(valueBox: primaryValue, loadImpulse: loadImpulse)
                        } else if let error = primary.error {
                            if let lastPrimarySuccessValueBox = cacheCompatibleResult(state: primarySuccess, loadImpulse: loadImpulse) {
                                return State.error(error: error, cached: lastPrimarySuccessValueBox, loadImpulse: loadImpulse)
                            } else if let cachedValueBox = cacheCompatibleResult(state: cache, loadImpulse: loadImpulse) {
                                return State.error(error: error, cached: cachedValueBox, loadImpulse: loadImpulse)
                            } else {
                                return State.error(error: error, cached: nil, loadImpulse: loadImpulse)
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
    
    private static func cacheCompatibleResult(state: SubDatasourceState, loadImpulse: LoadImpulse<P, LIT>) -> StrongEqualityValueBox<SubDatasourceState.Value>? {
        guard let valueBox = state.value,
            let stateLoadImpulse = state.loadImpulse,
            stateLoadImpulse.isCacheCompatible(loadImpulse) else {
                return nil
        }
        return valueBox
    }
    
}

public typealias LoadingStarted = Bool
