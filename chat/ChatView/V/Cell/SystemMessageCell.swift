//
//  SystemMessageCell.swift
//  chat
//
//  Created by 郑晨 on 2025/3/20.
//

import UIKit
import SnapKit

import UIKit
import SnapKit

class SystemMessageCell: MessageContentCell {
    

    lazy var contentImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.layer.cornerRadius = 5
        v.clipsToBounds = true
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.backgroundColor = Color_F6F7F8
        return v
    }()
    let detailLab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .center, text: "")
    
    override func setupViews() {
        super.setupViews()
        
        self.messageContainerView.addSubviews(self.contentImageView)
        self.contentImageView.addSubview(self.detailLab)
        
        self.detailLab.numberOfLines = 0
    }
    
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        self.contentImageView.frame = self.messageContainerView.bounds
        detailLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.height.equalTo(40)
            m.bottom.equalToSuperview()
        }
        
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        super.configure(with: message, at: indexPath, and: messageCollectionView)

        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessageDisplayDelegate")
        }
        switch message.kind {
        case .system:
            let text = message.msgType.systemTextValue
            detailLab.text = "【公告】" + text
            
        default:
            break
        }
    }
}




