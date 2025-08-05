//
//  ContactCardMessageCell.swift
//  chat
//
//  Created by 郑晨 on 2025/3/20.
//

import UIKit
import SnapKit

import UIKit
import SnapKit

class ContactCardMessageCell: MessageContentCell {
    
    lazy var contentImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.layer.cornerRadius = 5
        v.clipsToBounds = true
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.image = #imageLiteral(resourceName: "chat_fileBg")
        v.tag = 10086
        return v
    }()
    
    lazy var iconImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        return v
    }()
    
    let nameLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .center, text: "")
        lab.numberOfLines = 0
        lab.textAlignment = .left
        return lab
    }()
    
    let detailLab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: "")
    
    let line = UIView.getNormalLineView()
    
    override func setupViews() {
        super.setupViews()
        
        self.messageContainerView.addSubview(self.contentImageView)
        self.contentImageView.addSubview(self.iconImageView)
        self.contentImageView.addSubview(self.nameLab)
        self.contentImageView.addSubview(self.line)
        self.contentImageView.addSubview(self.detailLab)
        
    }
    
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        
        self.contentImageView.frame = self.messageContainerView.bounds
        iconImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 50, height: 50))
            m.left.equalToSuperview().offset(12)
            m.top.equalToSuperview().offset(10)
        }
        nameLab.numberOfLines = 0
        nameLab.textAlignment = .left
        nameLab.snp.makeConstraints { (m) in
            m.top.equalTo(self.iconImageView)
            m.left.equalTo(self.iconImageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-20)
            m.height.equalTo(50)
        }
        line.snp.makeConstraints { (m) in
            m.height.equalTo(0.5)
            m.left.right.equalToSuperview()
            m.top.equalTo(self.iconImageView.snp.bottom).offset(10)
        }
        self.contentImageView.addSubview(detailLab)
        detailLab.snp.makeConstraints { (m) in
            m.left.equalTo(self.iconImageView)
            m.right.equalToSuperview().offset(-12)
            m.height.equalTo(30)
            m.bottom.equalToSuperview()
        }
        
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        super.configure(with: message, at: indexPath, and: messageCollectionView)

        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessageDisplayDelegate")
        }
        switch message.kind {
        case .contactCard(let contactCardItem):
//            print("contactCardItem======>",contactCardItem)
//            let contactName = contactCardItem.contactName
            let contactType = contactCardItem.contactType
            let contactAvatar = contactCardItem.contactAvatar
            
            switch contactType {
            case -1:
                detailLab.text = "专属红包已领取"
                nameLab.text = "恭喜发财，大吉大利"
                nameLab.textColor = Color_FFFFFF
                detailLab.textColor = Color_FFFFFF
                self.contentImageView.image =  #imageLiteral(resourceName: "open_bag_bg")
                self.contentImageView.alpha =  0.5
                
                for view in self.messageContainerView.subviews {
                    if view.tag != 10086 {
                        view.isHidden = true
                    }
                }
                
                line.isHidden =  true
                iconImageView.image =  UIImage(named:"hongbao")
            case 1:
                detailLab.text = "个人名片"
                nameLab.text = contactAvatar
                nameLab.textColor = Color_24374E
                detailLab.textColor = Color_8A97A5
                self.contentImageView.image =  #imageLiteral(resourceName: "chat_fileBg")
                self.contentImageView.alpha =  1
                self.messageContainerView.alpha = 1
                line.isHidden =  false
                iconImageView.sd_setImage(with: URL(string: contactAvatar), placeholderImage:  UIImage(named: "avatar_persion"))
            case 2:
                detailLab.text = "群聊名片"
                nameLab.text = contactAvatar
                nameLab.textColor = Color_24374E
                detailLab.textColor = Color_8A97A5
                self.contentImageView.image =  #imageLiteral(resourceName: "chat_fileBg")
                self.contentImageView.alpha =  1
                self.messageContainerView.alpha = 1
                line.isHidden =  false
                iconImageView.sd_setImage(with: URL(string: contactAvatar), placeholderImage:  UIImage(named: "avatar_persion"))
            default:
                break
            }
        default:
            break
        }
    }
}




