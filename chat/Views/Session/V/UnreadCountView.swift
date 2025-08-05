//
//  UnreadCountLabel.swift
//  chat
//
//  Created by 陈健 on 2021/1/11.
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
        if isMuteNotification {
            self.text = ""
            self.frame = CGRect.init(x: self.frame.minX, y: self.frame.minY, width: 10, height: 10)
            self.layer.cornerRadius = 5
        } else {
            self.text = count > 99 ? "..." : "\(count)"
            self.frame = CGRect.init(x: self.frame.minX, y: self.frame.minY, width: 16, height: 16)
            self.layer.cornerRadius = 8
        }
    }
    
}
