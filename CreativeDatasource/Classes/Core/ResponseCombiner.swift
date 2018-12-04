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
    typealias CachedStateConcrete = CachedState<Value, P, LIT, E>
    
    func combinedState(datasource: AnyDatasource<Value, P, LIT, E>) -> SignalProducer<CachedStateConcrete, NoError>
}

public extension ResponseCombiner {
    public var any: AnyResponseCombiner<Value, P, LIT, E> {
        return AnyResponseCombiner(self)
    }
}

public struct AnyResponseCombiner<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError>: ResponseCombiner {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    public typealias CachedStateConcrete = CachedState<Value, P, LIT, E>
    
    private let _combinedState: (AnyDatasource<Value, P, LIT, E>) -> SignalProducer<CachedStateConcrete, NoError>
    
    init<RC: ResponseCombiner>(_ responseCombiner: RC) where RC.Value == Value, RC.P == P, RC.LIT == LIT, RC.E == E {
        self._combinedState = responseCombiner.combinedState
    }
    
    public func combinedState(datasource: AnyDatasource<Value, P, LIT, E>) -> SignalProducer<CachedStateConcrete, NoError> {
        return _combinedState(datasource)
    }
}

public struct SupersedingResponseCombiner<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError> : ResponseCombiner {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    public typealias CachedStateConcrete = CachedState<Value, P, LIT, E>
    
    public init() { }
    
    public func combinedState(datasource: AnyDatasource<Value, P, LIT, E>) -> SignalProducer<CachedStateConcrete, NoError> {
        return datasource.state.map({ state -> CachedStateConcrete in
            return CachedState.with(state) // just return the new state, purging all previous ones
        })
    }
}

public protocol Combinable {
    static func +(lhs: Self, rhs: Self) -> Self
}

extension Array: Combinable { }
