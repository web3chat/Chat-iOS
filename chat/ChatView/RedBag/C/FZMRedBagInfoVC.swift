//
//  IMRedBagInfoVC.swift
//  IM_SocketIO_Demo
//
//  Created by fzm on 2018/7/16.
//  Copyright © 2018年 Wang. All rights reserved.
//

import UIKit
import QuartzCore

class FZMRedBagInfoVC: FZMBaseViewController, ViewControllerProtocol {
    
    var packetId = ""
    var shouldAutoClaim = false
    /// 从聊天页带下来的私钥（用户在开红包面板上刚输过密码）：仅用于进页自动领取，用完即清
    var autoClaimPrivateKey: Data?
    var messageCoinName = ""
    var didAutoClaim = false
    var displayCoinName = ""
    var displayDecimals = 18

    /// 发送者的**会话地址**（不是链上 0x 地址）：从聊天页点红包进来时带上。
    /// 链上只给得到 `creator` 的 0x 地址、反查不到用户，所以头部的昵称靠它解析。
    /// （头部**不显示头像**，见 2026-09-28 决定）
    var senderAddress = ""
    /// 发送者昵称（解析一次后缓存；空 ⇒ 头部回落到链上短地址）
    private var senderDisplayName = ""

    /// 安卓端「专属红包」的原始 CSV（`领取人,金额,时间`）。**非空 ⇒ 进入「本地只读模式」**：
    /// 那条名片消息里没有链上红包 ID，所以整页跳过所有链上请求，只做展示。
    var localExclusiveCSV = ""
    /// 没有红包ID时隐藏「红包ID」那一行（本地只读模式用）
    var hidesPacketIdRow = false
        
    var packetModel : IMRedPacketModel? {
        didSet {
            guard let packet = self.packetModel else { return}
            remarkLab.text = packet.remark
            if packet.revInfo.amount == 0 {
                if packet.status == .receiveAll  || packet.status == .opened {
                    totalLab.text = L("红包已领完")
                } else if packet.status == .past {
                    totalLab.text = L("红包已过期")
                } else {
                    // 未领取成功：置空，不显示金额/数量
                    totalLab.text = ""
                }
            } else {
                totalLab.text = "\(packet.revInfo.amount) " + "\(packet.coinName)"
            }
            // 领取进度：显示「当前已领取份数 + 剩余份数」，不显示总份数；未领取成功时置空
            let claimedCount = packet.size - packet.remain
            remainLab.text = claimedCount > 0
                ? String(format: L("已领取%@个，余%@个"), "\(claimedCount)", "\(packet.remain)")
                : ""
            sharedBtn.isHidden = true
            
//            IMContactManager.shared().requestUserModel(with: packet.senderId) { (user, _, _) in
//                guard let user = user else { return }
//                let text = "\(user.showName)的\(packet.coinName)红包 "
//                let str = NSMutableAttributedString.init(string: text, attributes: [NSAttributedString.Key.font: UIFont.boldFont(16), NSAttributedString.Key.foregroundColor:UIColor.white])
//
//                if packet.type == .luck {
//                    let ach = NSTextAttachment.init()
//                    ach.image = GetBundleImage("send_bag_many")
//                    ach.bounds = CGRect.init(x: 0, y: -4, width: 20, height: 20)
//                    let imgText = NSAttributedString.init(attachment: ach)
//                    str.insert(imgText, at: str.length)
//                }
//
//                self.accountLab.attributedText = str
//            }
        }
    }
    
    
    lazy var accountLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.boldFont(17), textColor: UIColor.white, textAlignment: .center, text: "")
        lab.lineBreakMode = .byTruncatingMiddle
        return lab
    }()
    
    let remarkLab = UILabel.getLab(font: UIFont.boldFont(14), textColor: UIColor.init(hex: 0xFFC3C9), textAlignment: .center, text: "")
    
    /// 大号金额：等宽数字（数字变化不跳宽）+ 红底上的金色字
    lazy var totalLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.rpAmountFont(46, weight: .semibold), textColor: RP.onRedStrong, textAlignment: .center, text: "")
        lab.adjustsFontSizeToFitWidth = true
        lab.minimumScaleFactor = 0.6
        return lab
    }()

    let packetIdLab = UILabel.getLab(font: UIFont.regularFont(12), textColor: RP.onRedWeak, textAlignment: .center, text: "")

    lazy var headerView : UIView = {
        // 头部不显示头像：只靠文字层级（昵称 → 大金额 → 红包ID），高度相应收窄
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 240))
        view.backgroundColor = RP.redDeep
        view.clipsToBounds = false
        // 红金渐变：**竖直方向**。
        // 之前用斜向（0.1,0 → 0.9,1）时右上角会明显偏亮，紧贴导航栏的上边缘就和导航栏不是一个色，
        // 看起来像「导航栏比页面红」。竖直渐变能保证头图**顶边恰好是 redDeep**，与导航栏同色接得上。
        view.applyRPGradient(RP.primaryGradient, start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))
        // 金色高光下移到金额一带：离导航栏太近会在上边缘重新提亮，又把接缝打开
        view.applyRPGoldHighlight(center: CGPoint(x: 0.85, y: 0.42), spread: 0.5, alpha: 0.14)

        view.addSubview(accountLab)
        accountLab.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.top.equalToSuperview().offset(52)
            m.height.equalTo(24)
        })

        view.addSubview(remarkLab)
        remarkLab.isHidden = true

        // 层级：昵称 → 金额 → 红包ID（金额提到昵称正下方，视觉重心更清楚）
        view.addSubview(totalLab)
        totalLab.snp.makeConstraints({ (m) in
            m.centerX.equalTo(view)
            m.left.greaterThanOrEqualToSuperview().offset(16)
            m.right.lessThanOrEqualToSuperview().offset(-16)
            m.top.equalTo(accountLab.snp.bottom).offset(14)
            m.height.greaterThanOrEqualTo(52)
        })

        view.addSubview(packetIdLab)
        packetIdLab.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview().inset(20)
            m.top.equalTo(totalLab.snp.bottom).offset(14)
            m.height.equalTo(20)
        }

        return view
    }()

    let remainLab = UILabel.getLab(font: UIFont.regularFont(12), textColor: RP.inkSoft, textAlignment: NSTextAlignment.center, text: "")
    lazy var sharedBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setTitle(L("分享红包"), for: .normal)
        btn.setTitleColor(RP.redDeep, for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(14)
        btn.addTarget(self, action: #selector(shareBtnClick), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
    
    lazy var claimBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(L("领取红包"), for: .normal)
        btn.setTitleColor(RP.onRedStrong, for: .normal)
        btn.titleLabel?.font = UIFont.boldFont(17)
        // 渐变在 viewDidLayoutSubviews 里铺（那时才有真实 bounds）；
        // 圆角交给渐变层自己的 cornerRadius，本视图不裁剪，才能留住红色发光
        btn.applyRPGoldBorder(1, alpha: 0.45, cornerRadius: 25)
        btn.applyRPGlow(RP.redBright, radius: 14, opacity: 0.32, offsetY: 6)
        btn.isHidden = true
        btn.addTarget(self, action: #selector(claimRedPacketButtonClick), for: .touchUpInside)
        return btn
    }()
    
    lazy var sectionHeaderView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 44))
        view.backgroundColor = RP.cream
        // 金色装饰竖条（先 addSubview，再建引用了它的约束）
        let goldBar = UIView()
        goldBar.backgroundColor = RP.gold
        goldBar.layer.cornerRadius = 1.5
        view.addSubview(goldBar)
        goldBar.snp.makeConstraints { (m) in
            m.left.equalTo(view).offset(15)
            m.centerY.equalTo(view)
            m.size.equalTo(CGSize(width: 3, height: 14))
        }
        view.addSubview(remainLab)
        remainLab.textColor = RP.inkSoft
        remainLab.textAlignment = .left
        remainLab.snp.makeConstraints { (m) in
            m.centerY.equalTo(view)
            m.left.equalTo(goldBar.snp.right).offset(8)
            m.right.equalTo(view).offset(-15)
        }
        view.addSubview(sharedBtn)
        sharedBtn.snp.makeConstraints({ (m) in
            m.centerY.equalTo(remainLab)
            m.right.equalTo(view).offset(-15)
            m.width.equalTo(70)
            m.height.equalTo(20)
        })
        return view
    }()
    
    var dataArray = [IMRedPacketReceiveModel]()

    /// 详情是否允许展示：**未领取成功前为 false**（页面保持空白，只有转圈），
    /// 领取成功（或红包本身已不可领）后才置 true，一次性展示头部、
    /// 「已领取」栏与领取记录，避免先露出一份假详情再收起。
    /// 赋值点见 `RedPacketWeb3Integration.loadRedPacketInfoFromWeb3()`。
    var isPacketInfoLoaded = false

    /// 最近一次拉到的链上详情：进页自动领取（`autoClaimRedPacketIfNeeded`）直接用它判断能不能领，
    /// 不用自己再发一遍完整查询（那是白等一个网络往返）。
    var latestChainInfo: RedPacketChainInfo?
    /// 详情正在请求中（进页时正在拉）
    var isLoadingPacketInfo = false
    /// 自动领取在等「进页那次详情」：详情回来后再决定领不领
    var pendingAutoClaim = false

    /// 「详情 + 领取记录」的请求代次：每发起一次新的拉取就 +1，回包时代次已经不是最新的直接丢弃。
    /// 不加这个守卫时，「进页时（自己领取前）发出的那次请求」若比领取成功后的刷新更晚返回，
    /// 就会把新的领取记录（2 个领取人）覆盖回旧的（1 个领取人）——
    /// 表现就是「已领取 2 个，但领取记录只显示 1 个人」。
    var redPacketRequestGeneration = 0

    /// 页面停留时的轻量轮询定时器：只查领取份数，有人新领取才去拉完整详情
    var redPacketClaimWatchTimer: Timer?

    /// 详情未展示前先隐藏头部内容（昵称 / 金额 / 红包ID），
    /// 等领取成功（或数据回来）再一起显示，避免先露出空文案再跳变。
    func updateHeaderViewsVisibility() {
        let loaded = isPacketInfoLoaded
        accountLab.isHidden = !loaded
        packetIdLab.isHidden = !loaded || hidesPacketIdRow
        totalLab.isHidden = !loaded
    }

    /// 头部昵称：优先用聊天页解析出的发送者昵称，否则回落到链上短地址。
    /// - Parameter creator: 链上发起人，用于「记录页入口没带会话地址」时判断是不是自己发的
    func displayNameForHeader(fallback: String, creator: String = "") -> String {
        if !senderDisplayName.isEmpty { return senderDisplayName }
        if isSelfCreator(creator) {
            let me = LoginUser.shared().contactsName
            if !me.isEmpty { return me }
        }
        return fallback
    }

    /// 链上发起人是否就是当前钱包（自己发的红包）。
    /// ⚠️ 故意不加 `private`：`RedPacketWeb3Integration` 的 extension 在**另一个文件**里也要用它
    /// （判断「我发的红包还没人领」⇒ 头部显示「等待他人领取」）。全仓只有这一个定义，不会歧义。
    func isSelfCreator(_ creator: String) -> Bool {
        guard !creator.isEmpty,
            let me = RedPacketWeb3Service.shared.currentAddress(), !me.isEmpty
        else { return false }
        return me.lowercased() == creator.lowercased()
    }

    /// 解析发送者昵称（只做一次，`viewDidLoad` 里调）。
    func resolveSenderName() {
        guard !senderAddress.isEmpty else { return }
        senderDisplayName = UserManager.shared().user(by: senderAddress)?.contactsName ?? ""
    }

    /// 「红包ID xxxx」：前置金色圆点，正文用弱化白，避免这一行在红底上过重。
    /// ⚠️ 圆点用**红底专用** `onRedGold`（`gold` 压在珊瑚红上只有 ~1.9:1，几乎看不见）。
    /// 定义在 VC 侧是因为 `RedPacketWeb3Integration` 的 extension 负责赋值。
    static func makePacketIdText(_ id: String) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: "· ",
            attributes: [
                NSAttributedString.Key.foregroundColor: RP.onRedGold,
                NSAttributedString.Key.font: UIFont.boldFont(12)
            ]
        )
        text.append(NSAttributedString(
            string: L("红包ID ") + id,
            attributes: [
                NSAttributedString.Key.foregroundColor: RP.onRedWeak,
                NSAttributedString.Key.font: UIFont.regularFont(12)
            ]
        ))
        return text
    }
    
    lazy var tableView : UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: UITableView.Style.plain)
        view.backgroundColor = RP.pageBg
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        // 卡片式行：卡片高 64 + 上下各 4pt 留白
        view.rowHeight = 72
        // 卡片式列表用卡片间距区分，不再要系统分隔线
        view.separatorStyle = .none
        view.tableHeaderView = headerView
        view.tableFooterView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: CGFloat.leastNormalMagnitude))
        view.delegate = self
        view.dataSource = self
        view.bounces = false
        view.register(FZMRedBagReceiveCell.self, forCellReuseIdentifier: "FZMRedBagReceiveCell")
        
        return view
    }()
    let isShowRecord: Bool
    
    init(with packetId : String, isShowRecord: Bool = true, shouldAutoClaim: Bool = false, autoClaimPrivateKey: Data? = nil, coinName: String = "", senderAddress: String = "", localExclusiveCSV: String = "") {
        self.packetId = packetId
        self.isShowRecord = isShowRecord
        self.shouldAutoClaim = shouldAutoClaim
        self.autoClaimPrivateKey = autoClaimPrivateKey
        self.messageCoinName = coinName
        self.senderAddress = senderAddress
        self.localExclusiveCSV = localExclusiveCSV
        super.init(nibName: nil, bundle: nil)
        gk_statusBarStyle = .lightContent
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = RP.pageBg
        xls_navigationBarBackgroundColor = RP.redDeep
        xls_navigationBarTintColor = .white
        xls_isNavigationLineHidden = true
        navigationItem.title = nil
        self.createUI()
        // 发送者昵称（头部不显示头像，只解析昵称）
        self.resolveSenderName()
        // 详情返回前：头部（昵称/金额/红包ID）先不显示
        self.updateHeaderViewsVisibility()
        self.applyHeaderBottomCurveMaskIfNeeded()
        if localExclusiveCSV.isEmpty {
            self.getRedPacketInfo()
            // getRedPacketInfo 内部已一并获取领取记录，无需单独调用 getRedPacketReceiveDetail
        } else {
            // 安卓端专属红包：本地数据只读渲染，不查链
            self.applyLocalExclusiveRedPacket()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyHeaderBottomCurveMaskIfNeeded()
        headerView.layoutRPDecorations()
        // 按钮尺寸要 Auto Layout 跑完才知道，这里再铺渐变（applyRPGradient 会替换旧层，可重复调用）
        claimBtn.applyRPGradient(RP.primaryGradient,
                                 start: CGPoint(x: 0.1, y: 0),
                                 end: CGPoint(x: 0.9, y: 1),
                                 cornerRadius: 25)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyRedNavBarAppearance()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        autoClaimRedPacketIfNeeded()
        // 回到本页（含从「红包记录」等页面返回）时静默刷一次，并开始轻量轮询：
        // 否则别人在你停留期间领取了，页面会一直停在旧的领取记录上
        startRedPacketClaimWatch()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRedPacketClaimWatch()
    }

    deinit {
        redPacketClaimWatchTimer?.invalidate()
    }

    private func applyRedNavBarAppearance() {
        let red = RP.redDeep
        if #available(iOS 15.0, *) {
            let naba = UINavigationBarAppearance()
            naba.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            naba.buttonAppearance.normal.backgroundImage = UIImage()
            naba.buttonAppearance.highlighted.backgroundImage = UIImage()
            naba.doneButtonAppearance.normal.backgroundImage = UIImage()
            naba.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backButtonAppearance.normal.backgroundImage = UIImage()
            naba.backButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backgroundColor = red
            naba.shadowColor = .clear
            let titleFont = UIFont.boldFont(17)
            naba.titleTextAttributes = [
                NSAttributedString.Key.foregroundColor: UIColor.white,
                NSAttributedString.Key.font: titleFont
            ]
            navigationController?.navigationBar.standardAppearance = naba
            navigationController?.navigationBar.scrollEdgeAppearance = naba
            navigationController?.navigationBar.compactAppearance = naba
        } else {
            navigationController?.navigationBar.barTintColor = red
            navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        }
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.isTranslucent = false
    }

    /// 底部凹形圆角过渡至列表区，并在凹弧内侧压一条金色细线（实现见 `UIView.applyRPTopCurve`）
    private func applyHeaderBottomCurveMaskIfNeeded() {
        headerView.applyRPTopCurve()
    }

    @objc private func popRedBagInfoBack() {
        navigationController?.popViewController(animated: true)
    }
    
    /// 获取红包详情（使用合约接口）
    func getRedPacketInfo() {
        loadRedPacketInfoFromWeb3()
//        self.showProgress(with: nil)
//
//        let service = RedPacketService()
//        // 从合约获取红包详情
//        service.getRedPacketDetail(id: packetId) { [weak self] result in
//            self?.hideProgress()
//
//            switch result {
//            case .success(let detail):
//                self?.updateUIWithDetail(detail)
//            case .failure(let error):
//                self?.showToast(error.localizedDescription)
//            }
//        }
//
//        // 检查是否可以领取
//        checkCanClaim()
    }

    /// 获取红包领取记录（使用合约接口）
    func getRedPacketReceiveDetail() {
        loadClaimRecordsFromWeb3()
//       let service = RedPacketService()
//
//        service.getRedPacketClaimRecords(id: packetId) { [weak self] result in
//            switch result {
//            case .success(let records):
//                self?.updateClaimRecords(records)
//            case .failure(let error):
//                self?.showToast(error.localizedDescription)
//            }
//        }
    }

    /// 检查是否可以领取红包
    private func checkCanClaim() {
//       let service = RedPacketService()
//
//        service.canClaimRedPacket(id: packetId) { [weak self] result in
//            switch result {
//            case .success(let claimResult):
//                if claimResult.canClaim {
//                    // 显示领取按钮或自动弹出领取提示
//                    self?.showClaimButton()
//                }
//            case .failure:
//                break
//            }
//        }
    }

    /// 显示领取按钮
    private func showClaimButton() {
        // 在界面上添加领取按钮或调整UI提示可以领取
        // 这里简化处理，实际可以添加一个浮层按钮
    }

//    /// 使用合约详情更新UI
//    private func updateUIWithDetail(_ detail: RedPacketDetailModel) {
//        // 更新标题和金额
//        let amountStr = detail.totalAmount + " " + detail.tokenSymbol
//        totalLab.text = amountStr
//        totalLab.textColor = UIColor.white
//
//        // 更新状态显示
//        switch detail.status {
//        case .active:
//            remarkLab.text = detail.remark.isEmpty ? "恭喜发财，大吉大利！" : detail.remark
//        case .claimedAll:
//            totalLab.text = "红包已领完"
//            totalLab.textColor = UIColor(hex: 0xFFB7B7)
//            remarkLab.text = "红包已被领完"
//        case .expired:
//            totalLab.text = "红包已过期"
//            totalLab.textColor = UIColor(hex: 0xFFB7B7)
//            remarkLab.text = "红包已过期"
//        case .withdrawn:
//            totalLab.text = "红包已取回"
//            totalLab.textColor = UIColor(hex: 0xFFB7B7)
//            remarkLab.text = "红包已被取回"
//        }
//
//        // 更新领取进度
//        remainLab.text = String(
//            format: L("已领取%@/%@个，余%@个"),
//            "\(detail.claimedCount)",
//            "\(detail.totalCount)",
//            "\(detail.remainingCount)"
//        )
//
//        // 更新头像（根据红包创建者地址获取）
//        userHeadImageView.loadNetworkImage(with: "", placeImage: UIImage(named: "open_bag_humanhead"))
//    }

//    /// 更新领取记录列表
//    private func updateClaimRecords(_ records: [RedPacketClaimRecordModel]) {
//        // 转换为现有的数据模型格式
//        var receiveModels: [IMRedPacketReceiveModel] = []
//
//        for record in records {
//            let model = IMRedPacketReceiveModel()
//            model.userId = record.userAddress
//            model.userName = record.userName ?? ""
//            model.userAvatar = record.userAvatar ?? ""
//            model.amount = Float(record.amount) ?? 0
//            model.coinName = packetModel?.coinName ?? ""
//            model.createdAt = Date(timeIntervalSince1970: record.timestamp / 1000)
//            receiveModels.append(model)
//        }
//
//        self.dataArray = receiveModels
//        self.tableView.reloadData()
//    }

    /// 领取红包
//    @objc func claimRedPacket() {
//        // 显示密码输入框
//        let alertView = InputAlertView()
//        alertView.title = L("请输入密聊密码")
//        alertView.textFieldPlaceholder = L("请输入密聊密码")
//        alertView.isSecureTextEntry = true
//        alertView.confirmBtnTitle = L("确认")
//        alertView.touchBackgroundToHide = true
//
//        alertView.confirmBlock = { [weak self] password in
//            guard !password.isEmpty else {
//                self?.showToast(L("密码不能为空"))
//                return
//            }
//
//            self?.doClaimRedPacket(pwd: password)
//        }
//
//        alertView.show()
//    }

    /// 执行领取红包
//    private func doClaimRedPacket(pwd: String) {
//        showProgress(with: "领取中...")
//
//       let service = RedPacketService()
//
//        service.claimRedPacket(id: packetId, pwd: pwd) { [weak self] result in
//            self?.hideProgress()
//
//            switch result {
//            case .success(let amount):
//                self?.showToast(String(format: L("成功领取 %@"), amount))
//                // 刷新红包详情
//                self?.getRedPacketInfo()
//                self?.getRedPacketReceiveDetail()
//            case .failure(let error):
//                self?.showToast(error.localizedDescription)
//            }
//        }
//    }
    
    
    @objc func pushToRecord() -> Void {
        //查看记录
        let vc = FZMRedBagRecordVC.init()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func checkBalance(){
        //查看资产
    }
    
    func createUI() -> Void {
        let backItem = UIBarButtonItem(image: UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate),
                                       style: .plain,
                                       target: self,
                                       action: #selector(popRedBagInfoBack))
        backItem.tintColor = .white
        navigationItem.leftBarButtonItem = backItem

        refreshRedBagNavigationRightItems(chainInfo: nil)
        
        self.view.addSubview(self.tableView)
        tableView.snp.makeConstraints { (m) in
            m.top.left.right.equalToSuperview()
            m.bottom.equalToSuperview()
        }
        
        self.view.addSubview(claimBtn)
        claimBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(24)
            m.right.equalToSuperview().offset(-24)
            m.bottom.equalToSuperview().offset(-k_SafeBottomInset - 20)
            m.height.equalTo(50)
        }
        // 浮在列表之上的按钮会盖住最后一行，底部补出同高的可滚动区域
        tableView.contentInset.bottom = 50 + 20 + k_SafeBottomInset
    }
    
    @objc func shareBtnClick(){
//        let shareView = FZMShareAlertView.init()
//        UIApplication.shared.keyWindow?.addSubview(shareView)
//        shareView.shareBlock = {[weak self] (platment) in
//            if let packetUrl = self?.packetModel?.packetUrl, !packetUrl.isEmpty {
//                IMSDK.shared().shareDelegate?.shareRedBag(url: packetUrl, coinName: self?.packetModel?.coinName ?? "", platment: platment)
//            }
//        }
//        shareView.show()
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension FZMRedBagInfoVC : UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // 详情未展示时不占位（「已领取」栏等领取成功后一起显示）。
        // ⚠️ 一条领取记录都没有时也**不显示** —— 否则会留下一条 44pt 的空白米色栏
        //（自己发的专属红包还没人领时就是这样，很难看）。
        return (isPacketInfoLoaded && !self.dataArray.isEmpty) ? 44 : 0
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return (isPacketInfoLoaded && !self.dataArray.isEmpty) ? sectionHeaderView : nil
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 领取记录同属详情：未领取成功前也不显示，避免头部空着却露出他人领取记录
        return isPacketInfoLoaded ? self.dataArray.count : 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : FZMRedBagReceiveCell = tableView.dequeueReusableCell(withIdentifier: "FZMRedBagReceiveCell", for: indexPath) as! FZMRedBagReceiveCell
        let receiveModel = self.dataArray[indexPath.row]
        cell.configureWithData(receive: receiveModel)
        return cell
    }
    
}


