import Foundation
import ReactiveSwift
import Result

public struct PlainLocalDatasource<Value_: Codable, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError> : Datasource {
    public typealias Value = Value_
    public typealias LIT = LIT_
    public typealias P = P_
    public typealias E = E_
    public typealias StateConcrete = State<Value, P, LIT, E>
    public typealias StatePersisterConcrete = StatePersisterBox<Value, P, LIT, E>
    public typealias LoadImpulseEmitterConcrete = LoadImpulseEmitterBox<P, LIT>
    
    public let state: SignalProducer<StateConcrete, NoError>
    public var sendsFirstStateSynchronously: Bool {
        switch loadingMode {
        case .synchronously: return true
        case .waitForLoadImpulse: return false
        }
    }
    private let loadingMode: LoadingMode
    
    public init(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitterConcrete, cacheLoadError: E, loadingMode: LoadingMode = .synchronously) {
        self.loadingMode = loadingMode
        switch loadingMode {
        case .synchronously:
            let initialState = persister.load() ?? StateConcrete.initial
            self.state = SignalProducer(value: initialState)
        case .waitForLoadImpulse:
            self.state = PlainLocalDatasource.asyncStateProducer(persister: persister, loadImpulseEmitter: loadImpulseEmitter, cacheLoadError: cacheLoadError, loadingMode: loadingMode)
        }
    }
    
    private static func asyncStateProducer(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitterConcrete, cacheLoadError: E, loadingMode: LoadingMode) -> SignalProducer<StateConcrete, NoError> {
        
        let load = { (loadImpulse: LoadImpulse<P, LIT>?) -> SignalProducer<StateConcrete, NoError> in
            if let cached = persister.load() {
                return SignalProducer(value: cached)
            } else if let loadImpulse = loadImpulse {
                return SignalProducer(value: State.error(error: cacheLoadError, loadImpulse: loadImpulse))
            } else {
                return SignalProducer.empty
            }
        }
        
        switch loadingMode {
        case .synchronously:
            return load(nil)
        case .waitForLoadImpulse:
            return loadImpulseEmitter.loadImpulses
                .take(first: 1)
                .flatMap(.latest) { loadImpulse -> SignalProducer<StateConcrete, NoError> in
                    return load(loadImpulse)
            }
        }
        
    }
    
    public enum LoadingMode {
        case synchronously
        case waitForLoadImpulse
    }
    
}
