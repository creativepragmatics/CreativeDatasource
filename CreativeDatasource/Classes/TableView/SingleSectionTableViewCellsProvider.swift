import Foundation
import ReactiveSwift
import Result

public struct SingleSectionTableViewCellsProvider<DatasourceValue: Equatable, SelectableItem: Equatable, Id: CellId, P: Parameters, E: DatasourceError> {
    
    public typealias Cell = TableViewCell<SelectableItem, Id>
    public typealias Cells = TableViewCells<SelectableItem, Id>
    public typealias ValueToCells = (DatasourceValue) -> [Cell]?
    public typealias CachedDatasourceConcrete = CachedDatasource<DatasourceValue, P, PullToRefreshLoadImpulseType, E>
    public typealias ErrorCellGenerator = (E) -> Cell
    public typealias ArbitraryCellGenerator = () -> Cell
    private typealias CachedStateConcrete = CachedState<DatasourceValue, P, PullToRefreshLoadImpulseType, E>
    
    public let cells: Property<Cells>
    
    public init(cachedDatasource: CachedDatasourceConcrete,
                valueToCells: @escaping ValueToCells,
                noResultsCellGenerator: ArbitraryCellGenerator? = nil,
                errorCellGenerator: @escaping ErrorCellGenerator = defaultErrorCellGenerator,
                loadingCellGenerator: @escaping ArbitraryCellGenerator = defaultLoadingCellGenerator) {
        self.cells = Property(initial: TableViewCells.datasourceNotReady, then: SingleSectionTableViewCellsProvider.cellsFromStateProducer(cachedDatasource: cachedDatasource, valueToCells: valueToCells, noResultsCellGenerator: noResultsCellGenerator, errorCellGenerator: errorCellGenerator, loadingCellGenerator: loadingCellGenerator))
    }
    
    public static func defaultErrorCellGenerator(_ error: E) -> Cell {
        return Cell.error(error.cellContent)
    }
    
    public static func defaultLoadingCellGenerator() -> Cell {
        return Cell.loading
    }
    
    private static func cellsFromStateProducer(cachedDatasource: CachedDatasourceConcrete,
                                               valueToCells: @escaping ValueToCells,
                                               noResultsCellGenerator: ArbitraryCellGenerator?,
                                               errorCellGenerator: @escaping ErrorCellGenerator,
                                               loadingCellGenerator: @escaping ArbitraryCellGenerator)
        -> SignalProducer<Cells, NoError> {
            
            return cachedDatasource.cachedState.producer
                .flatMap(.latest, { state -> SignalProducer<Cells, NoError> in
                    
                    // We do the state-to-cells conversion on a background thread if feasible
                    // because we want the app to be as smooth as possible. For the initial states,
                    // which are most likely used when a view is first shown, we stay synchronous
                    // because we don't want a white screen when cached data is available.
                    switch state {
                    case .loading, .datasourceNotReady:
                        return cells(state: state, valueToCells: valueToCells, noResultsCellGenerator: noResultsCellGenerator, errorCellGenerator: errorCellGenerator)
                    case .success, .error:
                        // Start in background and return on main thread
                        return cells(state: state, valueToCells: valueToCells, noResultsCellGenerator: noResultsCellGenerator, errorCellGenerator: errorCellGenerator)
                            .start(on: QueueScheduler())
                            .observe(on: QueueScheduler.main)
                    }
                })
    }
    
    private static func cells(state: CachedStateConcrete,
                              valueToCells: @escaping ValueToCells,
                              noResultsCellGenerator: ArbitraryCellGenerator?,
                              errorCellGenerator: ErrorCellGenerator) -> SignalProducer<Cells, NoError> {
        
        func boxedValueToCells(_ box: StrongEqualityValueBox<DatasourceValue>?) -> [Cell]? {
            return (box?.value).flatMap({ valueToCells($0) })
        }
        
        switch state {
        case .datasourceNotReady:
            return SignalProducer(value: TableViewCells.datasourceNotReady)
        case let .loading(cached, _):
            if let cells = boxedValueToCells(cached), cells.count > 0 {
                return SignalProducer(value: TableViewCells.readyToDisplay(cells))
            } else if let _ = cached?.value {
                // Loading and there is a cached value, but it's empty
                if let noResultsCellGenerator = noResultsCellGenerator {
                    return SignalProducer(value: TableViewCells.readyToDisplay([noResultsCellGenerator()]))
                } else {
                    return SignalProducer(value: TableViewCells.readyToDisplay([Cell.empty]))
                }
            } else {
                return SignalProducer(value: TableViewCells.readyToDisplay([.loading])).delay(0.1, on: QueueScheduler.main)
            }
        case let .success(value, _):
            if let cells = boxedValueToCells(value), cells.count > 0 {
                return SignalProducer(value: TableViewCells.readyToDisplay(cells))
            } else if let noResultsCellGenerator = noResultsCellGenerator {
                return SignalProducer(value: TableViewCells.readyToDisplay([noResultsCellGenerator()]))
            } else {
                return SignalProducer(value: TableViewCells.readyToDisplay([Cell.empty]))
            }
        case let .error(error, cached, _):
            if let cells = boxedValueToCells(cached), cells.count > 0 {
                return SignalProducer(value: TableViewCells.readyToDisplay(cells))
            } else {
                return SignalProducer(value: TableViewCells.readyToDisplay([errorCellGenerator(error)]))
            }
        }
    }
}
