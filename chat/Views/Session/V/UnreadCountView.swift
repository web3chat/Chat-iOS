//
//  UnreadCountLabel.swift
//  chat
//
//  Created by fzm on 2021/1/11.
//

import UIKit

class UnreadCountView: UILabel {

    var unreadCount: Int = 0 { didSet { self.setCount(unreadCount) } }
    
    var isMuteNotification: Bool = false
//    var isMuteNotification: Bool = false { didSet { setColor(isMuteNotification) } }
    
    convenience init() {
        self.init(frame: CGRect.init(x: 0, y: 0, width: 16, height: 16))
    }
    
    override init(frame: CGRect) {
        super.init(frame: CGRect.init(x: 0, y: 0, width: 16, height: 16))
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.textAlignment = .center
        self.font = UIFont.systemFont(ofSize: 11)
        self.textColor = Color_FFFFFF
        self.backgroundColor = Color_DD5F5F
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        self.isHidden = true
    }
    
//    private func setColor(_ isMuteNotification: Bool = false) {
//        self.backgroundColor = isMuteNotification ? Color_C8D3DE : Color_DD5F5F
//    }
    
    private func setCount(_ count: Int) {
        guard count > 0 else {
            self.isHidden = true
            return
        }
        self.isHidden = false
        // ⚠️ 不要再在这里设 frame：红点的尺寸是 SnapKit 约束控制的（见
        //    `SessionCollectionViewCell`），frame 会被下一帧布局覆盖，改了也无效。
        if isMuteNotification {
            self.text = ""
            self.layer.cornerRadius = 5
        } else {
            // 超过 99 显示 `99+`（原来写死成 `"..."`，用户看到的就是两个省略号）
            self.text = count > 99 ? "99+" : "\(count)"
            self.layer.cornerRadius = 8
        }
    }

    /// 红点需要的宽度（供 cell 的约束用）。
    /// 1~2 位数固定 16；`99+` 比 16 宽，不跟着放宽会被 UIKit 截成省略号。
    var fittedWidth: CGFloat {
        guard !self.isMuteNotification else { return 10 }
        guard let text = self.text, !text.isEmpty else { return 16 }
        let font = self.font ?? UIFont.systemFont(ofSize: 11)
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        return max(16, textWidth + 3)
    }

}
