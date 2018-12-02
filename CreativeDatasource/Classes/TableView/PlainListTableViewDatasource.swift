import Foundation
import UIKit
import ReactiveSwift
import Result

open class PlainListTableViewDatasource<Item: Equatable, P: Parameters, E: DatasourceError>: NSObject, UITableViewDelegate, UITableViewDataSource {
    
    public typealias Cell = PlainListCell<Item, E>
    public typealias Cells = PlainListCells<Item, E>
    
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
    public let scrollViewDidScroll = Signal<Void, NoError>.pipe()
    private let cells: Property<Cells>
    private let tableViewCellForItem: (Item, IndexPath) -> UITableViewCell
    private let loadingTableViewCellProducer: (() -> UITableViewCell)
    private let errorTableViewCellProducer: ((ErrorTableViewCellContent) -> UITableViewCell)
    private let itemSelected: ((Item) -> ())?
    
    public init(cells: Property<Cells>,
                tableViewCellForItem: @escaping (Item, IndexPath) -> UITableViewCell,
                itemSelected: ((Item) -> ())?,
                loadingTableViewCellProducer: @escaping (() -> UITableViewCell) = defaultLoadingTableViewCellProducer,
                errorTableViewCellProducer: @escaping ((ErrorTableViewCellContent) -> UITableViewCell) = defaultErrorTableViewCellProducer
        ) {
        self.cells = cells
        self.tableViewCellForItem = tableViewCellForItem
        self.itemSelected = itemSelected
        self.loadingTableViewCellProducer = loadingTableViewCellProducer
        self.errorTableViewCellProducer = errorTableViewCellProducer
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let cells = cells.value.cells else { return 0 }
        return cells.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cells = cells.value.cells, indexPath.row < cells.count else { return UITableViewCell() }
        
        switch cells[indexPath.row] {
        case let .contentCell(item):
            return tableViewCellForItem(item, indexPath)
        case .loading:
            return loadingTableViewCellProducer()
        case .error:
            return errorTableViewCellProducer(.default)
        case .empty:
            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
            return cell
        case let .noResults(message):
            return errorTableViewCellProducer(.message(message))
        }
    }
    
    public static func defaultErrorTableViewCellProducer(_ content: ErrorTableViewCellContent) -> UITableViewCell {
        let cell = ErrorTableViewCell(frame: .zero)
        cell.content = .default
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
        return cell
    }
    
    public static func defaultLoadingTableViewCellProducer() -> UITableViewCell {
        let cell = LoadingCell(frame: .zero)
        cell.startAnimating()
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let cells = cells.value.cells else { return }
        
        switch cells[indexPath.row] {
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
}
