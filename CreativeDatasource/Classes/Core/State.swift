import Foundation
import Result

public protocol StateProtocol: Equatable {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype LIT: LoadImpulseType
    associatedtype E: DatasourceError
    
    var provisioningState: ProvisioningState {get}
    var loadImpulse: LoadImpulse<P, LIT>? {get}
    var value: StrongEqualityValueBox<Value>? {get}
    var error: E? {get}
    
    /// Creates an initial state with `provisioningState` == `.notReady`.
    /// Workaround since generic static vars or functions would not work
    /// with AnyState.
    init(notReadyProvisioningState: ProvisioningState)
    
    /// Creates an error state.
    init(error: E, loadImpulse: LoadImpulse<P, LIT>)
}

public extension StateProtocol {
    
    var hasLoadedSuccessfully: Bool {
        switch provisioningState {
        case .loading, .notReady:
            return false
        case .result:
            return value?.value != nil && error == nil
        }
    }
}

public enum ProvisioningState: Equatable {
    case notReady
    case loading
    case result
}

public class AnyState<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError>: StateProtocol {
    
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    
    public let provisioningState: ProvisioningState
    public let loadImpulse: LoadImpulse<P, LIT>?
    public let value: StrongEqualityValueBox<Value>?
    public let error: E?
    
    init<S: StateProtocol>(_ state: S) where S.Value == Value, S.P == P, S.LIT == LIT, S.E == E {
        self.provisioningState = state.provisioningState
        self.loadImpulse = state.loadImpulse
        self.value = state.value
        self.error = state.error
    }
    
    public required init(notReadyProvisioningState: ProvisioningState) {
        self.provisioningState = notReadyProvisioningState
        self.loadImpulse = nil
        self.value = nil
        self.error = nil
    }
    
    public required init(error: E, loadImpulse: LoadImpulse<P, LIT>) {
        self.provisioningState = .result
        self.loadImpulse = loadImpulse
        self.error = error
        self.value = nil
    }
    
    public static func == (lhs: AnyState<Value_, P_, LIT_, E_>, rhs: AnyState<Value_, P_, LIT_, E_>) -> Bool {
        guard lhs.provisioningState == rhs.provisioningState else { return false}
        guard lhs.loadImpulse == rhs.loadImpulse else { return false}
        
        let valueEqual: Bool = {
            switch (lhs.value, rhs.value) {
            case let (lValue?, rValue?):
                return lValue == rValue
            case (nil, nil):
                return true
            default:
                return false
            }
        }()
        
        guard valueEqual else { return false }
        
        let errorEqual: Bool = {
            switch (lhs.error, rhs.error) {
            case let (lValue?, rValue?):
                return lValue == rValue
            case (nil, nil):
                return true
            default:
                return false
            }
        }()
        
        guard errorEqual else { return false }
        
        return true
    }

}
