import Foundation
import UIKit
import ReactiveSwift
import Result

open class DefaultCollectionViewDatasource<Datasource: DatasourceProtocol, CellViewProducer: CollectionViewCellProducer, Section: ListSection>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate where CellViewProducer.Item : DefaultListItem, CellViewProducer.Item.E == Datasource.State.E {
    
    public typealias Core = DefaultListViewDatasourceCore<Datasource, CellViewProducer, Section>
    
    private let dataSource: Datasource
    public var core: Core
    
    public lazy var sections: Property<Core.Sections> = {
        return Property<Core.Sections>(initial: Core.Sections.datasourceNotReady, then: self.sectionsProducer())
    }()
    
    public init(dataSource: Datasource) {
        self.dataSource = dataSource
        self.core = DefaultListViewDatasourceCore()
    }
    
    public func configure(with collectionView: UICollectionView, _ build: (Core.Builder) -> (Core.Builder)) {
        core = build(core.builder).core
        
        core.errorSection = core.errorSection ?? { error in SectionWithItems(Section(), [Core.Item.errorCell(error)]) }
        core.loadingSection = core.loadingSection ?? { SectionWithItems(Section(), [Core.Item.loadingCell]) }
        core.noResultsSection = core.noResultsSection ?? { SectionWithItems(Section(), [Core.Item.noResultsCell]) }
        
        core.itemToViewMapping.forEach { arg in
            let (itemViewType, producer) = arg
            producer.register(itemViewType: itemViewType, at: collectionView)
        }
    }
    
    private func sectionsProducer() -> SignalProducer<Core.Sections, NoError> {
        return dataSource.state.map({ [weak self] state -> Core.Sections in
            guard let self = self else { return Core.Sections.datasourceNotReady }
            let stateToSections = self.core.stateToSections
            let valueToSections = self.core.valueToSections ?? { _ -> [SectionWithItems<Core.Item, Core.Section>]? in
                let errorItem = Core.Item.init(errorMessage: "Set DefaultCollectionViewDatasource.valueToSections")
                return [SectionWithItems.init(Core.Section(), [errorItem])]
            }
            
            return stateToSections(state, valueToSections, self.core.loadingSection, self.core.errorSection, self.core.noResultsSection)
        })
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.value.sectionsWithItems?.count ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections.value.sectionsWithItems?[section].items.count ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let sectionsWithItems = sections.value.sectionsWithItems, indexPath.row < sectionsWithItems.count else {
            return UICollectionViewCell()
        }
        let cell = sectionsWithItems[indexPath.section].items[indexPath.item]
        if let itemViewProducer = core.itemToViewMapping[cell.viewType] {
            return itemViewProducer.view(containingView: collectionView, item: cell, for: indexPath)
        } else {
            let fallbackCell = UICollectionViewCell()
            let label = UILabel()
            label.text = "Set DefaultListViewDatasourceCore.itemToViewMapping"
            label.textAlignment = .center
            fallbackCell.contentView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.topAnchor.constraint(equalTo: fallbackCell.contentView.topAnchor).isActive = true
            label.leftAnchor.constraint(equalTo: fallbackCell.contentView.leftAnchor).isActive = true
            label.rightAnchor.constraint(equalTo: fallbackCell.contentView.rightAnchor).isActive = true
            label.bottomAnchor.constraint(equalTo: fallbackCell.contentView.bottomAnchor).isActive = true
            return fallbackCell
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sectionsWithItems = sections.value.sectionsWithItems, indexPath.row < sectionsWithItems.count else {
            return
        }
        let sectionWithItems = sectionsWithItems[indexPath.section]
        let cell = sectionWithItems.items[indexPath.item]
        if cell.viewType.isSelectable {
            core.itemSelected?(cell, sectionWithItems.section)
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        core.scrollViewDidScroll.input.send(value: ())
    }
    
}

public extension DefaultCollectionViewDatasource {

    public func sectionWithItems(at indexPath: IndexPath) -> SectionWithItems<CellViewProducer.Item, Section>? {
        guard let sectionsWithItems = sections.value.sectionsWithItems,
            indexPath.section < sectionsWithItems.count else { return nil }
        return sectionsWithItems[indexPath.section]
    }
    
    public func section(at indexPath: IndexPath) -> Section? {
        return sectionWithItems(at: indexPath)?.section
    }
    
    public func item(at indexPath: IndexPath) -> CellViewProducer.Item? {
        guard let sectionWithItems = self.sectionWithItems(at: indexPath) else { return nil }
        guard indexPath.item < sectionWithItems.items.count else { return nil }
        return sectionWithItems.items[indexPath.item]
    }
}

