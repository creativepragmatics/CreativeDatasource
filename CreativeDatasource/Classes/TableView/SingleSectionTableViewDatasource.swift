import Foundation
import UIKit
import ReactiveSwift
import Result

open class SingleSectionTableViewDatasource<Datasource: DatasourceProtocol, Cell: ListItem>: NSObject, UITableViewDelegate, UITableViewDataSource {
    
    public typealias Cells = SingleSectionListItems<Cell>
    public typealias CellsProvider = SingleSectionListItemsProvider<Datasource, Cell>
    public typealias CellViewProducer = (Cell) -> DefaultTableViewCellProducer<Cell>
    
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
    public let scrollViewDidScroll = Signal<Void, NoError>.pipe()
    public let cells: Property<Cells>
    private let cellViewProducer: CellViewProducer
    private let itemSelected: ((Cell) -> ())?
    
    public init(cellsProvider: CellsProvider, cellViewProducer: @escaping CellViewProducer, itemSelected: ((Cell) -> ())?) {
        self.cells = cellsProvider.cells
        self.cellViewProducer = cellViewProducer
        self.itemSelected = itemSelected
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let cells = cells.value.items else { return 0 }
        return cells.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cells = cells.value.items, indexPath.row < cells.count else { return UITableViewCell() }
        let cell = cells[indexPath.row]
        return cellViewProducer(cell).view(containingView: tableView, item: cell)
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cells = cells.value.items else { return }
        let cell = cells[indexPath.row]
        if cell.isSelectable {
            itemSelected?(cell)
        }
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return heightAtIndexPath[indexPath] ?? UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        heightAtIndexPath[indexPath] = cell.frame.size.height
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewDidScroll.input.send(value: ())
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
}
