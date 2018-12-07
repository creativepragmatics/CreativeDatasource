import Foundation
import Cache

public struct DiskStatePersister<State_: StateProtocol & Codable>: StatePersister {
    public typealias State = State_
    
    public typealias StatePersistenceKey = String
    
    private let key: StatePersistenceKey
    
    private let transformer: Transformer<State> = {
        return Transformer.init(toData: { state -> Data in
            return try JSONEncoder().encode(state)
        }, fromData: { data -> State in
            return try JSONDecoder().decode(State.self, from: data)
        })
    }()
    
    private let storage: Storage<State>?
    
    public init(key: StatePersistenceKey) {
        self.key = key
        
        let diskConfig = DiskConfig(name: self.key)
        let memoryConfig = MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)
        self.storage = try? Storage<State>.init(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: self.transformer)
    }
    
    public func persist(_ state: State) {
        try? storage?.setObject(state, forKey: "latestValue")
    }
    
    public func load(_ parameters: State.P) -> State? {
        guard let storage = self.storage else {
            return nil
        }
        
        do {
            let state = try storage.object(forKey: "latestValue")
            if (state.loadImpulse?.parameters.isCacheCompatible(parameters) ?? false) {
                return state
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    public func purge() {
        try? storage?.removeAll()
    }
    
}
