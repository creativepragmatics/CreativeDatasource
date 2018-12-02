import Foundation

public enum PlainListCell<ContentCell: Codable & Equatable, E: DatasourceError>: Equatable {
    case contentCell(ContentCell)
    case loading
    case error(E)
    case noResults(String)
    case empty // empty placeholder cell to prevent pull-to-refresh glitches
}

public enum PlainListCells<ContentCell: Codable & Equatable, E: DatasourceError>: Equatable {
    case datasourceNotReady
    case readyToDisplay([PlainListCell<ContentCell, E>])
    
    var cells: [PlainListCell<ContentCell, E>]? {
        switch self {
        case .datasourceNotReady: return nil
        case let .readyToDisplay(cells): return cells
        }
    }
}
