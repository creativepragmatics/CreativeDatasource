import Foundation
import ReactiveSwift
import Result

/// Combines responses, if necessary, retrieved by a datasource.
/// E.g. for endless scrolling, upcoming responses are appended to the previous
/// ones, and all responses together form the final result that is rendered to the user.
/// In case each new response supersedes all other responses (for a simple pull-to-refresh list),
/// the combiner need not do much (SupersedingResponseCombiner).
public protocol ResponseCombiner {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype LIT: LoadImpulseType
    associatedtype E: DatasourceError
    typealias CompositeStateConcrete = CompositeState<Value, P, LIT, E>
    
    func combinedState(datasource: DatasourceBox<Value, P, LIT, E>) -> SignalProducer<CompositeStateConcrete, NoError>
}

public extension ResponseCombiner {
    var boxed: ResponseCombinerBox<Value, P, LIT, E> {
        return ResponseCombinerBox(self)
    }
}

public struct ResponseCombinerBox<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError>: ResponseCombiner {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    public typealias CompositeStateConcrete = CompositeState<Value, P, LIT, E>
    
    private let _combinedState: (DatasourceBox<Value, P, LIT, E>) -> SignalProducer<CompositeStateConcrete, NoError>
    
    init<RC: ResponseCombiner>(_ responseCombiner: RC) where RC.Value == Value, RC.P == P, RC.LIT == LIT, RC.E == E {
        self._combinedState = responseCombiner.combinedState
    }
    
    public func combinedState(datasource: DatasourceBox<Value, P, LIT, E>) -> SignalProducer<CompositeStateConcrete, NoError> {
        return _combinedState(datasource)
    }
}

public struct SupersedingResponseCombiner<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError> : ResponseCombiner {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    public typealias CompositeStateConcrete = CompositeState<Value, P, LIT, E>
    
    public init() { }
    
    public func combinedState(datasource: DatasourceBox<Value, P, LIT, E>) -> SignalProducer<CompositeStateConcrete, NoError> {
        return datasource.state.map({ state -> CompositeStateConcrete in
            return CompositeState.with(state) // just return the new state, purging all previous ones
        })
    }
}

public protocol Combinable {
    static func +(lhs: Self, rhs: Self) -> Self
}

extension Array: Combinable { }
