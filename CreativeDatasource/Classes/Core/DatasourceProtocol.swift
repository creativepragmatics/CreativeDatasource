import Foundation
import ReactiveSwift
import Result

public protocol DatasourceProtocol {
    associatedtype State: StateProtocol
    
    var state: SignalProducer<State, NoError> {get}
    
    /// Must return `true` if the datasource sends a `state`
    /// immediately on subscription.
    var loadsSynchronously: Bool {get}
}

public extension DatasourceProtocol {
    public var any: AnyDatasource<State> {
        return AnyDatasource(self)
    }
    
    public var anyState: SignalProducer<AnyState<State.Value, State.P, State.LIT, State.E>, NoError> {
        return self.state.map({ $0.any })
    }
    
    var stateWithSynchronousInitial: SignalProducer<State, NoError> {
        if loadsSynchronously {
            return state
        } else {
            let initialState = SignalProducer(value: State(notReadyProvisioningState: .notReady))
            return initialState.concat(state)
        }
    }
}

public struct AnyDatasource<State_: StateProtocol>: DatasourceProtocol {
    public typealias State = State_
    
    public let state: SignalProducer<State, NoError>
    public let loadsSynchronously: Bool
    
    init<D: DatasourceProtocol>(_ datasource: D) where D.State == State {
        self.state = datasource.state
        self.loadsSynchronously = datasource.loadsSynchronously
    }
}

public protocol DatasourceError: Error, Equatable {
    
    var errorType: DatasourceErrorType {get}
}

public enum DatasourceErrorType: Equatable, Codable {
    case `default`
    case message(String)
    
    enum CodingKeys: String, CodingKey {
        case enumCaseKey = "type"
        case `default`
        case message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let enumCaseString = try container.decode(String.self, forKey: .enumCaseKey)
        guard let enumCase = CodingKeys(rawValue: enumCaseString) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case '\(enumCaseString)'"))
        }
        
        switch enumCase {
        case .default:
            self = .default
        case .message:
            if let message = try? container.decode(String.self, forKey: .message) {
                self = .message(message)
            } else {
                self = .default
            }
        default: throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case '\(enumCase)'"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .message(message):
            try container.encode(CodingKeys.message.rawValue, forKey: .enumCaseKey)
            try container.encode(message, forKey: .message)
        case .default:
            try container.encode(CodingKeys.default.rawValue, forKey: .enumCaseKey)
        }
    }
}

public protocol CachedDatasourceError: DatasourceError {
    
    init(cacheLoadError type: DatasourceErrorType)
}
