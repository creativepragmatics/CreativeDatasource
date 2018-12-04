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
open class LoadingAndErrorCapableTableViewControllerProvider<ResponseContainer: Equatable, Cell: LoadingAndErrorCapableCell, P: Parameters, E> where Cell.E == E {
    public typealias CachedDatasourceConcrete = CachedDatasource<ResponseContainer, P, PullToRefreshLoadImpulseType, E>
    public typealias TableViewController = SingleSectionTableViewController<ResponseContainer, Cell, P, E>
    public typealias TableViewDatasource = SingleSectionTableViewDatasource<ResponseContainer, Cell, P, E>
    public typealias ListItemsProvider = SingleSectionListItemsProvider<ResponseContainer, Cell, P, E>
    public typealias StateToListItemsTransformer = DefaultStateToSingleSectionListItemsTransformer<ResponseContainer, Cell, P, E>
    public typealias TableViewCellProducer = DefaultTableViewCellProducer<Cell>
    public typealias CellSelected = (Cell) -> ()
    public typealias OnPullToRefresh = () -> ()
    public typealias ResponseContainerToCells = (ResponseContainer) -> [Cell]?
    public typealias GetTableViewCellProducer = (Cell) -> TableViewCellProducer
    
    private let datasource: CachedDatasourceConcrete
    private let cellSelected: CellSelected
    private let pullToRefresh: OnPullToRefresh
    private let responseContainerToCells: ResponseContainerToCells
    private let getTableViewCellProducer: GetTableViewCellProducer
    
    public lazy var tableViewController : TableViewController = {
        return TableViewController(tableViewDatasource: self.tableViewDatasource, onPullToRefresh: { [weak self] in
            self?.pullToRefresh()
        })
    }()
    
    private lazy var tableViewDatasource: TableViewDatasource = {
        let transformer = self.stateToListItemsTransformer
        
        let cellsProvider = ListItemsProvider.init(cachedDatasource: self.datasource,
                                                   itemsTransformer: self.stateToListItemsTransformer.any,
                                                   valueToItems: self.responseContainerToCells)
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
        let errorCellGenerator: (E) -> (Cell) = {
            return Cell.errorCell($0)
        }
        let loadingCellGenerator: () -> (Cell) = {
            return Cell.loadingCell
        }
        return StateToListItemsTransformer(noResultsItemGenerator: noResultsCellGenerator,
                                           errorItemGenerator: errorCellGenerator,
                                           loadingCellGenerator: loadingCellGenerator)
    }()
    
    public init(datasource: CachedDatasourceConcrete, cellSelected: @escaping CellSelected, pullToRefresh: @escaping OnPullToRefresh, responseContainerToCells: @escaping ResponseContainerToCells, getTableViewCellProducer: @escaping GetTableViewCellProducer) {
        self.datasource = datasource
        self.cellSelected = cellSelected
        self.pullToRefresh = pullToRefresh
        self.responseContainerToCells = responseContainerToCells
        self.getTableViewCellProducer = getTableViewCellProducer
    }
}

public protocol LoadingAndErrorCapableCell : ListItem {
    associatedtype E: DatasourceError
    static var loadingCell: Self {get}
    static var noResultsCell: Self {get}
    static func errorCell(_ error: E) -> Self
}
