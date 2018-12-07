import Foundation

/// Instantiates standard components and assumes standard behavior that might be suitable
/// for most "normal" UITableView use cases:
///   - Cached datasource is required (which can also be instantiated without a cache BTW)
///   - A response container is shown from which Cells are retrieved (configurable via closure)
///   - Pull to refresh is enabled (might be configurable later on)
///   - When loading, a UIActivityIndicatorView is shown in a cell
///   - If an error occurs, a specific cell is shown
///   - If no results are visible, a specific cell is shown
///   - Cells are either selectable or not
///   - TableView updates are animated if the view is visible
///
/// Usage: Instantiate with the required parameters and add the `tableViewController`
/// to the view hierarchy.
open class LoadingAndErrorCapableTableViewControllerProvider<Datasource: DatasourceProtocol, Cell: LoadingAndErrorCapableCell> where Cell.E == Datasource.State.E {
    public typealias State = Datasource.State
    public typealias Value = State.Value
    public typealias TableViewController = SingleSectionTableViewController<Datasource, Cell>
    public typealias TableViewDatasource = SingleSectionTableViewDatasource<Datasource, Cell>
    public typealias ListItemsProvider = SingleSectionListItemsProvider<Datasource, Cell>
    public typealias StateToListItemsTransformer = DefaultStateToSingleSectionListItemsTransformer<Datasource.State, Cell>
    public typealias TableViewCellProducer = DefaultTableViewCellProducer<Cell>
    public typealias CellSelected = (Cell) -> ()
    public typealias OnPullToRefresh = () -> ()
    public typealias ValueToCells = (Value) -> [Cell]?
    public typealias GetTableViewCellProducer = (Cell) -> TableViewCellProducer
    
    private let datasource: Datasource
    private let cellSelected: CellSelected
    private let pullToRefresh: OnPullToRefresh
    private let valueToCells: ValueToCells
    private let getTableViewCellProducer: GetTableViewCellProducer
    
    public lazy var tableViewController : TableViewController = {
        return TableViewController(tableViewDatasource: self.tableViewDatasource, onPullToRefresh: { [weak self] in
            self?.pullToRefresh()
        })
    }()
    
    private lazy var tableViewDatasource: TableViewDatasource = {
        let transformer = self.stateToListItemsTransformer
        
        let cellsProvider = ListItemsProvider.init(datasource: self.datasource,
                                                   itemsTransformer: self.stateToListItemsTransformer.any,
                                                   valueToItems: self.valueToCells)
        return TableViewDatasource(cellsProvider: cellsProvider,
                                   cellViewProducer: self.getTableViewCellProducer,
                                   itemSelected: { [weak self] cell in
                                    self?.cellSelected(cell)
        })
    }()
    
    private lazy var stateToListItemsTransformer: StateToListItemsTransformer = {
        let noResultsCellGenerator: () -> (Cell) = {
            return Cell.noResultsCell
        }
        let errorCellGenerator: (State.E) -> (Cell) = {
            return Cell.errorCell($0)
        }
        let loadingCellGenerator: () -> (Cell) = {
            return Cell.loadingCell
        }
        return StateToListItemsTransformer(noResultsItemGenerator: noResultsCellGenerator,
                                           errorItemGenerator: errorCellGenerator,
                                           loadingCellGenerator: loadingCellGenerator)
    }()
    
    public init(datasource: Datasource, cellSelected: @escaping CellSelected, pullToRefresh: @escaping OnPullToRefresh, valueToCells: @escaping ValueToCells, getTableViewCellProducer: @escaping GetTableViewCellProducer) {
        self.datasource = datasource
        self.cellSelected = cellSelected
        self.pullToRefresh = pullToRefresh
        self.valueToCells = valueToCells
        self.getTableViewCellProducer = getTableViewCellProducer
    }
}

public protocol LoadingAndErrorCapableCell : ListItem {
    associatedtype E: DatasourceError
    static var loadingCell: Self {get}
    static var noResultsCell: Self {get}
    static func errorCell(_ error: E) -> Self
}
