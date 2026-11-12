//
//  SessionVC.swift
//  chat
//
//  Created by fzm on 2021/1/4.
//

import UIKit
import SnapKit
import MapKit
import RxSwift
import GKNavigationBarSwift

class SessionVC: UIViewController, ViewControllerProtocol, UIScrollViewDelegate, FZMTabBarReselectHandler {
    
    private var showView : FZMScrollPageView?
    private let bag = DisposeBag.init()
    
    lazy var downQRcodeView : SessionListDownQRCodeView = {
        let view = SessionListDownQRCodeView()
        view.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight - k_TabBarHeight)
        return view
    }()
    
    lazy var privateHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: L("私聊"))
        return view
    }()
    
    lazy var groupHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: L("群聊"))
        return view
    }()
    
    /// 第一段：广场（默认选中）
    lazy var squareHeader : ChatHeadSegment = {
        let view = ChatHeadSegment(with: L("广场"))
        view.show(true)
        return view
    }()
    
    /// 每段宽度（三段：广场 / 私聊 / 群聊）
    /// 自适应：窄屏（如 320pt）下缩短，避免与右上角按钮区重叠（重叠区域内的点击会被右上角视图吞掉）
    /// 上限 76（原 70）：非中文标题明显更长（日语 グループ / チャット），70pt 会把文字截断；
    /// 这里贴着可用宽度放宽一点，≤375pt 的窄屏仍走下面的自适应值，不会压到右上角按钮区。
    static var segmentWidth: CGFloat {
        return min(76, (k_ScreenWidth - 15 - 123) / 3)
    }
    /// 广场红点静默查询节流
    private var lastSquareUnreadCheckTime = 0
    /// 是否正在执行点击切换（动画期间的中间态回调需要忽略）
    private var isSelectingSegment = false
    /// 点击切换的目标分段
    private var pendingSegmentIndex = 0
    /// 是否已把分页容器挪到「上次停留的分段」（建视图时 bounds 可能还是 0，首帧布局后再补一次）
    private var didRestoreSegmentScroll = false
    /// 恢复完成前不写盘：首帧布局期间的中间态回调会把上次选的分段覆盖成「广场」
    private var isRestoringSegment = true
    /// 本次启动要恢复到的分段
    private var restoredSegmentIndex = 0

    /// 分段（0 广场 / 1 私聊 / 2 群聊）按账号持久化：
    /// 用户点了哪一段，杀进程重进 App 后要停在同一段，而不是每次都回到「广场」。
    private static var savedSegmentKey: String {
        let address = LoginUser.shared().address.lowercased()
        return address.isEmpty ? "kSessionVCSelectedSegment" : "kSessionVCSelectedSegment_\(address)"
    }

    /// 上次停留的分段（越界/未写过一律当 0，即「广场」）
    private var savedSegmentIndex: Int {
        get { min(max(UserDefaults.standard.integer(forKey: SessionVC.savedSegmentKey), 0), 2) }
        set { UserDefaults.standard.set(newValue, forKey: SessionVC.savedSegmentKey) }
    }
        
    lazy var chatView:FZMPrivateChatListView = {
      let view = FZMPrivateChatListView(with: L("好友消息"))
        return view
    }()
    
    lazy var groupView:FZMGroupChatListView = {
        let view = FZMGroupChatListView(with: L("群聊消息"))
        return view
    }()
    
    lazy var squareView:SquareFeedPageView = {
        let view = SquareFeedPageView(with: L("广场"))
        return view
    }()
    
    lazy var selectBackView : UIView = {
        let view = UIView()
        view.backgroundColor = Color_Auxiliary
        view.layer.cornerRadius = 17.5
        view.clipsToBounds = true
        return view
    }()
    
    
    private lazy var activityIndicatorView: FZMActivityIndicatorView = {
        let v = FZMActivityIndicatorView.init(frame: CGRect.zero, title: L("收取中..."))
        v.isHidden = true
        v.backgroundColor = Color_FAFBFC
        return v
    }()
    
    lazy var navigationHeaderView : UIView = {
        let view = UIView()
        view.backgroundColor = .white
        // 不要在这里给自身加 size 约束：外部会用 segmentWidth * 3 再约束一次，两个必选约束冲突会导致实际宽度不确定（广场那一段可能落在父视图 bounds 之外而点不到）
        view.addSubview(selectBackView)
        selectBackView.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(0)
            m.centerY.equalToSuperview()
            m.height.equalTo(35)
            m.width.equalTo(SessionVC.segmentWidth)
        })
        view.addSubview(privateHeader)
        privateHeader.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(SessionVC.segmentWidth)
            m.centerY.equalToSuperview()
            m.height.equalTo(35)
            m.width.equalTo(SessionVC.segmentWidth)
        })
        view.addSubview(groupHeader)
        groupHeader.snp.makeConstraints({ (m) in
            m.left.equalToSuperview().offset(SessionVC.segmentWidth * 2)
            m.centerY.equalToSuperview()
            m.height.equalTo(35)
            m.width.equalTo(SessionVC.segmentWidth)
        })
        view.addSubview(squareHeader)
        squareHeader.snp.makeConstraints({ (m) in
            m.left.equalToSuperview()
            m.centerY.equalToSuperview()
            m.height.equalTo(35)
            m.width.equalTo(SessionVC.segmentWidth)
        })
        
        
        view.addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints({ (m) in
            m.edges.equalToSuperview().inset(UIEdgeInsets.init(top: 0, left: -10, bottom: 0, right: -10))
        })
        return view
    }()
    
    private lazy var navBarView: UIView = {
        let navView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_StatusNavigationBarHeight))
        navView.backgroundColor = .white
        
        navView.addSubview(self.navigationHeaderView)
        navigationHeaderView.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.bottom.equalToSuperview()
            m.size.equalTo(CGSize.init(width: SessionVC.segmentWidth * 3, height: 44))
        }
        
        let rightView = CustomBarView.init()
        navView.addSubview(rightView)
        rightView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview()
            make.size.equalTo(CGSize.init(width: 108, height: 44))
        }

        return navView
    }()
    
    private lazy var mainView: UIView = {
        let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight - k_TabBarHeight))
        v.backgroundColor = .white
        v.layer.cornerRadius = 0
        v.layer.masksToBounds = true
        return v
    }()

    // ⚠️ AI 客服悬浮球已改挂到 `FZMTabBarController` 上（用户 2026-09-30：放在 TabBar 上，
    // 切 Tab 不消失、push 进二级页面才隐藏）⇒ 显隐与重排都在那边，本页不再管理
    
    var privateUnreadCount = 0 {
        didSet {
            privateHeader.setBadge(privateUnreadCount)
        }
    }
    var groupUnreadCount = 0 {
        didSet{
            groupHeader.setBadge(groupUnreadCount)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setNavBackgroundColor()
        checkSquareUnreadIfNeeded()
        // 收件箱红点：每次进消息页都查一次（内部有 60s 节流；不依赖广场页的 didAppear）
        squareView.refreshInboxBadge()
        // AI 客服悬浮球已挂到 TabBar 控制器上，显隐由它自己按「Tab 根页面 / 二级页面」判断
    }
    
    /// 广场红点：进入消息页时隔 60s 静默查一次最新帖 id（无未读接口，用本地记录比较）
    private func checkSquareUnreadIfNeeded() {
        guard LoginUser.shared().isLogin else {
            self.squareHeader.setDot(false)
            return
        }
        let now = Date.timestamp
        guard now - lastSquareUnreadCheckTime > 60 * 1000 else { return }
        lastSquareUnreadCheckTime = now
        self.squareView.checkUnread()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.hideRQCodeView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 首帧布局完成后，把分页容器挪到上次停留的分段（`setupViews` 里那次 bounds 可能还是 0）
        guard !didRestoreSegmentScroll else { return }
        didRestoreSegmentScroll = true
        showView?.select(with: restoredSegmentIndex, animated: false)
        isRestoringSegment = false
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            naba.buttonAppearance.normal.backgroundImage = UIImage()
            naba.buttonAppearance.highlighted.backgroundImage = UIImage()
            naba.doneButtonAppearance.normal.backgroundImage = UIImage()
            naba.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backButtonAppearance.normal.backgroundImage = UIImage()
            naba.backButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backgroundColor = .white
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupViews()
        self.setRX()
        
        FZM_NotificationCenter.addObserver(self,selector: #selector(handleShowQRCodeViewNofi),name: FZM_Notify_ShowQRCodeView,object: nil)
        FZM_NotificationCenter.addObserver(self, selector: #selector(updateLan), name: LanguageManager.LanguageChangedNotification, object: nil)

        // 首屏（广场）稳定后，预热「私聊」列表的可见 cell：
        // 分页容器里离屏的分段不会创建 cell，等用户点「私聊」切过去那一瞬间才现场建 ⇒ 就是那一下卡顿。
        // 这里把这一下开销提前到用户操作之前（详见 `SessionListView.prewarmVisibleCells()`）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.chatView.prewarmVisibleCells()
        }
    }
    
    @objc func updateLan(){
        privateHeader.text = L("私聊")
        groupHeader.text = L("群聊")
        squareHeader.text = L("广场")
        // ⚠️ `ChatHeadSegment` 的**字号也跟着语言走**（中文 17/14、英文 14/12，见 `show(_:)`），
        // 只改 text 字号不会变（中英切换后大小会不一致）⇒ 按当前选中段再走一遍 `show(_:)`。
        // 这里**不能**调 `applySegmentUI`：它带 `enterPage/leavePage` 副作用
        let segment = isSelectingSegment ? pendingSegmentIndex : (showView?.currentIndex ?? 0)
        squareHeader.show(segment == 0)
        privateHeader.show(segment == 1)
        groupHeader.show(segment == 2)
       
       
        
        
        self.chatView.noDataView.desLab.text = L("暂无好友消息")
        self.chatView.noDataView.bottomBtn.setAttributedTitle(NSAttributedString(string: L("开启聊天"), attributes: [.font:UIFont.regularFont(16),.foregroundColor:Color_Theme]), for: .normal)
        self.groupView.noDataView.desLab.text = L("暂无群消息")
        self.groupView.noDataView.bottomBtn.setAttributedTitle(NSAttributedString(string: L("开启群聊"), attributes: [.font:UIFont.regularFont(16),.foregroundColor:Color_Theme]), for: .normal)
        
        // 列表里每一行的文案（会话预览、时间、尤其是「小Y」AI 客服入口行的名字/副标题）
        // 都是 cell 配置时取的 L()，不重新配置就会一直停在旧语言 ⇒ 切语言后整表刷一次
        self.chatView.reloadCollectionView()
        self.groupView.reloadCollectionView()
    }
    
    private func setupViews() {
        self.xls_isNavigationBarHidden = true
        self.xls_navigationBarTintColor = Color_F6F7F8
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
        
        self.view.addSubview(self.downQRcodeView)
        
        self.view.addSubview(self.mainView)
        
        self.mainView.addSubview(self.navBarView)
        
        let block : (Session)->() = { session in
            FZMUIMediator.shared().pushVC(.goChatVC(sessionID: session.id))
        }
//        let view1 = FZMPrivateChatListView(with: L("好友消息"))
//        view1.selectBlock = block
        self.chatView.selectBlock = block
//        let view2 = FZMGroupChatListView(with: L("群聊消息"))
//        view2.selectBlock = block
        self.groupView.selectBlock = block
        
        let param = FZMSegementParam()
        param.headerHeight = 0
        
        let height = k_ScreenHeight - k_TabBarHeight - k_StatusNavigationBarHeight
        let view = FZMScrollPageView(frame: CGRect(x: 0, y: k_StatusNavigationBarHeight, width: k_ScreenWidth, height: height), dataViews: [self.squareView, self.chatView, self.groupView], param: param)
        self.showView = view
        view.selectBlock = {[weak self] index in
            guard let strongSelf = self else { return }
            // 点击切换时，滚动动画会产生中间态回调，忽略掉避免选中态来回跳
            if strongSelf.isSelectingSegment, index != strongSelf.pendingSegmentIndex {
                return
            }
            strongSelf.applySegmentUI(index)
        }
        self.mainView.addSubview(view)
        view.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(k_StatusNavigationBarHeight)
            m.left.right.bottom.equalToSuperview()
        }
        
        // 统一挂在头部容器上，按点击位置换算分段：
        // 不依赖各 label 自身命中区域（label 若因约束问题落到父视图 bounds 之外会完全收不到点击）
        let segmentTap = UITapGestureRecognizer()
        segmentTap.rx.event.subscribe {[weak self] (event) in
            guard let strongSelf = self, let tap = event.element else { return }
            let x = tap.location(in: strongSelf.navigationHeaderView).x
            let index = min(max(Int(x / SessionVC.segmentWidth), 0), 2)
            strongSelf.selectSegment(index)
        }.disposed(by: bag)
        navigationHeaderView.addGestureRecognizer(segmentTap)
//        self.downQRcodeView.isHidden = true

        // 恢复上次停留的分段（0 广场 / 1 私聊 / 2 群聊），没记录过就还是「广场」
        let restoredSegment = savedSegmentIndex
        restoredSegmentIndex = restoredSegment
        pendingSegmentIndex = restoredSegment
        applySegmentUI(restoredSegment)
        // 分页容器这里先挪一次；首帧布局后 `viewDidLayoutSubviews` 会再补一次（此时 bounds 可能还是 0）
        view.select(with: restoredSegment, animated: false)
        view.currentIndex = restoredSegment

        // AI 客服悬浮球：已经改挂到 `FZMTabBarController` 上（见那边的 `updateFloatingAIVisibility()`）
    }
    
    // MARK: - 分段切换

    /// 点击分段：选中态与页面回调立即生效，页面滑动切换
    private func selectSegment(_ index: Int) {
        pendingSegmentIndex = index
        isSelectingSegment = true
        applySegmentUI(index)
        // 保持带动画切换：实测非动画 setContentOffset 不会真正切页（点击无反应）
        self.showView?.select(with: index, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.isSelectingSegment = false
        }
    }

    /// 同步分段选中态 + 广场页的进入/离开回调（顺序：0 广场 / 1 私聊 / 2 群聊）
    private func applySegmentUI(_ index: Int) {
        // 记住用户停在的那一段：杀进程重进 App 后要回到这里（恢复过程中不写，避免被中间态覆盖）
        if !isRestoringSegment {
            savedSegmentIndex = index
        }
        squareHeader.show(index == 0)
        privateHeader.show(index == 1)
        groupHeader.show(index == 2)
        selectBackView.snp.updateConstraints({ (m) in
            m.left.equalToSuperview().offset(SessionVC.segmentWidth * CGFloat(index))
        })
        if index == 0 {
            squareView.enterPage()
        } else {
            squareView.leavePage()
        }
    }

    // MARK: - 再次点击「消息」Tab

    /// 再次点击已选中的「消息」Tab：当前这一段列表回到顶部（广场帖子 / 私聊 / 群聊）。
    /// 由 `FZMTabBarController` 的 `UITabBarControllerDelegate` 调用（只在 Tab 根页面时回调）。
    func tabBarDidReselect() {
        // 点击切换分段时 currentIndex 会滞后，这里优先用点击时的目标分段
        let index = isSelectingSegment ? pendingSegmentIndex : (showView?.currentIndex ?? 0)
        switch index {
        case 0:
            squareView.scrollToTop()
        case 1:
            chatView.scrollToTop()
        default:
            groupView.scrollToTop()
        }
    }
    
    private func setRX() {
        // 私聊未读数订阅
        SessionManager.shared().privateUnReadCountSubject.subscribe(onNext: { [weak self] (unreadCount) in
            guard let self = self else { return }
            // 设置私聊未读数
            FZMLog("私聊未读数--------  \(unreadCount)")
            self.privateUnreadCount = unreadCount
        }).disposed(by: self.bag)
        
        // 群聊未读数订阅
        SessionManager.shared().groupUnReadCountSubject.subscribe(onNext: { [weak self] (unreadCount) in
            guard let self = self else { return }
            // 设置群聊未读数
            FZMLog("群聊未读数--------  \(unreadCount)")
            self.groupUnreadCount = unreadCount
        }).disposed(by: self.bag)
        
        // 底部显示未读总数
        Observable.combineLatest(SessionManager.shared().privateUnReadCountSubject, SessionManager.shared().groupUnReadCountSubject).subscribe { (event) in
            guard case .next((let groupUnreadCount, let privateUnreadCount)) = event else { return }
            let count = groupUnreadCount + privateUnreadCount
            FZMUIMediator.shared().setTabbarBadge(with: 0, count: count)
        }.disposed(by: bag)
        
        // 广场红点（有新帖时显示在「广场」文字上）
        self.squareView.onUnreadChanged = { [weak self] hasUnread in
            self?.squareHeader.setDot(hasUnread)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: view) else { return }
        let p = self.mainView.layer.convert(point, from: view.layer)
        if self.mainView.layer.contains(p) {
            self.hideRQCodeView()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension SessionVC {
    @objc private func handleShowQRCodeViewNofi(_ showFlgNofi: Notification) {
        let showFlg = showFlgNofi.object as? Bool ?? false
        
        if showFlg {
            UIView .animate(withDuration: 0.4) {
                self.mainView.layer.cornerRadius = 30
                self.mainView.frame = CGRect(x: 0, y: 420, width: k_ScreenWidth, height: self.mainView.frame.height)
                
            } completion: { Bool  in
//                self.downQRcodeView.isHidden = false
                APP.shared().hasShowQRCodeViewFlg = true
            }
        } else {
            self.hideRQCodeView()
        }
    }
    
    //展示下拉二维码
    private func showQRCodeView(_ data : Notification) {
        APP.shared().hasShowQRCodeViewFlg = true
        let offsetY = data.object as? CGFloat ?? 0
        if offsetY < -30 {
            UIView .animate(withDuration: 0.4) {
                self.mainView.layer.cornerRadius = 30
                self.mainView.frame = CGRect(x: 0, y: 420, width: k_ScreenWidth, height: self.mainView.frame.height)
                
            } completion: { Bool  in
//                self.downQRcodeView.isHidden = false
            }
        }
    }
    
    //点击收起下拉二维码
    private func hideRQCodeView() {
        UIView .animate(withDuration: 0.4) {
            self.mainView.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: self.mainView.frame.height)
            self.mainView.layer.cornerRadius = 0
        } completion: { Bool  in
//            self.downQRcodeView.isHidden = true
            APP.shared().hasShowQRCodeViewFlg = false
        }
    }
}

