import Foundation
import ReactiveSwift
import Result

public struct SingleSectionListItemsProvider<DatasourceValue: Equatable, Item: ListItem, P: Parameters, E: DatasourceError> {
    public typealias Items = SingleSectionListItems<Item>
    public typealias ValueToItems = (DatasourceValue) -> [Item]?
    public typealias CachedDatasourceConcrete = CachedDatasource<DatasourceValue, P, PullToRefreshLoadImpulseType, E>
    public typealias ItemsTransformer = AnyStateToSingleSectionListItemsTransformer<DatasourceValue, Item, P, E>
    private typealias CachedStateConcrete = CachedState<DatasourceValue, P, PullToRefreshLoadImpulseType, E>
    
    public let cells: Property<Items>
    
    public init(cachedDatasource: CachedDatasourceConcrete,
                itemsTransformer: ItemsTransformer,
                valueToItems: @escaping ValueToItems) {
        self.cells = Property(initial: .datasourceNotReady, then: SingleSectionListItemsProvider.cellsFromStateProducer(cachedDatasource: cachedDatasource, itemsTransformer: itemsTransformer, valueToItems: valueToItems))
    }
    
    private static func cellsFromStateProducer(cachedDatasource: CachedDatasourceConcrete, itemsTransformer: ItemsTransformer, valueToItems: @escaping ValueToItems)
        -> SignalProducer<Items, NoError> {
            
            return cachedDatasource.cachedState.producer
                .flatMap(.latest, { state -> SignalProducer<Items, NoError> in
                    
                    // We do the state-to-cells conversion on a background thread if feasible
                    // because we want the app to be as smooth as possible. For the initial states,
                    // which are most likely used when a view is first shown, we stay synchronous
                    // because we don't want a white screen when cached data is available.
                    switch state {
                    case .loading, .datasourceNotReady:
                        return itemsTransformer.cells(state: state, valueToItems: valueToItems)
                    case .success, .error:
                        // Start in background and return on main thread
                        return itemsTransformer.cells(state: state, valueToItems: valueToItems)
                            .start(on: QueueScheduler())
                            .observe(on: QueueScheduler.main)
                    }
                })
    }
}

extension SingleSectionListItemsProvider {
    public typealias ErrorItemGenerator = (E) -> Item
    public typealias ArbitraryItemGenerator = () -> Item
    
    static func withDefaultItemsTransformer(cachedDatasource: CachedDatasourceConcrete,
                                            valueToItems: @escaping ValueToItems,
                                            noResultsItemGenerator: ArbitraryItemGenerator? = nil,
                                            errorItemGenerator: ErrorItemGenerator? = nil,
                                            loadingCellGenerator: ArbitraryItemGenerator? = nil) -> SingleSectionListItemsProvider {
        typealias ItemsTransformer = DefaultStateToSingleSectionListItemsTransformer<DatasourceValue, Item, P, E>
        let defaultItemsTransformer = ItemsTransformer.init(noResultsItemGenerator: noResultsItemGenerator, errorItemGenerator: errorItemGenerator, loadingCellGenerator: loadingCellGenerator).any
        return SingleSectionListItemsProvider.init(cachedDatasource: cachedDatasource, itemsTransformer: defaultItemsTransformer, valueToItems: valueToItems)
    }
}

/// Transforms the given state to list items for use in a single section
/// list.
public protocol StateToSingleSectionListItemsTransformer {
    associatedtype DatasourceValue: Equatable
    associatedtype Item: ListItem
    associatedtype P: Parameters
    associatedtype E: DatasourceError
    typealias CachedStateConcrete = CachedState<DatasourceValue, P, PullToRefreshLoadImpulseType, E>
    typealias ValueToItems = (DatasourceValue) -> [Item]?
    typealias ArbitraryItemGenerator = () -> Item
    
    func cells(state: CachedStateConcrete,
               valueToItems: @escaping ValueToItems) -> SignalProducer<SingleSectionListItems<Item>, NoError>
}

public extension StateToSingleSectionListItemsTransformer {
    public var any: AnyStateToSingleSectionListItemsTransformer<DatasourceValue, Item, P, E> {
        return AnyStateToSingleSectionListItemsTransformer(self)
    }
}

public struct AnyStateToSingleSectionListItemsTransformer<DatasourceValue_: Equatable, Item_: ListItem, P_: Parameters, E_: DatasourceError>: StateToSingleSectionListItemsTransformer {
    public typealias DatasourceValue = DatasourceValue_
    public typealias Item = Item_
    public typealias P = P_
    public typealias E = E_
    public typealias CachedStateConcrete = CachedState<DatasourceValue, P, PullToRefreshLoadImpulseType, E>
    public typealias ValueToItems = (DatasourceValue) -> [Item]?
    
    private let _cells: (CachedStateConcrete, @escaping ValueToItems) -> SignalProducer<SingleSectionListItems<Item>, NoError>
    
    init<T: StateToSingleSectionListItemsTransformer>(_ transformer: T) where T.DatasourceValue == DatasourceValue, T.P == P, T.Item == Item, T.E == E {
        self._cells = transformer.cells
    }
    
    public func cells(state: CachedStateConcrete, valueToItems: @escaping ValueToItems) -> SignalProducer<SingleSectionListItems<Item>, NoError> {
        return _cells(state, valueToItems)
    }
}


/// Default implementation for `StateToSingleSectionListItemsTransformer`.
public struct DefaultStateToSingleSectionListItemsTransformer<DatasourceValue_: Equatable, Item_: ListItem, P_: Parameters, E_: DatasourceError>: StateToSingleSectionListItemsTransformer {
    public typealias DatasourceValue = DatasourceValue_
    public typealias Item = Item_
    public typealias P = P_
    public typealias E = E_
    public typealias CachedStateConcrete = CachedState<DatasourceValue, P, PullToRefreshLoadImpulseType, E>
    public typealias ValueToItems = (DatasourceValue) -> [Item]?
    public typealias Items = SingleSectionListItems<Item>
    public typealias ErrorItemGenerator = (E) -> Item
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
    public func cells(state: CachedStateConcrete, valueToItems: @escaping ValueToItems) -> SignalProducer<Items, NoError> {
        
        func boxedValueToItems(_ box: StrongEqualityValueBox<DatasourceValue>?) -> [Item]? {
            return (box?.value).flatMap({ valueToItems($0) })
        }
        
        switch state {
        case .datasourceNotReady:
            return SignalProducer(value: Items.datasourceNotReady)
        case let .loading(cached, _):
            if let items = boxedValueToItems(cached), items.count > 0 {
                // Loading and there are cached items, return them
                return SignalProducer(value: Items.readyToDisplay(items))
            } else if let _ = cached?.value {
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
        case let .success(value, _):
            if let cells = boxedValueToItems(value), cells.count > 0 {
                // Success, return items
                return SignalProducer(value: SingleSectionListItems.readyToDisplay(cells))
            } else if let noResultsItemGenerator = noResultsItemGenerator {
                // Success without items, return noResult item
                return SignalProducer(value: SingleSectionListItems.readyToDisplay([noResultsItemGenerator()]))
            } else {
                // Success without items and no noResultsItemGenerator set, return empty items
                return SignalProducer(value: SingleSectionListItems.readyToDisplay([]))
            }
        case let .error(error, cached, _):
            if let cells = boxedValueToItems(cached), cells.count > 0 {
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
