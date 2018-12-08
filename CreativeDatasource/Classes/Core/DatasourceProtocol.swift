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

public enum DatasourceErrorType: Equatable {
    case `default`
    case message(String)
}
