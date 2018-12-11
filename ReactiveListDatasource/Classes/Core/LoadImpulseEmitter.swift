import Foundation
import ReactiveSwift
import Result

public protocol LoadImpulseEmitterProtocol {
    associatedtype P: Parameters
    associatedtype LIT: LoadImpulseType
    
    var loadImpulses: SignalProducer<LoadImpulse<P, LIT>, NoError> {get}
    func emit(_ loadImpulse: LoadImpulse<P, LIT>)
}

public extension LoadImpulseEmitterProtocol {
    public var any: AnyLoadImpulseEmitter<P, LIT> {
        return AnyLoadImpulseEmitter(self)
    }
}

public struct AnyLoadImpulseEmitter<P_: Parameters, LIT_: LoadImpulseType>: LoadImpulseEmitterProtocol {
    public typealias P = P_
    public typealias LIT = LIT_
    
    public let loadImpulses: SignalProducer<LoadImpulse<P_, LIT_>, NoError>
    private let _emit: (LoadImpulse<P, LIT>) -> ()
    
    init<E: LoadImpulseEmitterProtocol>(_ emitter: E) where E.P == P, E.LIT == LIT {
        self.loadImpulses = emitter.loadImpulses
        self._emit = emitter.emit
    }
    
    public func emit(_ loadImpulse: LoadImpulse<P_, LIT_>) {
        _emit(loadImpulse)
    }
}


public struct DefaultLoadImpulseEmitter<P_: Parameters, LIT_: LoadImpulseType>: LoadImpulseEmitterProtocol {
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

public struct RecurringLoadImpulseEmitter<P_: Parameters, LIT_: LoadImpulseType>: LoadImpulseEmitterProtocol {
    public typealias P = P_
    public typealias LIT = LIT_
    public typealias LI = LoadImpulse<P, LIT>
    private typealias Pipe = (output: Signal<LI, NoError>, input: Signal<LI, NoError>.Observer)
    
    private let innerEmitter: DefaultLoadImpulseEmitter<P, LIT>
    public let loadImpulses: SignalProducer<LI, NoError>
    public let timerMode: MutableProperty<TimerMode> // change at any time to adapt
    
    public init(emitInitially initialImpulse: LoadImpulse<P, LIT>?, timerMode: TimerMode = .none) {
        
        let timerModeProperty = MutableProperty(timerMode)
        self.timerMode = timerModeProperty
        self.innerEmitter = DefaultLoadImpulseEmitter<P, LIT>.init(emitInitially: initialImpulse)
        
        self.loadImpulses = innerEmitter.loadImpulses
            .combineLatest(with: timerModeProperty.producer)
            .flatMap(.latest, { (loadImpulse, timerMode) -> SignalProducer<LoadImpulse<P, LIT>, NoError> in
                let current = SignalProducer<LoadImpulse<P, LIT>, NoError>(value: loadImpulse)
                
                switch timerMode {
                case .none:
                    return current
                case let .timeInterval(timeInterval):
                    let subsequent = SignalProducer.timer(interval: timeInterval, on: QueueScheduler.main).map({ _ in loadImpulse })
                    return current.concat(subsequent)
                }
            })
    }
    
    public func emit(_ loadImpulse: LoadImpulse<P, LIT>) {
        innerEmitter.emit(loadImpulse)
    }
    
    public enum TimerMode {
        case none
        case timeInterval(DispatchTimeInterval)
    }
    
}
