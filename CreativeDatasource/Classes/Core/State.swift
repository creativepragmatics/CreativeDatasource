import Foundation

public enum State<Value: Any, P: Parameters, LIT: LoadImpulseType, E: DatasourceError>: Equatable {
    case datasourceNotReady
    case loading(loadImpulse: LoadImpulse<P, LIT>)
    case success(valueBox: StrongEqualityValueBox<Value>, loadImpulse: LoadImpulse<P, LIT>)
    case error(error: E, loadImpulse: LoadImpulse<P, LIT>)
    
    func value(_ parameters: P) -> StrongEqualityValueBox<Value>? {
        switch self {
        case let .success(value, loadImpulse) where loadImpulse.parameters.isCacheCompatible(parameters):
            return value
        case .datasourceNotReady, .loading, .success, .error:
            return nil
        }
    }
    
    var loadImpulse: LoadImpulse<P, LIT>? {
        switch self {
        case .datasourceNotReady:
            return nil
        case let .loading(loadImpulse):
            return loadImpulse
        case let .success(_, loadImpulse):
            return loadImpulse
        case let .error(_, loadImpulse):
            return loadImpulse
        }
    }
    
    var parameters: P? {
        return loadImpulse?.parameters
    }
    
    public static func == (lhs: State, rhs: State) -> Bool {
        switch (lhs, rhs) {
        case (.datasourceNotReady, .datasourceNotReady):
            return true
        case (.loading(let lhs), .loading(let rhs)):
            return lhs == rhs
        case (.success(let lhs), .success(let rhs)):
            if lhs.valueBox != rhs.valueBox { return false }
            if lhs.loadImpulse != rhs.loadImpulse { return false }
            return true
        case (.error(let lhs), .error(let rhs)):
            if lhs.error != rhs.error { return false }
            if lhs.loadImpulse != rhs.loadImpulse { return false }
            return true
        default: return false
        }
    }
}

extension State : Codable where Value: Codable, LIT: Codable, P: Codable, E: Codable {
    
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
        
        static func with(_ state: State) -> Case {
            switch state {
            case .datasourceNotReady: return .initial
            case .loading: return .loading
            case .success: return .success
            case .error: return .error
            }
        }
        
        func state(loadImpulse: LoadImpulse<P, LIT>?, value: Value?, error: E?) -> State? {
            switch self {
            case .initial:
                return .datasourceNotReady
            case .loading:
                if let loadImpulse = loadImpulse {
                    return State<Value, P, LIT, E>.loading(loadImpulse: loadImpulse)
                } else {
                    return nil
                }
            case .success:
                if let value = value, let loadImpulse = loadImpulse {
                    return State<Value, P, LIT, E>.success(valueBox: StrongEqualityValueBox(value), loadImpulse: loadImpulse)
                } else {
                    return nil
                }
            case .error:
                if let error = error, let loadImpulse = loadImpulse {
                    return State<Value, P, LIT, E>.error(error: error, loadImpulse: loadImpulse)
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
