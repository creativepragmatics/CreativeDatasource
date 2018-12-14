import Foundation
import UIKit

public protocol CollectionViewCellProducer : ListItemViewProducer {
    typealias ProducedView = UICollectionViewCell
    typealias ContainingView = UICollectionView
}

public enum DefaultCollectionViewCellProducer<Cell: ListItem>: CollectionViewCellProducer {
    public typealias UICollectionViewDequeueIdentifier = String
    
    // Cell class registration is performed automatically:
    case classAndIdentifier(class: UICollectionViewCell.Type, identifier: UICollectionViewDequeueIdentifier, configure: (Cell, UICollectionViewCell) -> ())
    
    case nibAndIdentifier(nib: UINib, identifier: UICollectionViewDequeueIdentifier, configure: (Cell, UICollectionViewCell) -> ())
    
    public func view(containingView: UICollectionView, item: Cell, for indexPath: IndexPath) -> ProducedView {
        switch self {
        case let .classAndIdentifier(clazz, identifier, configure):
            guard let collectionViewCell = containingView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? UICollectionViewCell else {
                return ProducedView()
            }
            configure(item, collectionViewCell)
            return collectionViewCell
        case let .nibAndIdentifier(nib, identifier, configure):
            guard let collectionViewCell = containingView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? UICollectionViewCell else {
                return ProducedView()
            }
            configure(item, collectionViewCell)
            return collectionViewCell
        }
    }
    
    public func register(itemViewType: Cell.ViewType, at containingView: UICollectionView) {
        switch self {
        case let .classAndIdentifier(clazz, identifier, _):
            containingView.register(clazz, forCellWithReuseIdentifier: identifier)
        case let .nibAndIdentifier(nib, identifier, _):
            containingView.register(nib, forCellWithReuseIdentifier: identifier)
        }
    }
    
    public var defaultView: UICollectionViewCell { return UICollectionViewCell() }
}
