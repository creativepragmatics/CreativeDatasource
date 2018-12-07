import Foundation

extension SingleSectionTableViewController where Cell: LoadingAndErrorCapableItem, Datasource.State.E == Cell.E {
    
    open class Builder {
        public typealias TableViewDatasource = SingleSectionTableViewDatasource<Datasource, Cell>
        
        private let tableViewDatasource: TableViewDatasource
        
        public lazy var tableViewController: SingleSectionTableViewController = {
            return SingleSectionTableViewController(tableViewDatasource: self.tableViewDatasource, onPullToRefresh: nil)
        }()
        
        public init(tableViewDatasource: TableViewDatasource) {
            self.tableViewDatasource = tableViewDatasource
        }
        
        @discardableResult
        public func pullToRefresh(_ closure: @escaping () -> ()) -> SingleSectionTableViewController.Builder {
            tableViewController.onPullToRefresh = closure
            return self
        }
        
    }
    
}
