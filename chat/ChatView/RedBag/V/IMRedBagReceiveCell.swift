//
//  IMRedBagReceiveCell.swift
//  IM_SocketIO_Demo
//
//  Created by 吴文拼 on 2018/7/16.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit

class IMRedBagRecordCell: UITableViewCell {
    
    let userLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: FZM_BlackWordColor, textAlignment: .left, text: "")
        lab.lineBreakMode = .byTruncatingMiddle
        return lab
    }()
    
    let timeLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: FZM_GrayWordColor, textAlignment: .left, text: "")
        return lab
    }()
    
    let moneyLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(18), textColor: FZM_BlackWordColor, textAlignment: .right, text: "")
        return lab
    }()
    
    let statusLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: FZM_GrayWordColor, textAlignment: .right, text: "")
        return lab
    }()
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        
        self.contentView.addSubview(self.timeLab)
        
        self.contentView.addSubview(self.userLab)
        userLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(16)
            m.left.equalToSuperview().offset(15)
            m.height.equalTo(23)
            m.width.equalTo(188)
        }
        
        timeLab.snp.makeConstraints { (m) in
            m.bottom.equalToSuperview().offset(-16)
            m.left.equalTo(userLab)
            m.height.equalTo(20)
        }
        
        self.contentView.addSubview(self.moneyLab)
        moneyLab.snp.makeConstraints { (m) in
            m.top.equalTo(userLab)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(21)
        }
        
        self.contentView.addSubview(self.statusLab)
        statusLab.snp.makeConstraints { (m) in
            m.bottom.equalTo(timeLab)
            m.right.equalTo(moneyLab)
            m.height.equalTo(20)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func configureWithData(packet: IMRedPacketModel, operation:IMRedPacketRecordType = .receive) {
        if operation == .receive {
//            IMContactManager.shared().requestUserModel(with: packet.senderId) { (user, _, _) in
//                guard let user = user else { return }
//                let text = "\(user.showName) "
//                let str = NSMutableAttributedString.init(string: text, attributes: [NSAttributedString.Key.font: UIFont.regularFont(16), NSAttributedString.Key.foregroundColor:FZM_BlackWordColor])
//                if packet.type == .luck {
//                    let ach = NSTextAttachment.init()
//                    ach.image = UIImage(named:"send_bag_many")
//                    ach.bounds = CGRect.init(x: 0, y: -4, width: 20, height: 20)
//                    let imgText = NSAttributedString.init(attachment: ach)
//                    str.insert(imgText, at: str.length)
//                }
//                self.userLab.attributedText = str
//            }
            statusLab.text = packet.getStatusStr(with: operation)
        } else {
            statusLab.text = packet.getStatusStr(with: operation) + " " + packet.countStr
            self.userLab.text = (packet.type == .luck ? "拼手气红包" : "普通红包")
        }
        
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        timeLab.text = formatter.string(from: packet.createdAt)
        let numStr = NSMutableAttributedString.init(string: "\(packet.amount)" + "\(packet.coinName)", attributes: [.font : UIFont.boldFont(20), .foregroundColor: FZM_BlackWordColor])
        moneyLab.attributedText = numStr
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

