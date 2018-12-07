import Foundation
import UIKit

public protocol TableViewCellProducer : ListItemViewProducer {
    typealias ProducedView = UITableViewCell
    typealias ContainingView = UITableView
}

public enum DefaultTableViewCellProducer<Cell: ListItem>: TableViewCellProducer {

    public typealias TableViewCellDequeueIdentifier = String
    
    // Cell class registration is performed automatically:
    case classAndIdentifier(class: UITableViewCell.Type, identifier: TableViewCellDequeueIdentifier)
    
    case nibAndIdentifier(nib: UINib, identifier: TableViewCellDequeueIdentifier)
    
    // No cell class registration is performed:
    case generator((Cell) -> UITableViewCell)
    
    public func view(containingView: UITableView, item: Cell) -> ProducedView {
        switch self {
        case let .classAndIdentifier(clazz, identifier):
            containingView.register(clazz, forCellReuseIdentifier: identifier)
            guard let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell else {
                return ProducedView()
            }
            return tableViewCell
        case let .nibAndIdentifier(nib, identifier):
            containingView.register(nib, forCellReuseIdentifier: identifier)
            guard let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell else {
                return ProducedView()
            }
            return tableViewCell
        case let .generator(generator):
            return generator(item)
        }
    }
}
