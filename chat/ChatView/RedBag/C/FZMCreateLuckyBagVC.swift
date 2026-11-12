//
//  FZMCreateLuckyBagVC.swift
//  Chat33
//
//  Created by fzm on 2018/11/7.
//  Copyright © 2018年 fzm. All rights reserved.
//


import UIKit
// ⚠️ 必须显式 import：`snp` 靠桥接头就能用，但 `SnapKit.Constraint` 这类**模块限定名**需要模块可见
// （工程里没有 `@_exported import SnapKit`，所以不写这行会报 `Cannot find type 'SnapKit' in scope`）
import SnapKit
import RxSwift
import KeychainAccess
import JKBigInteger

// MARK: - 发红包页面
class FZMCreateLuckyBagVC: FZMBaseViewController {
    
  
    let toId : String
    let isGroup : Bool
    var isRandom = true
    var isTextRedBag = false

    /// 专属红包领取人链上地址列表（空 = 普通红包，人人可领）
    let exclusiveAddresses: [String]
    /// 专属红包领取人显示名（与地址一一对应，仅用于展示）
    let exclusiveNames: [String]
    /// 专属红包领取人的**会话地址**（与 `exclusiveAddresses` 同下标一一对应）
    /// —— 仅用于展示：弹层里给用户看的是聊天地址（`1…`），不是链上 0x 地址
    let exclusiveChatAddresses: [String]

    /// 是否发专属红包（仅指定地址可领，份数 = 领取人数）
    var isExclusive: Bool {
        return !exclusiveAddresses.isEmpty
    }

    /// 专属红包领取人数（非专属为 0）
    var exclusiveMemberCount: Int {
        return exclusiveAddresses.count
    }
    
    var sendCompleteBlock : (( Int, String, IMRedPacketType, String, String, String, Bool)->())?
    
    lazy var coinTypeLab: UILabel = {
        let lbl = UILabel()
        lbl.textColor = RP.ink
        lbl.font = UIFont.mediumFont(16)
        lbl.textAlignment = .right
        return lbl
    }()
    
    lazy var coinTypeLab2: UILabel = {
        let lbl = UILabel()
        lbl.textColor = UIColor.white.withAlphaComponent(0.78)
        lbl.font = UIFont.regularFont(13)
        return lbl
    }()
    
    /// 封面上的总额预览（原来是飘在页面底部的一块大数字，现在印到红包封面上）
    lazy var totalCountLab: UILabel = {
        let lbl = UILabel()
        lbl.textColor = RP.onRedStrong
        lbl.font = UIFont.rpAmountFont(34, weight: .semibold)
        lbl.adjustsFontSizeToFitWidth = true
        lbl.minimumScaleFactor = 0.6
        return lbl
    }()
    
    var packetType: IMRedPacketType = .luck
    
    /// 金额行左侧标题（文案随红包类型变：总数额 / 单个数额）
    private var amountModeTitleLbl: UILabel!
    
    /// 顶部「红包类型」展示
    private lazy var packetTypeValueLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = RP.ink
        lbl.font = UIFont.mediumFont(16)
        lbl.text = L("拼手气红包")
        lbl.textAlignment = .right
        lbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        return lbl
    }()
    
    private lazy var packetTypeSelectRow: UIView = {
        let v = UIView()
        v.makeRPCard()
        v.isUserInteractionEnabled = true
        let title = UILabel()
        title.textColor = RP.inkSoft
        title.font = UIFont.regularFont(15)
        title.text = L("红包类型")
        let arrow = UIImageView()
        arrow.image = UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate)
        arrow.contentMode = .scaleAspectFit
        arrow.tintColor = RP.inkSoft
        arrow.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        v.addSubview(title)
        v.addSubview(packetTypeValueLabel)
        v.addSubview(arrow)
        title.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(15)
            m.width.equalTo(66)
            m.centerY.equalToSuperview()
        }
        arrow.snp.makeConstraints { m in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.width.equalTo(6)
            m.height.equalTo(10)
        }
        packetTypeValueLabel.snp.makeConstraints { m in
            m.centerY.equalToSuperview()
            m.right.equalTo(arrow.snp.left).offset(-10)
            m.left.greaterThanOrEqualTo(title.snp.right).offset(12)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(showPacketTypePicker))
        v.addGestureRecognizer(tap)
        return v
    }()

    /// 专属红包：领取人展示行（仅专属模式占位）
    /// 名字左对齐展示；点击整行可查看当前全部领取人（见 `showReceiverListSheet`）
    private lazy var exclusiveReceiverRow: UIView = {
        let v = UIView()
        v.makeRPCard()
        v.isUserInteractionEnabled = true
        let title = UILabel()
        title.textColor = RP.inkSoft
        title.font = UIFont.regularFont(15)
        title.text = L("领取人")
        // 标签列固定 66pt，英文（Recipients）比中文长：
        // ① 超出时缩字；② compression 从 required 降为 defaultHigh ——
        // `.required` 会与「宽度 == 66」这条 required 约束冲突（Xcode 会打断一条并报约束冲突日志）
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7
        title.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        let value = UILabel()
        value.textColor = RP.ink
        value.font = UIFont.mediumFont(16)
        // ⚠️ 值统一**右对齐**贴在箭头前：左对齐会让每行内容都挤在左边、右侧空一大块
        value.textAlignment = .right
        value.lineBreakMode = .byTruncatingTail
        let names = self.exclusiveNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if names.isEmpty {
            // 名字拿不到时展示**会话地址**（`1…`），再拿不到才回落到链上 0x 地址
            let chatAddress = self.exclusiveChatAddresses.first ?? ""
            let chainAddress = self.exclusiveAddresses.first ?? ""
            value.text = (chatAddress.isEmpty ? chainAddress : chatAddress).shortAddress
        } else {
            value.text = names.joined(separator: "、")
        }
        // 右侧箭头：提示整行可点击（查看全部领取人）
        let arrow = UIImageView()
        arrow.image = UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate)
        arrow.contentMode = .scaleAspectFit
        arrow.tintColor = RP.inkSoft
        arrow.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        v.addSubview(title)
        v.addSubview(value)
        v.addSubview(arrow)
        // 固定 66pt 标签列：所有行的标签左边缘对齐，值从同一列开始
        title.snp.makeConstraints { m in
            m.left.equalToSuperview().offset(15)
            m.width.equalTo(66)
            m.centerY.equalToSuperview()
        }
        arrow.snp.makeConstraints { m in
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
            m.width.equalTo(6)
            m.height.equalTo(10)
        }
        value.snp.makeConstraints { m in
            m.left.equalTo(title.snp.right).offset(12)
            m.right.equalTo(arrow.snp.left).offset(-10)
            m.centerY.equalToSuperview()
        }
        return v
    }()
    
    /// 金额行的左侧标题。
    /// v2-A 改动：原来这里还挂着「装饰箭头 + 拼手气图标」——
    /// 箭头**没有任何手势**（点了没反应，误导用户），图标又和上一行「红包类型：拼手气红包」重复，
    /// 而且它们把「总数额」推到了 x≈61，和别的行（x=15）对不齐 ⇒ 一起删掉。
    lazy var randomView: UIView = {
        let view = UIView.init()
        let totalLbl = UILabel()
        self.amountModeTitleLbl = totalLbl
        totalLbl.textColor = RP.inkSoft
        totalLbl.font = UIFont.regularFont(15)
        view.addSubview(totalLbl)
        totalLbl.snp.makeConstraints({ (m) in
            m.left.centerY.equalToSuperview()
        })
        totalLbl.text = L("总数额")
        return view
    }()

    lazy var bagMoneyTF: UITextField = {
        let tf = UITextField()
        tf.textAlignment = .right
        tf.keyboardType = .decimalPad
        tf.font = UIFont.mediumFont(22)
        tf.textColor = RP.ink
        tf.tintColor = RP.redBright
        return tf
    }()
    
    lazy var balanceLbl: UILabel = {
        let lbl = UILabel()
        // 「可用余额」小胶囊：金色浅底 + 金褐字（原来是主题蓝，与红金体系不搭）
        lbl.textColor = RP.goldDeep
        lbl.textAlignment = .center
        lbl.font = UIFont.regularFont(12)
        lbl.text = L("余额 0")
        lbl.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        tap.rx.event.subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self,
                  let coin = strongSelf.currentCoin else { return }
            let balance = Double(coin.coin_balance)
            guard balance > 0 else { return }
            let dataSource = RedPacketWalletDataSource.shared
            let decimalPlaces = dataSource.getDecimalPlaces(for: coin)
            strongSelf.bagMoneyTF.text = "\(balance.roundTo(places: decimalPlaces))"
            strongSelf.setTotalCount()
        }).disposed(by: disposeBag)
        lbl.addGestureRecognizer(tap)
        return lbl
    }()
    
    lazy var bagNumberTF: UITextField = {
        let tf = UITextField()
        tf.attributedPlaceholder = NSAttributedString(
            string: L("填入数量"),
            attributes: [.foregroundColor: RP.placeholder, .font: UIFont.mediumFont(22)])
        tf.textAlignment = .right
        tf.keyboardType = .numberPad
        tf.font = UIFont.mediumFont(22)
        tf.textColor = RP.ink
        tf.tintColor = RP.redBright
        return tf
    }()
    
    
    lazy var bagRemark: UITextField = {
        let tf = UITextField()
        // 卡片内的一行：**无边框 / 无底色 / 无内边距**。
        // 旧版是「卡片里再套一个灰底圆角盒子」（box-in-box），而 UITextField 默认没有 padding，
        // 占位符直接顶着左侧圆角 ⇒ 看起来既挤又廉价。
        // 现在它与「币种 / 红包类型」等行同一套结构：灰标题 + 深色内容。
        tf.backgroundColor = .clear
        tf.borderStyle = .none
        tf.font = UIFont.regularFont(16)
        tf.textColor = RP.ink
        tf.tintColor = RP.redBright
        return tf
    }()

    /// 备注行的左侧标题（与其他行的标题同规格）
    lazy var remarkTitleLab: UILabel = {
        let lbl = UILabel()
        lbl.textColor = RP.inkSoft
        lbl.font = UIFont.regularFont(15)
        lbl.text = L("祝福语")
        lbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        return lbl
    }()
    
    lazy var changeTypeView: UIImageView = {
        let v = UIImageView.init()
        v.isUserInteractionEnabled = true
        // 不要在懒加载中使用 target: self，移到 setupViews 中设置
        return v
    }()
    
    var remarkCount: Int {
        get{
            return self.isTextRedBag ? 500 : 20
        }
    }
    
    lazy var remarkCountLab: UILabel = {
        let lbl = UILabel()
        lbl.textColor = RP.inkSoft
        lbl.textAlignment = .right
        lbl.font = UIFont.regularFont(12)
        lbl.text = "0/" + "\(self.remarkCount)"
        // 空文本时不显示（否则它浮在行中间偏右，和谁都不挨着）
        lbl.isHidden = true
        return lbl
    }()
    
     let sendBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(L("塞币进红包"), for: .normal)
        btn.titleLabel?.font = UIFont.boldFont(17)
        btn.setTitleColor(RP.onRedStrong, for: .normal)
        // 禁用态是中性暖灰底 ⇒ 字也用中性灰（别用 onRedWeak 那种"红底上的白"）
        btn.setTitleColor(RP.onDisabled, for: .disabled)
        // 渐变在 viewDidLayoutSubviews 里铺（那时才有真实 bounds）；
        // 圆角交给渐变层自己的 cornerRadius，本视图不裁剪，才能留住红色发光
        btn.applyRPGoldBorder(1, alpha: 0.45, cornerRadius: 26)
        btn.applyRPGlow(RP.redBright, radius: 14, opacity: 0.30, offsetY: 6)
        return btn
    }()
    
     let adBtn: UIButton = {
        let btn = UIButton(type: .custom)
         btn.backgroundColor = UIColor(hex: 0xE14D5C)
        btn.setTitle(L("推广红包"), for: .normal)
        btn.titleLabel?.font = UIFont.regularFont(18)
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.setTitleColor(UIColor(hex: 0xff7878), for: .disabled)
        btn.layer.cornerRadius = 3
        btn.layer.masksToBounds = true
        return btn
    }()
    
    
//    /// 当前选中的币种
//    var currentCoin: LocalCoin?

    /// 所有币种列表
//    var coinsArray: [LocalCoin] = []

    lazy var coinView: FZMRedBagCoinView = {
        let view = FZMRedBagCoinView.init()
        view.selectedBlock = {[weak self] selectedCoin in
            self?.currentCoin = selectedCoin
            self?.updateUIWithSelectedCoin(selectedCoin)
            self?.hideCoinView()
        }
        return view
    }()
    
    let bty: UILabel = {
        let lbl = UILabel()
        lbl.textColor = RP.goldDeep
        lbl.font = UIFont.regularFont(13)
        return lbl
    }()
    
    var decimalPlaces: Int = 0
    
    var balance:Double = 0

    /// 根据选中的 LocalCoin 更新UI
    private func updateUIWithSelectedCoin(_ coin: LocalCoin) {
        let dataSource = RedPacketWalletDataSource.shared
        let decimalPlaces = dataSource.getDecimalPlaces(for: coin)
        let coinName = coin.coin_type ?? ""

        self.decimalPlaces = decimalPlaces
        self.bagMoneyTF.attributedPlaceholder = NSAttributedString(
            string: L("请输入金额"),
            attributes: [.foregroundColor: RP.placeholder, .font: UIFont.mediumFont(22)])
        self.coinTypeLab.text = coinName
        self.bty.text = coinName
        self.coinTypeLab2.text = coinName

        // 刷新余额
        refreshBalanceForCoin(coin)

        // 重置输入（专属红包份数 = 领取人数，由 applyPacketType 统一设置）
        self.bagMoneyTF.text = nil
        self.bagNumberTF.text = self.isGroup && !self.isExclusive ? nil : "1"

        // 重置红包类型（专属/普通都默认拼手气，可切换）
        self.applyPacketType(isRandom: true)
    }

    /// 刷新指定币种的余额
    private func refreshBalanceForCoin(_ coin: LocalCoin) {
        let coinId = Int(coin.coin_coinid)
        let coinName = coin.coin_type ?? ""

        // 显示加载中
        balanceLbl.text = L("余额加载中...")

        RedPacketWalletBridge.getTokenBalanceWithUpdate(coinId: coinId) { [weak self] balance in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }

                // 更新余额
                strongSelf.balance = balance.roundTo(places: strongSelf.decimalPlaces)

                // 确保币种标签显示正确（币名前面补一个空格，否则拼出 "64.245BTY"）
                strongSelf.balanceLbl.text = L("可用 ") + "\(strongSelf.balance)" + " " + coinName
                strongSelf.bty.text = coinName
            }
        }
    }
 
    lazy var coinViewGroup: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight))
        view.backgroundColor = UIColor.init(white: 0, alpha: 0.7)
        
        let tap = UITapGestureRecognizer.init()
        tap.delegate = self
        tap.rx.event.subscribe(onNext: {[weak self] (_) in
            self?.hideCoinView()
        }).disposed(by: disposeBag)
        view.addGestureRecognizer(tap)
        
        coinView.frame = CGRect.init(x: view.frame.size.width, y: 0, width: view.frame.size.width - 70, height: view.frame.size.height)
        view.addSubview(coinView)
        return view
    }()
    
    @objc func changeRedBagType() {
        self.isTextRedBag = !self.isTextRedBag
        self.changeTypeView.image = self.isTextRedBag ? UIImage(named:"redBag_msgType") : UIImage(named:"redBag_bagType")
        self.applyRemarkModeAppearance()
        self.bagRemark.limitText(with: 20)
        let count = self.bagRemark.text?.count ?? 0
        self.remarkCountLab.text = "\(count)" + "/" + "\(self.remarkCount)"
        self.remarkCountLab.isHidden = (count == 0)
    }

    /// 备注输入域的「模式外观」：占位文案 + 左侧标题随「红包 / 文字红包」切换。
    /// ⚠️ 必须用 `attributedPlaceholder` 而不是 `placeholder`：
    /// 直接赋 `placeholder` 会把占位符颜色重置回系统灰（和页面的暖中性调不搭）。
    private func applyRemarkModeAppearance() {
        let placeholder = isTextRedBag ? L("请输入消息内容") : L("恭喜发财，大吉大利！")
        bagRemark.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: RP.placeholder,
                .font: UIFont.regularFont(16)
            ])
        remarkTitleLab.text = isTextRedBag ? L("消息内容") : L("祝福语")
    }
    
    func showCoinView() {
        
        UIApplication.shared.keyWindow?.addSubview(coinViewGroup)
        UIView.animate(withDuration: 0.3) {
            self.coinView.frame = CGRect.init(x: 70, y: 0, width: self.coinView.frame.size.width, height: self.coinView.frame.size.height)
        }
    }
    
    func hideCoinView() {
        UIView.animate(withDuration: 0.3, animations: {
            self.coinView.frame = CGRect.init(x: self.coinViewGroup.frame.size.width, y: 0, width: self.coinView.frame.size.width, height: self.coinView.frame.size.height)
        }) { (_) in
            self.coinViewGroup.removeFromSuperview()
        }
    }
    
    init(to: String, isGroup: Bool, exclusiveAddresses: [String] = [], exclusiveNames: [String] = [], exclusiveChatAddresses: [String] = []) {
        self.toId = to
        self.isGroup = isGroup
        self.exclusiveAddresses = exclusiveAddresses
        self.exclusiveNames = exclusiveNames
        self.exclusiveChatAddresses = exclusiveChatAddresses
        super.init(nibName:nil, bundle:nil)
        // 注意：不要在 init 中访问懒加载属性，移到 viewDidLoad 中设置
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.navBarColor = UIColor(hex: 0xFAFBFC)
//        self.navTintColor = Color_Theme
//        self.navTitleColor = Color_Theme
        // 页面底改中性暖灰：原来继承基类的**纯白**，而卡片是 cream 底 ⇒
        // 卡片和白底只差 4/255 亮度，边界看不出来，整页还发黄。
        self.view.backgroundColor = RP.pageBg
        // 专属红包（指定领取人）与普通发红包共用本页，标题区分开
        self.navigationItem.title = isExclusive ? L("专属红包") : L("发红包")
        let backItem = UIBarButtonItem(image: UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate),
                                       style: .plain,
                                       target: self,
                                       action: #selector(popBack))
        backItem.tintColor = .black
        self.navigationItem.leftBarButtonItem = backItem
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("红包记录"), style: .plain, target: self, action: #selector(pushToRecord))
        self.navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : RP.redDeep,.font : UIFont.boldFont(14)], for: .normal)
        self.navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : RP.redDeep,.font : UIFont.boldFont(14)], for: .highlighted)
        initView()
        observeKeyboard()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 每次进入页面刷新当前选中币种的余额
        if let coin = currentCoin {
            refreshBalanceForCoin(coin)
        }
    }
    
    @objc private func popBack() {
        navigationController?.popViewController(animated: true)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // 安全区变化（横竖屏 / 机型切换）时把底部按钮重新对位
        updateSendBtnBottom()
    }

    // MARK: - 键盘：底部「塞币进红包」跟着键盘上移
    //
    // 与发帖页 `SquareCreatePostVC` 同一套：按钮固定在页面底部，键盘弹起时把它的 bottom 约束
    // 上移到键盘上方；滚区底边挂在按钮顶部，所以可视区会同步缩短，按钮永远不会被键盘盖住。
    // ⚠️ 本页已加进 `AppDelegateIntercepter.loadIQKeyboard` 的 `disabledDistanceHandlingClasses`，
    // 否则 IQKeyboardManager 会把滚动内容再调一次偏量（两套逻辑打架）。
    private func observeKeyboard() {
        let follow: (KeyboardNotification) -> Void = { [weak self] notification in
            guard let self = self else { return }
            let height = notification.endFrame.height
            guard height > 0, abs(height - self.keyboardHeight) > 0.5 else { return }
            self.keyboardHeight = height
            self.updateSendBtnBottom(notification)
        }
        keyboardObserver.callbacks[.willShow] = follow
        keyboardObserver.callbacks[.willChangeFrame] = follow
        keyboardObserver.callbacks[.willHide] = { [weak self] notification in
            guard let self = self, self.keyboardHeight > 0 else { return }
            self.keyboardHeight = 0
            self.updateSendBtnBottom(notification)
        }

        // ⚠️ 在输入框之间**切换**时键盘高度不变 ⇒ `.willShow` / `.willChangeFrame` 都不会再触发，
        // 上面「跟着键盘滚」那套就不会跑 ⇒ 新聚焦的那一行可能还压在键盘下面。
        // ⇒ 每个输入框开始编辑时补滚一次（异步一帧，等布局稳定再量 rect）。
        for tf in [bagMoneyTF, bagNumberTF, bagRemark] {
            tf.rx.controlEvent(.editingDidBegin)
                .subscribe(onNext: { [weak self] in
                    DispatchQueue.main.async { self?.revealEditingFieldIfNeeded() }
                })
                .disposed(by: disposeBag)
        }
    }

    /// 按钮离屏幕底部的距离 = 键盘高度 + 10（键盘收起时是安全区 + 10）
    private func updateSendBtnBottom(_ notification: KeyboardNotification? = nil) {
        let base = max(keyboardHeight, self.view.safeAreaInsets.bottom)
        sendBtnBottomConstraint?.update(offset: -(base + 10))
        if keyboardHeight == 0 {
            // 键盘收起：把「为滚动补出来的底部 inset」还回去
            //（不复位的话下次进来内容底部会多一段空白，offset 也会停在旧位置）
            scrollView.contentInset.bottom = 0
        }
        guard let notification = notification else { return }
        UIView.animate(withDuration: notification.timeInterval,
                       delay: 0,
                       options: [notification.animationOptions, .allowAnimatedContent, .beginFromCurrentState],
                       animations: { [weak self] in
                           self?.view.layoutIfNeeded()
                           // ⚠️ 必须和键盘**同帧**上跳：放到 completion 里会变成「键盘弹完页面才动」，
                           // 体感就是用户说的「页面也没有往上跳」。
                           // `layoutIfNeeded()` 已经把 scrollView 的 bounds 顶到目标值，
                           // 所以这里量到的高度已经是键盘弹起后的高度。
                           self?.revealEditingFieldIfNeeded()
                       },
                       completion: { [weak self] _ in
                           // 幂等再兜一次：键盘动画中若出现过中间布局，这里按最终尺寸纠正
                           self?.revealEditingFieldIfNeeded()
                       })
    }

    /// 键盘弹起后把「输入区」滚到键盘上方。
    ///
    /// ⚠️ 两个真实踩过的坑（用户报「页面也没有往上跳 / 键盘会挡住个数栏」）：
    /// 1. **只露「正在编辑的那个输入框」不够**：「总金额」和「个数」是相邻两行
    ///    （帧量过：个数行在屏幕 62.5% 高度处，正落在键盘上方边缘），编辑金额时个数行会被压住
    ///    ⇒ 编辑其中任一都按**两行的并集**算。
    /// 2. **`scrollRectToVisible` 在「内容只比一屏多一点点」时基本滚不动**：
    ///    本页内容高度 ≈ 一屏，它算出来「已在可视区内」就直接不滚了 ⇒ 看上去页面没反应。
    ///    ⇒ 先按需补 `contentInset.bottom` 造出滚动空间，再直接 `setContentOffset` 到位。
    private func revealEditingFieldIfNeeded() {
        guard let field = [bagMoneyTF, bagNumberTF, bagRemark].first(where: { $0.isFirstResponder }) else { return }

        var rect = field.convert(field.bounds, to: scrollView)
        // 「金额 / 个数」相邻两行：编辑任一行就把两行一起露出来
        let pair = [bagMoneyTF, bagNumberTF].filter { !$0.isHidden && $0.alpha > 0 && $0.superview?.isHidden != true }
        if pair.count == 2, pair.contains(where: { $0 === field }) {
            rect = pair.reduce(rect) { $0.union($1.convert($1.bounds, to: scrollView)) }
        }

        let target = rect.maxY + 16 - scrollView.bounds.height
        guard target > 0 else { return }        // 本来就在可视区里，别硬滚回顶部
        scrollView.contentInset.bottom = target // 造出滚动空间（内容不足一屏时必需，否则滚不动）
        scrollView.setContentOffset(CGPoint(x: 0, y: target), animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySendButtonStyle()
        // 封面卡的渐变 / 金高光是装饰层，尺寸要在布局完成后同步（否则停在 0 就是一张看不见的层）
        coverCard.layoutRPDecorations()
    }

    /// 发送按钮配色（**可用 / 禁用两套**）。
    /// ⚠️ 禁用态不能用「红渐变 + alpha」表达 —— 半透明的红会糊成**脏粉色**，
    /// 真机截图里那块最丑的就是它。禁用应该是中性暖灰。
    private func applySendButtonStyle() {
        let enabled = sendBtn.isEnabled
        // 按钮尺寸要 Auto Layout 跑完才知道，所以在这里铺渐变（applyRPGradient 会替换旧层，可重复调用）
        sendBtn.applyRPGradient(
            enabled ? RP.primaryGradient : RP.disabledGradient,
            start: CGPoint(x: 0.1, y: 0),
            end: CGPoint(x: 0.9, y: 1),
            cornerRadius: 26)
        sendBtn.applyRPGoldBorder(1, alpha: enabled ? 0.45 : 0.0, cornerRadius: 26)
        sendBtn.applyRPGlow(enabled ? RP.redBright : UIColor.clear,
                            radius: 14,
                            opacity: enabled ? 0.30 : 0,
                            offsetY: 6)
    }
    
    @objc func pushToRecord() {
        let vc = FZMRedBagRecordVC.init()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    private func initView() {
        setupViews()
        setActions()
        // 初始化默认值（从 init 移到这里，避免在 init 中访问懒加载属性）
        // 专属红包份数 = 领取人数
        self.bagNumberTF.text = self.isExclusive
            ? "\(self.exclusiveMemberCount)"
            : (self.isGroup ? nil : "1")
        self.loadData()
    }
    
    /// 所有币种列表
    var coinsArray: [LocalCoin] = []

    /// 当前选中的币种
    var currentCoin: LocalCoin? {
        didSet {
            guard let coin = currentCoin else { return }
            updateUIWithSelectedCoin(coin)
        }
    }

    func loadData() {
        // 从项目钱包获取币种数据
        self.showProgress(with: L("加载中..."))

        RedPacketWalletBridge.fetchWalletTokensForRedPacket { [weak self] coins in
            self?.hideProgress()

            // 剔除 BTY 币种（1开头地址或主链/币种均为BTY）
            let filteredCoins = coins.filter { !RedPacketWalletDataSource.shared.shouldExcludeBTYCoin($0) }

            if filteredCoins.isEmpty {
                self?.showToast(L("暂无可用币种"))
            } else {
                self?.coinsArray = filteredCoins
                self?.coinView.setCoins(filteredCoins)
                // 默认选中 0x 地址开头的 BTY 币种（没有则回退列表第一个）
                let defaultCoin = filteredCoins.first(where: { coin in
                    let type = (coin.coin_type ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    let address = (coin.coin_address ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return type == "BTY" && address.hasPrefix("0x")
                }) ?? filteredCoins.first
                if let defaultCoin = defaultCoin {
                    self?.currentCoin = defaultCoin
                }
            }
        }
    }

    /// 刷新所有币种余额（后台更新，不直接操作UI）
    func refreshBalances() {
        guard !coinsArray.isEmpty else { return }

        for coin in coinsArray {
            let coinId = Int(coin.coin_coinid)

            RedPacketWalletBridge.getTokenBalanceWithUpdate(coinId: coinId) { [weak self] balance in
                // 如果当前选中的币种，更新UI显示
                if let strongSelf = self,
                   let current = strongSelf.currentCoin,
                   Int(current.coin_coinid) == coinId {
                    DispatchQueue.main.async {
                        strongSelf.balance = balance.roundTo(places: strongSelf.decimalPlaces)
                        let coinName = current.coin_type ?? ""
                        strongSelf.balanceLbl.text = L("可用 ") + "\(strongSelf.balance)" + " " + coinName
                    }
                }
            }
        }
    }
    
    private func setActions() {
        Observable.combineLatest([bagMoneyTF.rx.text, bagNumberTF.rx.text]).subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.bagNumberTF.limitText(with: 10)
            if strongSelf.bagNumberTF.text ?? "" == "0" {
                strongSelf.bagNumberTF.text = nil
            }
            
            if strongSelf.bagMoneyTF.text ?? "" == "." {
                strongSelf.bagMoneyTF.text = nil
            }
            
            if let text = strongSelf.bagMoneyTF.text, text.count == 2,
                let first = text.first, first == Character.init("0"),
                text != "0."{
                 strongSelf.bagMoneyTF.text = "0"
            }
            
            
            if let text = strongSelf.bagMoneyTF.text, let last = text.last, last == Character.init(".") {
                let newText = text.substring(to: text.count - 2)
                if newText.contains(".") {
                    strongSelf.bagMoneyTF.text = newText
                }
            }
           
            if let text = strongSelf.bagMoneyTF.text,
                text.contains("."),
                let integer = (text as NSString).components(separatedBy: ".").first,
                let decimal = (text as NSString).components(separatedBy: ".").last,
                decimal.count > strongSelf.decimalPlaces {
                strongSelf.bagMoneyTF.text = integer + "." + decimal.substring(to: strongSelf.decimalPlaces - 1)
            }
            
            if Double(strongSelf.bagMoneyTF.text ?? "0") ?? 0 > strongSelf.balance {
                if strongSelf.balance <= 0 {
                    strongSelf.bagMoneyTF.text = ""
                } else {
                    strongSelf.bagMoneyTF.text = "\(strongSelf.balance)"
                }
            }
            var btnEnabled = false
            if let money = strongSelf.bagMoneyTF.text, let numberString = strongSelf.bagNumberTF.text, let number = Int(numberString), let moneyNumber = Double(money) {
                if moneyNumber > strongSelf.balance {
                    strongSelf.bagMoneyTF.text = "\(strongSelf.balance)"
                }
                btnEnabled = moneyNumber > 0 && number > 0
            }
            strongSelf.setBtnEnable(btnEnabled)
            strongSelf.setTotalCount()
            
        }).disposed(by: disposeBag)
        //发送红包
        sendBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.checkPaw(with: 1)
            
        }).disposed(by: disposeBag)
        
        adBtn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            self?.checkPaw(with: 2)
        }).disposed(by: disposeBag)
        
        bagRemark.rx.text.orEmpty.asObservable().subscribe(onNext: { [weak self] (str) in
            guard let strongSelf = self else{ return }
            strongSelf.bagRemark.limitText(with: strongSelf.remarkCount)
            // 空文本时隐藏计数器（原来一直显示，浮在行中间偏右和谁都不挨着）
            strongSelf.remarkCountLab.isHidden = (strongSelf.bagRemark.text ?? "").isEmpty
            if let text = strongSelf.bagRemark.text, text.count > 0 {
                strongSelf.remarkCountLab.text = "\(text.count)/" + "\(strongSelf.remarkCount)"
            }else {
                strongSelf.remarkCountLab.text = "0/" + "\(strongSelf.remarkCount)"
            }
        }).disposed(by: disposeBag)
    }
    
    private func setTotalCount() {
        if !self.isRandom {
            if let str1 = self.bagMoneyTF.text, let str2 = self.bagNumberTF.text,
                let mu = Double(str1), let count = Double(str2) {
                if mu == 0 {
                    return
                }
                let total = mu * count
                var totalCount = "\(total)"
                
                if let decimals = totalCount.components(separatedBy: ".").last, decimals.count == 1 {
                    totalCount = totalCount + "0"
                }
                self.totalCountLab.text =  totalCount
                
                if total > self.balance {
                    self.showToast(L("资产不足"))
                    self.setBtnEnable(false)
                    return
                }
                
                if count > 99999 {
                    self.showToast(L("红包个数不能大于99999"))
                    self.setBtnEnable(false)
                    return
                }
                self.setBtnEnable(true)
                
            } else {
                self.totalCountLab.text = "0.00"
                self.setBtnEnable(false)
            }
        } else {
            if let str1 = self.bagMoneyTF.text,let mu = Double(str1) {
                if mu == 0 {
                    return
                }
                let total = mu
                var totalCount = "\(total)"
                
                if let decimals = totalCount.components(separatedBy: ".").last, decimals.count == 1 {
                    totalCount = totalCount + "0"
                }
                self.totalCountLab.text =  totalCount
                
                guard let str2 = self.bagNumberTF.text,let count = Double(str2) else { return }
                if count > 99999 {
                    self.showToast(L("红包个数不能大于99999"))
                    self.setBtnEnable(false)
                    return
                }
                if mu > self.balance {
                    self.showToast(L("资产不足"))
                    self.setBtnEnable(false)
                    return
                }
                if mu > 0 && (mu / count) < pow(0.1, Double(self.decimalPlaces)).roundTo(places: self.decimalPlaces) {
                    let maxCount = Int((mu / pow(0.1, Double(self.decimalPlaces))).rounded())
                    self.showToast(String(format: L("当前金额下红包个数不能大于%@"), "\(maxCount)"))
                    self.setBtnEnable(false)
                    return
                }
                self.setBtnEnable(true)
                
            } else {
                self.totalCountLab.text = "0.00"
                self.setBtnEnable(false)
            }
        }
    }
    
    private func checkPaw(with type: Int) {
        self.view.endEditing(true)
        guard let coin = currentCoin else {
            showToast(L("请选择币种"))
            return
        }
        // 专属红包：必须已选定所有领取人的链上地址
        if isExclusive {
            guard !exclusiveAddresses.isEmpty,
                  exclusiveAddresses.allSatisfy({ $0.isValidEthereumAddressString }) else {
                showToast(L("未获取到对方地址"))
                return
            }
        }
        let ds = RedPacketWalletDataSource.shared
        if ds.shouldBlockBTYMainCoinRedPacket(coin) {
            showToast(L("BTY主链原生币暂不支持发红包"))
            return
        }
        if !ds.isRedPacketNativeToken(coin), ds.redPacketERC20ContractAddress(for: coin) == nil {
            showToast(L("代币合约地址无效"))
            return
        }
        // 显示密码输入弹框
        showPasswordAlert(type: type)
    }

    /// 发红包前的取私钥：**每次都弹密码框**（不看缓存、也不写缓存）。
    ///
    /// 2026-09-24 用户要求：「发红包的时候，每次都需要输入密码，不依据缓存密钥来做」。
    /// 密码正确性由 `WalletPrivateKeyStore.derivePrivateKey` 内部用 `GoFunction.checkPassword` 校验，
    /// 所以这里不再重复验一次。
    private func showPasswordAlert(type: Int) {
        WalletPrivateKeyStore.shared.requestPrivateKeyByPassword(title: L("请输入密聊密码"), success: { [weak self] privateKey in
            // 私钥到手，调用发送红包方法
            self?.sendRedPacket(privateKey: privateKey)
        }, failure: { [weak self] error in
            switch error {
            case .cancelled:
                break
            default:
                FZMLog("发红包取私钥失败：\(error.message)")
                self?.showToast(error.message)
            }
        })
    }


    /// 发送红包
    private func sendRedPacket(privateKey: Data) {
        sendRedPacketWithWeb3(privateKey: privateKey)
        // 1. 获取输入参数
//        guard let moneyText = bagMoneyTF.text,
//              let money = Double(moneyText),
//              let numberText = bagNumberTF.text,
//              let number = Int(numberText),
//              let coin = currentCoin else {
//            showToast(L("参数错误"))
//            return
//        }
//
//        // 2. 获取合约地址
//        let dataSource = RedPacketWalletDataSource.shared
//        let contractAddress = dataSource.getContractAddress(for: coin) ?? "0x0000000000000000000000000000000000000000"
//
//        // 3. 计算总金额
//        let totalAmount = isRandom ? money : money * Double(number)
//
//        // 4. 获取祝福语
//        let remark = bagRemark.text?.isEmpty == false ? bagRemark.text! : "恭喜发财，大吉大利！"
//
//        // 5. 创建红包服务
//        let service = RedPacketService() 
//
//        // 6. 显示加载
//        showProgress(with: L("创建红包中..."))
//
//        // 7. 判断红包类型并创建
//        let packetType: IMRedPacketType = isRandom ? .luck : .common
//
//        if isRandom {
//            // 创建随机金额红包
//            service.createRandomRedPacket(
//                token: contractAddress,
//                totalAmount: String(totalAmount),
//                totalCount: number,
//                expireHours: 24,
//                allowedAddresses: [], // 空数组表示人人可领
//                pwd: pwd,
//                coin: coin
//            ) { [weak self] result in
//                self?.handleCreateRedPacketResult(
//                    result: result,
//                    packetType: packetType,
//                    totalAmount: totalAmount,
//                    number: number,
//                    remark: remark,
//                    contractAddress: contractAddress,
//                    coin: coin
//                )
//            }
//        } else {
//            // 创建固定金额红包
//            service.createFixedRedPacket(
//                token: contractAddress,
//                totalAmount: String(totalAmount),
//                totalCount: number,
//                expireHours: 24,
//                allowedAddresses: [],
//                pwd: pwd,
//                coin: coin
//            ) { [weak self] result in
//                self?.handleCreateRedPacketResult(
//                    result: result,
//                    packetType: packetType,
//                    totalAmount: totalAmount,
//                    number: number,
//                    remark: remark,
//                    contractAddress: contractAddress,
//                    coin: coin
//                )
//            }
//        }
    }

//    /// 处理创建红包结果
//    private func handleCreateRedPacketResult(
//        result: Result<String, RedPacketServiceError>,
//        packetType: IMRedPacketType,
//        totalAmount: Double,
//        number: Int,
//        remark: String,
//        contractAddress: String,
//        coin: LocalCoin
//    ) {
//        hideProgress()
//
//        switch result {
//        case .success(let packetId):
//            // 创建成功
//            showToast(String(format: L("红包创建成功，ID: %@"), packetId))
//
//            // 构建红包消息并发送
//            self.sendRedPacketMessage(
//                packetId: packetId,
//                packetType: packetType,
//                totalAmount: totalAmount,
//                number: number,
//                remark: remark,
//                contractAddress: contractAddress,
//                coin: coin
//            )
//
//        case .failure(let error):
//            // 创建失败
//            showToast(error.localizedDescription)
//        }
//    }

    /// 发送红包消息到聊天
//    private func sendRedPacketMessage(
//        packetId: String,
//        packetType: IMRedPacketType,
//        totalAmount: Double,
//        number: Int,
//        remark: String,
//        contractAddress: String,
//        coin: LocalCoin
//    ) {
//        // 构建红包消息参数
//        let coinName = coin.coin_type ?? "ETH"
//        let packetTypeInt = packetType == .luck ? 0 : 1
//        let expire = UInt64(Date().timeIntervalSince1970 * 1000) + UInt64(24 * 3600 * 1000)
//
//        // 调用发送完成回调
//        if let block = sendCompleteBlock {
//            block(
//                Int(coin.coin_coinid),
//                packetId,
//                packetType,
//                contractAddress,
//                coinName,
//                remark,
//                isTextRedBag
//            )
//        }
//
//        // 返回上一页
//        navigationController?.popViewController(animated: true)
//    }

    /// 将金额转换为最小单位（wei）
    private func convertAmountToWei(amount: Double, decimals: Int) -> String {
        let multiplier = pow(10.0, Double(decimals))
        let weiAmount = amount * multiplier
        // 使用 JKBigInteger 处理大数
        let weiString = String(format: "%.0f", weiAmount)
        return weiString
    }
    
    private func setBtnEnable(_ enabled: Bool) {
        sendBtn.isEnabled = enabled
        adBtn.isEnabled = enabled
        adBtn.backgroundColor = UIColor(hex: enabled ? 0xE33143: 0xD45353)
        // sendBtn 的底色是渐变层（插在 layer 最底层），再设 backgroundColor 会被盖住 ⇒ 用透明度表达禁用态
        sendBtn.isEnabled = enabled
        // 配色由 applySendButtonStyle 按 isEnabled 铺（禁用 = 中性暖灰，不要用 alpha 压红渐变）
        applySendButtonStyle()
    }
    
    /// 根据红包类型更新发送按钮标题
    private func updateSendButtonTitle() {
        if isRandom {
            sendBtn.setTitle(L("塞币进红包"), for: .normal)
        } else {
            let count = Int(bagNumberTF.text ?? "1") ?? 1
            if count > 1 {
                sendBtn.setTitle(String(format: L("发给%@人"), "\(count)"), for: .normal)
            } else {
                sendBtn.setTitle(L("塞币进红包"), for: .normal)
            }
        }
    }
    /// 顶部「红包封面」卡：红金竖渐变 + 金边 + 金高光。
    /// ⚠️ 铺渐变时视图 bounds 还是 0（尺寸由 Auto Layout 决定），装饰层尺寸靠
    /// `viewDidLayoutSubviews` 里的 `layoutRPDecorations()` 补齐（它会把 `RP.` 前缀的层同步成 bounds）。
    private lazy var coverCard: UIView = {
        let v = UIView()
        v.applyRPGradient(
            RP.primaryGradient, start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1),
            cornerRadius: 20)
        v.applyRPGoldHighlight(center: CGPoint(x: 0.85, y: 0.42), spread: 0.5, alpha: 0.16)
        v.applyRPGoldBorder(1, alpha: 0.35, cornerRadius: 20)
        return v
    }()

    // MARK: - 滚动容器 / 键盘跟随

    /// 页面滚动容器（内容一屏放不下时滑动；键盘弹起时底边上移，见「键盘」一节）
    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .onDrag
        return view
    }()
    /// 「塞币进红包」的底部约束（键盘弹起时把它顶到键盘上方，与发帖页 `SquareCreatePostVC` 同一套）
    private var sendBtnBottomConstraint: SnapKit.Constraint?
    /// 当前键盘高度（0 = 收起）
    private var keyboardHeight: CGFloat = 0
    /// 工程已有的键盘模块（`KeyboardObserver.swift`），用法见发帖页
    private lazy var keyboardObserver = KeyboardObserver()

    private func setupViews() {
        let luckyImageV: UIImageView = {
            let imgV = UIImageView()
            imgV.contentMode = .scaleAspectFill
            imgV.image = UIImage(named: "")
            return imgV
        }()
        self.view.addSubview(luckyImageV)

        // 页面改成可滚动：加了封面卡之后小屏（iPhone SE）放不下。
        // 底边不在这里定：它要挂在页面底部那颗「塞币进红包」的顶部（键盘弹起时跟着缩）
        self.view.addSubview(scrollView)

        let bgView = UIView()
        bgView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer()
        bgView.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: {[weak self] (_) in
            self?.dismissKeyboard()
        }).disposed(by: disposeBag)
        scrollView.addSubview(bgView)
        
        luckyImageV.snp.makeConstraints { (m) in
            m.edges.equalTo(self.safeArea)
        }
        scrollView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            // ⚠️ `safeAreaTop` 是 UIView 扩展上的属性（UIViewController 扩展里叫 `safeTop`），
            // 所以要写 self.view.safeAreaTop；工程里其它页面都是这个写法
            m.top.equalTo(self.view.safeAreaTop)
            // ⚠️⚠️ **显式钉宽度**：只写 left/right 钉 superview 时，真机上整块滚动内容比屏幕窄了
            // 约 50pt（卡片右边缘离屏幕右边一大截、行内值和箭头整体左偏）。
            // 底部那颗「塞币进红包」直接挂在 self.view 上，实测宽度是对的 ⇒ 问题就在滚动容器这一层。
            // 补一条等于屏幕宽度的硬约束，杜绝 Auto Layout 把宽度退化成「按内容自适应」。
            m.width.equalTo(self.view.snp.width)
        }
        bgView.snp.makeConstraints { (m) in
            // ⚠️ 这里刻意**不用** `left.right.top.equalToSuperview()` 那种链式写法：
            // 内容宽度直接用 left + width 定死（= 屏幕宽度），完全不依赖 right 那一端，
            // 避免宽度被 Auto Layout 退化成「按内容自适应」（真机上就是这么窄掉 50pt 的）。
            m.left.top.equalToSuperview()
            m.width.equalTo(self.view.snp.width)
        }

        // 顶部红包封面卡（实例见 lazy var coverCard）：红金渐变 + 金边，金额直接印在封面上。
        // 金额用的还是 totalCountLab / coinTypeLab2（只是从底部挪进来了），所以 setTotalCount 不用改。
        bgView.addSubview(coverCard)
        // 内嵌细金线（inset 7）：金只做线、不做大面积填充 —— 这是"高级感"的关键
        let coverHairline = UIView()
        coverHairline.isUserInteractionEnabled = false
        coverHairline.layer.borderWidth = 1
        coverHairline.layer.borderColor = RP.onRedGold.withAlphaComponent(0.32).cgColor
        coverHairline.layer.cornerRadius = 14
        coverCard.addSubview(coverHairline)
        coverHairline.snp.makeConstraints { (m) in
            m.edges.equalToSuperview().inset(7)
        }
        coverCard.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(16)
            m.height.equalTo(148)
        }
        // ⚠️ hongbao@3x.png 实际只有 75px = 25pt，按 44pt 显示 = 拉伸 1.76× 会发虚
        // （真机截图里就是一块糊的黄方块）；染成香槟金剪影 + 收到 36pt（拉伸 1.44×）
        let bagIcon = UIImageView(
            image: UIImage(named: "hongbao")?.withRenderingMode(.alwaysTemplate))
        bagIcon.contentMode = .scaleAspectFit
        bagIcon.tintColor = RP.onRedStrong
        coverCard.addSubview(bagIcon)
        bagIcon.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.top.equalToSuperview().offset(26)
            m.size.equalTo(36)
        }
        coverCard.addSubview(totalCountLab)
        totalCountLab.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.left.greaterThanOrEqualToSuperview().offset(16)
            m.right.lessThanOrEqualToSuperview().offset(-16)
            m.top.equalTo(bagIcon.snp.bottom).offset(10)
            m.height.equalTo(42)
        }
        coverCard.addSubview(coinTypeLab2)
        coinTypeLab2.snp.makeConstraints { (m) in
            m.centerX.equalToSuperview()
            m.left.greaterThanOrEqualToSuperview().offset(16)
            m.right.lessThanOrEqualToSuperview().offset(-16)
            m.top.equalTo(totalCountLab.snp.bottom).offset(2)
            m.height.equalTo(18)
        }
        
        bgView.addSubview(exclusiveReceiverRow)
        exclusiveReceiverRow.isHidden = !isExclusive
        exclusiveReceiverRow.snp.makeConstraints { m in
            m.leading.equalToSuperview().offset(15)
            // ⚠️ 这里**不能**写成 `offset(isExclusive ? 16 : 0)`：
            // 非专属红包时「领取人」行高度为 0，间距也跟着变 0 ⇒ 封面卡和「红包类型」卡
            // 上下紧贴、圆角咬在一起，看起来就是"重合了"。固定 16pt 后两种模式都有呼吸空间。
            m.top.equalTo(coverCard.snp.bottom).offset(16)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(isExclusive ? 56 : 0)
        }
        // 点击「领取人」行：查看当前全部领取人
        exclusiveReceiverRow.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(showReceiverListSheet)))

        bgView.addSubview(packetTypeSelectRow)
        // 专属红包同样可以切换红包类型（拼手气 / 普通）
        packetTypeSelectRow.snp.makeConstraints { m in
            m.leading.equalToSuperview().offset(15)
            m.top.equalTo(exclusiveReceiverRow.snp.bottom).offset(isExclusive ? 15 : 0)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(56)
        }
        
        let coinTypePart: UIView = {
           let v = UIView.init()
            v.makeRPCard()
            return v
        }()
        bgView.addSubview(coinTypePart)
        
        let coinName: UILabel = {
            let lbl = UILabel()
            lbl.textColor = RP.inkSoft
            lbl.font = UIFont.regularFont(15)
            lbl.text = L("币种")
            return lbl
        }()
        let arrowsImageV: UIImageView = {
            let v = UIImageView.init()
            v.image = UIImage(named: "nav_back_blue")?.withRenderingMode(.alwaysTemplate)
            v.contentMode = .scaleAspectFit
            v.tintColor = RP.inkSoft
            v.transform = CGAffineTransform.init(rotationAngle: CGFloat(Double.pi))
            return v
        }()
        
        coinTypePart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.top.equalTo(packetTypeSelectRow.snp.bottom).offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(56)
        }
        
        coinTypePart.addSubview(coinName)
        coinName.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.width.equalTo(66)
            m.centerY.equalToSuperview()
        }
        coinTypePart.addSubview(arrowsImageV)
        arrowsImageV.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalToSuperview().offset(-15)
            m.width.equalTo(6)
            m.height.equalTo(10)
        }
        coinTypePart.addSubview(coinTypeLab)
        coinTypeLab.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.right.equalTo(arrowsImageV.snp.left).offset(-10)
        }
        
        let tap2 = UITapGestureRecognizer.init()
        tap2.rx.event.subscribe(onNext: {[weak self] (_) in
            self?.showCoinView()
        }).disposed(by: disposeBag)
        coinTypePart.addGestureRecognizer(tap2)
        
        
        let onePart: UIView = {
            let v = UIView()
            v.makeRPCard()
            return v
        }()
        bgView.addSubview(onePart)
        onePart.addSubview(randomView)
        onePart.addSubview(bagMoneyTF)
        onePart.addSubview(bty)
        
        onePart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.top.equalTo(coinTypePart.snp.bottom).offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(coinTypePart)
        }
        randomView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.bottom.equalToSuperview()
            // = 标签列 66（与领取人 / 红包类型 / 币种行同一列）
            m.width.equalTo(66)
        }
        
        bagMoneyTF.snp.makeConstraints { (m) in
            // 15(边距) + 66(标签列) + 12(间距) = 93。
            // 原来写死 90，而左侧内容实占 86 ⇒ 只剩 4pt 间隙，金额一长就顶到一起
            m.leading.equalToSuperview().offset(93)
            m.centerY.equalToSuperview()
            m.trailing.equalTo(bty.snp.leading).offset(-10)
            m.height.equalTo(30)
        }
        
        bty.snp.makeConstraints { (m) in
            // -31 而不是 -10：让「BTY」的右边界与带箭头行的**值右边界（344）对齐**，
            // 否则金额/个数两行的右侧会和上面三行错开 21pt
            m.trailing.equalToSuperview().offset(-31)
            m.centerY.equalToSuperview()
        }
        
        // 「可用余额」胶囊：v2-A 改成**右对齐 + 透明底 + 细金线描边**。
        // 原来是实心淡黄、宽度由文字撑开、贴在左边，右侧空一大块，像张贴纸。
        let balancePill = UIView()
        balancePill.backgroundColor = .clear
        balancePill.layer.cornerRadius = 12
        balancePill.layer.borderWidth = 1
        balancePill.layer.borderColor = RP.goldHairline.cgColor
        bgView.addSubview(balancePill)
        balancePill.addSubview(balanceLbl)
        balancePill.snp.makeConstraints { (m) in
            // 与上面的金额输入、下面的个数输入同一竖直右边界
            m.trailing.equalToSuperview().offset(-15)
            m.leading.greaterThanOrEqualToSuperview().offset(15)
            m.top.equalTo(onePart.snp.bottom).offset(8)
            m.height.equalTo(24)
        }
        balanceLbl.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(10)
            m.right.equalToSuperview().offset(-10)
            m.centerY.equalToSuperview()
        }
        
        let twoPart: UIView = {
            let v = UIView()
            v.makeRPCard()
            return v
        }()
        bgView.addSubview(twoPart)
        let bagNumberLbl: UILabel = {
            let lbl = UILabel()
            lbl.textColor = RP.inkSoft
            lbl.font = UIFont.regularFont(15)
            // 标签列固定 66pt：英文（Quantity / Currency / Receiver…）比中文长，
            // 超出时缩字而不是截断，其它语言也不会顶破这一列
            lbl.adjustsFontSizeToFitWidth = true
            lbl.minimumScaleFactor = 0.7
            lbl.text = L("红包个数")
            return lbl
        }()
        twoPart.addSubview(bagNumberLbl)
        twoPart.addSubview(bagNumberTF)
        
        let countLbl: UILabel = {
            let lbl = UILabel()
            lbl.textColor = RP.goldDeep
            lbl.font = UIFont.regularFont(13)
            lbl.text = L("个")
            return lbl
        }()
        twoPart.addSubview(countLbl)
        // 所有模式都显示个数输入栏；专属红包的份数固定为领取人数（只读）
        twoPart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.top.equalTo(balancePill.snp.bottom).offset(8)
            m.height.equalTo(56)
        }
        bagNumberLbl.snp.makeConstraints { (make) in
            // 与「总数额 / 领取人 / 红包类型 / 币种 / 祝福语」同一套：标签从 15 起、固定 66pt 列
            //（原来这里是 10，值又从 80 起 ⇒ 和金额行对不齐，看着像另一套排布）
            make.leading.equalToSuperview().offset(15)
            make.width.equalTo(66)
            make.centerY.equalToSuperview()
        }
        bagNumberTF.snp.makeConstraints { (m) in
            // 15(边距) + 66(标签列) + 12(间距) = 93，与金额行的 `bagMoneyTF` 完全一致
            m.leading.equalToSuperview().offset(93)
            m.height.equalTo(30)
            m.centerY.equalToSuperview()
            // ⚠️ 值的右边界**挂在「个」单位标签左边**（不再写死 -57 常量）。
            // 常量 57 = 31(值右边界) + 16(中文「个」宽) + 10(间距)，是**按中文宽度**算的；
            // 切成英文后单位文案变宽（「 pcs」≈32pt）⇒ 输入框右边界仍然停在 -57，
            // 数字就压到单位标签上（现象：数量和「个」的翻译叠在一起）。
            m.trailing.equalTo(countLbl.snp.leading).offset(-10)
        }
        // 「个」单位标签：**先把右边界钉死**（-31，与带箭头行 / bty 的值右边界对齐），
        // 宽度取内容自适应（hug + compression 都 required ⇒ 宽度 = 固有宽度，位置唯一、无歧义约束）。
        // 这样整条链是「单位.right 固定 → 单位宽度 → 输入框.trailing」，任何语言文案都能正确让位。
        countLbl.setContentHuggingPriority(.required, for: .horizontal)
        countLbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        countLbl.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-31)
            make.width.lessThanOrEqualTo(80)
        }
        let bgRemark: UIView = {
            let v = UIView()
            v.makeRPCard()
            return v
        }()
        bgView.addSubview(bgRemark)
        // 「红包 / 文字红包」切换按钮：从 self.view 挪进卡片内
        // （原来挂在 self.view 上、centerY 绑 bgRemark.top，跨父视图且会压住新的圆角）
        bgRemark.addSubview(changeTypeView)
        // 设置图片和手势识别器（从懒加载移到此处）
        changeTypeView.image = self.isTextRedBag ? UIImage(named:"redBag_msgType") : UIImage(named:"redBag_bagType")
        let changeTypeTap = UITapGestureRecognizer(target: self, action: #selector(changeRedBagType))
        changeTypeView.addGestureRecognizer(changeTypeTap)

        bgRemark.addSubview(remarkTitleLab)
        bgRemark.addSubview(bagRemark)
        bgRemark.addSubview(remarkCountLab)
        bgRemark.snp.makeConstraints { (make) in
            // 所有模式都显示红包个数输入栏，所以都跟在 twoPart 后面
            make.top.equalTo(twoPart.snp.bottom).offset(16)
            make.height.equalTo(76)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
            // 备注卡是滚动内容的最后一块（按钮已挑到页面底部固定），给它一个底边距收尾
            make.bottom.equalToSuperview().offset(-24)
        }
        changeTypeView.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalToSuperview().offset(14)
            m.size.equalTo(CGSize.init(width: 60, height: 30))
        }
        // 「灰标题 + 内容」：与币种 / 红包类型行同节奏，不再套灰底盒子
        remarkTitleLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalTo(changeTypeView)
        }
        bagRemark.snp.makeConstraints { (make) in
            make.leading.equalTo(remarkTitleLab.snp.trailing).offset(12)
            // 右边给「红包/文字红包」切换按钮（60 宽）留出 10 的间距
            make.trailing.equalTo(changeTypeView.snp.leading).offset(-10)
            make.height.equalTo(30)
            make.centerY.equalTo(changeTypeView)
        }
        // 计数跟随输入域的右边，而不是贴着卡片右边界（否则看着和输入域无关）
        remarkCountLab.snp.makeConstraints { (m) in
            m.bottom.equalToSuperview().offset(-5)
            m.right.equalTo(bagRemark)
        }
        
        // 「塞币进红包」固定在页面底部（不再随内容滚动），键盘弹起时跟着上移
        let threePart = UIView()
        self.view.addSubview(threePart)
        threePart.addSubview(sendBtn)
        threePart.snp.makeConstraints { (m) in
            m.leading.equalToSuperview().offset(15)
            m.trailing.equalToSuperview().offset(-15)
            m.height.equalTo(52)
            // 底部约束留着被键盘驱动（见 updateSendBtnBottom）
            sendBtnBottomConstraint = m.bottom.equalToSuperview().offset(-10).constraint
        }
        sendBtn.snp.makeConstraints { (m) in
            m.leading.trailing.equalToSuperview()
            m.height.equalTo(52)
            m.top.equalToSuperview()
        }
        // 滚区底边挂在按钮顶部 ⇒ 键盘弹起时可视区自动缩短，内容不会钻到按钮下面
        scrollView.snp.makeConstraints { (m) in
            m.bottom.equalTo(threePart.snp.top)
        }
        updateSendBtnBottom()

        // 占位文案 / 左侧标题（默认非文字红包模式）
        applyRemarkModeAppearance()
        applyPacketType(isRandom: true)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func dismissKeyboard() {
        self.bagMoneyTF.resignFirstResponder()
        self.bagNumberTF.resignFirstResponder()
        self.bagRemark.resignFirstResponder()
    }
    
    /// 底部弹框选择红包类型（拼手气 / 普通），业务校验逻辑仍走原 isRandom、packetType 分支
    @objc private func showPacketTypePicker() {
        let sheet = UIAlertController(title: L("选择红包类型"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L("拼手气红包"), style: .default) { [weak self] _ in
            self?.applyPacketType(isRandom: true)
        })
        sheet.addAction(UIAlertAction(title: L("普通红包"), style: .default) { [weak self] _ in
            self?.applyPacketType(isRandom: false)
        })
        sheet.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = packetTypeSelectRow
            pop.sourceRect = packetTypeSelectRow.bounds
        }
        present(sheet, animated: true)
    }
    
    private func applyPacketType(isRandom: Bool) {
        self.isRandom = isRandom
        packetType = isRandom ? .luck : .common
        packetTypeValueLabel.text = isRandom ? L("拼手气红包") : L("普通红包")
        amountModeTitleLbl?.text = isRandom ? L("总数额") : (isGroup ? L("单个数额") : L("单个金额"))
        applyExclusiveCountIfNeeded()
        setTotalCount()
        updateSendButtonTitle()
    }

    /// 专属红包：份数固定为领取人数且只读（份数必须与白名单人数一致，否则会有人领不到）
    private func applyExclusiveCountIfNeeded() {
        guard isExclusive else { return }
        self.bagNumberTF.text = "\(self.exclusiveMemberCount)"
        self.bagNumberTF.isEnabled = false
        self.bagNumberTF.isUserInteractionEnabled = false
    }

    /// 点击「领取人」行：弹出当前全部领取人（名字 + 短地址）
    @objc private func showReceiverListSheet() {
        guard isExclusive, !exclusiveAddresses.isEmpty else { return }
        let sheet = FZMRedPacketReceiverSheet(
            names: exclusiveNames, addresses: exclusiveAddresses,
            chatAddresses: exclusiveChatAddresses)
        sheet.show(in: self.view)
    }
    
}

extension FZMCreateLuckyBagVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == self.coinViewGroup
    }
}

// MARK: - 领取人查看弹层
/// 专属红包「领取人」弹层：列出当前全部领取人（名字 + 短地址），点击背景或「关闭」收起
private final class FZMRedPacketReceiverSheet: UIView, UITableViewDataSource, UITableViewDelegate {

    private let names: [String]
    private let addresses: [String]
    /// 与 `addresses` 同下标的**会话地址**（优先展示，链上 0x 地址只做回落）
    private let chatAddresses: [String]

    /// 卡片视图（用于判断背景点击是否落在卡片内）
    private weak var cardView: UIView?

    private static let rowHeight: CGFloat = 52
    private static let titleHeight: CGFloat = 60
    private static let closeButtonHeight: CGFloat = 52

    init(names: [String], addresses: [String], chatAddresses: [String] = []) {
        self.names = names
        self.addresses = addresses
        self.chatAddresses = chatAddresses
        super.init(frame: UIScreen.main.bounds)
        self.backgroundColor = UIColor(white: 0, alpha: 0.45)
        self.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:))))
        self.setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let count = self.addresses.count
        let listHeight = min(
            CGFloat(count) * FZMRedPacketReceiverSheet.rowHeight, k_ScreenHeight * 0.5)

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.clipsToBounds = true
        self.addSubview(card)
        self.cardView = card
        card.snp.makeConstraints { m in
            m.center.equalToSuperview()
            m.width.equalTo(k_ScreenWidth - 64)
            m.height.equalTo(
                FZMRedPacketReceiverSheet.titleHeight + listHeight
                    + FZMRedPacketReceiverSheet.closeButtonHeight)
        }

        let title = UILabel.getLab(
            font: UIFont.mediumFont(16), textColor: RP.ink, textAlignment: .center,
            text: L("领取人") + "(\(count))")
        card.addSubview(title)
        title.snp.makeConstraints { m in
            m.top.left.right.equalToSuperview()
            m.height.equalTo(FZMRedPacketReceiverSheet.titleHeight)
        }

        let separator = UIView()
        separator.backgroundColor = RP.creamLine
        card.addSubview(separator)
        separator.snp.makeConstraints { m in
            m.top.equalTo(title.snp.bottom)
            m.left.right.equalToSuperview()
            m.height.equalTo(1)
        }

        let closeBtn = UIButton(type: .custom)
        closeBtn.setTitle(L("关闭"), for: .normal)
        closeBtn.setTitleColor(RP.ink, for: .normal)
        closeBtn.titleLabel?.font = UIFont.regularFont(17)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        card.addSubview(closeBtn)
        closeBtn.snp.makeConstraints { m in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(FZMRedPacketReceiverSheet.closeButtonHeight)
        }

        let topSeparator = UIView()
        topSeparator.backgroundColor = RP.creamLine
        card.addSubview(topSeparator)
        topSeparator.snp.makeConstraints { m in
            m.bottom.equalTo(closeBtn.snp.top)
            m.left.right.equalToSuperview()
            m.height.equalTo(1)
        }

        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = FZMRedPacketReceiverSheet.rowHeight
        tableView.separatorColor = RP.creamLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.showsVerticalScrollIndicator = false
        card.addSubview(tableView)
        tableView.snp.makeConstraints { m in
            m.top.equalTo(separator.snp.bottom)
            m.left.right.equalToSuperview()
            m.height.equalTo(listHeight)
        }
    }

    @objc private func closeTapped() {
        self.removeFromSuperview()
    }

    /// 点背景关闭；点在卡片内不关闭
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard let card = self.cardView, !card.frame.contains(point) else { return }
        self.removeFromSuperview()
    }

    // MARK: - UITableViewDataSource / UITableViewDelegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.addresses.count
    }

    /// 单行：左边名字，右边短地址
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "FZMRedPacketReceiverCell"
        let cell =
            tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .value1, reuseIdentifier: identifier)
        cell.selectionStyle = .none
        let name = indexPath.row < names.count ? names[indexPath.row] : ""
        // 展示**会话地址**（`1…`）优先；拿不到再回落到链上 0x 地址
        let chatAddress = indexPath.row < chatAddresses.count ? chatAddresses[indexPath.row] : ""
        let chainAddress = indexPath.row < addresses.count ? addresses[indexPath.row] : ""
        let address = (chatAddress.isEmpty ? chainAddress : chatAddress).shortAddress
        cell.textLabel?.font = UIFont.regularFont(16)
        cell.textLabel?.textColor = RP.ink
        cell.textLabel?.text = name.isEmpty ? address : name
        cell.detailTextLabel?.font = UIFont.regularFont(13)
        cell.detailTextLabel?.textColor = RP.inkSoft
        cell.detailTextLabel?.text = address
        return cell
    }

    func show(in view: UIView) {
        self.alpha = 0
        view.addSubview(self)
        self.snp.makeConstraints { m in
            m.edges.equalToSuperview()
        }
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }
}
