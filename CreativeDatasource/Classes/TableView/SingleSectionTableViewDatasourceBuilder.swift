import Foundation

extension SingleSectionTableViewDatasource where Cell: LoadingAndErrorCapableItem, Datasource.State.E == Cell.E {
    
    /// Configures standard components and assumes standard behavior that might be suitable
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
    /// Usage: Instantiate and configure with the offered parameters and functions and add the
    /// `tableViewController` to the view hierarchy.
    open class Builder {
        public typealias TableViewDatasource = SingleSectionTableViewDatasource<Datasource, Cell>
        
        private let datasource: Datasource
        
        public lazy var tableViewDatasource: TableViewDatasource = {
            return TableViewDatasource.init(dataSource: self.datasource, cellToView: nil, cellSelected: nil)
        }()
        
        public init(datasource: Datasource) {
            self.datasource = datasource
            
            self
                .loadingCell { () -> Cell in
                    return Cell.loadingCell
                }
                .errorCell { (error) -> Cell in
                    return Cell.errorCell(error)
                }
                .noResultsCell { () -> Cell in
                    return Cell.noResultsCell
            }
        }
        
        @discardableResult
        public func valueToCells(_ closure: @escaping (Datasource.State.Value) -> [Cell]?) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.valueToCells = closure
            return self
        }
        
        @discardableResult
        public func cellToView(_ closure: @escaping (Cell) -> DefaultTableViewCellProducer<Cell>) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.cellToView = closure
            return self
        }
        
        @discardableResult
        public func loadingCell(_ closure: @escaping () -> Cell) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.loadingCell = closure
            return self
        }
        
        @discardableResult
        public func errorCell(_ closure: @escaping (Datasource.State.E) -> Cell) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.errorCell = closure
            return self
        }
        
        @discardableResult
        public func noResultsCell(_ closure: @escaping () -> Cell) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.noResultsCell = closure
            return self
        }
        
        @discardableResult
        public func cellSelected(_ closure: @escaping (Cell) -> ()) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.cellSelected = closure
            return self
        }
        
        @discardableResult
        public func stateToCells(_ closure: @escaping TableViewDatasource.StateToCells) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.stateToCells = closure
            return self
        }
        
        @discardableResult
        public func configureTableViewCell(_ closure: @escaping (UITableViewCell, Cell) -> ()) -> SingleSectionTableViewDatasource.Builder {
            tableViewDatasource.configureTableViewCell = closure
            return self
        }
        
    }
}


public protocol LoadingAndErrorCapableItem : ListItem {
    associatedtype DatasourceItem: Any
    associatedtype E: DatasourceError
    static var loadingCell: Self {get}
    static var noResultsCell: Self {get}
    static func errorCell(_ error: E) -> Self
    
    init(datasourceItem: DatasourceItem)
}
