import Foundation
import ReactiveSwift
import Result

public protocol Datasource {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype LIT: LoadImpulseType
    associatedtype E: DatasourceError
    typealias StateConcrete = State<Value, P, LIT, E>
    
    var state: SignalProducer<StateConcrete, NoError> {get}
    
    /// Must return `true` if the datasource sends a `state`
    /// immediately on subscription.
    var sendsFirstStateSynchronously: Bool {get}
}

public extension Datasource {
    var boxed: DatasourceBox<Value, P, LIT, E> {
        return DatasourceBox(self)
    }
}

public struct DatasourceBox<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError>: Datasource {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    public typealias StateConcrete = State<Value, P, LIT, E>
    
    public let state: SignalProducer<StateConcrete, NoError>
    public let sendsFirstStateSynchronously: Bool
    
    init<D: Datasource>(_ datasource: D) where D.Value == Value, D.P == P, D.LIT == LIT, D.E == E {
        self.state = datasource.state
        self.sendsFirstStateSynchronously = datasource.sendsFirstStateSynchronously
    }
}

public protocol DatasourceError: Error, Equatable { }
