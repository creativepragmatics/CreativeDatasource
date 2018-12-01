import Foundation

public enum PlainListCell<ContentCell: Codable & Equatable, E: DatasourceError>: Equatable {
    case contentCell(ContentCell)
    case loading
    case error(E)
    case noResults(String)
    case empty // empty placeholder cell to prevent pull-to-refresh glitches
}
