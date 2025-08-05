//
//  WalletDetailInforTopView.swift
//  chat
//
//  Created by fzm on 2022/1/26.
//

import Foundation
import UIKit

class WalletDetailInforSecondView : UIView {
    
    lazy var backView : UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var titleLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 30)
        label.text = "+0.55"
        return label
    }()
    
    lazy var nameLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.text = "ABC"
        return label
    }()
    
    lazy var zzLabel1 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#939FAB")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "转账地址"
        return label
    }()
    
    lazy var zzLabel2 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.text = "bccbudsbabds…udsbcudsbc"
        return label
    }()
    
    lazy var markLabel1 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#939FAB")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "对方备注"
        return label
    }()
    
    lazy var markLabel2 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.text = "备注/昵称"
        return label
    }()
    
    lazy var skLabel1 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#939FAB")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "收款地址"
        return label
    }()
    
    lazy var skLabel2 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#DD5F5F")
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.text = "bccudsbcubds…udsbcudsbc"
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = Color_F9F9F9
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.addSubview(self.backView)
        self.backView.addSubview(titleLabel)
        self.backView.addSubview(nameLabel)
        self.backView.addSubview(zzLabel1)
        self.backView.addSubview(zzLabel2)
        self.backView.addSubview(markLabel1)
        self.backView.addSubview(markLabel2)
        self.backView.addSubview(skLabel1)
        self.backView.addSubview(skLabel2)
        
        self.backView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalTo(15)
            make.right.equalTo(-15)
        }
        
        self.titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(30)
        }
        
        self.nameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.titleLabel.snp.bottom)
        }
        
        self.zzLabel1.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.top.equalTo(114)
        }
        
        self.zzLabel2.snp.makeConstraints { make in
            make.centerY.equalTo(self.zzLabel1)
            make.right.equalTo(-15)
        }
        
        self.markLabel1.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.top.equalTo(self.zzLabel1.snp.bottom).offset(20)
        }
        
        self.markLabel2.snp.makeConstraints { make in
            make.centerY.equalTo(self.markLabel1)
            make.right.equalTo(-15)
        }
        
        self.skLabel1.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.top.equalTo(self.markLabel1.snp.bottom).offset(20)
        }
        
        self.skLabel2.snp.makeConstraints { make in
            make.centerY.equalTo(self.skLabel1)
            make.right.equalTo(-15)
        }
        
        
        
        
    }
    
    
    
}

