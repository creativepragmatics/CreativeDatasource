import Foundation

public struct LoadImpulse<P: Parameters, LIT : LoadImpulseType>: Equatable {
    
    var parameters: P
    let loadImpulseType: LIT
    let skipIfResultAvailable: Bool
    
    public init(parameters: P, loadImpulseType: LIT, skipIfResultAvailable: Bool = false) {
        self.parameters = parameters
        self.loadImpulseType = loadImpulseType
        self.skipIfResultAvailable = skipIfResultAvailable
    }
    
    func with(parameters: P) -> LoadImpulse<P, LIT> {
        var modified = self
        modified.parameters = parameters
        return modified
    }
}

extension LoadImpulse : Codable where P: Codable, LIT: Codable {}

public protocol LoadImpulseType : Equatable {
    static var initialValue: Self {get}
}
