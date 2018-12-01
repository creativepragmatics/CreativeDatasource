import Foundation
import ReactiveSwift
import Result

/// Maintains state coming from multiple sources (remote and local).
/// It is able to support pagination, live feeds, etc in the remote datasource (yet to be implemented).
public struct CompositeDatasource<Value: Codable, P: Parameters, LIT: LoadImpulseType, E: DatasourceError> {
    
    public typealias CompositeStateConcrete = CompositeState<Value, P, LIT, E>
    public typealias DatasourceConcrete = DatasourceBox<Value, P, LIT, E>
    public typealias LoadImpulseEmitterConcrete = LoadImpulseEmitterBox<P, LIT>
    public typealias ResponseCombinerConcrete = ResponseCombinerBox<Value, P, LIT, E>
    public typealias StatePersisterConcrete = StatePersisterBox<Value, P, LIT, E>
    
    private let loadImpulseEmitter: LoadImpulseEmitterConcrete
    
    public let compositeState: Property<CompositeStateConcrete>
    
    public init(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                localDatasource: DatasourceConcrete? = nil,
                remoteDatasource: DatasourceConcrete? = nil,
                persister: StatePersisterConcrete? = nil,
                responseCombiner: ResponseCombinerConcrete) {
        self.loadImpulseEmitter = loadImpulseEmitter
        self.compositeState = Property<CompositeState>(initial: .initial, then: CompositeDatasource.compositeStatesProducer(loadImpulseEmitter: loadImpulseEmitter,localDatasource: localDatasource, remoteDatasource: remoteDatasource, persister: persister, responseCombiner: responseCombiner))
    }   
    
    public func load(_ loadImpulse: LoadImpulse<P, LIT>) -> SignalProducer<RefreshingEnded, NoError> {
        
        guard !shouldSkipRefresh(for: loadImpulse) else {
            return SignalProducer(value: RefreshingEnded())
        }
        
        let loadingEnded = compositeState.producer
            .skip(first: 1) // skip first (= current) value
            .filter({ fetchState -> Bool in // only allow end-states (failed, success)
                switch fetchState {
                case .error, .success:
                    return true
                case .initial, .loading:
                    return false
                }
            })
            .map({ _ in RefreshingEnded() })
            .replayLazily(upTo: 1) // cache only 1 endstate for every subscriber
        
        // We start the producer right now, because we need to observe
        // any states send as soon as a loadImpulse is triggered.
        // Else, we might miss immediately returned state (e.g. reading from
        // disk).
        loadingEnded
            .take(first: 1) // take only 1 so this subscriber gets disposed afterwards
            .start()
        
        // Start loadImpulse
        loadImpulseEmitter.emit(loadImpulse)
        
        return loadingEnded.take(first: 1)
    }
    
    private func shouldSkipRefresh(for loadImpulse: LoadImpulse<P, LIT>) -> Bool {
        return loadImpulse.skipIfResultAvailable && compositeState.value.value(loadImpulse.parameters) != nil
    }
    
    private static func datasourceState(_ datasource: DatasourceConcrete?) -> SignalProducer<CompositeStateConcrete, NoError> {
        let initialState = SignalProducer<CompositeStateConcrete, NoError>(value: .initial)
        guard let datasource = datasource else { return initialState }
        
        let compositeStates = datasource.state.producer.map({ CompositeState.with($0) })
        return initialState.concat(compositeStates)
    }
    
    private static func compositeStatesProducer(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                                                localDatasource: DatasourceConcrete? = nil,
                                                remoteDatasource: DatasourceConcrete? = nil,
                                                persister: StatePersisterConcrete? = nil,
                                                responseCombiner: ResponseCombinerConcrete)
        -> SignalProducer<CompositeStateConcrete, NoError> {
            
            let localState = datasourceState(localDatasource)
            let remoteState: SignalProducer<CompositeStateConcrete, NoError> = {
                if let remoteDatasource = remoteDatasource {
                    return responseCombiner.combinedState(datasource: remoteDatasource).replayLazily(upTo: 1)
                } else {
                    return SignalProducer(value: CompositeStateConcrete.initial)
                }
            }()
            
            let remoteSuccess = SignalProducer(value: .initial)
                .concat(remoteState.filter({ remote in
                    if case .success = remote {
                        return true
                    } else {
                        return false
                    }
                }))
            
            let loadImpulse = loadImpulseEmitter.loadImpulses.skipRepeats()
            
            return SignalProducer
                .combineLatest(localState, remoteState, remoteSuccess)
                .combineLatest(with: loadImpulse)
                .observe(on: QueueScheduler())
                .map({ arg -> CompositeStateConcrete in
                    
                    let ((local, remote, remoteSuccess), currentRefresh) = arg
                    let currentParameters = currentRefresh.parameters
                    
                    // If fetchRemote == nil, use local as main datasource and return immediately:
                    guard let _ = remoteDatasource else {
                        switch local {
                        case .initial:
                            return .initial
                        case let .loading(_, loadImpulse):
                            return CompositeState.loading(cached: nil, loadImpulse: loadImpulse)
                        case let .success(valueBox, loadImpulse):
                            return CompositeState.success(valueBox: valueBox, loadImpulse: loadImpulse)
                        case let .error(error, _, loadImpulse):
                            return CompositeState.error(error: error, cached: nil, loadImpulse: loadImpulse)
                        }
                    }
                    
                    switch remote {
                    case let .success(_, loadImpulse) where loadImpulse.parameters.isCacheCompatible(currentParameters):
                        // Remote is success > save to local storage
                        if let persister = persister {
                            persist(remoteState: remote, statePersister: persister)
                        }
                        return remote
                    case let .loading(remoteCached, remoteRefresh):
                        if let _ = remoteCached {
                            return remote
                        } else {
                            // Remote is loading and has no cache, but we might fall back to last remote success
                            return unifiedStateForRemoteLoading(remoteRefresh: remoteRefresh, remoteSuccess: remoteSuccess, local: local, currentParameters: currentParameters)
                                ?? fallbackCompositeState(remote: remote)
                        }
                    case let .error(error, remoteCached, remoteRefresh):
                        if let _ = remoteCached {
                            return remote
                        } else {
                            // Remote is error, but we might fall back to last remote success
                            return unifiedStateForRemoteError(error: error, remoteRefresh: remoteRefresh, remoteSuccess: remoteSuccess, local: local, currentParameters: currentParameters)
                                ?? fallbackCompositeState(remote: remote)
                        }
                    case .initial, .success:
                        return fallbackCompositeState(remote: remote)
                    }
                })
                .observe(on: QueueScheduler.main)
    }
    
    /// Persists the provided `CompositeState` to disk.
    private static func persist(remoteState: CompositeStateConcrete, statePersister: StatePersisterConcrete) {
        let stateToPersist: State<Value, P, LIT, E> = {
            switch remoteState {
            case .initial:
                return .initial
            case let .loading(cached, loadImpulse):
                // Cached is used by "remote" for previously (successfully) loaded pages!
                if let cached = cached {
                    return .success(valueBox: cached, loadImpulse: loadImpulse)
                } else {
                    return .loading(loadImpulse: loadImpulse)
                }
            case let .success(value, loadImpulse):
                return .success(valueBox: value, loadImpulse: loadImpulse)
            case let .error(error, cached, loadImpulse):
                // Cached is used by "remote" for previously (successfully) loaded pages!
                if let cached = cached {
                    return .success(valueBox: cached, loadImpulse: loadImpulse)
                } else {
                    return .error(error: error, loadImpulse: loadImpulse)
                }
            }
        }()
        
        statePersister.persist(stateToPersist)
    }
    
    /// Only use to get state if remote datasource has state `.loading`.
    /// Returns either the last remote success state, or last local success state,
    /// or nil if none of these are available/admissible.
    private static func unifiedStateForRemoteLoading(remoteRefresh: LoadImpulse<P, LIT>, remoteSuccess: CompositeStateConcrete, local: CompositeStateConcrete, currentParameters: P) -> CompositeStateConcrete? {
        
        guard remoteRefresh.parameters.isCacheCompatible(currentParameters) else {
            return nil
        }
        
        switch (remoteSuccess, local) {
        case let (.success(_, successRefresh), _) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // remote is loading, but we can fall back to last REMOTE success
            let remoteSuccessValue = remoteSuccess.value(successRefresh.parameters)
            return CompositeState.loading(cached: remoteSuccessValue, loadImpulse: remoteRefresh)
        case let (_, .success(_, successRefresh)) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // remote is loading, but we can fall back to last LOCAL success
            let localSuccessValue = local.value(successRefresh.parameters)
            return CompositeState.loading(cached: localSuccessValue, loadImpulse: remoteRefresh)
        default:
            return nil
        }
    }
    
    /// Only use to get state if remote datasource has state `.error`.
    /// Returns either the last remote success state, or last local success state,
    /// or nil if none of these are available/admissible.
    private static func unifiedStateForRemoteError(error: E, remoteRefresh: LoadImpulse<P, LIT>, remoteSuccess: CompositeStateConcrete, local: CompositeStateConcrete, currentParameters: P) -> CompositeStateConcrete? {
        
        guard remoteRefresh.parameters.isCacheCompatible(currentParameters) else {
            return nil
        }
        
        switch (remoteSuccess, local) {
        case let (.success(_, successRefresh), _) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // remote is error, but we can fall back to last remote success
            let remoteSuccessValue = remoteSuccess.value(successRefresh.parameters)
            return CompositeState.error(error: error, cached: remoteSuccessValue, loadImpulse: remoteRefresh)
        case let (_, .success(_, successRefresh)) where successRefresh.parameters.isCacheCompatible(currentParameters):
            // remote is error, but we can fall back to last local success
            let localSuccessValue = local.value(successRefresh.parameters)
            return CompositeState.error(error: error, cached: localSuccessValue, loadImpulse: remoteRefresh)
        default:
            return nil
        }
    }
    
    /// Returns a fallback state for when the remote-success and local
    /// datasources have failed to provide a cached state.
    private static func fallbackCompositeState(remote: CompositeStateConcrete) -> CompositeStateConcrete {
        switch remote {
        case .initial:
            return .initial
        case let .loading(_, loadImpulse):
            return .loading(cached: nil, loadImpulse: loadImpulse)
        case .success:
            // This happens when the current success state's tag doesn't match the
            // current tag. Return .initial to force views into a blank state, wiping
            // previously displayed items.
            return .initial
        case let .error(error, _, loadImpulse):
            return CompositeState.error(error: error, cached: nil, loadImpulse: loadImpulse)
        }
    }
    
}

public typealias RefreshingEnded = Void
