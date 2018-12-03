import Foundation
import UIKit
import ReactiveSwift
import Result

open class TableViewDatasource<SelectableItem: Equatable, Id: CellId, P: Parameters, E: DatasourceError>: NSObject, UITableViewDelegate, UITableViewDataSource {
    
    public typealias Cell = TableViewCell<SelectableItem, Id>
    public typealias Cells = TableViewCells<SelectableItem, Id>
    public typealias LoadingTableViewCellProducer = () -> Cell
    public typealias ErrorTableViewCellProducer = (ErrorTableViewCellContent) -> Cell
    
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
    public let scrollViewDidScroll = Signal<Void, NoError>.pipe()
    private let cells: Property<Cells>
    private let loadingTableViewCellProducer: LoadingTableViewCellProducer
    private let errorTableViewCellProducer: ErrorTableViewCellProducer
    private let itemSelected: ((SelectableItem) -> ())?
    
    public init(cells: Property<Cells>,
                itemSelected: ((SelectableItem) -> ())?,
                loadingTableViewCellProducer: @escaping LoadingTableViewCellProducer = defaultLoadingTableViewCellProducer,
                errorTableViewCellProducer: @escaping ErrorTableViewCellProducer = defaultErrorTableViewCellProducer
        ) {
        self.cells = cells
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
        return cells[indexPath.row].cell(tableView: tableView)
    }
    
    public static func defaultErrorTableViewCellProducer(_ content: ErrorTableViewCellContent) -> Cell {
        return Cell.error(content)
    }
    
    public static func defaultLoadingTableViewCellProducer() -> Cell {
        return Cell.loading
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cells = cells.value.cells else { return }
        
        if let item = cells[indexPath.row].selectableItem {
            itemSelected?(item)
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
