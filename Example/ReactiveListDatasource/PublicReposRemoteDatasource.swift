import Foundation
import ReactiveSwift
import Result
import ReactiveListDatasource

struct PublicReposPrimaryDatasource : PersistableStateDatasource {
    typealias Value = PublicReposResponseContainer
    typealias P = VoidParameters
    typealias E = APIError
    typealias DatasourceState = State<Value, P, E>
    typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<DatasourceState.P>
    
    let state: SignalProducer<DatasourceState, NoError>
    let loadsSynchronously: Bool = false
    
    init(loadImpulseEmitter: LoadImpulseEmitterConcrete) {
        self.state = PublicReposPrimaryDatasource.statesProducer(loadImpulseEmitter: loadImpulseEmitter)
    }
    
    private static func statesProducer(loadImpulseEmitter: LoadImpulseEmitterConcrete) -> SignalProducer<DatasourceState, NoError> {
        
        return loadImpulseEmitter.loadImpulses
            .flatMap(.latest) { loadImpulse -> SignalProducer<DatasourceState, NoError> in
                
                let loadingState = SignalProducer<DatasourceState, NoError>(value: DatasourceState.loading(loadImpulse: loadImpulse, fallbackValue: nil, fallbackError: nil))
                
                let apiStates = fetch()
                    .map({ DatasourceState.value(value: $0, loadImpulse: loadImpulse, fallbackError: nil) })
                    .flatMapError({ SignalProducer(value: State.error(error: $0, loadImpulse: loadImpulse, fallbackValue: nil)) })
                
                return loadingState.concat(apiStates)
        }
    }
    
    private static func fetch() -> SignalProducer<Value, APIError> {
        
        let publicReposUrlString: String = "https://api.github.com/repositories"
        guard let url = URL(string: publicReposUrlString) else {
            return SignalProducer(error: APIError.unknown(description: "Repositories URL could not be parsed"))
        }
        
        return SignalProducer.init({ (observer, lifetime) in
            
            let urlRequest = URLRequest(url: url)
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            
            let task = session.dataTask(with: urlRequest) {
                (data, response, error) in
                
                guard error == nil else {
                    observer.send(error: APIError.unknown(description: "Public repos could not be loaded - we are too lazy to parse the actual error ;)"))
                    observer.sendCompleted()
                    return
                }
                
                // make sure we got data
                guard let responseData = data else {
                    observer.send(error: APIError.unknown(description: "Public repos data is missing"))
                    observer.sendCompleted()
                    return
                }
                
                do {
                    let reposContainer = try JSONDecoder.decode(responseData, to: PublicReposResponseContainer.self)
                    observer.send(value: reposContainer)
                    observer.sendCompleted()
                } catch {
                    observer.send(error: APIError.unknown(description: "Repos container cannot be parsed: \(String(describing: error))"))
                    observer.sendCompleted()
                }
            }
            task.resume()
        })
    }
}

struct VoidParameters: Parameters, Codable {
    func isCacheCompatible(_ candidate: VoidParameters) -> Bool {
        return true
    }
}
