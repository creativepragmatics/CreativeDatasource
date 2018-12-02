import Foundation

public enum PlainListCell<ContentCell: Equatable, E: DatasourceError>: Equatable {
    case contentCell(ContentCell)
    case loading
    case error(E)
    case noResults(String)
    case empty // empty placeholder cell to prevent pull-to-refresh glitches
}

public enum PlainListCells<ContentCell: Equatable, E: DatasourceError>: Equatable {
    case datasourceNotReady
    case readyToDisplay([PlainListCell<ContentCell, E>])
    
    var cells: [PlainListCell<ContentCell, E>]? {
        switch self {
        case .datasourceNotReady: return nil
        case let .readyToDisplay(cells): return cells
        }
    }
}
