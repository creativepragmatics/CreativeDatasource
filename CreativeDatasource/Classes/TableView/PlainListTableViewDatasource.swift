import Foundation
import UIKit
import ReactiveSwift
import Result

open class PlainListTableViewDatasource<Item: Codable & Equatable, P: Parameters, E: DatasourceError>: NSObject, UITableViewDelegate, UITableViewDataSource {
    
    public typealias Cell = PlainListCell<Item, E>
    
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
    private let cells: Property<[Cell]>
    private let tableViewCellForItem: (Item, IndexPath) -> UITableViewCell
    private let itemSelected: ((Item) -> ())?
    private let scrollViewDidScroll = Signal<Void, NoError>.pipe()
    
    public init(cells: Property<[Cell]>, tableViewCellForItem: @escaping (Item, IndexPath) -> UITableViewCell, itemSelected: ((Item) -> ())?) {
        self.cells = cells
        self.tableViewCellForItem = tableViewCellForItem
        self.itemSelected = itemSelected
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.value.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard indexPath.row < cells.value.count else { return UITableViewCell() }
        
        switch cells.value[indexPath.row] {
        case let .contentCell(item):
            return tableViewCellForItem(item, indexPath)
        case .loading:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "loadingCell") as? LoadingCell else {
                return UITableViewCell()
            }
            let _ = cell.loadingIndicatorView
            cell.startAnimating()
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            return cell
        case .error:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "undefinedErrorCell") as? ErrorTableViewCell else {
                return UITableViewCell()
            }
            cell.content = .default
            cell.selectionStyle = .none
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
            return cell
        case .empty:
            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
            return cell
        case let .noResults(message):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "undefinedErrorCell") as? ErrorTableViewCell else {
                return UITableViewCell()
            }
            cell.content = .message(message)
            cell.selectionStyle = .none
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch cells.value[indexPath.row] {
        case let .contentCell(item):
            itemSelected?(item)
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return heightAtIndexPath[indexPath] ?? UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        heightAtIndexPath[indexPath] = cell.frame.size.height
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewDidScroll.input.send(value: ())
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func retryButtonTapped() {
        // Override if necessary
    }
}
