import Foundation
import UIKit

open class ErrorTableViewCell : UITableViewCell {
    
    public var content: ErrorTableViewCellContent = .default {
        didSet {
            refreshContent()
        }
    }
    
    open var defaultErrorMessage: String {
        return NSLocalizedString("An error occurred while loading.\nPlease try again!", comment: "")
    }
    
    public lazy var label: UILabel = {
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
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    public init() {
        super.init(style: .default, reuseIdentifier: nil)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("ErrorTableViewCell cannot be used from a storyboard")
    }
    
    override open func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        refreshContent()
    }
    
    func refreshContent() {
        label.text = {
            switch content {
            case .default:
                return defaultErrorMessage
            case let .message(string):
                return string
            }
        }()
    }
    
    open func commonInit() {
        backgroundColor = .white
        separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9999)
        selectionStyle = .none
    }
}

public enum ErrorTableViewCellContent: Equatable {
    case `default`
    case message(String)
}

