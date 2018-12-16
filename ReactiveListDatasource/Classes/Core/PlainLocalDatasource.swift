import Foundation
import ReactiveSwift
import Result

public struct PlainCacheDatasource<Value_, P_, E_: DatasourceError, LoadImpulseEmitter_: LoadImpulseEmitterProtocol> : DatasourceProtocol where P_ == LoadImpulseEmitter_.P {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias LoadImpulseEmitter = LoadImpulseEmitter_
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>
    
    public let state: SignalProducer<DatasourceState, NoError>
    public let loadsSynchronously = true
    
    public init(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitter, cacheLoadError: E) {
        self.state = PlainCacheDatasource.asyncStateProducer(persister: persister, loadImpulseEmitter: loadImpulseEmitter, cacheLoadError: cacheLoadError)
    }
    
    private static func asyncStateProducer(persister: StatePersisterConcrete, loadImpulseEmitter: LoadImpulseEmitter, cacheLoadError: E) -> SignalProducer<DatasourceState, NoError> {
        
        return loadImpulseEmitter.loadImpulses
            .skipRepeats()
            .flatMap(.latest) { loadImpulse -> SignalProducer<DatasourceState, NoError> in
                guard let cached = persister.load(loadImpulse.parameters) else {
                    let errorState = DatasourceState.error(error: cacheLoadError, loadImpulse: loadImpulse, fallbackValue: nil)
                    return SignalProducer(value: errorState)
                }
                
                return SignalProducer(value: cached)
        }
    }
    
}
