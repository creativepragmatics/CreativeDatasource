import Foundation
import ReactiveSwift
import Result

public struct PlainListCellsProvider<Value: Codable & Equatable, Item: Codable & Equatable, P: Parameters, E: DatasourceError> {
    
    public typealias Cell = PlainListCell<Item, E>
    public typealias Cells = PlainListCells<Item, E>
    public typealias ValueToCells = (Value) -> [Cell]?
    public typealias CompositeDatasourceConcrete = CompositeDatasource<Value, P, PullToRefreshLoadImpulseType, E>
    private typealias CompositeStateConcrete = CompositeState<Value, P, PullToRefreshLoadImpulseType, E>
    
    public let cells: Property<Cells>
    
    public init(compositeDatasource: CompositeDatasourceConcrete, valueToCells: @escaping ValueToCells, noResultsCell: Cell = .empty) {
        self.cells = Property(initial: Cells.datasourceNotReady, then: PlainListCellsProvider.cellsFromStateProducer(compositeDatasource: compositeDatasource, valueToCells: valueToCells, noResultsCell: noResultsCell))
    }
    
    private static func cellsFromStateProducer(compositeDatasource: CompositeDatasourceConcrete, valueToCells: @escaping ValueToCells, noResultsCell: Cell) -> SignalProducer<Cells, NoError> {
        
        return compositeDatasource.compositeState.producer
            .flatMap(.latest, { state -> SignalProducer<Cells, NoError> in
                
                // We do the state-to-cells conversion on a background thread if feasible
                // because we want the app to be as smooth as possible. For the initial states,
                // which are most likely used when a view is first shown, we stay synchronous
                // because we don't want a white screen when cached data is available.
                switch state {
                case .loading, .datasourceNotReady:
                    return cells(state: state, valueToCells: valueToCells, noResultsCell: noResultsCell)
                case .success, .error:
                    // Start in background and return on main thread
                    return cells(state: state, valueToCells: valueToCells, noResultsCell: noResultsCell)
                        .start(on: QueueScheduler())
                        .observe(on: QueueScheduler.main)
                }
            })
    }
    
    private static func cells(state: CompositeStateConcrete, valueToCells: @escaping ValueToCells, noResultsCell: Cell) -> SignalProducer<Cells, NoError> {
        
        func boxedValueToCells(_ box: StrongEqualityValueBox<Value>?) -> [Cell]? {
            return (box?.value).flatMap({ valueToCells($0) })
        }
        
        switch state {
        case .datasourceNotReady:
            return SignalProducer(value: Cells.datasourceNotReady)
        case let .loading(cached, _):
            if let cells = boxedValueToCells(cached), cells.count > 0 {
                return SignalProducer(value: Cells.readyToDisplay(cells))
            } else if let _ = cached?.value {
                // Loading and there is a cached value, but it's empty
                return SignalProducer(value: Cells.readyToDisplay([noResultsCell]))
            } else {
                return SignalProducer(value: Cells.readyToDisplay([.loading])).delay(0.1, on: QueueScheduler.main)
            }
        case let .success(value, _):
            if let cells = boxedValueToCells(value), cells.count > 0 {
                return SignalProducer(value: Cells.readyToDisplay(cells))
            } else {
                return SignalProducer(value: Cells.readyToDisplay([noResultsCell]))
            }
        case let .error(error, cached, _):
            if let cells = boxedValueToCells(cached), cells.count > 0 {
                return SignalProducer(value: Cells.readyToDisplay(cells))
            } else {
                return SignalProducer(value: Cells.readyToDisplay([.error(error)]))
            }
        }
    }
}
