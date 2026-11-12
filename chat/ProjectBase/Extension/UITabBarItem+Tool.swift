//
//  UITabBarItem+Tool.swift
//  Chat33
//
//  Created by fzm on 2018/10/29.
//  Copyright © 2018年 fzm. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

/// 只在第一次走兜底时打一行日志，避免每次未读刷新都刷屏
private var didLogTabBadgeFallback = false

extension UITabBarItem {
    
    func setUnreadCount(_ count: Int) {
        guard let view = self.value(forKey: "view") as? UIView else { return }
        
        var bgView : UIView?
        view.subviews.forEach { (subView) in
            if subView.isKind(of: NSClassFromString("UITabBarSwappableImageView")!) {
                bgView = subView
            }
        }
        // 🔴 iOS 26+（Liquid Glass TabBar）层级变了：已经找不到 `UITabBarSwappableImageView`，
        //    原来这里直接 return ⇒ 底部导航栏的未读数彻底不显示了（用户 iOS 27 反馈）。
        //    ⇒ 自定义 label 没地方挂时，退回系统官方的 `badgeValue`（系统角标同样能显示 99+）。
        guard bgView != nil else {
            let text = count > 0 ? (count > 99 ? "99+" : "\(count)") : nil
            self.badgeValue = text
            if !didLogTabBadgeFallback {
                didLogTabBadgeFallback = true
                FZMLog("TabBar 角标：找不到 UITabBarSwappableImageView（iOS 26+ 层级变了），改用系统 badgeValue\(text ?? "nil")")
            }
            return
        }
        var getView : UIView?
        bgView?.subviews.forEach({ (subView) in
            if subView.tag == 200 {
                getView = subView
            }
        })
        
        if let useView = getView as? FZMUnreadLab {
            useView.setUnreadCount(count, maxCount: 100)
        }else {
            let lab = FZMUnreadLab(frame: CGRect.zero)
            lab.tag = 200
            bgView!.addSubview(lab)
            lab.snp.makeConstraints { (m) in
                m.left.equalTo(bgView!.snp.right)
                m.top.equalToSuperview()
                m.size.equalTo(CGSize.zero)
            }
            lab.setUnreadCount(count, maxCount: 100)
        }
    }
    
    func set(text: String) {
        guard let view = self.value(forKey: "view") as? UIView else { return }
        
        var bgView : UIView?
        view.subviews.forEach { (subView) in
            if subView.isKind(of: NSClassFromString("UITabBarSwappableImageView")!) {
                bgView = subView
            }
        }
        guard bgView != nil else {
            // 同 `setUnreadCount`：iOS 26+ 找不到 `UITabBarSwappableImageView` 时退回系统 badgeValue
            self.badgeValue = text.isEmpty ? nil : text
            return
        }
        var getView : UIView?
        bgView?.subviews.forEach({ (subView) in
            if subView.tag == 300 {
                getView = subView
            }
        })
        
        if let useView = getView as? UILabel {
            useView.text = text
        }else {
            let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_DD5F5F, textAlignment: .center, text: text)
            lab.tag = 300
            bgView!.addSubview(lab)
            lab.snp.makeConstraints { (m) in
                m.left.equalTo(bgView!.snp.right)
                m.top.equalToSuperview()
                m.size.equalTo(CGSize(width: 12, height: 12))
            }
        }
    }
    
}

