import Foundation

public typealias PullToRefreshLoadImpulse<P: Parameters> = LoadImpulse<P, PullToRefreshLoadImpulseType>

public extension PullToRefreshLoadImpulse {
    
    static func initial(parameters: P) -> PullToRefreshLoadImpulse<P> {
        return PullToRefreshLoadImpulse<P>.init(parameters: parameters, loadImpulseType: .initial, skipIfResultAvailable: false)
    }
    
    static func refresh(parameters: P) -> PullToRefreshLoadImpulse<P> {
        return PullToRefreshLoadImpulse<P>.init(parameters: parameters, loadImpulseType: .pullToRefresh, skipIfResultAvailable: false)
    }
    
    static func softRefresh(parameters: P) -> PullToRefreshLoadImpulse<P> {
        return PullToRefreshLoadImpulse<P>.init(parameters: parameters, loadImpulseType: .pullToRefresh, skipIfResultAvailable: true)
    }
    
}

// Inherits from String so we get Equatable & Codable conformance for free
public enum PullToRefreshLoadImpulseType : String, LoadImpulseType, Codable {
    
    case initial
    case pullToRefresh
    
    public static var initialValue: PullToRefreshLoadImpulseType {
        return PullToRefreshLoadImpulseType.initial
    }
}
