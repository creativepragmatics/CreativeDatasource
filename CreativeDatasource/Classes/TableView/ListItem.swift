import Foundation
import UIKit

public protocol ListItem: Equatable {
    var isSelectable: Bool {get}
    
    // Required to display configuration or system errors
    // for easier debugging.
    init(errorMessage: String)
}

public protocol ListItemViewProducer {
    associatedtype Item: ListItem
    associatedtype ProducedView: UIView
    associatedtype ContainingView: UIView
    func view(containingView: ContainingView, item: Item) -> ProducedView
}

public extension ListItemViewProducer {
    public var any: AnyListItemViewProducer<Item, ProducedView, ContainingView> {
        return AnyListItemViewProducer(self)
    }
}

public struct AnyListItemViewProducer<Item_: ListItem, ProducedView_: UIView, ContainingView_: UIView> : ListItemViewProducer {
    public typealias Item = Item_
    public typealias ProducedView = ProducedView_
    public typealias ContainingView = ContainingView_
    
    private let _view: (ContainingView, Item) -> ProducedView
    
    public init<P: ListItemViewProducer>(_ producer: P) where P.Item == Item, P.ProducedView == ProducedView, P.ContainingView == ContainingView {
        self._view = producer.view
    }
    
    public func view(containingView: ContainingView, item: Item) -> ProducedView {
        return _view(containingView, item)
    }
}

public enum SingleSectionListItems<LI: ListItem>: Equatable {
    case datasourceNotReady
    case readyToDisplay([LI])

    public var items: [LI]? {
        switch self {
        case .datasourceNotReady: return nil
        case let .readyToDisplay(items): return items
        }
    }
}
