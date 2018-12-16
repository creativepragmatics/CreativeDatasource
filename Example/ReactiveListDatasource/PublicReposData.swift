import Foundation
import ReactiveListDatasource

struct PublicReposData {
    typealias DatasourceBundle = DefaultCachedAPICallDatasourceBundle<PublicReposPrimaryDatasource>
    
    let datasourceBundle: DatasourceBundle
    
    public init() {
        
        let initialLoadImpulse = LoadImpulse(parameters: VoidParameters())
        self.datasourceBundle = DefaultCachedAPICallDatasourceBundle.init(primaryDatasourceGenerator: { loadImpulseEmitter in
            return PublicReposPrimaryDatasource(loadImpulseEmitter: loadImpulseEmitter.any)
        }, initialLoadImpulse: initialLoadImpulse, cacheKey: "public_repos")
    }
    
    func refreshPublicRepos() {
        let loadImpulse = LoadImpulse(parameters: VoidParameters())
        let _ = datasourceBundle.cachedDatasource.load(loadImpulse)
    }
    
}
