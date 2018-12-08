import Foundation
import UIKit
import ReactiveSwift
import Result

open class DefaultSingleSectionTableViewDatasource<Datasource: DatasourceProtocol, CellViewProducer: TableViewCellProducer>: NSObject, UITableViewDelegate, UITableViewDataSource where CellViewProducer.Item : DefaultListItem, CellViewProducer.Item.E == Datasource.State.E {
    
    public typealias Core = DefaultSingleSectionListViewDatasourceCore<Datasource, CellViewProducer>
    
    private let dataSource: Datasource
    public var core: Core
    
    lazy var cells: Property<Core.Items> = {
        return Property<Core.Items>(initial: Core.Items.datasourceNotReady, then: self.cellsProducer())
    }()
    
    public init(dataSource: Datasource) {
        self.dataSource = dataSource
        self.core = DefaultSingleSectionListViewDatasourceCore()
    }
    
    public func configure(with tableView: UITableView, _ build: (Core.Builder) -> (Core.Builder)) {
        core = build(core.builder).core
        
        core.errorItem = core.errorItem ?? { error in Core.Item.errorCell(error) }
        core.loadingItem = core.loadingItem ?? { Core.Item.loadingCell }
        core.noResultsItem = core.noResultsItem ?? { Core.Item.noResultsCell }
        
        core.itemToViewMapping.forEach { (itemViewType, producer) in
            producer.register(itemViewType: itemViewType, at: tableView)
        }
    }
    
    private func cellsProducer() -> SignalProducer<Core.Items, NoError> {
        return dataSource.state.map({ [weak self] state -> Core.Items in
            guard let self = self else { return Core.Items.datasourceNotReady }
            
            let stateToItems = self.core.stateToItems
            let valueToItems = self.core.valueToItems ?? { _ -> [Core.Item] in
                return [Core.Item(errorMessage: "Set DefaultSingleSectionListViewDatasourceCore.valueToItems")]
            }
            
            return stateToItems(state, valueToItems, self.core.loadingItem, self.core.errorItem, self.core.noResultsItem)
        })
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let cells = cells.value.items else { return 0 }
        return cells.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cells = cells.value.items, indexPath.row < cells.count else { return UITableViewCell() }
        let cell = cells[indexPath.row]
        if let itemViewProducer = core.itemToViewMapping[cell.viewType] {
            return itemViewProducer.view(containingView: tableView, item: cell)
        } else {
            let fallbackCell = UITableViewCell()
            fallbackCell.textLabel?.text = "Set DefaultSingleSectionListViewDatasourceCore.itemToViewMapping"
            return fallbackCell
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cells = cells.value.items else { return }
        let cell = cells[indexPath.row]
        if cell.viewType.isSelectable {
            core.itemSelected?(cell)
        }
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return core.heightAtIndexPath[indexPath] ?? UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        core.heightAtIndexPath[indexPath] = cell.frame.size.height
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        core.scrollViewDidScroll.input.send(value: ())
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
}

