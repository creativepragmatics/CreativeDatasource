import Foundation

public struct LoadImpulse<P: Parameters, LIT : LoadImpulseType>: Equatable {
    
    public var parameters: P
    public let loadImpulseType: LIT
    public let skipIfResultAvailable: Bool
    
    public init(parameters: P, loadImpulseType: LIT, skipIfResultAvailable: Bool = false) {
        self.parameters = parameters
        self.loadImpulseType = loadImpulseType
        self.skipIfResultAvailable = skipIfResultAvailable
    }
    
    public func with(parameters: P) -> LoadImpulse<P, LIT> {
        var modified = self
        modified.parameters = parameters
        return modified
    }
    
    func isCacheCompatible(_ candidate: LoadImpulse<P, LIT>) -> Bool {
        return parameters.isCacheCompatible(candidate.parameters)
    }
}

extension LoadImpulse : Codable where P: Codable, LIT: Codable {}

public protocol LoadImpulseType : Equatable {
    static var initialValue: Self {get}
}
