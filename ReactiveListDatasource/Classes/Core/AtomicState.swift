import Foundation
import Result

public enum AtomicState<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError>: StateProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    
    case datasourceNotReady
    case loading(loadImpulse: LoadImpulse<P, LIT>)
    case success(valueBox: StrongEqualityValueBox<Value>, loadImpulse: LoadImpulse<P, LIT>)
    case error(error: E, loadImpulse: LoadImpulse<P, LIT>)
    
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
        case let .loading(impulse): return impulse
        case let .success(_, impulse): return impulse
        case let .error(_, impulse): return impulse
        }
    }
    
    public var value: StrongEqualityValueBox<Value>? {
        switch self {
        case .datasourceNotReady, .loading, .error: return nil
        case let .success(valueBox, _): return valueBox
        }
    }
    
    public var error: E? {
        switch self {
        case .datasourceNotReady, .loading, .success: return nil
        case let .error(error, _): return error
        }
    }
    
    public init(notReadyProvisioningState: ProvisioningState) {
        self = AtomicState.datasourceNotReady
    }
    
    public init(error: E, loadImpulse: LoadImpulse<P, LIT>) {
        self = AtomicState.error(error: error, loadImpulse: loadImpulse)
    }
    
}

extension AtomicState : Codable where Value: Codable, LIT: Codable, P: Codable, E: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case enumCase
        case loadImpulse
        case value
        case error
    }
    
    private enum Case: String {
        case initial
        case loading
        case success
        case error
        
        static func with(_ state: AtomicState) -> Case {
            switch state {
            case .datasourceNotReady: return .initial
            case .loading: return .loading
            case .success: return .success
            case .error: return .error
            }
        }
        
        func state(loadImpulse: LoadImpulse<P, LIT>?, value: Value?, error: E?) -> AtomicState? {
            switch self {
            case .initial:
                return .datasourceNotReady
            case .loading:
                if let loadImpulse = loadImpulse {
                    return AtomicState<Value, P, LIT, E>.loading(loadImpulse: loadImpulse)
                } else {
                    return nil
                }
            case .success:
                if let value = value, let loadImpulse = loadImpulse {
                    return AtomicState<Value, P, LIT, E>.success(valueBox: StrongEqualityValueBox(value), loadImpulse: loadImpulse)
                } else {
                    return nil
                }
            case .error:
                if let error = error, let loadImpulse = loadImpulse {
                    return AtomicState<Value, P, LIT, E>.error(error: error, loadImpulse: loadImpulse)
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
            
            if let state = enumCase.state(loadImpulse: loadImpulse, value: value, error: error) {
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
        case let .loading(loadImpulse):
            try container.encode(loadImpulse, forKey: .loadImpulse)
        case let .success(value, _):
            try container.encode(value.value, forKey: .value)
            try container.encode(loadImpulse, forKey: .loadImpulse)
        case let .error(error, _):
            try container.encode(error, forKey: .error)
            try container.encode(loadImpulse, forKey: .loadImpulse)
        }
    }
}
