import Foundation
import ReactiveSwift
import Result

public struct LastResultRetainingDatasource<Value_: Any, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    
    public typealias SubDatasource = AnyDatasource<Value, P, E>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P>
    
    public let loadsSynchronously = true
    
    public let state: SignalProducer<DatasourceState, NoError>
    
    public init(innerDatasource: SubDatasource) {
        self.state = LastResultRetainingDatasource.stateProducer(innerDatasource: innerDatasource)
    }
    
    private static func stateProducer(innerDatasource: SubDatasource)
        -> SignalProducer<DatasourceState, NoError> {
            let initialState = SignalProducer(value: DatasourceState.notReady)
            let lazyStates: SignalProducer<DatasourceState, NoError> = {
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
                .map { (latestState, lastResultState) -> DatasourceState in
                    switch latestState.provisioningState {
                    case .notReady:
                        return DatasourceState.notReady
                    case .loading:
                        guard let loadImpulse = latestState.loadImpulse else { return .notReady }
                        
                        if let successValueBox = latestState.cacheCompatibleValue(for: loadImpulse) {
                            return DatasourceState.loading(loadImpulse: loadImpulse, fallbackValue: successValueBox.value, fallbackError: latestState.error)
                        } else if let lastResultValueBox = lastResultState.cacheCompatibleValue(for: loadImpulse) {
                            return DatasourceState.loading(loadImpulse: loadImpulse, fallbackValue: lastResultValueBox.value, fallbackError: latestState.error)
                        } else {
                            return DatasourceState.loading(loadImpulse: loadImpulse, fallbackValue: nil, fallbackError: latestState.error)
                        }
                    case .result:
                        guard let loadImpulse = latestState.loadImpulse else { return .notReady }
                        
                        if let latestSuccessValueBox = latestState.cacheCompatibleValue(for: loadImpulse) {
                            if let error = latestState.error {
                                return DatasourceState.error(error: error, loadImpulse: loadImpulse, fallbackValue: latestSuccessValueBox.value)
                            } else {
                                return DatasourceState.value(value: latestSuccessValueBox.value, loadImpulse: loadImpulse, fallbackError: nil)
                            }
                        } else if let latestError = latestState.error {
                            if let lastResultValue = lastResultState.cacheCompatibleValue(for: loadImpulse) {
                                return DatasourceState.error(error: latestError, loadImpulse: loadImpulse, fallbackValue: lastResultValue.value)
                            } else {
                                return DatasourceState.error(error: latestError, loadImpulse: loadImpulse, fallbackValue: nil)
                            }
                        } else {
                            // Latest state might not match current parameters - return .notReady
                            // so all cached data is purged. This can happen if e.g. an authenticated API
                            // request has been made, but the user has logged out in the meantime. The result
                            // must be discarded or the next logged in user might see the previous user's data.
                            return DatasourceState.notReady
                        }
                    }
            }
            
    }

}

public extension DatasourceProtocol {
    
    public typealias LastResultRetaining = LastResultRetainingDatasource<Value, P, E>
    
    public var retainLastResult: LastResultRetaining {
        return LastResultRetaining(innerDatasource: self.any)
    }
}
