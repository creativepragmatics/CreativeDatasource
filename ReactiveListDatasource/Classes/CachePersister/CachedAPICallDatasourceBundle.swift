public protocol CachedAPICallDatasourceBundleProtocol {
    associatedtype APICallDatasource: PersistableStateDatasource
    typealias APICallState = APICallDatasource.State
    typealias LastResultRetainingAPICallState = APICallDatasource.LastResultRetaining.State
    typealias CachedDatasourceConcrete = CachedDatasource<LastResultRetainingAPICallState>
    typealias LoadImpulseEmitterConcrete = RecurringLoadImpulseEmitter<LastResultRetainingAPICallState.P, LastResultRetainingAPICallState.LIT>
    
    var apiCallDatasource: APICallDatasource {get}
    var cachedDatasource: CachedDatasourceConcrete {get}
    var loadImpulseEmitter: LoadImpulseEmitterConcrete {get}
    var persister: DiskStatePersister<LastResultRetainingAPICallState>? {get}
}

public protocol PersistableStateDatasource: DatasourceProtocol {
    associatedtype State: Codable where State.Value: Codable, State.P: Codable, State.LIT: Codable, State.E: Codable & CachedDatasourceError
}

/// Pure convenience bundle of:
/// - API call datasource whose last success state is retained when a reload
///     occurs (`.retainLastResult` applied).
/// - Disk state persister (for writing success states to disk)
/// - Cached datasource
///
public struct DefaultCachedAPICallDatasourceBundle<APICallDatasource_: PersistableStateDatasource>: CachedAPICallDatasourceBundleProtocol {
    public typealias APICallDatasource = APICallDatasource_
    public typealias LoadImpulseEmitterConcrete = RecurringLoadImpulseEmitter<LastResultRetainingAPICallState.P, LastResultRetainingAPICallState.LIT>
    public typealias CachedDatasourceConcrete = CachedDatasource<LastResultRetainingAPICallState>
    
    public let apiCallDatasource: APICallDatasource
    public let cachedDatasource: CachedDatasourceConcrete
    public let loadImpulseEmitter: LoadImpulseEmitterConcrete
    public let persister: DiskStatePersister<APICallDatasource.LastResultRetaining.State>? // optional because init can fail
    
    public init(primaryDatasourceGenerator: (LoadImpulseEmitterConcrete) -> APICallDatasource, initialLoadImpulse: LoadImpulse<APICallDatasource.State.P, APICallDatasource.State.LIT>?, cacheKey: String) {
        
        let diskStatePersister = DiskStatePersister<LastResultRetainingAPICallState>(key: cacheKey)
        let loadImpulseEmitter = LoadImpulseEmitterConcrete.init(emitInitially: initialLoadImpulse)
        let primaryDatasource = primaryDatasourceGenerator(loadImpulseEmitter)
        let cacheLoadError = APICallDatasource.State.E.init(cacheLoadError: .default)
        let cacheDatasource = PlainCacheDatasource.init(persister: diskStatePersister.any, loadImpulseEmitter: loadImpulseEmitter.any, cacheLoadError: cacheLoadError)
        let lastResultRetainingPrimaryDatasource = primaryDatasource.retainLastResult
        
        self.cachedDatasource = CachedDatasourceConcrete(loadImpulseEmitter: loadImpulseEmitter.any, primaryDatasource: lastResultRetainingPrimaryDatasource.any, cacheDatasource: cacheDatasource.any, persister: diskStatePersister.any)
        self.apiCallDatasource = primaryDatasource
        self.persister = diskStatePersister
        self.loadImpulseEmitter = loadImpulseEmitter
    }
}
