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
    
    /// 红点（广场新帖提示，与未读数徽标互不干扰）
    private lazy var dotView: UIView = {
        let view = UIView()
        view.backgroundColor = FZM_RedColor
        view.layer.cornerRadius = 4
        view.isHidden = true
        return view
    }()
    
    private var showType: ChatHeaderShowType = .session
    
    /// 字号缩小的量（默认 0 = 消息页顶部那排的原字号）。
    /// 广场筛选栏传 2，让整排（选中/未选中）都比消息页小 2 号。
    private let fontDecrement: CGFloat
    
    init(with title: String, showType: ChatHeaderShowType = .session, fontDecrement: CGFloat = 0) {
        self.fontDecrement = fontDecrement
        super.init(frame: CGRect.zero)
        self.showType = showType
        self.addSubview(unreadLab)
        unreadLab.snp.makeConstraints { (m) in
            m.bottom.equalTo(self.snp.top).offset(13)
            m.centerX.equalTo(self.snp.right).offset(-8)
            m.size.equalTo(CGSize.zero)
        }
        self.addSubview(dotView)
        dotView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(2)
            m.centerX.equalTo(self.snp.right).offset(-14)
            m.size.equalTo(CGSize(width: 8, height: 8))
        }
        self.text = title
        self.textAlignment = .center
        // 长标题（日语/韩语/英语）优先缩小字号而不是截断，避免顶部分段「显示不全」
        self.adjustsFontSizeToFitWidth = true
        self.minimumScaleFactor = 0.7
        self.lineBreakMode = .byTruncatingTail
        self.isUserInteractionEnabled = true
        self.show(false)
    }
    
    /// 广场红点显隐
    func setDot(_ show: Bool) {
        DispatchQueue.main.async {
            self.dotView.isHidden = !show
        }
    }
    
    /// 基准字号减去缩小量（下限 10，避免缩到看不清）
    private func scaled(_ base: CGFloat) -> CGFloat {
        return max(base - fontDecrement, 10)
    }
    
    func show(_ selected: Bool) {
        if showType == .session {
            if LanguageManager.shared.isChinese {
                self.font = .boldFont(scaled(selected ? 17 : 14))
            }else {
                self.font = .boldFont(scaled(selected ? 14 : 12))
            }
            self.textColor = selected ? Color_Theme : Color_8A97A5
        } else if showType == .contact {
            if LanguageManager.shared.isChinese {
                self.font = .boldFont(scaled(selected ? 17 : 14))
            }else {
                self.font = .boldFont(scaled(selected ? 14 : 12))
            }
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
