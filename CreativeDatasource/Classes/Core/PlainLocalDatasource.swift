import Foundation
import ReactiveSwift
import Result

public struct PlainCacheDatasource<State_: StateProtocol> : DatasourceProtocol {
    public typealias State = State_
    public typealias StatePersisterConcrete = AnyStatePersister<State>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<State.P, State.LIT>
    
    public let state: SignalProducer<State, NoError>
    public let loadsSynchronously = true
    
    public init(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitterConcrete, cacheLoadError: State.E) {
        self.state = PlainCacheDatasource.asyncStateProducer(persister: persister, loadImpulseEmitter: loadImpulseEmitter, cacheLoadError: cacheLoadError)
    }
    
    private static func asyncStateProducer(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitterConcrete, cacheLoadError: State.E) -> SignalProducer<State, NoError> {
        
        return loadImpulseEmitter.loadImpulses
            .skipRepeats()
            .flatMap(.latest) { loadImpulse -> SignalProducer<State, NoError> in
                guard let cached = persister.load(loadImpulse.parameters) else {
                    return SignalProducer(value: State.init(error: cacheLoadError, loadImpulse: loadImpulse))
                }
                
                return SignalProducer(value: cached)
        }
    }
    
}
