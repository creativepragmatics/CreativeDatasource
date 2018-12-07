import Foundation
import ReactiveSwift
import Result

public struct SingleSectionListItemsProvider<Datasource: DatasourceProtocol, Item: ListItem> {
    public typealias Items = SingleSectionListItems<Item>
    public typealias State = Datasource.State
    public typealias Value = Datasource.State.Value
    public typealias ValueToItems = (Value) -> [Item]?
    public typealias ItemsTransformer = AnyStateToSingleSectionListItemsTransformer<State, Item>
    
    public let cells: Property<Items>
    
    public init(datasource: Datasource,
                itemsTransformer: ItemsTransformer,
                valueToItems: @escaping ValueToItems) {
        self.cells = Property(initial: .datasourceNotReady, then: SingleSectionListItemsProvider.cellsFromStateProducer(datasource: datasource, itemsTransformer: itemsTransformer, valueToItems: valueToItems))
    }
    
    private static func cellsFromStateProducer(datasource: Datasource, itemsTransformer: ItemsTransformer, valueToItems: @escaping ValueToItems)
        -> SignalProducer<Items, NoError> {
            
            return datasource.state
                .flatMap(.latest, { state -> SignalProducer<Items, NoError> in
                    
                    // We do the state-to-cells conversion on a background thread if feasible
                    // because we want the app to be as smooth as possible. For the initial states,
                    // which are most likely used when a view is first shown, we stay synchronous
                    // because we don't want a white screen when cached data is available.
                    switch state.provisioningState {
                    case .loading, .notReady:
                        return itemsTransformer.cells(state: state, valueToItems: valueToItems)
                    case .result:
                        // Start in background and return on main thread
                        return itemsTransformer.cells(state: state, valueToItems: valueToItems)
                            .start(on: QueueScheduler())
                            .observe(on: QueueScheduler.main)
                    }
                })
    }
}

extension SingleSectionListItemsProvider {
    public typealias ErrorItemGenerator = (State.E) -> Item
    public typealias ArbitraryItemGenerator = () -> Item
    
    static func withDefaultItemsTransformer(datasource: Datasource,
                                            valueToItems: @escaping ValueToItems,
                                            noResultsItemGenerator: ArbitraryItemGenerator? = nil,
                                            errorItemGenerator: ErrorItemGenerator? = nil,
                                            loadingCellGenerator: ArbitraryItemGenerator? = nil) -> SingleSectionListItemsProvider {
        typealias ItemsTransformer = DefaultStateToSingleSectionListItemsTransformer<State, Item>
        let defaultItemsTransformer = ItemsTransformer.init(noResultsItemGenerator: noResultsItemGenerator, errorItemGenerator: errorItemGenerator, loadingCellGenerator: loadingCellGenerator).any
        return SingleSectionListItemsProvider.init(datasource: datasource, itemsTransformer: defaultItemsTransformer, valueToItems: valueToItems)
    }
}

/// Transforms the given state to list items for use in a single section
/// list.
public protocol StateToSingleSectionListItemsTransformer {
    associatedtype State: StateProtocol
    associatedtype Item: ListItem
    typealias ValueToItems = (State.Value) -> [Item]?
    typealias ArbitraryItemGenerator = () -> Item
    
    func cells(state: State,
               valueToItems: @escaping ValueToItems) -> SignalProducer<SingleSectionListItems<Item>, NoError>
}

public extension StateToSingleSectionListItemsTransformer {
    public var any: AnyStateToSingleSectionListItemsTransformer<State, Item> {
        return AnyStateToSingleSectionListItemsTransformer(self)
    }
}

public struct AnyStateToSingleSectionListItemsTransformer<State_: StateProtocol, Item_: ListItem>: StateToSingleSectionListItemsTransformer {
    public typealias State = State_
    public typealias Item = Item_
    public typealias ValueToItems = (State.Value) -> [Item]?
    
    private let _cells: (State, @escaping ValueToItems) -> SignalProducer<SingleSectionListItems<Item>, NoError>
    
    init<T: StateToSingleSectionListItemsTransformer>(_ transformer: T) where T.State == State, T.Item == Item {
        self._cells = transformer.cells
    }
    
    public func cells(state: State, valueToItems: @escaping ValueToItems) -> SignalProducer<SingleSectionListItems<Item>, NoError> {
        return _cells(state, valueToItems)
    }
}


/// Default implementation for `StateToSingleSectionListItemsTransformer`.
public struct DefaultStateToSingleSectionListItemsTransformer<State_: StateProtocol, Item_: ListItem>: StateToSingleSectionListItemsTransformer {
    public typealias State = State_
    public typealias Item = Item_
    public typealias ValueToItems = (State.Value) -> [Item]?
    public typealias Items = SingleSectionListItems<Item>
    public typealias ErrorItemGenerator = (State.E) -> Item
    public typealias ArbitraryItemGenerator = () -> Item
    
    private let noResultsItemGenerator: ArbitraryItemGenerator?
    private let errorItemGenerator: ErrorItemGenerator?
    private let loadingCellGenerator: ArbitraryItemGenerator?
    
    public init(noResultsItemGenerator: ArbitraryItemGenerator? = nil,
         errorItemGenerator: ErrorItemGenerator?,
         loadingCellGenerator: ArbitraryItemGenerator?) {
        
        self.noResultsItemGenerator = noResultsItemGenerator
        self.errorItemGenerator = errorItemGenerator
        self.loadingCellGenerator = loadingCellGenerator
    }
    
    /// Returns cells according to the `state` and the given `valueToItems` closure.
    /// If no values are currently available, return nil in valueToItems to
    /// show an item generated by `noResultsItemGenerator`/`errorItemGenerator`/`loadingCellGenerator`
    /// instead.
    public func cells(state: State, valueToItems: @escaping ValueToItems) -> SignalProducer<Items, NoError> {
        
        func boxedValueToItems(_ box: StrongEqualityValueBox<State.Value>?) -> [Item]? {
            return (box?.value).flatMap({ valueToItems($0) })
        }
        
        switch state.provisioningState {
        case .notReady:
            return SignalProducer(value: Items.datasourceNotReady)
        case let .loading:
            let cachedValueBox = state.result?.value
            if let items = boxedValueToItems(cachedValueBox), items.count > 0 {
                // Loading and there are cached items, return them
                return SignalProducer(value: Items.readyToDisplay(items))
            } else if let _ = cachedValueBox {
                // Loading and there are empty cached items, return noResults item
                if let noResultsItemGenerator = noResultsItemGenerator {
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay([noResultsItemGenerator()]))
                } else {
                    // No noResultsItemGenerator set, return empty items
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay([]))
                }
            } else {
                // Loading and there is no cached value, return loading item
                if let loadingCellGenerator = loadingCellGenerator {
                    // Delay the loading cell by 0.1 seconds
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay([loadingCellGenerator()]))
                } else {
                    // No loadingCellGenerator set, return empty items
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay([]))
                }
            }
        case let .result:
            guard let result = state.result else { return SignalProducer(value: SingleSectionListItems.readyToDisplay([])) }
            
            switch result {
            case let .success(valueBox):
                if let cells = boxedValueToItems(valueBox), cells.count > 0 {
                    // Success, return items
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay(cells))
                } else if let noResultsItemGenerator = noResultsItemGenerator {
                    // Success without items, return noResult item
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay([noResultsItemGenerator()]))
                } else {
                    // Success without items and no noResultsItemGenerator set, return empty items
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay([]))
                }
            case let .failure(error):
                if let cells = boxedValueToItems(state.result?.value), cells.count > 0 {
                    // Error and there are cached items, return them
                    return SignalProducer(value: SingleSectionListItems.readyToDisplay(cells))
                } else {
                    // Error and no cached items, return error item
                    if let errorItemGenerator = errorItemGenerator {
                        return SignalProducer(value: SingleSectionListItems.readyToDisplay([errorItemGenerator(error)]))
                    } else {
                        // No errorItemGenerator set, return empty items
                        return SignalProducer(value: SingleSectionListItems.readyToDisplay([]))
                    }
                }
            }
        }
    }
    
}
