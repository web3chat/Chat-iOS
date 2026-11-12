//
//  SessionListView.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/5.
//

import Foundation
import SnapKit
import RxSwift
import UIKit
import SwifterSwift

enum SessionListType: Int {
    case privateSession = 1
    case groupSession = 2
}

let headerIdentifier = "CollectionReusableViewHeader"
 
class CollectionReusableViewHeader: UICollectionReusableView {
    
    let disposeBag = DisposeBag()
    
    var label:UILabel!
    
    // 顶部网络问题视图
    lazy private var topView: UIView = {
       let v = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 0))
        v.backgroundColor = .init(hexString: "#FAEEEE")!
        
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_DD5F5F, textAlignment: .center, text: L("服务器正在连接，点击查看"))// 服务器正在连接，点击查看
        v.addSubview(lab)
        lab.snp.makeConstraints { m in
            m.edges.equalToSuperview()
        }
        
        let tap = UITapGestureRecognizer.init()
        tap.rx.event.subscribe(onNext: { (_) in
            // 跳转到选择服务器页面
            FZMUIMediator.shared().pushVC(.goServer)
        }).disposed(by: disposeBag)

        v.addGestureRecognizer(tap)
        
        return v
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(self.topView)
        topView.snp.makeConstraints { m in
            m.edges.equalToSuperview()
        }
    }
 
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SessionListView: FZMScrollPageItemBaseView {

    let disposeBag = DisposeBag()
    var sessionArr = [Session]()
    var selectBlock: ((Session)->())?
    
    var dataSource = [Session]()// 会话数据源
    
    /// 好友状态变化数据源（只包含置顶/免打扰）。
    /// 赋值时会重建 `privateFlags` / `privateTopAddresses` 两个索引
    var privateSource = [User]() {
        didSet { rebuildPrivateIndex() }
    }
    
    /// 群聊状态变化数据源（只包含置顶/免打扰）
    var groupSource = [Group]() {
        didSet { rebuildGroupIndex() }
    }
    
    // MARK: - 置顶 / 免打扰索引
    //
    // 原来 `cellForItemAt` 每个 cell 都要 `privateSource.filter{ $0.address == session.id.idValue }.first`：
    // 每次都新建数组、O(好友数)，一屏十几行就是十几次全量扫描；好友多时每次 reload 都明显耗主线程。
    // 这里在赋值时一次性建「地址 → 置顶/免打扰」字典，cell 与排序都改成 O(1) 查。
    private var privateFlags = [String: (isOnTop: Bool, isMute: Bool)]()
    /// 置顶好友地址（排置顶会话用，只含置顶项）
    private var privateTopAddresses = [String]()
    private var groupFlags = [String: (isOnTop: Bool, isMute: Bool)]()
    private var groupTopAddresses = [String]()
    
    private func rebuildPrivateIndex() {
        var flags = [String: (isOnTop: Bool, isMute: Bool)](minimumCapacity: privateSource.count)
        var tops = [String]()
        for user in privateSource {
            flags[user.address] = (user.isOnTop, user.isMuteNotification)
            if user.isOnTop { tops.append(user.address) }
        }
        privateFlags = flags
        privateTopAddresses = tops
    }
    
    private func rebuildGroupIndex() {
        var flags = [String: (isOnTop: Bool, isMute: Bool)](minimumCapacity: groupSource.count)
        var tops = [String]()
        for group in groupSource {
            flags[group.address] = (group.isOnTop, group.isMuteNotification)
            if group.isOnTop { tops.append(group.address) }
        }
        groupFlags = flags
        groupTopAddresses = tops
    }
    
    /// 新的「置顶 / 免打扰」好友集合与当前是否完全一致（顺序无关）。
    /// 好友增删、改昵称/头像都会触发 `allusersSubject`，但绝大多数与列表排序、置顶样式无关 ⇒ 一致就不重排不刷新。
    func isPrivateSourceUnchanged(_ users: [User]) -> Bool {
        guard users.count == privateFlags.count else { return false }
        for user in users {
            guard let flag = privateFlags[user.address],
                  flag.isOnTop == user.isOnTop,
                  flag.isMute == user.isMuteNotification else { return false }
        }
        return true
    }
    
    func isGroupSourceUnchanged(_ groups: [Group]) -> Bool {
        guard groups.count == groupFlags.count else { return false }
        for group in groups {
            guard let flag = groupFlags[group.address],
                  flag.isOnTop == group.isOnTop,
                  flag.isMute == group.isMuteNotification else { return false }
        }
        return true
    }
    
    var sessionType: SessionListType = .privateSession// 聊天类型（私聊、群聊）
    
    let topViewHeight: CGFloat = 50// 顶部网络提示视图高度

    /// 列表里**虚拟行**的数量（默认 0）。
    ///
    /// 私聊列表用它放一行「小Y」（AI 客服）入口：这一行不是真实会话 —— 客服是 H5 页面，
    /// 本地既没有聊天记录也没有真实用户/群信息，所以**不写库、不进 `SessionManager` 数据源**，
    /// 只存在于列表渲染层（不参与未读统计，也不会被删除聊天误删）。
    var virtualRowCount: Int { return 0 }

    /// 虚拟行落在列表的第几行（默认最前面）。
    /// `FZMPrivateChatListView` 按「小Y」的置顶状态返回 0（置顶）或末尾（取消置顶）。
    var virtualRowIndex: Int { return 0 }

    /// 点击虚拟行（子类覆写）
    func didSelectVirtualRow(at index: Int) {}

    /// 某一行是不是虚拟行
    func isVirtualRow(_ row: Int) -> Bool {
        return virtualRowCount > 0 && row == virtualRowIndex
    }

    /// 把 collectionView 的行号换算成 `dataSource` 下标（虚拟行 / 越界都返回 nil）
    func dataSourceIndex(forRow row: Int) -> Int? {
        guard virtualRowCount > 0 else {
            return (row >= 0 && row < dataSource.count) ? row : nil
        }
        guard !isVirtualRow(row) else { return nil }
        let index = row > virtualRowIndex ? row - 1 : row
        return (index >= 0 && index < dataSource.count) ? index : nil
    }
    
    lazy var collectionView: SessionColletionView = {
        let v = SessionColletionView.init()
        v.register(cellWithClass: SessionCollectionViewCell.self)
        v.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: CollectionReusableViewHeader.self)
        v.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: SessionCollectionReusableView.self)
        v.delegate = self
        v.dataSource = self
        
        return v
    }()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(with pageTitle: String) {
        super.init(with: pageTitle)
        self.addSubview(collectionView)
        collectionView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        self.setRX()
    }

    /// 列表回到顶部（再次点击「消息」Tab 时调用）；已经在顶部就不动，避免多余动画
    func scrollToTop() {
        let top = CGPoint(x: 0, y: -collectionView.adjustedContentInset.top)
        guard collectionView.contentOffset.y > top.y + 1 else { return }
        collectionView.setContentOffset(top, animated: true)
    }
    
//    // 网络连接状态变化时设置顶部视图高度 50/0
//    private func setCollectionVewiHeaderViewHeight() {
//
//    }
    
    func setRX(){
    }
    
    // 会话列表排序（置顶优先，其余按最新消息时间倒序）
    func sortSessions() {
        // 先整体按时间倒序（与原来一致：置顶部分在此基础上再排一次，时间相同的相对顺序也更稳定）
        self.dataSource = self.dataSource.sorted { $0.timestamp > $1.timestamp }
        
        let topAddresses = self.sessionType == .privateSession ? self.privateTopAddresses : self.groupTopAddresses
        
        guard !topAddresses.isEmpty, !self.dataSource.isEmpty else {
            self.reloadCollectionView()
            return
        }
        
        // ⚠️ 原来是「每个置顶好友 × 全量会话 filter」= O(好友 × 会话)，好友一多就是几十万次比较。
        // 现在用置顶地址集合一趟分组（置顶里/置顶外各排一次序）。
        let pinned = Set(topAddresses)
        var topSessions = [Session]()
        var normalSessions = [Session]()
        normalSessions.reserveCapacity(self.dataSource.count)
        for session in self.dataSource {
            if pinned.contains(session.id.idValue) {
                topSessions.append(session)
            } else {
                normalSessions.append(session)
            }
        }
        
        self.dataSource = topSessions.sorted { $0.timestamp > $1.timestamp } + normalSessions.sorted { $0.timestamp > $1.timestamp }
        
        self.reloadCollectionView()
    }
    
    // 获取显示置顶和免打扰样式flg（O(1) 字典查，不要再全量 filter）
    func filterFriends(session: Session) -> (Bool, Bool) {
        guard let flag = self.privateFlags[session.id.idValue] else {
            return (false, false)
        }
        return (flag.isOnTop, flag.isMute)
    }
    
    // 获取显示置顶和免打扰样式flg（O(1) 字典查）
    func filterGroups(session: Session) -> (Bool, Bool) {
        guard let flag = self.groupFlags[session.id.idValue] else {
            return (false, false)
        }
        return (flag.isOnTop, flag.isMute)
    }
    
    func reloadCollectionView() {
        // 同一轮内可能被多个数据源反复请求（好友/群列表批量加载时尤其密集）：
        // 合并成一次 reloadData，避免主线程被无意义的整表刷新挤满
        guard !reloadScheduled else { return }
        reloadScheduled = true
        DispatchQueue.main.async {
            self.reloadScheduled = false
            self.collectionView.reloadData()
        }
    }

    /// 预布局：让 collectionView 提前把可见区域的 cell 建出来。
    ///
    /// 分页容器（`FZMScrollPageView`）里的分段一直处于**离屏**状态，离屏的 collectionView 不会创建 cell；
    /// 等用户点「私聊」切过去那一瞬间才现场建 cell（头像加载 + 文本测量 + 约束更新）
    /// ⇒ 观感就是「点了卡一下才进私聊页」。首屏稳定后提前跑一次，把这一下开销移到用户操作之前。
    func prewarmVisibleCells() {
        guard self.collectionView.window != nil, self.frame.width > 0, self.frame.height > 0 else { return }
        self.collectionView.layoutIfNeeded()
        FZMLog("会话列表预热完成：\(self.dataSource.count) 条")
    }

    private var reloadScheduled = false
    
    // MARK: - 下拉展示二维码
    //
    // 原来判定是 `contentOffset.y < 0`：只要偏移越过顶部 1pt 就会立刻弹出二维码 ⇒
    // 用户反馈「还没滑到最顶部，页面就下滑出现二维码页面了」。常见触发场景：
    // ① 手指刚按住、列表还在回弹（bounce）时偏移在 0 附近反复穿越；
    // ② 快速滑动往回滑，惯性让列表越过顶部；
    // ③ 列表内容不满一屏时，一碰就进入 over-scroll。
    // ⇒ 现在要求：手指确实按在列表上拖动 + 已经到顶 + 继续下拉超过 `qrCodePullThreshold`。
    private let qrCodePullThreshold: CGFloat = 48
    /// 上一次开关二维码通知的时间（`APP.hasShowQRCodeViewFlg` 要等 0.4s 动画结束才置位，
    /// 中间态用这个时间做防抖，避免同一手势里反复 post）
    private var lastQRCodeToggleTime: TimeInterval = 0
    
    private func postQRCodeViewNotification(_ show: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastQRCodeToggleTime > 0.5 else { return }
        lastQRCodeToggleTime = now
        FZMLog("下拉二维码：\(show ? "展开" : "收起")（offset=\(collectionView.contentOffset.y)）")
        FZM_NotificationCenter.post(name: FZM_Notify_ShowQRCodeView, object: show)
        // 展开/收起过程中先禁一下滑动，避免手势和动画抢；300ms 后恢复
        self.collectionView.isScrollEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.collectionView.isScrollEnabled = true
        }
    }
}

extension SessionListView: UICollectionViewDataSource, UICollectionViewDelegate,UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let topInset = scrollView.adjustedContentInset.top
        // 「到顶之后又继续下拉的距离」：>0 表示已经越过列表顶部
        let pullDistance = -(scrollView.contentOffset.y + topInset)
        
        if !APP.shared().hasShowQRCodeViewFlg {
            // 只在**手指按住拖动**、且已到顶并继续下拉超过阈值时才展开；
            // 惯性滑动 / 松手回弹越过顶部（isTracking == false）一律不触发
            guard scrollView.isTracking, !scrollView.isDecelerating,
                  pullDistance > qrCodePullThreshold else { return }
            postQRCodeViewNotification(true)
            return
        }
        
        // 已展开：内容往上滚过顶部（说明用户在往上拉列表）就收起
        if scrollView.contentOffset.y > 0 {
            postQRCodeViewNotification(false)
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource.count + virtualRowCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SessionCollectionViewCell.self, for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 虚拟行（如私聊列表的「小Y」入口行）单独处理
        if self.isVirtualRow(indexPath.item) {
            self.didSelectVirtualRow(at: indexPath.item)
            return
        }
        guard let row = self.dataSourceIndex(forRow: indexPath.item) else { return }
        let session = self.dataSource[row]
        
        // 更新会话的最新消息
        SessionManager.shared().updateLatestInfo(session)
        
        if !session.isPrivateChat, let group = GroupManager.shared().getDBGroupInTable(groupId: session.id.idValue.intEncoded, onlyInquire: true), !group.isInGroup {
            // ⚠️ 本地 `isInGroup` 只是本地标记：切账号瞬间在途的 `getGroupInfo` 曾用另一个账号的身份
            //    拿到 10015 并把它写成 false，写脏后**重启也不会恢复**，表现就是「明明在群里却提示已不在此群聊」。
            //    这里以服务端为准：再确认一次群信息，确认在群里就顺手修正标记并进入。
            var serverUrl = group.chatServerUrl ?? ""
            if serverUrl.isEmpty { serverUrl = session.chatServerUrl }
            GroupManager.shared().getGroupInfo(serverUrl: serverUrl, groupId: group.id, successBlock: { _ in
                GroupManager.shared().updateDBGroupIsInFlg(groupId: group.id, isInGroup: true)
                FZMUIMediator.shared().pushVC(.goChatVC(sessionID: session.id))
            }, failureBlock: { error in
                if abs((error as NSError).code) == 10015 {
                    // 服务端明确表示不在群里 → 顺手清掉这条残留会话，避免它一直占着列表
                    GroupManager.shared().updateDBGroupIsInFlg(groupId: group.id, isInGroup: false)
                    SessionManager.shared().deleteSession(id: session.id)
                }
                self.showToast(L("已不在此群聊"))
            })
            return
        }
        FZMUIMediator.shared().pushVC(.goChatVC(sessionID: session.id))
    }
}

extension SessionListView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize.init(width: k_ScreenWidth, height: 70)
    }
}

//MARK:- 私聊
class FZMPrivateChatListView: SessionListView {
    
    private var hasWebsocketLostConnect = true// 当前是否有websocket未连接标识
    
    private var isFirstLoad = true
    
    lazy var noDataView : FZMNoDataView = {
        return FZMNoDataView(image: #imageLiteral(resourceName: "nodata_session_person"), imageSize: CGSize(width: 250, height: 260), desText: L("暂无好友消息"), btnTitle: L("开启聊天"), clickBlock: {
            FZMUIMediator.shared().selectConversationNav()
        })
    }()
    
    // MARK: - 「小Y」（AI 客服）入口行
    //
    // 客服是 H5 页面，本地既没有聊天记录也没有真实的用户信息，所以**不写成真实会话**，
    // 只在列表渲染层占一行：可长按置顶/取消置顶（菜单只有这一项），不参与未读统计。

    /// 登录后才展示（客服静默登录依赖登录态密钥）
    override var virtualRowCount: Int {
        return AICustomerStore.isEntryVisible ? 1 : 0
    }

    /// 置顶 → 排在列表最前面；取消置顶 → 它没有消息时间可排序，放到列表末尾
    override var virtualRowIndex: Int {
        guard virtualRowCount > 0 else { return 0 }
        return AICustomerStore.isEntryOnTop ? 0 : self.dataSource.count
    }

    override func didSelectVirtualRow(at index: Int) {
        AICustomerLauncher.push()
    }
    
    override func setRX() {
        self.sessionType = .privateSession
        
        self.collectionView.addSubview(noDataView)
        noDataView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth, height: 415))
        }
        // 网络连接状态监听
        APP.shared().hasNetworkSubject.subscribe(onNext: { [weak self] (hasNetwork) in
            guard let strongSelf = self else { return }
            // 刷新顶部视图
            strongSelf.refreshTopView()
        }).disposed(by: bag)
        
        // websocket连接状态监听
        MultipleSocketManager.shared().isAvailableSubject.subscribe {[weak self] (event) in
            guard let strongSelf = self else { return }
            // 刷新顶部视图
            strongSelf.refreshTopView()
        }.disposed(by: self.bag)
        
        // 好友状态变化订阅（置顶、免打扰）
        UserManager.shared().allusersSubject.subscribe(onNext: {[weak self] (friends) in
            guard let strongSelf = self else { return }
            let source = friends.filter { $0.isOnTop == true || $0.isMuteNotification == true }
            // 好友增删 / 改资料都会发这个通知，但绝大多数与置顶、免打扰无关 ⇒ 没变就什么都不用做
            guard !strongSelf.isPrivateSourceUnchanged(source) else { return }
            strongSelf.privateSource = source
            // 会话列表排序（置顶）
            strongSelf.sortSessions()
        }).disposed(by: bag)
        
        // 会话数据订阅
        SessionManager.shared().privateSessionsSubject.subscribe(onNext: { [weak self] (sessions) in
            guard let strongSelf = self else { return }
//            FZMLog("私聊会话数据订阅 --- \(sessions)")
            let list = sessions
            strongSelf.dataSource = list
            strongSelf.updateNoDataView()
            // 会话列表排序（置顶）
            strongSelf.sortSessions()
        }).disposed(by: self.bag)
    }

    /// 空态（「暂无好友消息」/「开启聊天」）显隐。
    ///
    /// ★ 「小Y」（AI 客服）虚拟行**也算一条内容**：它就是一个聊天对象，
    /// 所以列表里只有小Y 时也是"有会话"，不能再摆一张"暂无好友消息"的空页。
    private func updateNoDataView() {
        noDataView.isHidden = (dataSource.count + virtualRowCount) > 0
    }
    
    // 刷新顶部视图（判断是否有连接失败的服务器）
    private func refreshTopView() {
        hasWebsocketLostConnect = true
        if let alreadyAddURL = MultipleSocketManager.shared().getAllSocketConnectStatus(), alreadyAddURL.count > 0 {
            let ConnectURL = alreadyAddURL.filter({ $0.1 == true })
            if ConnectURL.count == alreadyAddURL.count {
                hasWebsocketLostConnect = false
            }
        }
        
        var delayTimeInterval: TimeInterval = 0
        
        if !hasWebsocketLostConnect {
            delayTimeInterval = 0
        } else if isFirstLoad {
            isFirstLoad = false
            delayTimeInterval = 5
        } else {
            delayTimeInterval = 2
        }
        // 避免app从后台进入前台时立即显示服务器连接失败
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTimeInterval) {
            self.reloadCollectionView()
        }
    }
    
    // 返回HeadView的宽高
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height = topViewHeight
        if !hasWebsocketLostConnect {
            height = CGFloat.leastNormalMagnitude
        }
        return CGSize(width: k_ScreenWidth, height: height)
    }
    
    // 返回自定义HeadView
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        var reusableview: UICollectionReusableView!
        if kind == UICollectionView.elementKindSectionHeader && self.sessionType == .privateSession {
            reusableview = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerIdentifier, for: indexPath) as! CollectionReusableViewHeader
            reusableview.backgroundColor = UIColor.clear
        }
        
        return reusableview
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SessionCollectionViewCell.self, for: indexPath)
        if self.isVirtualRow(indexPath.row) {
            // 「小Y」（AI 客服）入口行
            cell.configureAIEntry(name: L("小Y"),
                                  subtitle: L("7×24 小时在线，有问题随时问我"),
                                  isOnTop: AICustomerStore.isEntryOnTop)
            // 长按菜单里的「置顶 / 取消置顶」→ 存状态并刷新列表（行的位置 / 背景色都会跟着变）
            cell.onToggleAIPin = { [weak self] in
                AICustomerStore.isEntryOnTop = !AICustomerStore.isEntryOnTop
                self?.reloadCollectionView()
            }
            return cell
        }
        guard let row = self.dataSourceIndex(forRow: indexPath.row) else {
            return cell
        }
        // 获取显示置顶和免打扰样式flg
        let (isOnTop, isMuteNotification) = self.filterFriends(session: self.dataSource[row])
        cell.configure(self.dataSource[row], isMuteNotification: isMuteNotification, isOnTop: isOnTop)
        return cell
    }
}

//MARK:- 群聊
class FZMGroupChatListView: SessionListView {
    
    lazy var noDataView : FZMNoDataView = {
        return FZMNoDataView(image: #imageLiteral(resourceName: "nodata_session_group"), imageSize: CGSize(width: 250, height: 260), desText: L("暂无群消息"), btnTitle: L("开启群聊"), clickBlock: {
            FZMUIMediator.shared().selectConversationNav(showGroup: true)
        })
    }()
    
    override func setRX() {
        self.sessionType = .groupSession
        
        self.collectionView.addSubview(noDataView)
        noDataView.snp.makeConstraints { (m) in
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth, height: 415))
        }
        // 网络连接状态监听
        APP.shared().hasNetworkSubject.subscribe(onNext: { [weak self] (hasNetwork) in
            guard let strongSelf = self else { return }
            // 网络连接状态变化时设置顶部视图高度 50/0
            strongSelf.reloadCollectionView()
            
        }).disposed(by: bag)
        
        // 群状态变化订阅（置顶、免打扰）
        GroupManager.shared().groupsSubject.subscribe(onNext: {[weak self] (groups) in
            guard let strongSelf = self else { return }
            let source = groups.filter { $0.isOnTop == true || $0.isMuteNotification == true }
            // 同私聊：与置顶/免打扰无关的变更不用重排列表
            guard !strongSelf.isGroupSourceUnchanged(source) else { return }
            strongSelf.groupSource = source
            // 会话列表排序（置顶）
            strongSelf.sortSessions()
        }).disposed(by: bag)
        
        // 会话数据订阅
        SessionManager.shared().groupSessionsSubject.subscribe(onNext: { [weak self] (sessions) in
            guard let strongSelf = self else { return }
            strongSelf.dataSource = sessions
            strongSelf.noDataView.isHidden = sessions.count > 0
            // 会话列表排序（置顶）
            strongSelf.sortSessions()
        }).disposed(by: self.bag)
        
        // 获取聊天服务器状态
        MultipleSocketManager.shared().isAvailableSubject.subscribe {[weak self] (event) in
//            guard let strongSelf = self, case .next((let url, let isAvailable)) = event else { return }
            guard let strongSelf = self else { return }
//            for i in 0..<(self?.serverDataSource.count)! {
//                if self?.serverDataSource[i].url == url && self?.serverDataSource[i].status != isAvailable {
//                    self?.serverDataSource[i].status = isAvailable
//                }
//            }
//
//            if (self?.dataSource.count)! > 0 {
                strongSelf.reloadCollectionView()
//            }
        }.disposed(by: self.disposeBag)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SessionCollectionViewCell.self, for: indexPath)
        guard indexPath.row < self.dataSource.count else {
            return cell
        }
        let model = self.dataSource[indexPath.row]
        // 获取显示置顶和免打扰样式flg
        let (isOnTop, isMuteNotification) = self.filterGroups(session: model)
        cell.configure(model, isMuteNotification: isMuteNotification, isOnTop: isOnTop)
        let connectStatus = MultipleSocketManager.shared().getSingleSocketConnectStatus(model.chatServerUrl)
        cell.statusType = connectStatus
        return cell
    }
}

/*
//MARK: 私聊和群聊
class FZMPrivateAndGroupChatListView: SessionListView {
//class FZMPrivateAndGroupChatListView: SessionListView, UITableViewDataSource {

    lazy var noDataView : FZMNoDataView = {
        return FZMNoDataView(image: #imageLiteral(resourceName: "nodata_session_person"), imageSize: CGSize(width: 250, height: 260), desText: L("暂无消息"), btnTitle: L("开启聊天"), clickBlock: {
//            FZMUIMediator.shared().pushVC(.selectFriend(type: .all, completeBlock: nil))
        })
    }()
    var showSelect = false
    var showGroup = true
    var privateAndGroupChatList = [Session]() {
        didSet {
            if !self.showGroup {
                privateAndGroupChatList = privateAndGroupChatList.filter({$0.isPrivateChat == true})
            }
        }
    }
    init(with pageTitle: String , showSelect: Bool = false, showGroup: Bool = true) {
        self.showSelect = showSelect
        self.showGroup = showGroup
        super.init(with: pageTitle)
        tableView.tableHeaderView?.isHidden = true
//        tableView.register(FZMConversationCell.self, forCellReuseIdentifier: "FZMConversationCell")
//        tableView.delegate = self
//        tableView.dataSource = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func requestData() {
        self.addSubview(noDataView)
        noDataView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth, height: 365))
        }
        
//        IMConversationManager.shared().privateAndGroupChatListSubject.subscribe {[weak self] (event) in
//            guard case .next(let list) = event else { return }
//            self?.noDataView.isHidden = list.count > 0
//            self?.privateAndGroupChatList = list
//            for model in list {
//                model.isSelected = false
//            }
//            self?.tableView.reloadData()
//        }.disposed(by: disposeBag)
        
    }
    
//    func selectOrDeselect(model:FZMContactViewModel) {
//        for i in 0..<privateAndGroupChatList.count {
//            if privateAndGroupChatList[i].conversationId == model.contactId {
//                privateAndGroupChatList[i].isSelected = model.isSelected
//                tableView.reloadRows(at: [IndexPath(item: i, section: 0)], with: .none)
//            }
//        }
//    }
//
//     func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return self.privateAndGroupChatList.count
//    }
//
//     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "FZMConversationCell", for: indexPath) as! FZMConversationCell
//        let model = self.privateAndGroupChatList[indexPath.row]
//        cell.configure(with: model)
//        if showSelect {
//            cell.showSelect()
//            cell.selectStyle = model.isSelected ? .select : .disSelect
//        }
//        return cell
//    }
//
//     func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        if showSelect {
//           let model = self.privateAndGroupChatList[indexPath.row]
//           model.isSelected = !model.isSelected
//           tableView.reloadRows(at: [indexPath], with: .none)
//        }
//        self.selectBlock?(self.privateAndGroupChatList[indexPath.row])
//    }
    
//    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
//        return
//    }
}
*/

//MARK: 接收消息处理
extension SessionListView {
    /*
    func receiveMessage(with msg: Message, isLocal: Bool) {
        self.refreshLastMsg(with: msg)
    }
    
    func failSendMessage(with msg: Message) {
        self.refreshLastMsg(with: msg)
    }
    
    private func refreshLastMsg(with msg: Message) {
        if let _ = self as? FZMPrivateChatListView {
            //私聊
            guard msg.channelType == .person else { return }
        }else if let _ = self as? FZMGroupChatListView {
            //群聊
            guard msg.channelType == .group else { return }
        }else if let _ = self as? FZMChatRoomListView {
            //聊天室
            guard msg.channelType == .chatRoom else { return }
        }
        let conversation = SocketConversationModel(msg: msg)
        var oldIndex : Int?
        var unreadCount = 0
        conversationArr.forEach { (model) in
            if model == conversation {
                model.lastMsg = msg
                oldIndex = conversationArr.index(of: model)
                if IMConversationManager.shared().selectConversation != model && msg.direction == .receive {
                    model.unreadCount += 1
                }
                unreadCount += model.unreadCount
            }
        }
        if let useIndex = oldIndex {
            let model = conversationArr[useIndex]
            conversationArr.remove(at: useIndex)
            conversationArr.insert(model, at: 0)
            tableView.moveRow(at: IndexPath(row: useIndex, section: 0), to: IndexPath(row: 0, section: 0))
        }else {
            if IMConversationManager.shared().selectConversation != conversation && msg.direction == .receive {
                conversation.unreadCount += 1
                unreadCount += 1
            }
            conversationArr.insert(conversation, at: 0)
            tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
        }
        self.unreadCount = unreadCount
    }
    */
}
