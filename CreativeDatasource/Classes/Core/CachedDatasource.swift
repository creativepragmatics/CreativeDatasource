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
                primaryDatasource: SubDatasource? = nil,
                cacheDatasource: SubDatasource? = nil,
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
                    
                    // If fetchPrimary == nil, use cache as main datasource and return immediately:
                    guard let _ = primaryDatasource else {
                        return stateForCacheSubDatasourceStateOnly(cache: cache)
                    }
                    
                    switch primary.provisioningState {
                    case .notReady, .loading:
                        if let lastPrimarySuccessResult = cacheCompatibleResult(state: primarySuccess, loadImpulse: loadImpulse) {
                            switch lastPrimarySuccessResult {
                            case let .success(valueBox):
                                return State.loading(cached: valueBox, loadImpulse: loadImpulse)
                            case .failure:
                                break
                            }
                        }
                        
                        if let cacheResult = cacheCompatibleResult(state: cache, loadImpulse: loadImpulse) {
                            switch cacheResult {
                            case let .success(valueBox):
                                return State.loading(cached: valueBox, loadImpulse: loadImpulse)
                            case let .failure(error):
                                switch primary.provisioningState {
                                case .notReady: return State.datasourceNotReady
                                case .loading: return State.loading(cached: nil, loadImpulse: loadImpulse)
                                case .result: return State.datasourceNotReady // cannot happen because not in parent case
                                }
                            }
                        }
                        
                        // Neither remote success nor cachely cached value
                        switch primary.provisioningState {
                        case .notReady, .result: return State.datasourceNotReady
                        case .loading: return State.loading(cached: nil, loadImpulse: loadImpulse)
                        }
                    case .result:
                        guard let primaryResult = cacheCompatibleResult(state: primary, loadImpulse: loadImpulse) else {
                            return State.datasourceNotReady
                        }
                        
                        switch primaryResult {
                        case let .success(valueBox):
                            persister?.persist(primary)
                            return State.success(valueBox: valueBox, loadImpulse: loadImpulse)
                        case let .failure(error):
                            if let lastPrimarySuccessResult = cacheCompatibleResult(state: primarySuccess, loadImpulse: loadImpulse) {
                                switch lastPrimarySuccessResult {
                                case let .success(valueBox):
                                    return State.error(error: error, cached: valueBox, loadImpulse: loadImpulse)
                                case .failure:
                                    break
                                }
                            }
                            
                            guard let cacheResult = cacheCompatibleResult(state: cache, loadImpulse: loadImpulse) else {
                                return State.error(error: error, cached: nil, loadImpulse: loadImpulse)
                            }
                            
                            switch cacheResult {
                            case let .success(valueBox): return State.error(error: error, cached: valueBox, loadImpulse: loadImpulse)
                            case .failure: return State.error(error: error, cached: nil, loadImpulse: loadImpulse)
                            }
                        }
                    }
                })
    }
    
    private static func cacheCompatibleResult(state: SubDatasourceState, loadImpulse: LoadImpulse<P, LIT>) -> Result<StrongEqualityValueBox<SubDatasourceState.Value>, E>? {
        guard let result = state.result,
            let stateLoadImpulse = state.loadImpulse,
            stateLoadImpulse.isCacheCompatible(loadImpulse) else {
                return nil
        }
        return result
    }
    
    private static func stateForCacheSubDatasourceStateOnly(cache: SubDatasourceState) -> State {
        switch cache.provisioningState {
        case .notReady:
            return State.datasourceNotReady
        case .loading:
            if let loadImpulse = cache.loadImpulse {
                return State.loading(cached: nil, loadImpulse: loadImpulse)
            } else {
                return State.datasourceNotReady
            }
        case .result:
            if let result = cache.result, let loadImpulse = cache.loadImpulse {
                switch result {
                case let .success(valueBox):
                    return State.success(valueBox: valueBox, loadImpulse: loadImpulse)
                case let .failure(error):
                    return State.error(error: error, cached: nil, loadImpulse: loadImpulse)
                }
            } else {
                return State.datasourceNotReady
            }
        }
    }
    
}

public typealias LoadingStarted = Bool
