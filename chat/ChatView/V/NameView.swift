//
//  NameView.swift
//  chat
//
//  Created by 王俊豪 on 2021/12/24.
//

import Foundation
import UIKit
import SnapKit
import SwifterSwift

class NameView: UIView {
    
    // 昵称
    lazy var nameLable: UILabel = {
        let lab = UILabel.init()
        lab.numberOfLines = 1
        lab.font = UIFont.systemFont(ofSize: 12)
        lab.textAlignment = .left
        lab.text = "阿里抠脚大汉公企鹅然后就评价带回家哦脾气"
        lab.textColor = Color_8A97A5
        return lab
    }()
    
    // 群成员类型（群主、管理员）
    lazy var typeLable: UILabel = {
        let lab = UILabel.init()
        lab.numberOfLines = 1
        lab.textAlignment = .center
        lab.font = UIFont.systemFont(ofSize: 12)
        lab.backgroundColor = #colorLiteral(red: 0.8862745098, green: 0.937254902, blue: 0.968627451, alpha: 1)
        lab.layer.cornerRadius = 4
        lab.layer.masksToBounds = true
        lab.text = "群主"
        return lab
    }()
    
    override init(frame: CGRect) {
        super.init(frame: CGRect.init(x: 0, y: 0, width: NameViewMaxWidth, height: 18))
        self.createUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createUI() {
        self.addSubview(self.nameLable)
        nameLable.snp.makeConstraints { make in
            make.top.left.bottom.equalToSuperview()
            make.width.equalTo(100)
        }
        
        self.addSubview(self.typeLable)
        typeLable.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(100)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(48)
        }
    }
    
    func setNameAndType(isOutgoing: Bool, name: String, userType: Int) {
        self.nameLable.text = name
        
        var nameWidth = name.getContentWidth(font: .systemFont(ofSize: 12), height: 18) + 2// (+2): 计算有偏差，实际显示可能会显示不全，需再加宽一点
        
        var typeStr = ""
        if userType == 2 {
            typeLable.isHidden = false
            typeLable.backgroundColor = Color_Theme_Light
            typeLable.textColor = Color_Theme
            typeStr = "群主"
        } else if userType == 1 {
            typeLable.isHidden = false
            typeLable.backgroundColor = UIColor.init(hexString: "#EFA019", transparency: 0.1)!
            typeLable.textColor = UIColor.init(hexString: "#EFA019")!
            typeStr = "管理员"
        } else {// if userType == 0
            self.typeLable.isHidden = true
        }
        typeLable.text = typeStr
        
        let typeWidth = typeStr.isBlank ? 0 : typeStr.getContentWidth(font: .systemFont(ofSize: 12), height: 18) + 10
        
        let totalWidth = min(nameWidth + typeWidth + 5, self.width)
        nameWidth = totalWidth - (typeWidth + 5)
        
        if isOutgoing {
            self.nameLable.textAlignment = .right
            
            if typeWidth == 0 {// 不显示类型lab
                self.nameLable.snp.updateConstraints { m in
                    m.left.equalToSuperview()
                    m.width.equalTo(NameViewMaxWidth)
                }
                self.typeLable.snp.updateConstraints { m in
                    m.width.equalTo(0)
                }
            } else {
                let leftR = self.width - typeWidth - 5 - nameWidth
                
                self.typeLable.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(leftR)
                    make.width.equalTo(typeWidth)
                }
                self.nameLable.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(leftR + typeWidth + 5)
                    make.width.equalTo(nameWidth)
                }
            }
        } else {
            self.nameLable.textAlignment = .left
            
            if typeWidth == 0 {// 不显示类型lab
                self.nameLable.snp.updateConstraints { m in
                    m.left.equalToSuperview()
                    m.width.equalTo(NameViewMaxWidth)
                }
                self.typeLable.snp.updateConstraints { m in
                    m.width.equalTo(0)
                }
            } else {
                self.nameLable.snp.updateConstraints { make in
                    make.left.equalToSuperview()
                    make.width.equalTo(nameWidth)
                }
                self.typeLable.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(nameWidth + 5)
                    make.width.equalTo(typeWidth)
                }
            }
        }
    }
    
}
