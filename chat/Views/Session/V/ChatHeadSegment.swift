//
//  SessionTypeView.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/4.
//

import Foundation
import SnapKit

enum ChatHeaderShowType {
    case session
    case contact
}

class ChatHeadSegment: UILabel {
    
    lazy var unreadLab : FZMUnreadLab = {
        return FZMUnreadLab(frame: CGRect.zero)
    }()
    
    private var showType: ChatHeaderShowType = .session
    
    init(with title: String, showType: ChatHeaderShowType = .session) {
        super.init(frame: CGRect.zero)
        self.showType = showType
        self.addSubview(unreadLab)
        unreadLab.snp.makeConstraints { (m) in
            m.bottom.equalTo(self.snp.top).offset(13)
            m.centerX.equalTo(self.snp.right).offset(-8)
            m.size.equalTo(CGSize.zero)
        }
        self.text = title
        self.textAlignment = .center
        self.isUserInteractionEnabled = true
        self.show(false)
    }
    
    func show(_ selected: Bool) {
        if showType == .session {
            self.font = selected ? .boldFont(17) : .boldFont(14)
            self.textColor = selected ? Color_Theme : Color_8A97A5
        } else if showType == .contact {
            self.font = selected ? .boldFont(17) : .boldFont(14)
            self.textColor = selected ? Color_24374E : Color_8A97A5
        }
    }
    
    func setBadge(_ badge: Int) {
        DispatchQueue.main.async {
            self.unreadLab.setUnreadCount(badge, maxCount: 100)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
