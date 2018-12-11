import Foundation
import Cache

public struct DiskStatePersister<State_: StateProtocol & Codable>: StatePersister {
    public typealias State = State_
    
    public typealias StatePersistenceKey = String
    
    private let key: StatePersistenceKey
    private let storage: Storage<State>?
    
    public init(key: StatePersistenceKey, storage: Storage<State>?) {
        self.key = key
        self.storage = storage
    }
    
    public init(key: StatePersistenceKey, diskConfig: DiskConfig? = nil, memoryConfig: MemoryConfig? = nil) {
        
        var fallbackDiskConfig: DiskConfig {
            return DiskConfig(name: key)
        }
        
        var fallbackMemoryConfig: MemoryConfig {
            return MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)
        }
        
        var transformer: Transformer<State> {
            return Transformer.init(toData: { state -> Data in
                return try JSONEncoder().encode(state)
            }, fromData: { data -> State in
                return try JSONDecoder().decode(State.self, from: data)
            })
        }
        
        let storage = try? Storage<State>.init(diskConfig: diskConfig ?? fallbackDiskConfig, memoryConfig: memoryConfig ?? fallbackMemoryConfig, transformer: transformer)
        
        self.init(key: key, storage: storage)
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
