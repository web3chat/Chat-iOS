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
        
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_DD5F5F, textAlignment: .center, text: "服务器连接失败，点击查看")// 服务器连接失败，点击查看
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
    
    var privateSource = [User]()// 好友状态变化数据源（只包含置顶/免打扰）
    
    var groupSource = [Group]()// 群聊状态变化数据源（只包含置顶/免打扰）
    
    var sessionType: SessionListType = .privateSession// 聊天类型（私聊、群聊）
    
    let topViewHeight: CGFloat = 50// 顶部网络提示视图高度
    
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
    
//    // 网络连接状态变化时设置顶部视图高度 50/0
//    private func setCollectionVewiHeaderViewHeight() {
//
//    }
    
    func setRX(){
    }
    
    // 会话列表排序（置顶）
    func sortSessions() {
        self.dataSource = self.dataSource.sorted { $0.timestamp > $1.timestamp }
        
        if sessionType == .privateSession {// 私聊
            guard self.privateSource.count > 0, self.dataSource.count > 0 else {
                self.reloadCollectionView()
                return
            }
        } else {// 群聊
            guard self.groupSource.count > 0, self.dataSource.count > 0 else {
                self.reloadCollectionView()
                return
            }
        }
        
        var topSessions = [Session]()
        var normalSessions = self.dataSource
        
        if sessionType == .privateSession {// 私聊
            self.privateSource.forEach { friend in
                if friend.isOnTop, let session = normalSessions.filter({ $0.id.idValue == friend.address }).first {
                    topSessions += [session]
                    normalSessions = normalSessions.filter { $0.id.idValue != friend.address }
                }
            }
        } else {// 群聊
            self.groupSource.forEach { group in
                if group.isOnTop, let session = normalSessions.filter({ $0.id.idValue == group.address }).first {
                    topSessions += [session]
                    normalSessions = normalSessions.filter { $0.id.idValue != group.address }
                }
            }
        }
        
        let newSessions = topSessions.sorted { $0.timestamp > $1.timestamp } + normalSessions.sorted { $0.timestamp > $1.timestamp }
        
        self.dataSource = newSessions
        
        self.reloadCollectionView()
    }
    
    // 获取显示置顶和免打扰样式flg
    func filterFriends(session: Session) -> (Bool, Bool) {
        let friend = self.privateSource.filter{ $0.address == session.id.idValue }.first
        if (friend != nil) {
            return (friend!.isOnTop, friend!.isMuteNotification)
        } else {
            return (false ,false)
        }
    }
    
    // 获取显示置顶和免打扰样式flg
    func filterGroups(session: Session) -> (Bool, Bool) {
        let group = self.groupSource.filter{ $0.address == session.id.idValue }.first
        if (group != nil) {
            return (group!.isOnTop, group!.isMuteNotification)
        } else {
            return (false ,false)
        }
    }
    
    func reloadCollectionView() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
}

extension SessionListView: UICollectionViewDataSource, UICollectionViewDelegate,UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        FZMLog("偏移量=========\(scrollView.contentOffset.y)")
        
//        if scrollView.contentOffset.y < -40, !APP.shared().hasShowQRCodeViewFlg {
        if scrollView.contentOffset.y < 0, !APP.shared().hasShowQRCodeViewFlg {
            // 到达顶部后继续下拉，并还未展示二维码
            // 发出需展示二维码通知
            FZM_NotificationCenter.post(name: FZM_Notify_ShowQRCodeView, object: true)
            self.collectionView.isScrollEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                self.collectionView.isScrollEnabled = true
            })
            return
        }
        if scrollView.contentOffset.y > 0, APP.shared().hasShowQRCodeViewFlg {// 上拉视图 已展示二维码
            // 发出需隐藏二维码通知
            FZM_NotificationCenter.post(name: FZM_Notify_ShowQRCodeView, object: false)
            self.collectionView.isScrollEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                self.collectionView.isScrollEnabled = true
            })
            return
        }
        
//        FZM_NotificationCenter.post(name: FZM_Notify_ShowQRCodeView, object: scrollView.contentOffset.y)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SessionCollectionViewCell.self, for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.row < self.dataSource.count else { return }
        let session = self.dataSource[indexPath.row]
        
        // 更新会话的最新消息
        SessionManager.shared().updateLatestInfo(session)
        
        if !session.isPrivateChat, let group = GroupManager.shared().getDBGroupInTable(groupId: session.id.idValue.intEncoded, onlyInquire: true), !group.isInGroup {
            // 不在群聊（群已解散/被踢出群聊）
            self.showToast("已不在此群聊")
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
        return FZMNoDataView(image: #imageLiteral(resourceName: "nodata_session_person"), imageSize: CGSize(width: 250, height: 260), desText: "暂无好友消息", btnTitle: "开启聊天", clickBlock: {
            FZMUIMediator.shared().selectConversationNav()
        })
    }()
    
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
            strongSelf.privateSource = friends.filter { $0.isOnTop == true || $0.isMuteNotification == true }
            // 会话列表排序（置顶）
            strongSelf.sortSessions()
        }).disposed(by: bag)
        
        // 会话数据订阅
        SessionManager.shared().privateSessionsSubject.subscribe(onNext: { [weak self] (sessions) in
            guard let strongSelf = self else { return }
//            FZMLog("私聊会话数据订阅 --- \(sessions)")
            strongSelf.dataSource = sessions
            strongSelf.noDataView.isHidden = sessions.count > 0
            // 会话列表排序（置顶）
            strongSelf.sortSessions()
        }).disposed(by: self.bag)
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
        guard indexPath.row < self.dataSource.count else {
            return cell
        }
        // 获取显示置顶和免打扰样式flg
        let (isOnTop, isMuteNotification) = self.filterFriends(session: self.dataSource[indexPath.row])
        cell.configure(self.dataSource[indexPath.row], isMuteNotification: isMuteNotification, isOnTop: isOnTop)
        return cell
    }
}

//MARK:- 群聊
class FZMGroupChatListView: SessionListView {
    
    lazy var noDataView : FZMNoDataView = {
        return FZMNoDataView(image: #imageLiteral(resourceName: "nodata_session_group"), imageSize: CGSize(width: 250, height: 260), desText: "暂无群消息", btnTitle: "开启群聊", clickBlock: {
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
            strongSelf.groupSource = groups.filter { $0.isOnTop == true || $0.isMuteNotification == true }
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
        return FZMNoDataView(image: #imageLiteral(resourceName: "nodata_session_person"), imageSize: CGSize(width: 250, height: 260), desText: "暂无消息", btnTitle: "开启聊天", clickBlock: {
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
