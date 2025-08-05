//
//  UITabBarItem+Tool.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/29.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

extension UITabBarItem {
    
    func setUnreadCount(_ count: Int) {
        guard let view = self.value(forKey: "view") as? UIView else { return }
        
        var bgView : UIView?
        view.subviews.forEach { (subView) in
            if subView.isKind(of: NSClassFromString("UITabBarSwappableImageView")!) {
                bgView = subView
            }
        }
        guard bgView != nil else { return }
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
        guard bgView != nil else { return }
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

