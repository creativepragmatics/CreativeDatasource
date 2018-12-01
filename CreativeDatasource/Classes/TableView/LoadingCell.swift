import Foundation
import UIKit

open class LoadingCell : UITableViewCell {
    
    lazy var loadingIndicatorView: UIActivityIndicatorView = {
        let loadingIndicatorView = UIActivityIndicatorView(style: .whiteLarge)
        loadingIndicatorView.color = .gray
        loadingIndicatorView.hidesWhenStopped = false
        self.contentView.addSubview(loadingIndicatorView)
        loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicatorView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 20).isActive = true
        loadingIndicatorView.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor).isActive = true
        loadingIndicatorView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -20).isActive = true
        
        return loadingIndicatorView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = .white
        separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
        selectionStyle = .none
    }
    
    func startAnimating() {
        loadingIndicatorView.startAnimating()
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        loadingIndicatorView.startAnimating()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
