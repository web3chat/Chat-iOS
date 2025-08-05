//
//  WalletdetailInforThirdView.swift
//  chat
//
//  Created by fzm on 2022/1/26.
//

import Foundation

class WalletdetailInforThirdView : UIView {
    
    lazy var backView : UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var heightLabel1 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#939FAB")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "区块高度"
        return label
    }()
    
    lazy var heighLabel2 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.text = "2998002"
        return label
    }()
    
    lazy var jyLabel1 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#939FAB")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "交易哈希"
        return label
    }()
    
    lazy var jyLabel2 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#32B2F7")
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.text = "bccbudsbabds…udsbcudsbc"
        return label
    }()
    
    lazy var timeLabel1 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#939FAB")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "交易时间"
        return label
    }()
    
    lazy var timeLabel2 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.text = "2018/10/29 12:33:45"
        return label
    }()
    
    lazy var markLabel1 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#939FAB")
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.text = "上链备注"
        return label
    }()
    
    lazy var markLabel2 : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#24374E")
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.text = "感谢你请我吃饭，一点小币请收下啦啦啦啦啦啦啦啦啦啦啦啦"
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
        self.backView.addSubview(self.heightLabel1)
        self.backView.addSubview(self.heighLabel2)
        self.backView.addSubview(self.jyLabel1)
        self.backView.addSubview(self.jyLabel2)
        self.backView.addSubview(self.timeLabel1)
        self.backView.addSubview(self.timeLabel2)
        self.backView.addSubview(self.markLabel1)
        self.backView.addSubview(self.markLabel2)
        
        self.backView.snp.makeConstraints { make in
            
        }
    }
    
}
