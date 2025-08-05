//
//  IMRedBagReceiveCell.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/7/16.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit

class FZMRedBagReceiveCell: UITableViewCell {
    
    private var receiveData : IMRedPacketReceiveModel?
    
    let headImV : UIImageView = {
        let imV = UIImageView.init(image: UIImage(named:"open_bag_humanhead"))
        imV.layer.cornerRadius = 5
        imV.clipsToBounds = true
        return imV
    }()
    
    let userLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .left, text: "")
        lab.lineBreakMode = .byTruncatingTail
        return lab
    }()
    
    let timeLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")
        return lab
    }()
    
    let moneyLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(20), textColor: Color_24374E, textAlignment: .right, text: "")
        return lab
    }()
    
    let newUserView : UIView = {
        let view = UIView.init()
        let imV = UIImageView.init(image: UIImage(text: .userVIP, imageSize: CGSize(width: 18, height: 13), imageColor: UIColor(hex: 0xE8AE10)))
        view.addSubview(imV)
        imV.snp.makeConstraints({ (m) in
            m.left.equalToSuperview()
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 18, height: 13))
        })
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: UIColor(hex: 0xE8AE10), textAlignment: .left, text: "新用户")
        view.addSubview(lab)
        lab.snp.makeConstraints({ (m) in
            m.left.equalTo(imV.snp.right).offset(5)
            m.centerY.equalToSuperview()
            m.height.equalTo(16)
        })
        return view
    }()
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = Color_Theme
        self.selectionStyle = .none
        self.contentView.addSubview(self.headImV)
        headImV.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.left.equalToSuperview().offset(12)
            m.size.equalTo(CGSize.init(width: 45, height: 45))
        }
        self.contentView.addSubview(self.userLab)
        userLab.snp.makeConstraints { (m) in
            m.top.equalTo(headImV)
            m.left.equalTo(headImV.snp.right).offset(10)
            m.right.equalTo(self.contentView.snp.centerX).offset(16)
            m.height.equalTo(23)
        }
        self.contentView.addSubview(self.newUserView)
        newUserView.snp.makeConstraints { (m) in
            m.centerY.equalTo(userLab)
            m.left.equalTo(userLab.snp.right).offset(10)
            m.size.equalTo(CGSize(width: 70, height: 16))
        }
        self.contentView.addSubview(self.timeLab)
        timeLab.snp.makeConstraints { (m) in
            m.bottom.equalTo(headImV)
            m.left.equalTo(userLab)
            m.height.equalTo(20)
        }
        
        self.contentView.addSubview(self.moneyLab)
        moneyLab.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(24)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureWithData(receive : IMRedPacketReceiveModel){
        self.receiveData = receive
        userLab.text = receive.userName
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        timeLab.text = formatter.string(from: receive.createdAt)
        moneyLab.text = "\(receive.amount)" + "\(receive.coinName)"
        newUserView.isHidden = true
        let image = UIImage(named:"avatar_persion")
        headImV.loadNetworkImage(with: receive.userAvatar.getDownloadUrlString(width: 35), placeImage: image)
    }
    
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}


