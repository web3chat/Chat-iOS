//
//  RedPacketMessageCell.swift
//  chat
//
//  红包消息Cell
//

import UIKit
import SnapKit

class RedPacketMessageCell: MessageContentCell {

    // MARK: - UI Components
    private var didSetupConstraints = false

    /// 背景容器（红包样式）：底色是代码绘制的红金渐变（`RPGradientView` 会在布局时铺上）
    lazy var redPacketContainerView: RPGradientView = {
        let view = RPGradientView()
        view.layer.cornerRadius = 14
        view.layer.masksToBounds = true
        view.applyRPGoldBorder(1, alpha: 0.30, cornerRadius: 14)
        return view
    }()

    /// 旧的红包底图（`open_bag_bg`）：底色已改成渐变，这里只保留视图以免动 `updateStatusOverlay` 里的 alpha 逻辑
    lazy var redPacketBackgroundImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "open_bag_bg"))
        iv.contentMode = .scaleToFill
        iv.isHidden = true
        return iv
    }()

    /// 红包图标
    lazy var redPacketIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "hongbao") ?? UIImage(named: "redBag_msgType") ?? UIImage(named: "send_bag_many")
        iv.contentMode = .scaleAspectFit
        // 半透明白圆底，把图标从红底上托起来
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        iv.layer.cornerRadius = 20
        iv.layer.masksToBounds = true
        return iv
    }()

    /// 祝福语（大标题）。
    /// ⚠️ 2026-09-28 修「显示不全」：原来是 16pt + **单行** ⇒ 可用宽度只有 138pt，
    /// 而「恭喜发财，大吉大利！」就需要 160pt，尾部直接被截掉。
    /// 改成 15pt + **2 行**，并同步把气泡放大到 250×92（见 `RedPacketMessageSizeCalculator.bubbleSize`）。
    lazy var blessingLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldFont(15)
        label.textColor = UIColor.white
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// 币种名称标签（实际上放的是「查看红包 / 红包已领取」这类状态/入口文案）
    lazy var coinNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.regularFont(12)
        label.textColor = RP.onRedWeak
        label.lineBreakMode = .byTruncatingTail
        // 比右侧类型标签更「不肯缩」（label 默认就是 750，这里写出来表明意图）
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    /// 红包类型标签（拼手气 / 普通 / 专属，还可能带币种前缀 "BTY Exclusive"）
    lazy var typeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.regularFont(12)
        label.textColor = RP.onRedWeak
        label.textAlignment = .right
        // 右对齐 ⇒ 截断头部，保留尾部的类型名（"… Exclusive"）
        label.lineBreakMode = .byTruncatingHead
        // 英文下「左文案 + 间距 + 类型」刚好卡在 158pt 可用宽度上（实测 "Open Packet" + "BTY Exclusive" = 158），
        // 币种符号更长时允许缩字（不留就只差 2~3pt 被截断，很难看）
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        // ⚠️ 必须比左侧状态文案低：两者同一行，英文远比中文长（"BTY Exclusive" vs "专属红包"），
        // 不给它低优先级就会和左侧叠在一起（用户 2026-09-28 录屏里报的「红包消息文案重叠」）
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    /// 状态遮罩（已领取/已过期等）
    lazy var statusOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.isHidden = true
        return view
    }()

    /// 状态标签
    lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = UIColor.white
        label.textAlignment = .center
        return label
    }()

    // MARK: - Properties

    private var packetId: String?
    private var redPacketItem: RedpacketItem?

    // MARK: - Setup

    override func setupViews() {
        super.setupViews()

        messageContainerView.addSubview(redPacketContainerView)
        redPacketContainerView.addSubview(redPacketBackgroundImageView)
        redPacketContainerView.addSubview(redPacketIconImageView)
        redPacketContainerView.addSubview(blessingLabel)
        redPacketContainerView.addSubview(coinNameLabel)
        redPacketContainerView.addSubview(typeLabel)
        redPacketContainerView.addSubview(statusOverlayView)
        statusOverlayView.addSubview(statusLabel)
    }

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        setupRedPacketConstraintsIfNeeded()
    }

    private func setupRedPacketConstraintsIfNeeded() {
        guard !didSetupConstraints else { return }
        didSetupConstraints = true

        redPacketContainerView.snp.makeConstraints { make in
            make.left.top.right.equalToSuperview()
            // ⚠️ 必须与 `RedPacketMessageSizeCalculator.bubbleSize.height`（92）一致，
            // 否则要么气泡被裁、要么消息容器下留白
            make.height.equalTo(92)
        }
        redPacketBackgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        redPacketIconImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        blessingLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(18)
            make.right.equalTo(redPacketIconImageView.snp.left).offset(-12)
            make.top.equalToSuperview().offset(14)
            // 最多 2 行（2×~21pt），给个上界免得长文案把下面的币种行压掉
            make.height.lessThanOrEqualTo(46)
        }
        coinNameLabel.snp.makeConstraints { make in
            make.left.equalTo(blessingLabel)
            make.bottom.equalToSuperview().offset(-12)
            // ⚠️ 必须和右侧类型标签划清边界：两者在同一行，中文都只有 4 个字不会撞，
            // 英文（"Open Packet" + "BTY Exclusive"）会**直接叠在一起**（用户 2026-09-28 录屏里的重叠）
            make.right.lessThanOrEqualTo(typeLabel.snp.left).offset(-6)
            // 再兜一条图标边界：claimed / expired / allClaimed 这些状态下 `typeLabel.isHidden = true`，
            // 只有文案长（"The red envelope has been collected"）时它会**压到红包图标上**（同一份录屏里能看到）
            make.right.lessThanOrEqualTo(redPacketIconImageView.snp.left).offset(-12)
        }
        typeLabel.snp.makeConstraints { make in
            make.right.equalTo(redPacketIconImageView.snp.left).offset(-12)
            make.centerY.equalTo(coinNameLabel)
        }
        statusOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        statusLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        redPacketContainerView.isActiveStyle = true
        redPacketBackgroundImageView.alpha = 1
        redPacketIconImageView.alpha = 1
        blessingLabel.alpha = 1
        typeLabel.isHidden = false
        statusOverlayView.isHidden = true
        packetId = nil
        redPacketItem = nil
    }

    // MARK: - Configuration

    override func configure(
        with message: Message,
        at indexPath: IndexPath,
        and messageCollectionView: MessageCollectionView
    ) {
        super.configure(with: message, at: indexPath, and: messageCollectionView)

        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            FZMLog("RedPacketMessageCell：messagesDisplayDelegate 为空，跳过配置")
            return
        }

        switch message.kind {
        case .redPacket(let redPacketItem):
            self.redPacketItem = redPacketItem
            configureWithRedPacketItem(redPacketItem, isOutgoing: message.isOutgoing)
        case .contactCard(let card):
            // 安卓端的「专属红包」是**名片消息兼容通道**（contactType == -1）。
            // 外观在这里就定下来，保证任何调用点都不会渲染出一个空气泡。
            // ⚠️ 尺寸必须配套：见 `RedPacketMessageSizeCalculator.messageContainerSize`
            if card.contactType == -1 {
                configureAsAndroidExclusiveRedPacket()
            }
        default:
            break
        }
    }

    private func configureWithRedPacketItem(_ item: RedpacketItem, isOutgoing: Bool) {
        // 祝福语
        let remark = item.remark ?? L("恭喜发财，大吉大利！")
        blessingLabel.text = remark

        // 币种名称
        let coinName = item.redcoinName ?? ""
        coinNameLabel.text = L("查看红包")

        // 红包类型（未知时给中性文案，不写可能错的类型 —— 详见 refreshTypeLabel）
        refreshTypeLabel(coinName: coinName)

        // 保存红包ID
        self.packetId = item.redtxHash

        // 根据发送方向调整布局
        if isOutgoing {
            // 我发送的红包
            blessingLabel.textAlignment = .left
            coinNameLabel.textAlignment = .left
        } else {
            // 收到的红包
            blessingLabel.textAlignment = .left
            coinNameLabel.textAlignment = .left
        }

        // 根据状态设置样式（可以从缓存或预加载的数据中获取）
        updateStatusOverlay(status: .active, isOutgoing: isOutgoing)
        refreshRedPacketStatus(packetId: item.redtxHash, isOutgoing: isOutgoing)
    }

    /// 红包类型文案。
    /// - 已知「是不是专属」（本地档案 / 链上详情缓存）⇒ 直接写死类型，不会再有闪变；
    /// - 未知 ⇒ 给中性文案「红包」（`allowPlaceholder`），**不写任何可能错的类型**，等链上查询回来再定
    ///   （消息体 pb 里 `packetType` 只有 0=拼手气/1=普通，「专属」只能靠链上 `whitelistCount` 判断）；
    /// - 查询失败（断网）时用 `allowPlaceholder: false` 退回按 `packetType` 显示，免得类型一直空着。
    private func refreshTypeLabel(coinName: String, allowPlaceholder: Bool = true) {
        let packetType = self.redPacketItem?.packetType ?? 0
        let txHash = self.redPacketItem?.redtxHash
        let fallbackText = packetType == 0 ? L("拼手气红包") : L("普通红包")
        var isExclusive = RedPacketWeb3Service.shared.knownPacketExclusiveFlag(id: txHash)
        if isExclusive == nil, let info = RedPacketWeb3Service.shared.cachedRedPacketInfo(id: txHash) {
            isExclusive = info.hasWhitelist
        }
        let text: String
        if isExclusive == true {
            text = L("专属红包")
        } else if isExclusive == false {
            text = fallbackText
        } else {
            text = allowPlaceholder ? L("红包") : fallbackText
        }
        typeLabel.text = coinName.isEmpty ? text : "\(coinName) \(text)"
    }

    private func refreshRedPacketStatus(packetId: String?, isOutgoing: Bool) {
        guard let packetId = packetId, !packetId.isEmpty else { return }
        RedPacketWeb3Service.shared.getRedPacketInfo(id: packetId) { [weak self] result in
            guard let self = self, self.packetId == packetId else { return }
            let coinName = self.redPacketItem?.redcoinName ?? ""
            guard case .success(let info) = result else {
                // 查询失败（断网等）：退回按消息里的 packetType 显示，不然类型一直空着
                self.refreshTypeLabel(coinName: coinName, allowPlaceholder: false)
                return
            }
            // 「专属」只能按链上 whitelistCount 判断 —— 记进本地档案（已持久化），
            // 下次渲染 / 滚动复用 / 重进会话 / 断网都能直接显示对
            RedPacketWeb3Service.shared.markKnownPacket(id: packetId, isExclusive: info.hasWhitelist)
            self.refreshTypeLabel(coinName: coinName)
            if info.userClaimed {
                self.updateStatusOverlay(status: .claimed, isOutgoing: isOutgoing)
            } else if info.status == .claimedAll {
                self.updateStatusOverlay(status: .allClaimed, isOutgoing: isOutgoing)
            } else if info.status == .expiredWithdrawn {
                self.updateStatusOverlay(status: .expiredWithdrawn, isOutgoing: isOutgoing)
            } else if info.status == .expired || info.status == .withdrawn {
                self.updateStatusOverlay(status: .expired, isOutgoing: isOutgoing)
            } else {
                self.updateStatusOverlay(status: .active, isOutgoing: isOutgoing)
            }
        }
    }

    /// 更新状态遮罩
    /// - 底色不再是 `backgroundColor`（会被渐变层盖住），改为切换 `RPGradientView.isActiveStyle`
    private func updateStatusOverlay(status: RedPacketStatus, isOutgoing: Bool) {
        let isActive = (status == .active)
        redPacketContainerView.isActiveStyle = isActive
        switch status {
        case .active:
            statusOverlayView.isHidden = true
            redPacketBackgroundImageView.alpha = 1
            redPacketIconImageView.alpha = 1
            blessingLabel.alpha = 1
            typeLabel.isHidden = false
            coinNameLabel.text = L("查看红包")
        case .claimed:
            statusOverlayView.isHidden = true
            redPacketBackgroundImageView.alpha = 0.45
            redPacketIconImageView.alpha = 0.45
            blessingLabel.alpha = 0.75
            typeLabel.isHidden = true
            coinNameLabel.text = L("红包已领取")
        case .expired:
            statusOverlayView.isHidden = true
            redPacketBackgroundImageView.alpha = 0.45
            redPacketIconImageView.alpha = 0.45
            blessingLabel.alpha = 0.75
            typeLabel.isHidden = true
            coinNameLabel.text = L("红包已过期")
        case .expiredWithdrawn:
            statusOverlayView.isHidden = true
            redPacketBackgroundImageView.alpha = 0.45
            redPacketIconImageView.alpha = 0.45
            blessingLabel.alpha = 0.75
            typeLabel.isHidden = true
            coinNameLabel.text = L("过期已取回")
        case .allClaimed:
            statusOverlayView.isHidden = true
            redPacketBackgroundImageView.alpha = 0.45
            redPacketIconImageView.alpha = 0.45
            blessingLabel.alpha = 0.75
            typeLabel.isHidden = true
            coinNameLabel.text = L("红包已领完")
        }
    }

    // MARK: - 安卓端「专属红包」（名片消息兼容通道 type = -1）

    /// 安卓端的「专属红包」在 iOS 侧是一条**名片消息**（type = -1），
    /// 为了两端观感一致，这里复用同一个气泡 cell 渲染（路由见 `MessageVC` / `MessageCollectionViewLayout`）。
    /// 它没有链上红包 ID，所以**不做任何链上查询**，直接按「已被领取」态写死文案。
    func configureAsAndroidExclusiveRedPacket() {
        blessingLabel.text = L("恭喜发财，大吉大利！")
        coinNameLabel.text = L("查看详情")
        typeLabel.text = L("专属红包")
        typeLabel.isHidden = false
        // 暗红 + 降低不透明度 = 「已被领取」，与自家红包领取后的样子一致
        redPacketContainerView.isActiveStyle = false
        redPacketBackgroundImageView.alpha = 0.45
        redPacketIconImageView.alpha = 0.45
        blessingLabel.alpha = 0.75
        statusOverlayView.isHidden = true
        packetId = nil
        redPacketItem = nil
    }

    // MARK: - Actions

    /// 获取红包ID
    func getRedPacketId() -> String? {
        return packetId
    }
}

// MARK: - RedPacket Status Enum

enum RedPacketStatus {
    case active      // 可领取
    case claimed     // 已领取
    case expired     // 已过期
    case expiredWithdrawn // 过期且发起人已取回未领余额
    case allClaimed  // 已领完
}
