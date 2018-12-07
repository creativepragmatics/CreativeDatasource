import Foundation

public protocol StatePersister {
    associatedtype State: StateProtocol
    
    func persist(_ state: State)
    func load(_ parameters: State.P) -> State?
    func purge()
}

public extension StatePersister {
    var any: AnyStatePersister<State> {
        return AnyStatePersister(self)
    }
}

public struct AnyStatePersister<State_: StateProtocol> : StatePersister {
    public typealias State = State_
    
    private let _persist: (State) -> ()
    private let _load: (State.P) -> State?
    private let _purge: () -> ()
    
    public init<SP: StatePersister>(_ persister: SP) where SP.State == State {
        self._persist = persister.persist
        self._load = persister.load
        self._purge = persister.purge
    }
    
    public func persist(_ state: State) {
        _persist(state)
    }
    
    public func load(_ parameters: State.P) -> State? {
        return _load(parameters)
    }
    
    public func purge() {
        _purge()
    }
}

