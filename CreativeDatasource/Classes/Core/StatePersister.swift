import Foundation

public protocol StatePersister {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype LIT: LoadImpulseType
    associatedtype E: DatasourceError
    typealias StateConcrete = State<Value, P, LIT, E>
    
    func persist(_ state: StateConcrete)
    func load(_ parameters: P) -> StateConcrete?
    func purge()
}

public extension StatePersister {
    var any: AnyStatePersister<Value, P, LIT, E> {
        return AnyStatePersister(self)
    }
}

public struct AnyStatePersister<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError> : StatePersister {
    public typealias Value = Value_
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias E = E_
    public typealias StateConcrete = State<Value, P, LIT, E>
    
    private let _persist: (StateConcrete) -> ()
    private let _load: (P) -> StateConcrete?
    private let _purge: () -> ()
    
    public init<SP: StatePersister>(_ persister: SP) where SP.Value == Value, SP.P == P, SP.LIT == LIT, SP.E == E {
        self._persist = persister.persist
        self._load = persister.load
        self._purge = persister.purge
    }
    
    public func persist(_ state: StateConcrete) {
        _persist(state)
    }
    
    public func load(_ parameters: P) -> StateConcrete? {
        return _load(parameters)
    }
    
    public func purge() {
        _purge()
    }
}

