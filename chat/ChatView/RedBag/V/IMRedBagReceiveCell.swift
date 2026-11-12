//
//  IMRedBagReceiveCell.swift
//  IM_SocketIO_Demo
//
//  Created by fzm on 2018/7/16.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
// ⚠️ 必须显式 import：`snp` 靠桥接头就能用，但 `SnapKit.Constraint` 这类**模块限定名**需要模块可见。
// 少了这行，`[SnapKit.Constraint]()` 会被当成「数组字面量 + 调用」，报成
// `Cannot call value of non-function type '[Any]'`（跟真实原因完全不像，别被带偏）。
import SnapKit

class IMRedBagRecordCell: UITableViewCell {

    /// 卡片容器：圆角 + 暖阴影由它承担（contentView 不裁剪，否则阴影会被吃掉）
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = RP.cream
        v.layer.cornerRadius = 14
        return v
    }()

    let userLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(15), textColor: RP.ink, textAlignment: .left, text: "")
        lab.lineBreakMode = .byTruncatingMiddle
        return lab
    }()
    
    let timeLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: RP.inkSoft, textAlignment: .left, text: "")
        return lab
    }()
    
    let moneyLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.rpAmountFont(18, weight: .semibold), textColor: RP.ink, textAlignment: .right, text: "")
        return lab
    }()
    
    let statusLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(12), textColor: RP.inkSoft, textAlignment: .right, text: "")
        return lab
    }()

    /// 专属红包标签容器（宽度随文案自适应）：金色浅底 + 金边金字
    private let exclusiveTagView : UIView = {
        let v = UIView()
        v.layer.cornerRadius = 8
        v.layer.masksToBounds = true
        v.backgroundColor = RP.goldLight.withAlphaComponent(0.55)
        v.layer.borderWidth = 0.5
        v.layer.borderColor = RP.goldDeep.withAlphaComponent(0.55).cgColor
        v.isHidden = true
        return v
    }()

    private let exclusiveTagLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(10), textColor: RP.goldDeep, textAlignment: .center, text: L("专属红包"))
        lab.numberOfLines = 1
        lab.adjustsFontSizeToFitWidth = true
        lab.minimumScaleFactor = 0.75
        return lab
    }()

    /// 「专属红包」标签的两套位置（互斥切换，单位：SnapKit.Constraint 因为本工程内有同名 `Constraint`）：
    /// - A：贴在**状态文案**左侧（`发出红包` 用）；
    /// - B：贴在**金额右侧对齐**（`收到红包` 不再展示右侧状态，标签单独留在右侧）。
    private var tagBesideStatusConstraints = [SnapKit.Constraint]()
    private var tagTrailingConstraints = [SnapKit.Constraint]()
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        backgroundColor = RP.pageBg
        contentView.backgroundColor = RP.pageBg

        // 卡片：上下各 4pt，行高 72 ⇒ 卡片净高 64
        self.contentView.addSubview(cardView)
        cardView.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(4)
            m.bottom.equalToSuperview().offset(-4)
            m.left.equalToSuperview().offset(16)
            m.right.equalToSuperview().offset(-16)
        }
        cardView.applyRPCardShadow()

        cardView.addSubview(self.userLab)
        userLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(12)
            m.left.equalToSuperview().offset(16)
            // 不写死宽度：以卡片中线为界，窄屏也不会压到右下角的金额/状态
            m.right.lessThanOrEqualTo(cardView.snp.centerX).offset(24)
            m.height.equalTo(22)
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
            m.right.equalToSuperview().offset(-16)
            m.height.equalTo(22)
        }

        cardView.addSubview(self.statusLab)
        statusLab.snp.makeConstraints { (m) in
            m.bottom.equalTo(timeLab)
            m.right.equalTo(moneyLab)
            m.height.equalTo(18)
        }

        // 专属红包标签：默认贴状态文案左侧；「收到红包」没有状态时改到第二行右端（见 configure）
        cardView.addSubview(self.exclusiveTagView)
        exclusiveTagView.addSubview(self.exclusiveTagLab)
        exclusiveTagLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(6)
            m.right.equalToSuperview().offset(-6)
            m.top.equalToSuperview().offset(2)
            m.bottom.equalToSuperview().offset(-2)
        }
        exclusiveTagView.snp.makeConstraints { (m) in
            m.height.equalTo(16)
            m.width.lessThanOrEqualTo(90)
            // A：状态文案左侧
            tagBesideStatusConstraints = [
                m.centerY.equalTo(statusLab).constraint,
                m.right.equalTo(statusLab.snp.left).offset(-6).constraint,
            ]
            // B：与金额右对齐、和日期同一行（此时状态文案是隐藏的）
            tagTrailingConstraints = [
                m.centerY.equalTo(timeLab).constraint,
                m.right.equalTo(moneyLab).constraint,
            ]
        }
        setExclusiveTagFollowsStatus(true)
    }

    /// 切换「专属红包」标签位置：`true` = 贴状态左侧（发出红包），`false` = 贴金额右侧（收到红包）
    private func setExclusiveTagFollowsStatus(_ followsStatus: Bool) {
        if followsStatus {
            tagTrailingConstraints.forEach { $0.deactivate() }
            tagBesideStatusConstraints.forEach { $0.activate() }
        } else {
            tagBesideStatusConstraints.forEach { $0.deactivate() }
            tagTrailingConstraints.forEach { $0.activate() }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 列表展示链上钱包地址（中间省略）
    static func shortWalletAddress(_ address: String) -> String {
        let s = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "—" }
        guard s.count > 12 else { return s }
        return String(s.prefix(6)) + "…" + String(s.suffix(4))
    }

    /// 展示发送者：优先昵称。
    /// ⚠️ 后端在查不到昵称时会把**地址塞进 `senderName`**，所以不能只看「空不空」——
    /// 「非空就原样显示」会把整串 42 位地址打印到列表里（把布局撑坏）。
    static func displaySender(_ name: String, fallbackId: String) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return shortWalletAddress(fallbackId) }
        let lower = n.lowercased()
        // 看起来是地址的才缩：0x… / 1x… 开头，或「够长且全是十六进制字符」
        //（昵称里一般会有汉字/空格等非 hex 字符，不会被误伤）
        let looksLikeAddress =
            lower.hasPrefix("0x") || lower.hasPrefix("1x")
            || (n.count >= 26 && n.allSatisfy { $0.isHexDigit })
        return looksLikeAddress ? shortWalletAddress(n) : n
    }

    /// 代币名兵底：链上无 symbol 且本地/合约均查不到时会拿到合约地址，列表里按短地址展示避免撑破布局
    static func displayCoinName(_ name: String) -> String {
        let s = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count == 42, s.lowercased().hasPrefix("0x") else { return s }
        return String(s.prefix(6)) + "…" + String(s.suffix(4))
    }

    /// 金额统一保留 4 位小数（`amount` 是 Float，直接插值会打出 7 位）
    static func displayAmount(_ amount: Float) -> String {
        return "\(Double(amount).roundTo(places: 4))"
    }
    
    
    func configureWithData(packet: IMRedPacketModel, operation:IMRedPacketRecordType = .receive) {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        exclusiveTagView.isHidden = !packet.isExclusive
        // cell 复用：状态文案默认暖灰，只有「已过期」高亮为红
        statusLab.textColor = RP.inkSoft
        // 金额颜色：**收到的**记录用微信那种暖金（收入色，偏橙）；发出的保持常规墨色（支出色）。
        // ⚠️ 必须每次都复位 —— cell 是两个 tab 共用的，不复位会串色。
        moneyLab.textColor = (operation == .receive) ? RP.incomeGold : RP.ink
        if operation == .receive {
            let revInfo = packet.revInfo
            // 发送者：昵称为空、或昵称本身就是地址 ⇒ 都按短地址展示
            userLab.text = IMRedBagRecordCell.displaySender(packet.senderName, fallbackId: packet.senderId)
            timeLab.text = formatter.string(from: revInfo.createdAt)
            // 「收到的」金额前面加 +（微信零钱明细的写法：收入 + 暖金，支出 − 墨色）
            moneyLab.text = "+\(IMRedBagRecordCell.displayAmount(revInfo.amount)) \(IMRedBagRecordCell.displayCoinName(revInfo.coinName))"
            // 「收到的红包」右侧不再展示入账状态（用户 2026-09-29）：右半边只留金额，
            // 「专属红包」标签保留，但改到第二行右端与金额同侧（见 setExclusiveTagFollowsStatus）。
            statusLab.text = ""
            statusLab.isHidden = true
            setExclusiveTagFollowsStatus(false)
        } else {
            userLab.text = IMRedBagRecordCell.shortWalletAddress(packet.senderId)
            // 状态复位：两个 tab 共用同一个 cell，不复位会把上一个 tab 的隐藏态串过来
            statusLab.isHidden = false
            setExclusiveTagFollowsStatus(true)
            statusLab.text = packet.getStatusStr(with: operation) + " " + packet.countStr
            // 已过期：状态文案用红高亮，比灰色更醒目
            if packet.status == .past {
                statusLab.textColor = RP.redDeep
            }
            timeLab.text = formatter.string(from: packet.createdAt)
            // 「发出的」金额前面加 −（钱从自己余额出去）
            moneyLab.text = "-\(IMRedBagRecordCell.displayAmount(packet.amount)) \(IMRedBagRecordCell.displayCoinName(packet.coinName))"
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

