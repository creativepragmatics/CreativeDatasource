import Foundation
import ReactiveSwift
import Result

public protocol LoadImpulseEmitter {
    associatedtype P: Parameters
    associatedtype LIT: LoadImpulseType
    
    var loadImpulses: SignalProducer<LoadImpulse<P, LIT>, NoError> {get}
    func emit(_ loadImpulse: LoadImpulse<P, LIT>)
}

public extension LoadImpulseEmitter {
    var boxed: LoadImpulseEmitterBox<P, LIT> {
        return LoadImpulseEmitterBox(self)
    }
}

public struct LoadImpulseEmitterBox<P_: Parameters, LIT_: LoadImpulseType>: LoadImpulseEmitter {
    public typealias P = P_
    public typealias LIT = LIT_
    
    public let loadImpulses: SignalProducer<LoadImpulse<P_, LIT_>, NoError>
    private let _emit: (LoadImpulse<P, LIT>) -> ()
    
    init<E: LoadImpulseEmitter>(_ emitter: E) where E.P == P, E.LIT == LIT {
        self.loadImpulses = emitter.loadImpulses
        self._emit = emitter.emit
    }
    
    public func emit(_ loadImpulse: LoadImpulse<P_, LIT_>) {
        _emit(loadImpulse)
    }
}

public struct DefaultLoadImpulseEmitter<P_: Parameters, LIT_: LoadImpulseType>: LoadImpulseEmitter {
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias LI = LoadImpulse<P, LIT>
    private typealias Pipe = (output: Signal<LI, NoError>, input: Signal<LI, NoError>.Observer)

    public let loadImpulses: SignalProducer<LI, NoError>
    private let pipe: Pipe

    public init(emitInitially initialImpulse: LoadImpulse<P, LIT>?) {
        
        func loadImpulsesProducer(pipe: Pipe, initialImpulse: LI?) -> SignalProducer<LI, NoError> {
            let impulses = SignalProducer(pipe.output)
            if let initialImpulse = initialImpulse {
                return SignalProducer(value: initialImpulse).concat(impulses)
            } else {
                return impulses
            }
        }
        
        let pipe = Signal<LoadImpulse<P, LIT>, NoError>.pipe()
        self.loadImpulses = loadImpulsesProducer(pipe: pipe, initialImpulse: initialImpulse)
        self.pipe = pipe
    }

    public func emit(_ loadImpulse: LoadImpulse<P, LIT>) {
        pipe.input.send(value: loadImpulse)
    }

}
