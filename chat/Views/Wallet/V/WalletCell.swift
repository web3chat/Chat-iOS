//
//  WalletCell.swift
//  chat
//
//  Created by fzm on 2022/1/21.
//

import Foundation
import UIKit
import sqlcipher

class WalletCell: UITableViewCell {
    
    
    lazy var smallBackView : UIView = {
        let view = UIView.init()
        view.backgroundColor = Color_EBAE44
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var backView : UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 6
        view.layer.masksToBounds = true
        return view
    }()
    
    
    lazy var mainLabel : UILabel = {
        let label = UILabel.init()
        label.backgroundColor = UIColor.init(hexString: "#DCF8FF")
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        label.font = UIFont.systemFont(ofSize: 22)
        label.text = "J"
        label.textColor = UIColor.init(hexString: "#32B2F7")
        label.textAlignment = .center
        return label
    }()
    
    lazy var titleLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = Color_24374E
        label.font = UIFont.systemFont(ofSize: 16)
        label.text = "JHYHQ"
        return label
    }()
    
    lazy var detailLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = Color_8A97A5
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "建行生活满减券"
        return label
    }()
    
    lazy var countLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = Color_24374E
        label.font = UIFont.systemFont(ofSize: 18)
        label.text = "2"
        return label
    }()
    
    lazy var priceLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = Color_8A97A5
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "≈¥0.2"
        return label
    }()
    
    lazy var lineView : UIView = {
        let view = UIView.init()
        view.backgroundColor = UIColor.init(hexString: "#F6F7F8")
        return view
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = UIColor.init(hexString: "#F6F7F8")
        self.setupViews()
    }
    
    func setViewHidden(isHiden : Bool){
        self.smallBackView.isHidden = isHiden
    }
    
    
    
    func setupViews(){
        self.addSubview(smallBackView)
        self.addSubview(backView)
        self.backView.addSubview(mainLabel)
        self.backView.addSubview(titleLabel)
        self.backView.addSubview(detailLabel)
        self.backView.addSubview(countLabel)
        self.backView.addSubview(priceLabel)
        self.addSubview(lineView)
        
        smallBackView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.height.equalTo(80)
            make.top.equalToSuperview().offset(-50)
        }
        
        backView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalToSuperview()
            make.height.equalTo(60)
        }
        
        mainLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(15)
            make.size.equalTo(36)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.equalTo(mainLabel.snp.right).offset(8)
        }
        
        detailLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-10)
            make.left.equalTo(mainLabel.snp.right).offset(8)
        }
        
        countLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalTo(titleLabel)
        }
        
        priceLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalTo(detailLabel)
        }
        
        lineView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(10)
        }
    }
    
    
}
