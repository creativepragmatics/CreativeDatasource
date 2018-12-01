import Foundation
import Cache

public struct DiskStatePersister<T: Codable, P: Parameters, LIT: LoadImpulseType, E: DatasourceError>: StatePersister {
    
    public typealias StatePersistenceKey = String
    private typealias PersistedState = State<T, P, LIT, E>
    
    private let key: StatePersistenceKey
    
    private let transformer: Transformer<PersistedState> = {
        return Transformer.init(toData: { state -> Data in
            return try JSONEncoder().encode(state)
        }, fromData: { data -> PersistedState in
            return try JSONDecoder().decode(PersistedState.self, from: data)
        })
    }()
    
    private let storage: Storage<PersistedState>?
    
    public init(key: StatePersistenceKey) {
        self.key = key
        
        let diskConfig = DiskConfig(name: self.key)
        let memoryConfig = MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)
        self.storage = try? Storage<PersistedState>.init(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: self.transformer)
    }
    
    public func persist(_ state: State<T, P, LIT, E>) {
        try? storage?.setObject(state, forKey: "latestValue")
    }
    
    public func load() -> State<T, P, LIT, E>? {
        guard let storage = self.storage else {
            return nil
        }
        
        do {
            return try storage.object(forKey: "latestValue")
        } catch {
            return nil
        }
    }
    
}
