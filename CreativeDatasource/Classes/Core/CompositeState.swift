import Foundation

public enum CompositeState<Value: Any, P: Parameters, LIT: LoadImpulseType, E: DatasourceError>: Equatable {
    case datasourceNotReady
    case loading(cached: StrongEqualityValueBox<Value>?, loadImpulse: LoadImpulse<P, LIT>)
    case success(valueBox: StrongEqualityValueBox<Value>, loadImpulse: LoadImpulse<P, LIT>)
    case error(error: E, cached: StrongEqualityValueBox<Value>?, loadImpulse: LoadImpulse<P, LIT>)
    
    /// Checked access to value
    func value(_ parameters: P) -> StrongEqualityValueBox<Value>? {
        switch self {
        case .datasourceNotReady:
            return nil
        case let .loading(cached, loadImpulse) where loadImpulse.parameters.isCacheCompatible(parameters):
            return cached
        case let .success(value, loadImpulse) where loadImpulse.parameters.isCacheCompatible(parameters):
            return value
        case let .error(_, cached, loadImpulse) where loadImpulse.parameters.isCacheCompatible(parameters):
            return cached
        case .success, .loading, .error:
            return nil
        }
    }
    
    /// Unchecked access to value. Discouraged.
    var valueUnchecked: Value? {
        switch self {
        case .datasourceNotReady:
            return nil
        case let .loading(cached, _):
            return cached?.value
        case let .success(value, _):
            return value.value
        case let .error(_, cached, _):
            return cached?.value
        }
    }
    
    static func with(_ state: State<Value, P, LIT, E>) -> CompositeState {
        switch state {
        case .datasourceNotReady: return .datasourceNotReady
        case let .loading(loadImpulse): return .loading(cached: nil, loadImpulse: loadImpulse)
        case let .success(value, loadImpulse): return .success(valueBox: value, loadImpulse: loadImpulse)
        case let .error(error, loadImpulse): return .error(error: error, cached: nil, loadImpulse: loadImpulse)
        }
    }
    
    var loadImpulse: LoadImpulse<P, LIT>? {
        switch self {
        case .datasourceNotReady:
            return nil
        case let .loading(_, loadImpulse):
            return loadImpulse
        case let .success(_, loadImpulse):
            return loadImpulse
        case let .error(_, _, loadImpulse):
            return loadImpulse
        }
    }
    
    var parameters: P? {
        return loadImpulse?.parameters
    }
    
    public static func == (lhs: CompositeState, rhs: CompositeState) -> Bool {
        switch (lhs, rhs) {
        case (.datasourceNotReady, .datasourceNotReady):
            return true
        case (.loading(let lhs), .loading(let rhs)):
            if lhs.loadImpulse != rhs.loadImpulse { return false }
            if lhs.cached != rhs.cached { return false }
            return true
        case (.success(let lhs), .success(let rhs)):
            if lhs.loadImpulse != rhs.loadImpulse { return false }
            if lhs.valueBox != rhs.valueBox { return false }
            return true
        case (.error(let lhs), .error(let rhs)):
            if lhs.error != rhs.error { return false }
            if lhs.loadImpulse != rhs.loadImpulse { return false }
            if lhs.cached != rhs.cached { return false }
            return true
        default: return false
        }
    }
    

}
