import Foundation
import UIKit

public protocol TableViewCellProducer : ListItemViewProducer {
    typealias ProducedView = UITableViewCell
    typealias ContainingView = UITableView
}

public enum DefaultTableViewCellProducer<Cell: ListItem>: TableViewCellProducer {
    public typealias TableViewCellDequeueIdentifier = String
    
    // Cell class registration is performed automatically:
    case classAndIdentifier(class: UITableViewCell.Type, identifier: TableViewCellDequeueIdentifier, configure: (Cell, UITableViewCell) -> ())
    
    case nibAndIdentifier(nib: UINib, identifier: TableViewCellDequeueIdentifier, configure: (Cell, UITableViewCell) -> ())
    
    // No cell class registration is performed:
    case instantiate((Cell) -> UITableViewCell)
    
    public func view(containingView: UITableView, item: Cell) -> ProducedView {
        switch self {
        case let .classAndIdentifier(clazz, identifier, configure):
            guard let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell else {
                return ProducedView()
            }
            configure(item, tableViewCell)
            return tableViewCell
        case let .nibAndIdentifier(nib, identifier, configure):
            guard let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell else {
                return ProducedView()
            }
            configure(item, tableViewCell)
            return tableViewCell
        case let .instantiate(instantiate):
            return instantiate(item)
        }
    }
    
    public func register(itemViewType: Cell.ViewType, at containingView: UITableView) {
        switch self {
        case let .classAndIdentifier(clazz, identifier, _):
            containingView.register(clazz, forCellReuseIdentifier: identifier)
        case let .nibAndIdentifier(nib, identifier, _):
            containingView.register(nib, forCellReuseIdentifier: identifier)
        case let .instantiate(instantiate):
            break
        }
    }
    
    public var defaultView: UITableViewCell { return UITableViewCell() }
}
