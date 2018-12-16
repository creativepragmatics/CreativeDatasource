import Foundation
import ReactiveListDatasource
import ReactiveSwift
import Result

class PublicReposViewModel {
    typealias DatasourceBundle = DefaultCachedAPICallDatasourceBundle<PublicReposPrimaryDatasource>
    
    let datasourceBundle: DatasourceBundle
    
    public init() {
        let initialLoadImpulse = LoadImpulse(parameters: VoidParameters())
        self.datasourceBundle = DefaultCachedAPICallDatasourceBundle.init(primaryDatasourceGenerator: { loadImpulseEmitter in
            return PublicReposPrimaryDatasource(loadImpulseEmitter: loadImpulseEmitter.any)
        }, initialLoadImpulse: initialLoadImpulse, cacheKey: "public_repos")
    }
    
    @discardableResult
    func refresh() -> LoadingStarted {
        let loadImpulse = LoadImpulse(parameters: VoidParameters())
        return datasourceBundle.cachedDatasource.load(loadImpulse)
    }
    
    var loadingEnded: SignalProducer<Void, NoError> {
        return datasourceBundle.cachedDatasource.loadingEnded
    }
    
}

