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
    case loading(fallbackValue: StrongEqualityValueBox<Value>?, fallbackError: E?, loadImpulse: LoadImpulse<P, LIT>)
    case success(valueBox: StrongEqualityValueBox<Value>, loadImpulse: LoadImpulse<P, LIT>)
    case error(error: E, fallbackValue: StrongEqualityValueBox<Value>?, loadImpulse: LoadImpulse<P, LIT>)
    
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
        case let .loading(_, _, impulse): return impulse
        case let .success(_, impulse): return impulse
        case let .error(_, _, impulse): return impulse
        }
    }
    
    public var value: StrongEqualityValueBox<Value>? {
        switch self {
        case .datasourceNotReady: return nil
        case let .loading(valueBox, _, _): return valueBox
        case let .success(valueBox, _): return valueBox
        case let .error(_, valueBox, _): return valueBox
        }
    }
    
    public var error: E? {
        switch self {
        case .datasourceNotReady, .success: return nil
        case let .loading(_, fallbackError, _): return fallbackError
        case let .error(error, _, _): return error
        }
    }
    
    public init(notReadyProvisioningState: ProvisioningState) {
        self = CompositeState.datasourceNotReady
    }
    
    public init(error: E, loadImpulse: LoadImpulse<P, LIT>) {
        self = CompositeState.error(error: error, fallbackValue: nil, loadImpulse: loadImpulse)
    }
    
}

extension CompositeState : Codable where Value: Codable, LIT: Codable, P: Codable, E: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case enumCase
        case loadImpulse
        case value
        case error
    }
    
    private enum Case: String {
        case datasourceNotReady
        case loading
        case success
        case error
        
        static func with(_ state: CompositeState) -> Case {
            switch state {
            case .datasourceNotReady: return .datasourceNotReady
            case .loading: return .loading
            case .success: return .success
            case .error: return .error
            }
        }
        
        func state(loadImpulse: LoadImpulse<P, LIT>?, value: StrongEqualityValueBox<Value>?, error: E?) -> CompositeState? {
            switch self {
            case .datasourceNotReady:
                return .datasourceNotReady
            case .loading:
                if let loadImpulse = loadImpulse {
                    return CompositeState.loading(fallbackValue: value, fallbackError: error, loadImpulse: loadImpulse)
                } else {
                    return nil
                }
            case .success:
                if let value = value, let loadImpulse = loadImpulse {
                    return CompositeState.success(valueBox: value, loadImpulse: loadImpulse)
                } else {
                    return nil
                }
            case .error:
                if let error = error, let loadImpulse = loadImpulse {
                    return CompositeState.error(error: error, fallbackValue: value, loadImpulse: loadImpulse)
                } else {
                    return nil
                }
            }
        }
    }
    
    enum StateCodingError: Error {
        case decoding(String)
        case decodingLowLevel(Error)
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        guard let caseString = try? values.decode(String.self, forKey: .enumCase),
            let enumCase = Case(rawValue: caseString) else {
                throw StateCodingError.decoding("StateCodingError: \(dump(values))")
        }
        
        do {
            let loadImpulse = try values.decodeIfPresent(LoadImpulse<P, LIT>.self, forKey: .loadImpulse)
            let value = try values.decodeIfPresent(Value.self, forKey: .value)
            let error = try values.decodeIfPresent(E.self, forKey: .error)
            
            if let state = enumCase.state(loadImpulse: loadImpulse, value: value.map({ StrongEqualityValueBox($0) }), error: error) {
                self = state
            } else {
                throw StateCodingError.decoding("StateCodingError: \(dump(values))")
            }
        } catch {
            throw StateCodingError.decodingLowLevel(error)
        }
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let enumCase = Case.with(self)
        try container.encode(enumCase.rawValue, forKey: .enumCase)
        
        switch self {
        case .datasourceNotReady:
            break
        case let .loading(fallbackValue, fallbackError, loadImpulse):
            try container.encode(loadImpulse, forKey: .loadImpulse)
            if let value = fallbackValue {
                try container.encode(value.value, forKey: .value)
            }
            if let error = fallbackError {
                try container.encode(error, forKey: .error)
            }
        case let .success(valueBox, loadImpulse):
            try container.encode(loadImpulse, forKey: .loadImpulse)
            try container.encode(valueBox.value, forKey: .value)
        case let .error(error, fallbackValue, loadImpulse):
            try container.encode(loadImpulse, forKey: .loadImpulse)
            try container.encode(error, forKey: .error)
            if let value = fallbackValue {
                try container.encode(value.value, forKey: .value)
            }
        }
    }
}
