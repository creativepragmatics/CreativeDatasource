import Foundation

public struct LoadImpulse<P: Parameters, LIT : LoadImpulseType>: Equatable, Codable {
    
    var parameters: P
    let loadImpulseType: LIT
    let skipIfResultAvailable: Bool
    
    init(parameters: P, loadImpulseType: LIT, skipIfResultAvailable: Bool = false) {
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

public protocol LoadImpulseType : Equatable, Codable {
    static var initialValue: Self {get}
}
