//
//  FZMUnreadLab.swift
//  Chat33
//
//  Created by fzm on 2018/10/29.
//  Copyright © 2018年 fzm. All rights reserved.
//

import UIKit
import SnapKit

class FZMUnreadLab: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.font = UIFont.regularFont(12)
        self.textAlignment = .center
        self.textColor = UIColor.white
        self.layer.cornerRadius = 8
        self.layer.backgroundColor = Color_DD5F5F.cgColor
    }
    
    /// 设置未读数。
    ///
    /// - Parameter count: 未读数；`<= 0` 时隐藏（尺寸缩成 0）。
    /// - Parameter maxCount: **历史参数**，仅为兼容现有调用方保留，展示上限已统一成 `99+`。
    ///   原来超过上限会显示成 `…`（群聊/私聊两个 tab 上方、以及底部 tab 角标都是这样），
    ///   用户看到的是省略号、看不出到底多少条，反馈「99+ 显示不全」。
    func setUnreadCount(_ count: Int, maxCount: Int = 1000) {
        _ = maxCount
        guard count > 0 else {
            self.text = nil
            self.isHidden = true
            self.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize(width: 0, height: 0))
            }
            return
        }
        self.isHidden = false
        if count < 10 {
            self.text = "\(count)"
            self.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize(width: 16, height: 16))
            }
        } else if count < 100 {
            self.text = "\(count)"
            self.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize(width: 22, height: 16))
            }
        } else {
            self.text = "99+"
            self.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize(width: 28, height: 16))
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


class FZMCountdownLab: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.font = UIFont.regularFont(12)
        self.textAlignment = .center
        self.textColor = UIColor.white
        self.layer.cornerRadius = 8
        self.layer.backgroundColor = Color_EF883E.cgColor
    }
    
    func setTime(_ count: Int) {
        self.text = "\(count)"
        if count < 100 {
            if count < 10 {
                if count <= 0 {
                    self.snp.updateConstraints { (m) in
                        m.size.equalTo(CGSize(width: 0, height: 0))
                    }
                }else {
                    self.snp.updateConstraints { (m) in
                        m.size.equalTo(CGSize(width: 16, height: 16))
                    }
                }
            }else {
                self.snp.updateConstraints { (m) in
                    m.size.equalTo(CGSize(width: 22, height: 16))
                }
            }
        }else if count < 1000{
            self.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize(width: 28, height: 16))
            }
        }else{
            self.snp.updateConstraints { (m) in
                m.size.equalTo(CGSize(width: 36, height: 16))
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
