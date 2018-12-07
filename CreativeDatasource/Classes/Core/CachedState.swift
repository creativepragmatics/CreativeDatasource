import Foundation
import Result

public enum CachedState<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError>: StateProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    
    case datasourceNotReady
    case loading(cached: StrongEqualityValueBox<Value>?, loadImpulse: LoadImpulse<P, LIT>)
    case success(valueBox: StrongEqualityValueBox<Value>, loadImpulse: LoadImpulse<P, LIT>)
    case error(error: E, cached: StrongEqualityValueBox<Value>?, loadImpulse: LoadImpulse<P, LIT>)
    
    public var provisioningState: ProvisioningState {
        switch self {
        case .datasourceNotReady: return .notReady
        case .loading: return .loading
        case .success, .error: return .result
        }
    }
    
    public var loadImpulse: LoadImpulse<P, LIT>? {
        switch self {
        case .datasourceNotReady: return nil
        case let .loading(_, impulse): return impulse
        case let .success(_, impulse): return impulse
        case let .error(_, _, impulse): return impulse
        }
    }
    
    public var result: Result<StrongEqualityValueBox<Value>, E>? {
        switch self {
        case .datasourceNotReady: return nil
        case let .loading(cached, _): return cached.map({ .success($0) })
        case let .success(valueBox, impulse): return .success(valueBox)
        case let .error(error, _, _): return .failure(error)
        }
    }
    
    public init(notReadyProvisioningState: ProvisioningState) {
        self = CachedState.datasourceNotReady
    }
    
    public init(error: E, loadImpulse: LoadImpulse<P, LIT>) {
        self = CachedState.error(error: error, cached: nil, loadImpulse: loadImpulse)
    }
    
}
