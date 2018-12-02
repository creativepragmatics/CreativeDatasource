import Foundation

public protocol StatePersister {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype LIT: LoadImpulseType
    associatedtype E: DatasourceError
    typealias StateConcrete = State<Value, P, LIT, E>
    
    func persist(_ state: StateConcrete)
    func load() -> StateConcrete?
}

public extension StatePersister {
    var boxed: StatePersisterBox<Value, P, LIT, E> {
        return StatePersisterBox(self)
    }
}

public struct StatePersisterBox<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError> : StatePersister {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    public typealias StateConcrete = State<Value, P, LIT, E>
    
    private let _persist: (StateConcrete) -> ()
    private let _load: () -> StateConcrete?
    
    public init<SP: StatePersister>(_ persister: SP) where SP.Value == Value, SP.P == P, SP.LIT == LIT, SP.E == E {
        self._persist = persister.persist
        self._load = persister.load
    }
    
    public func persist(_ state: StateConcrete) {
        _persist(state)
    }
    
    public func load() -> StateConcrete? {
        return _load()
    }
}

