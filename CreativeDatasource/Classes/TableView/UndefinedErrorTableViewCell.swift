import Foundation
import UIKit

open class ErrorTableViewCell : UITableViewCell {
    
    var content: ErrorTableViewCellContent = .default {
        didSet {
            refreshContent()
        }
    }
    
    lazy var label: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        l.textColor = .gray
        l.textAlignment = .center
        l.numberOfLines = 0
        
        self.contentView.addSubview(l)
        l.translatesAutoresizingMaskIntoConstraints = false
        l.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 20).isActive = true
        l.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: 20).isActive = true
        l.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -20).isActive = true
        l.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant: -20).isActive = true
        l.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        
        return l
    }()
    
    override open func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        refreshContent()
    }
    
    func refreshContent() {
        label.text = {
            switch content {
            case .default:
                return NSLocalizedString("Ein Fehler ist beim Laden aufgetreten.\nBitte versuchen Sie es erneut!", comment: "")
            case let .message(string):
                return string
            }
        }()
    }
}

enum ErrorTableViewCellContent {
    case `default`
    case message(String)
}

