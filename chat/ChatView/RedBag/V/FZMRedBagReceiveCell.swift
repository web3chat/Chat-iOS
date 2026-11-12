//
//  IMRedBagReceiveCell.swift
//  IM_SocketIO_Demo
//
//  Created by fzm on 2018/7/16.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import SnapKit

class FZMRedBagReceiveCell: UITableViewCell {
    
    private var receiveData : IMRedPacketReceiveModel?

    /// 有「领取时间」时昵称贴顶（top 12），没有时整行居中 —— 两条约束互斥切换
    private var nameTopConstraint: SnapKit.Constraint?
    private var nameCenterYConstraint: SnapKit.Constraint?

    /// 卡片容器：圆角 + 暖阴影由它承担（contentView 不裁剪，否则阴影会被吃掉）
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = RP.cream
        v.layer.cornerRadius = 14
        return v
    }()

    let userLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: RP.ink, textAlignment: .left, text: "")
        lab.lineBreakMode = .byTruncatingTail
        return lab
    }()
    
    let timeLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: RP.inkSoft, textAlignment: .left, text: "")
        return lab
    }()
    
    /// 每条领取记录的金额：与「收到的红包」记录页用**同一个颜色**（`RP.incomeGold`）。
    /// 卡片是白底（`RP.cream`），金色在白底上不会发闷。
    let moneyLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.rpAmountFont(18, weight: .semibold), textColor: RP.incomeGold, textAlignment: .right, text: "")
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
        let lab = UILabel.getLab(font: UIFont.regularFont(14), textColor: UIColor(hex: 0xE8AE10), textAlignment: .left, text: L("新用户"))
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
        self.backgroundColor = RP.pageBg
        self.contentView.backgroundColor = RP.pageBg
        self.selectionStyle = .none

        // 卡片：上下各留 4pt，行高 72 ⇒ 卡片实际高 64
        self.contentView.addSubview(cardView)
        cardView.snp.makeConstraints { m in
            m.top.equalToSuperview().offset(4)
            m.bottom.equalToSuperview().offset(-4)
            m.left.equalToSuperview().offset(16)
            m.right.equalToSuperview().offset(-16)
        }
        cardView.applyRPCardShadow()

        cardView.addSubview(self.userLab)
        userLab.snp.makeConstraints { (m) in
            nameTopConstraint = m.top.equalToSuperview().offset(12).constraint
            nameCenterYConstraint = m.centerY.equalToSuperview().constraint
            // 默认按「有时间」排；`configureWithData` 里按实际有没有时间切换
            nameCenterYConstraint?.deactivate()
            m.left.equalToSuperview().offset(16)
            m.right.equalTo(cardView.snp.centerX).offset(16)
            m.height.equalTo(22)
        }
        cardView.addSubview(self.newUserView)
        newUserView.snp.makeConstraints { (m) in
            m.centerY.equalTo(userLab)
            m.left.equalTo(userLab.snp.right).offset(10)
            m.size.equalTo(CGSize(width: 70, height: 16))
        }
        cardView.addSubview(self.timeLab)
        timeLab.snp.makeConstraints { (m) in
            m.top.equalTo(userLab.snp.bottom)
            m.left.equalTo(userLab)
            m.height.equalTo(18)
        }

        cardView.addSubview(self.moneyLab)
        moneyLab.snp.makeConstraints { (m) in
            m.centerY.equalTo(userLab)
            m.right.equalToSuperview().offset(-15)
            m.height.equalTo(24)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureWithData(receive : IMRedPacketReceiveModel){
        self.receiveData = receive
        userLab.text = IMRedBagRecordCell.shortWalletAddress(receive.userName)
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        // 时间：本地数据模式（安卓专属红包的 csv 透传）直接用文案；否则取链上 `Claimed` 事件区块时间
        // ⚠️ 拿不到就**整个不显示**那行 —— 绝不用「当前时间 / 我注意到的时刻」充数
        let timeText = receive.timeDisplayText
            ?? receive.claimedAt.map { formatter.string(from: $0) }
            ?? ""
        timeLab.text = timeText
        // 没有时间时：隐藏时间行 + 昵称居中，卡片不会留一条空带
        let hasTime = !timeText.isEmpty
        timeLab.isHidden = !hasTime
        if hasTime {
            nameCenterYConstraint?.deactivate()
            nameTopConstraint?.activate()
        } else {
            nameTopConstraint?.deactivate()
            nameCenterYConstraint?.activate()
        }
        moneyLab.text = receive.amountDisplayText ?? "\(receive.amount) \(receive.coinName)"
        newUserView.isHidden = true
    }
    
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}


