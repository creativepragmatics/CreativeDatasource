import Foundation
import ReactiveSwift
import Result

public struct LastResultRetainingDatasource<SubDatasourceState: StateProtocol>: DatasourceProtocol {
    public typealias State = CompositeState<SubDatasourceState.Value, SubDatasourceState.P, SubDatasourceState.LIT, SubDatasourceState.E>
    
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<SubDatasourceState.P, SubDatasourceState.LIT>
    public typealias SubDatasource = AnyDatasource<SubDatasourceState>
    
    public let loadsSynchronously = true
    
    public let state: SignalProducer<State, NoError>
    
    public init(innerDatasource: SubDatasource) {
        self.state = LastResultRetainingDatasource.stateProducer(innerDatasource: innerDatasource)
    }
    
    private static func stateProducer(innerDatasource: SubDatasource)
        -> SignalProducer<State, NoError> {
            let initialState = SignalProducer(value: SubDatasourceState(notReadyProvisioningState: .notReady))
            let lazyStates: SignalProducer<SubDatasourceState, NoError> = {
                if innerDatasource.loadsSynchronously {
                    return innerDatasource.state.replayLazily(upTo: 1)
                } else {
                    return initialState.concat(innerDatasource.state.replayLazily(upTo: 1))
                }
            }()
            let resultStates = initialState
                .concat(lazyStates.filter({
                    switch $0.provisioningState {
                    case .result: return true
                    case .loading, .notReady: return false
                    }
                }))
            
            return lazyStates
                .combineLatest(with: resultStates)
                .map { (latestState, lastResultState) -> State in
                    switch latestState.provisioningState {
                    case .notReady:
                        return State.datasourceNotReady
                    case .loading:
                        guard let loadImpulse = latestState.loadImpulse else { return .datasourceNotReady }
                        
                        if let successValue = latestState.cacheCompatibleValue(for: loadImpulse) {
                            return State.loading(fallbackValue: successValue, fallbackError: latestState.error, loadImpulse: loadImpulse)
                        } else if let lastResultValue = lastResultState.cacheCompatibleValue(for: loadImpulse) {
                            return State.loading(fallbackValue: lastResultValue, fallbackError: lastResultState.error, loadImpulse: loadImpulse)
                        } else {
                            return State.loading(fallbackValue: nil, fallbackError: latestState.error, loadImpulse: loadImpulse)
                        }
                    case .result:
                        guard let loadImpulse = latestState.loadImpulse else { return .datasourceNotReady }
                        
                        if let latestSuccessValue = latestState.cacheCompatibleValue(for: loadImpulse) {
                            if let error = latestState.error {
                                return State.error(error: error, fallbackValue: latestSuccessValue, loadImpulse: loadImpulse)
                            } else {
                                return State.success(valueBox: latestSuccessValue, loadImpulse: loadImpulse)
                            }
                        } else if let latestError = latestState.error {
                            if let lastResultValue = lastResultState.cacheCompatibleValue(for: loadImpulse) {
                                return State.error(error: latestError, fallbackValue: lastResultValue, loadImpulse: loadImpulse)
                            } else {
                                return State.error(error: latestError, fallbackValue: nil, loadImpulse: loadImpulse)
                            }
                        } else {
                            // Latest state might not match current parameters - return .datasourceNotReady
                            // so all cached data is purged. This can happen if e.g. an authenticated API
                            // request has been made, but the user has logged out in the meantime. The result
                            // must be discarded or the next logged in user might see the previous user's data.
                            return State.datasourceNotReady
                        }
                    }
            }
            
    }

}

public extension DatasourceProtocol {
    
    public typealias LastResultRetaining = LastResultRetainingDatasource<State>
    
    public var retainLastResult: LastResultRetaining {
        return LastResultRetaining(innerDatasource: self.any)
    }
}
