//
//  WalletDetailInforTopView.swift
//  chat
//
//  Created by fzm on 2022/1/26.
//

import Foundation

class WalletDetailInforTopView : UIView {
    
    lazy var titleLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 30)
        label.text = "交易完成"
        return label
    }()
    
    lazy var logoImg : UIImageView = {
        let img = UIImageView.init(image: UIImage.init(named: "交易成功"))
        return img
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
        self.addSubview(titleLabel)
        self.addSubview(logoImg)
        
        self.titleLabel.snp.makeConstraints { make in
            make.left.top.equalTo(15)
        }
        
        self.logoImg.snp.makeConstraints { make in
            make.centerY.equalTo(self.titleLabel)
            make.right.equalToSuperview().offset(-15)
            make.width.height.equalTo(42)
        }
    }
    
    
    
}

