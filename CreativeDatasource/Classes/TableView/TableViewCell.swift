import Foundation
import UIKit

/// SelectableItem can be anything, e.g. a custom Cell enum or the Values
/// returned by a server call. Any cell that can be selected should
/// have a value set so it can be identified on selection.
public struct TableViewCell<SelectableItem: Equatable, Id: CellId>: Equatable {
    public let cellProducer: Producer
    public let selectableItem: SelectableItem?
    public let cellId: Id // must be unique to a cell
    
    public init(cellProducer: Producer, selectableItem: SelectableItem?, cellId: Id) {
        self.cellProducer = cellProducer
        self.selectableItem = selectableItem
        self.cellId = cellId
    }
    
    public func cell(tableView: UITableView) -> UITableViewCell {
        return cellProducer.cell(tableView:tableView)
    }

    public static var loading: TableViewCell {
        return TableViewCell(cellProducer: .generator({ LoadingCell() }), selectableItem: nil, cellId: Id.loadingCell)
    }
    
    public static func error(_ content: ErrorTableViewCellContent) -> TableViewCell {
        return TableViewCell(cellProducer: .generator({
            let cell = ErrorTableViewCell()
            cell.content = content
            return cell
        }), selectableItem: nil, cellId: Id.errorCell(content: content))
    }
    
    public static var empty: TableViewCell {
        return TableViewCell(cellProducer: .generator({
            let cell = UITableViewCell()
            cell.backgroundColor = .white
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
            cell.selectionStyle = .none
            return cell
        }), selectableItem: nil, cellId: Id.loadingCell)
    }
    
}

public protocol CellId: Equatable {
    static var loadingCell: Self {get}
    static var emptyCell: Self {get}
    static func errorCell(content: ErrorTableViewCellContent) -> Self
}

public extension TableViewCell {
    
    public enum Producer: Equatable {
        
        // Cell class registration is performed automatically:
        case classAndIdentifier(class: UITableViewCell.Type, identifier: TableViewCellDequeueIdentifier, configure: (UITableViewCell) -> ())
        
        // No cell class registration is performed:
        case generator(() -> UITableViewCell)
        
        public func cell(tableView: UITableView) -> UITableViewCell {
            switch self {
            case let .classAndIdentifier(clazz, identifier, configure):
                tableView.register(clazz, forCellReuseIdentifier: identifier)
                guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier) else {
                    return UITableViewCell()
                }
                configure(cell)
                return cell
            case let .generator(generator):
                return generator()
            }
        }
        
        public static func == (lhs: Producer, rhs: Producer) -> Bool {
            switch (lhs, rhs) {
            case let (.classAndIdentifier(_, cellIdentifierL, _), .classAndIdentifier(_, cellIdentifierR, _)):
                return cellIdentifierL == cellIdentifierR
            case (.generator, .generator):
                // Weak definition of equality. We assume that we don't need it
                // to be stronger. The alternative would be to add some kind of tag
                // only for equality purposes.
                return true
            default:
                return false
            }
        }
    }
}

public typealias TableViewCellDequeueIdentifier = String

protocol ContentCell: Equatable {
    associatedtype UITVC: UITableViewCell
    associatedtype CellParameters: Any
    func tableViewCell(_ parameters: CellParameters) -> UITVC
}

public enum TableViewCells<SelectableItem: Equatable, Id: CellId>: Equatable {
    case datasourceNotReady
    case readyToDisplay([TableViewCell<SelectableItem, Id>])
    
    var cells: [TableViewCell<SelectableItem, Id>]? {
        switch self {
        case .datasourceNotReady: return nil
        case let .readyToDisplay(cells): return cells
        }
    }
}
