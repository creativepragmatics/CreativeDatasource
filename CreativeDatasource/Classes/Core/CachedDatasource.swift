import Foundation
import ReactiveSwift
import Result

/// Maintains state coming from multiple sources (primary and local).
/// It is able to support pagination, live feeds, etc in the primary datasource (yet to be implemented).
/// State coming from the primary datasource is treated as preferential over state from
/// the local datasource. You can think of the local datasource as cache.
public struct CachedDatasource<Value: Any, P: Parameters, LIT: LoadImpulseType, E: DatasourceError> {
    
    public typealias CachedStateConcrete = CachedState<Value, P, LIT, E>
    public typealias DatasourceConcrete = DatasourceBox<Value, P, LIT, E>
    public typealias LoadImpulseEmitterConcrete = LoadImpulseEmitterBox<P, LIT>
    public typealias ResponseCombinerConcrete = ResponseCombinerBox<Value, P, LIT, E>
    public typealias StatePersisterConcrete = StatePersisterBox<Value, P, LIT, E>
    
    private let loadImpulseEmitter: LoadImpulseEmitterConcrete
    
    public let cachedState: Property<CachedStateConcrete>
    
    public init(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                cacheDatasource: DatasourceConcrete? = nil,
                primaryDatasource: DatasourceConcrete? = nil,
                persister: StatePersisterConcrete? = nil,
                responseCombiner: ResponseCombinerConcrete) {
        self.loadImpulseEmitter = loadImpulseEmitter
        self.cachedState = Property<CachedState>(initial: .datasourceNotReady, then: CachedDatasource.cachedStatesProducer(loadImpulseEmitter: loadImpulseEmitter,cacheDatasource: cacheDatasource, primaryDatasource: primaryDatasource, persister: persister, responseCombiner: responseCombiner))
    }
    
    public func load(_ loadImpulse: LoadImpulse<P, LIT>) -> LoadingStarted {
        
        guard !shouldSkipLoad(for: loadImpulse) else {
            return false
        }
        
        loadImpulseEmitter.emit(loadImpulse)
        return true
    }
    
    public var loadingEnded: SignalProducer<Void, NoError> {
        return cachedState.producer
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
        return loadImpulse.skipIfResultAvailable && cachedState.value.value(loadImpulse.parameters) != nil
    }
    
    private static func datasourceState(_ datasource: DatasourceConcrete?) -> SignalProducer<CachedStateConcrete, NoError> {
        let initialState = SignalProducer<CachedStateConcrete, NoError>(value: .datasourceNotReady)
        guard let datasource = datasource else { return initialState }
        
        let cachedStates = datasource.state.map({ CachedState.with($0) })
        return initialState.concat(cachedStates)
    }
    
    private static func cachedStatesProducer(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                                                cacheDatasource: DatasourceConcrete? = nil,
                                                primaryDatasource: DatasourceConcrete? = nil,
                                                persister: StatePersisterConcrete? = nil,
                                                responseCombiner: ResponseCombinerConcrete)
        -> SignalProducer<CachedStateConcrete, NoError> {
            
            let initialStateProducer = SignalProducer(value: CachedStateConcrete.datasourceNotReady)
            
            let localState = datasourceState(cacheDatasource)
            
            let primaryState: SignalProducer<CachedStateConcrete, NoError> = {
                if let primaryDatasource = primaryDatasource {
                    let combinedPrimaryStates = responseCombiner.combinedState(datasource: primaryDatasource)
                        .replayLazily(upTo: 1)
                    return initialStateProducer
                        .concat(combinedPrimaryStates)
                } else {
                    return initialStateProducer
                }
            }()
            
            let primarySuccess = initialStateProducer
                .concat(primaryState.filter({ primary in
                    if case .success = primary {
                        return true
                    } else {
                        return false
                    }
                }))
            
            let loadImpulse = loadImpulseEmitter.loadImpulses.skipRepeats()
            
            return SignalProducer
                .combineLatest(localState, primaryState, primarySuccess)
                .combineLatest(with: loadImpulse)
                .observe(on: QueueScheduler())
                .map({ arg -> CachedStateConcrete in
                    
                    let ((local, primary, primarySuccess), currentRefresh) = arg
                    let currentParameters = currentRefresh.parameters
                    
                    // If fetchPrimary == nil, use local as main datasource and return immediately:
                    guard let _ = primaryDatasource else {
                        switch local {
                        case .datasourceNotReady:
                            return .datasourceNotReady
                        case let .loading(_, loadImpulse):
                            return CachedState.loading(cached: nil, loadImpulse: loadImpulse)
                        case let .success(valueBox, loadImpulse):
                            return CachedState.success(valueBox: valueBox, loadImpulse: loadImpulse)
                        case let .error(error, _, loadImpulse):
                            return CachedState.error(error: error, cached: nil, loadImpulse: loadImpulse)
                        }
                    }
                    
                    switch primary {
                    case let .success(_, loadImpulse) where loadImpulse.parameters.isCacheCompatible(currentParameters):
                        // Primary is success > save to local storage
                        if let persister = persister {
                            persist(primaryState: primary, statePersister: persister)
                        }
                        return primary
                    case let .loading(primaryCached, primaryRefresh):
                        if let _ = primaryCached {
                            return primary
                        } else {
                            // Primary is loading and has no cache, but we might fall back to last primary success
                            return unifiedStateForPrimaryLoading(primaryRefresh: primaryRefresh, primarySuccess: primarySuccess, local: local, currentParameters: currentParameters)
                                ?? fallbackCachedState(primary: primary)
                        }
                    case let .error(error, primaryCached, primaryRefresh):
                        if let _ = primaryCached {
                            return primary
                        } else {
                            // Primary is error, but we might fall back to last primary success
                            return unifiedStateForPrimaryError(error: error, primaryRefresh: primaryRefresh, primarySuccess: primarySuccess, local: local, currentParameters: currentParameters)
                                ?? fallbackCachedState(primary: primary)
                        }
                    case .datasourceNotReady, .success:
                        return fallbackCachedState(primary: primary)
                    }
                })
                .observe(on: QueueScheduler.main)
    }
    
    /// Persists the provided `CachedState` to disk.
    private static func persist(primaryState: CachedStateConcrete, statePersister: StatePersisterConcrete) {
        let stateToPersist: State<Value, P, LIT, E> = {
            switch primaryState {
            case .datasourceNotReady:
                return .datasourceNotReady
            case let .loading(cached, loadImpulse):
                // Cached is used by "primary" for previously (successfully) loaded pages!
                if let cached = cached {
                    return .success(valueBox: cached, loadImpulse: loadImpulse)
                } else {
                    return .loading(loadImpulse: loadImpulse)
                }
            case let .success(value, loadImpulse):
                return .success(valueBox: value, loadImpulse: loadImpulse)
            case let .error(error, cached, loadImpulse):
                // Cached is used by "primary" for previously (successfully) loaded pages!
                if let cached = cached {
                    return .success(valueBox: cached, loadImpulse: loadImpulse)
                } else {
                    return .error(error: error, loadImpulse: loadImpulse)
                }
            }
        }()
        
        statePersister.persist(stateToPersist)
    }
    
    /// Only use to get state if primary datasource has state `.loading`.
    /// Returns either the last primary success state, or last local success state,
    /// or nil if none of these are available/admissible.
    private static func unifiedStateForPrimaryLoading(primaryRefresh: LoadImpulse<P, LIT>, primarySuccess: CachedStateConcrete, local: CachedStateConcrete, currentParameters: P) -> CachedStateConcrete? {
        
        guard primaryRefresh.parameters.isCacheCompatible(currentParameters) else {
            return nil
        }
        
        switch (primarySuccess, local) {
        case let (.success(_, successRefresh), _) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // primary is loading, but we can fall back to last REMOTE success
            let primarySuccessValue = primarySuccess.value(successRefresh.parameters)
            return CachedState.loading(cached: primarySuccessValue, loadImpulse: primaryRefresh)
        case let (_, .success(_, successRefresh)) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // primary is loading, but we can fall back to last LOCAL success
            let localSuccessValue = local.value(successRefresh.parameters)
            return CachedState.loading(cached: localSuccessValue, loadImpulse: primaryRefresh)
        default:
            return nil
        }
    }
    
    /// Only use to get state if primary datasource has state `.error`.
    /// Returns either the last primary success state, or last local success state,
    /// or nil if none of these are available/admissible.
    private static func unifiedStateForPrimaryError(error: E, primaryRefresh: LoadImpulse<P, LIT>, primarySuccess: CachedStateConcrete, local: CachedStateConcrete, currentParameters: P) -> CachedStateConcrete? {
        
        guard primaryRefresh.parameters.isCacheCompatible(currentParameters) else {
            return nil
        }
        
        switch (primarySuccess, local) {
        case let (.success(_, successRefresh), _) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // primary is error, but we can fall back to last primary success
            let primarySuccessValue = primarySuccess.value(successRefresh.parameters)
            return CachedState.error(error: error, cached: primarySuccessValue, loadImpulse: primaryRefresh)
        case let (_, .success(_, successRefresh)) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // primary is error, but we can fall back to last local success
            let localSuccessValue = local.value(successRefresh.parameters)
            return CachedState.error(error: error, cached: localSuccessValue, loadImpulse: primaryRefresh)
        default:
            return nil
        }
    }
    
    /// Returns a fallback state for when the primary-success and local
    /// datasources have failed to provide a cached state.
    private static func fallbackCachedState(primary: CachedStateConcrete) -> CachedStateConcrete {
        switch primary {
        case .datasourceNotReady:
            return .datasourceNotReady
        case let .loading(_, loadImpulse):
            return .loading(cached: nil, loadImpulse: loadImpulse)
        case .success:
            // This happens when the current success state's tag doesn't match the
            // current tag. Return .initial to force views into a blank state, wiping
            // previously displayed items.
            return .datasourceNotReady
        case let .error(error, _, loadImpulse):
            return CachedState.error(error: error, cached: nil, loadImpulse: loadImpulse)
        }
    }
    
}

public typealias LoadingStarted = Bool
