import Foundation
import UIKit

public protocol TableViewCellProducer : ListItemViewProducer {
    typealias ProducedView = UITableViewCell
    typealias ContainingView = UITableView
}

public enum DefaultTableViewCellProducer<Cell: ListItem>: TableViewCellProducer {

    public typealias TableViewCellDequeueIdentifier = String
    
    // Cell class registration is performed automatically:
    case classAndIdentifier(class: UITableViewCell.Type, identifier: TableViewCellDequeueIdentifier, configure: (UITableViewCell, Cell) -> (), hashableTag: HashableTag)
    
    case nibAndIdentifier(nib: UINib, identifier: TableViewCellDequeueIdentifier, configure: (UITableViewCell, Cell) -> (), hashableTag: HashableTag)
    
    // No cell class registration is performed:
    case generator((Cell) -> UITableViewCell, hashableTag: HashableTag)
    
    var hashableTag: HashableTag {
        switch self {
        case let .classAndIdentifier(_, _, _, hashableTag): return hashableTag
        case let .nibAndIdentifier(_, _, _, hashableTag): return hashableTag
        case let .generator(_, hashableTag): return hashableTag
        }
    }
    
    public func view(containingView: UITableView, item: Cell) -> ProducedView {
        switch self {
        case let .classAndIdentifier(clazz, identifier, configure, _):
            containingView.register(clazz, forCellReuseIdentifier: identifier)
            guard let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell else {
                return ProducedView()
            }
            configure(tableViewCell, item)
            return tableViewCell
        case let .nibAndIdentifier(nib, identifier, configure, _):
            containingView.register(nib, forCellReuseIdentifier: identifier)
            guard let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier) as? UITableViewCell else {
                return ProducedView()
            }
            configure(tableViewCell, item)
            return tableViewCell
        case let .generator(generator, _):
            return generator(item)
        }
    }
}

public extension DefaultTableViewCellProducer {
    
    public struct HashableTag: Hashable {
        private let id: String
        public init() {
            self.id = UUID().uuidString
        }
        public static var `default`: HashableTag {
            return HashableTag()
        }
    }
    
    public static func == (lhs: DefaultTableViewCellProducer<Cell>, rhs: DefaultTableViewCellProducer<Cell>) -> Bool {
        return lhs.hashableTag == rhs.hashableTag
    }
    
    public var hashValue: Int {
        return hashableTag.hashValue
    }
    
    public func hash(into hasher: inout Hasher) {
        hashableTag.hash(into: &hasher)
    }
}
