import Foundation
import Result

/// Consists of a primary state and a fallback state. Fallback
/// is only relevant for .loading and .error states, when the
/// primary state does not provide meaningful information.
public enum CompositeState<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError>: StateProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    
    case datasourceNotReady
    case loading(fallback: StrongEqualityValueBox<Value>?, loadImpulse: LoadImpulse<P, LIT>)
    case success(valueBox: StrongEqualityValueBox<Value>, loadImpulse: LoadImpulse<P, LIT>)
    case error(error: E, fallback: StrongEqualityValueBox<Value>?, loadImpulse: LoadImpulse<P, LIT>)
    
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
    
    public var value: StrongEqualityValueBox<Value>? {
        switch self {
        case .datasourceNotReady: return nil
        case let .loading(valueBox, _): return valueBox
        case let .success(valueBox, _): return valueBox
        case let .error(_, valueBox, _): return valueBox
        }
    }
    
    public var error: E? {
        switch self {
        case .datasourceNotReady, .loading, .success: return nil
        case let .error(error, _, _): return error
        }
    }
    
    public init(notReadyProvisioningState: ProvisioningState) {
        self = CompositeState.datasourceNotReady
    }
    
    public init(error: E, loadImpulse: LoadImpulse<P, LIT>) {
        self = CompositeState.error(error: error, fallback: nil, loadImpulse: loadImpulse)
    }
    
}
