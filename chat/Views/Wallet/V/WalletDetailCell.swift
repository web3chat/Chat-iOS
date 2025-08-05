//
//  WalletDetailCell.swift
//  chat
//
//  Created by fzm on 2022/1/24.
//

import Foundation
import UIKit

class WalletDetailCell: UITableViewCell {
    
    lazy var moneyLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = Color_24374E
        label.font = UIFont.systemFont(ofSize: 18)
        label.text = "+5667900.00"
        return label
    }()
    
    lazy var markLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#8A97A5")
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "备注/昵称"
        label.textAlignment = .center
        label.backgroundColor = UIColor.init(hexString: "#F6F7F8")
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 3
        return label
    }()
    
    lazy var statusLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#8A97A5")
        label.font = UIFont.systemFont(ofSize: 14)
        label.text = "完成"
        return label
    }()
    
    
    lazy var addressLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#8A97A5")
        label.font = UIFont.systemFont(ofSize: 14)
        label.text = "15hdhuhu…dhudhhuudu"
        return label
    }()
    
    lazy var timeLabel : UILabel = {
        let label = UILabel.init()
        label.textColor = UIColor.init(hexString: "#8A97A5")
        label.font = UIFont.systemFont(ofSize: 13)
        label.text = "2021/08/03 11:11"
        return label
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
        self.backgroundColor = UIColor.white
        self.setupViews()
    }
    
    func setupViews(){
        self.addSubview(self.moneyLabel)
        self.addSubview(self.markLabel)
        self.addSubview(self.statusLabel)
        self.addSubview(self.addressLabel)
        self.addSubview(self.timeLabel)
        
        self.moneyLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalToSuperview().offset(10)
        }
        
        self.markLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self.moneyLabel)
            make.left.equalTo(self.moneyLabel.snp.right).offset(5)
            make.width.equalTo(65)
            make.height.equalTo(22)
        }
        
        self.statusLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self.moneyLabel)
            make.right.equalToSuperview().offset(-15)
        }
        
        self.addressLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.top.equalTo(self.moneyLabel.snp.bottom).offset(5)
        }
        
        self.timeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self.addressLabel)
            make.right.equalToSuperview().offset(-15)
        }
    }
    
}
