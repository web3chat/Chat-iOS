//
//  FZMGroupUserCell.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/29.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit
import SnapKit
import Kingfisher
import SDWebImage

class FZMGroupUserCell: UICollectionViewCell {
    
    private(set) var data : FZMGroupDetailUserViewModel?
    
    lazy var headImageView : UIImageView = {
        let imV = UIImageView.init(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    lazy var nameLab : UILabel = {
        return UILabel.getLab(font: UIFont.regularFont(10), textColor: Color_8A97A5, textAlignment: .center, text: nil)
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.addSubview(headImageView)
        headImageView.snp.makeConstraints { (m) in
            m.top.centerX.equalToSuperview()
            m.height.width.equalTo(35)
        }
        self.contentView.addSubview(nameLab)
        nameLab.snp.makeConstraints { (m) in
            m.bottom.left.right.equalToSuperview()
            m.height.equalTo(14)
        }
//        IMNotifyCenter.shared().addReceiver(receiver: self, type: .groupUser)
    }
    
    deinit {
//        IMNotifyCenter.shared().removeReceiver(receiver: self, type: .groupUser)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.headImageView.image = nil
        self.nameLab.text = nil
    }
    
    func setImageSize(_ size: CGFloat) {
        headImageView.snp.updateConstraints { (m) in
            m.height.width.equalTo(size)
        }
    }
    
    func configure(with data: FZMGroupDetailUserViewModel) {
        self.data = data
        self.headImageView.image = nil
        self.nameLab.text = nil
        switch data.type {
        case .person:
//            UserManager.shared().getUser(by: data.memberId) { (user) in
//                guard let user = user else { return }
//                self.headImageView.kf.setImage(with: URL.init(string: user.avatarURLStr), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
//            }
//            self.headImageView.kf.setImage(with: URL.init(string: data.avatar), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
            
            self.headImageView.sd_setImage(with: URL.init(string: data.avatar), placeholderImage: #imageLiteral(resourceName: "friend_chat_avatar"))
            self.nameLab.text = data.name
            self.nameLab.textColor = Color_8A97A5
        case .invite:
            self.nameLab.text = "邀请"
            self.nameLab.textColor = Color_Theme
            self.headImageView.image = #imageLiteral(resourceName: "group_add_user")
        case .remove:
            self.nameLab.text = "移除"
            self.nameLab.textColor = Color_Theme
            self.headImageView.image = #imageLiteral(resourceName: "group_remove_user")
        }
//        self.refreshView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//extension FZMGroupUserCell: UserGroupInfoChangeDelegate {
//    func userGroupInfoChange(groupId: String, userId: String) {
//        if let data = data, data.userId == userId, data.groupId == groupId {
//            self.refreshView()
//        }
//    }
//
//    private func refreshView() {
//        guard let data = self.data else { return }
//        switch data.type {
//        case .person:
//            IMContactManager.shared().getUsernameAndAvatar(with: data.userId, groupId: data.groupId) { (userId, name, avatar) in
//                guard let nowData = self.data, nowData.type == .person, nowData.userId == userId else { return }
//                self.headImageView.loadNetworkImage(with: avatar.getDownloadUrlString(width: 35), placeImage: #imageLiteral(resourceName: "friend_chat_avatar"))
//                self.nameLab.text = name
//                self.nameLab.textColor = Color_8A97A5
//            }
//        case .invite:
//            self.nameLab.text = "邀请"
//            self.nameLab.textColor = Color_Theme
//            self.headImageView.image = GetBundleImage("group_add_user")
//        case .remove:
//            self.nameLab.text = "移除"
//            self.nameLab.textColor = Color_Theme
//            self.headImageView.image = GetBundleImage("group_remove_user")
//        }
//    }
//}
