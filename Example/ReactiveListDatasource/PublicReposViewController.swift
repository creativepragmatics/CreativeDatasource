import Foundation
import UIKit
import ReactiveListDatasource

class PublicReposRootViewController : UIViewController {
    typealias TableViewControllerBundle = DefaultCachedAPICallSingleSectionTableViewControllerBundle<PublicReposData.DatasourceBundle, PublicReposCell>
    
    lazy var viewModel: PublicReposViewModel = {
        PublicReposViewModel()
    }()
    
    lazy var tableViewControllerBundle: DefaultCachedAPICallSingleSectionTableViewControllerBundle<PublicReposData.DatasourceBundle, PublicReposCell> = {
        return DefaultCachedAPICallSingleSectionTableViewControllerBundle(datasourceBundle: self.viewModel.datasourceBundle)
    }()
    
    lazy var tableViewController: TableViewControllerBundle.TableViewController = {
        let vc = tableViewControllerBundle.tableViewController
        
        vc.willMove(toParent: self)
        self.addChild(vc)
        self.view.addSubview(vc.view)
        
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        vc.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        vc.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        vc.view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        vc.view.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        
        vc.didMove(toParent: self)
        
        return vc
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Storyboards not supported for PublicReposViewController")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Github Public Repos"
        
        tableViewControllerBundle.tableViewDatasource
            .configure(with: tableViewController.tableView) { configure in
                return configure
                    .valueToItems({ publicReposResponseContainer -> [PublicReposCell]? in
                        return publicReposResponseContainer.map({ PublicReposCell.repo($0) })
                    })
                    .itemToView({ viewType -> TableViewControllerBundle.CellProducer in
                        switch viewType {
                        case .repo:
                            return TableViewControllerBundle.CellProducer.instantiate({ cell -> UITableViewCell in
                                switch cell {
                                case .loading, .noResults, .error: return UITableViewCell()
                                case let .repo(repo):
                                    let cell = UITableViewCell()
                                    cell.textLabel?.text = repo.full_name
                                    return cell
                                }
                            })
                        case .loading:
                            return .instantiate({ _ in return LoadingCell() })
                        case .error:
                            return .instantiate({ cell in
                                guard case let .error(error) = cell else { return ErrorTableViewCell() }
                                let tableViewCell = ErrorTableViewCell()
                                tableViewCell.content = error.errorMessage
                                return tableViewCell
                            })
                        case .noResults:
                            return .instantiate({ _ in
                                let tableViewCell = ErrorTableViewCell()
                                tableViewCell.content = DatasourceErrorMessage.message("Strangely, there are no public repos on Github.")
                                return tableViewCell
                            })
                        }
                    })
                    .itemSelected({ [weak self] cell in
                        guard case let .repo(repo) = cell else { return }
                        self?.repoSelected(repo: repo)
                    })
                
        }
        
        tableViewController.onPullToRefresh = { [weak self] in
            guard let strongSelf = self else { return }
            if !strongSelf.viewModel.refresh() {
                strongSelf.tableViewController.refreshControl?.beginRefreshing()
            }
        }
        
        let _ = tableViewController // force init
        
        setupObservers()
    }
    
    private func setupObservers() {
        
        viewModel.loadingEnded.startWithValues { [weak self] _ in
            self?.tableViewController.refreshControl?.endRefreshing()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        viewModel.datasourceBundle.loadImpulseEmitter.timerMode.value = .timeInterval(.seconds(30))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        viewModel.datasourceBundle.loadImpulseEmitter.timerMode.value = .none
    }
    
    func pullToRefresh() {
        if !viewModel.refresh() {
            tableViewController.refreshControl?.beginRefreshing()
        }
    }
    
    func repoSelected(repo: PublicRepo) {
        print("Repo selected")
    }
    
}
