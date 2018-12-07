import Foundation
import UIKit
import ReactiveSwift
import Result

open class SingleSectionTableViewDatasource<Datasource: DatasourceProtocol, Cell: ListItem>: NSObject, UITableViewDelegate, UITableViewDataSource {
    
    public typealias Cells = SingleSectionListItems<Cell>
    public typealias CellToView = (Cell) -> DefaultTableViewCellProducer<Cell>
    public typealias ValueToCells = (Datasource.State.Value) -> [Cell]?
    public typealias CellSelected = (Cell) -> ()
    public typealias ConfigureTableViewCell = (UITableViewCell, Cell) -> ()
    public typealias StateToCells =
        (_ state: Datasource.State,
        _ valueToCells: @escaping ValueToCells,
        _ loadingCell: (() -> Cell)?,
        _ errorCell: ((Datasource.State.E) -> Cell)?,
        _ noResultsCell: (() -> Cell)?) -> SingleSectionListItems<Cell>
    
    public var cellSelected: CellSelected?
    public var stateToCells: StateToCells
    public var valueToCells: ValueToCells?
    public var cellToView: CellToView?
    public var configureTableViewCell: ConfigureTableViewCell?
    public var loadingCell: (() -> Cell)?
    public var errorCell: ((Datasource.State.E) -> Cell)?
    public var noResultsCell: (() -> Cell)?
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
    public let scrollViewDidScroll = Signal<Void, NoError>.pipe()
    
    private let dataSource: Datasource
    
    lazy var cells: Property<Cells> = {
        return Property<Cells>(initial: Cells.datasourceNotReady, then: self.cellsProducer())
    }()
    
    public init(dataSource: Datasource, stateToCells: @escaping StateToCells = SingleSectionTableViewDatasource.defaultStateToCells, cellToView: CellToView?, cellSelected: CellSelected?) {
        self.dataSource = dataSource
        self.stateToCells = stateToCells
        self.cellToView = cellToView
        self.cellSelected = cellSelected
    }
    
    public static func defaultStateToCells(state: Datasource.State,
                                           valueToCells: @escaping ValueToCells,
                                           loadingCell: (() -> Cell)?,
                                           errorCell: ((Datasource.State.E) -> Cell)?,
                                           noResultsCell: (() -> Cell)?) -> SingleSectionListItems<Cell> {
        return state.singleSectionListItems(valueToItems: valueToCells, loadingItem: loadingCell, errorItem: errorCell, noResultsItem: noResultsCell)
    }
    
    private func cellsProducer() -> SignalProducer<Cells, NoError> {
        return dataSource.state.map({ [weak self] state -> Cells in
            guard let self = self else { return Cells.datasourceNotReady }
            
            let stateToCells = self.stateToCells
            let valueToCells = self.valueToCells ?? { _ -> [Cell] in
                return [Cell(errorMessage: "Set SingleSectionTableViewDatasource.valueToCells")]
            }
            
            return stateToCells(state, valueToCells, self.loadingCell, self.errorCell, self.noResultsCell)
        })
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let cells = cells.value.items else { return 0 }
        return cells.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cells = cells.value.items, indexPath.row < cells.count else { return UITableViewCell() }
        let cell = cells[indexPath.row]
        if let cellToView = cellToView {
            let tableViewCell = cellToView(cell).view(containingView: tableView, item: cell)
            configureTableViewCell?(tableViewCell, cell)
            return tableViewCell
        } else {
            let fallbackCell = UITableViewCell()
            fallbackCell.textLabel?.text = "Set SingleSectionTableViewDatasource.cellToView"
            return fallbackCell
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cells = cells.value.items else { return }
        let cell = cells[indexPath.row]
        if cell.isSelectable {
            cellSelected?(cell)
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
