import Foundation
import ReactiveSwift
import Result

public struct PlainCacheDatasource<Value_: Any, P_: Parameters, LIT_: LoadImpulseType, E_: DatasourceError> : Datasource {
    public typealias Value = Value_
    public typealias LIT = LIT_
    public typealias P = P_
    public typealias E = E_
    public typealias StateConcrete = State<Value, P, LIT, E>
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, LIT, E>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P, LIT>
    
    public let state: SignalProducer<StateConcrete, NoError>
    public let loadsSynchronously = true
    
    public init(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitterConcrete, cacheLoadError: E) {
        self.state = PlainCacheDatasource.asyncStateProducer(persister: persister, loadImpulseEmitter: loadImpulseEmitter, cacheLoadError: cacheLoadError)
    }
    
    private static func asyncStateProducer(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitterConcrete, cacheLoadError: E) -> SignalProducer<StateConcrete, NoError> {
        
        return loadImpulseEmitter.loadImpulses
            .skipRepeats()
            .flatMap(.latest) { loadImpulse -> SignalProducer<StateConcrete, NoError> in
                guard let cached = persister.load(loadImpulse.parameters) else {
                    return SignalProducer(value: State.error(error: cacheLoadError, loadImpulse: loadImpulse))
                }
                
                return SignalProducer(value: cached)
        }
        
    }
    
}
