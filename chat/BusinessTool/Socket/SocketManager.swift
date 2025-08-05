//
//  SocketManager.swift
//  chat
//
//  Created by 陈健 on 2021/1/15.
//

import UIKit
import Starscream
import RxSwift
import SwiftProtobuf
import Kingfisher

class SocketManager: NSObject {
    
    var reConnectTime = 0 // 设置重连次数
//    let reConnectMaxTime = 1000 // 设置最大重连次数
    let reConnectIntervalTime: TimeInterval = 30 // 设置重连时间间隔(秒) 心跳间隔时间
    
    let bag = DisposeBag.init()
    private(set) lazy var isConnectedSubject = BehaviorSubject.init(value: false)
    private(set) lazy var isAuthSubject = BehaviorSubject.init(value: false)
    
    private(set) lazy var receiveMsgsSubject = PublishSubject<[Message]>.init()// 收到消息订阅
    private(set) lazy var sendMsgStatusSubject = PublishSubject<SendMsgStatus>.init()// 消息发送结果订阅
    
    private static let socketThread = ResidentThread.init()
    
    func executeInSocketThread(_ task: @escaping ()->()) {
        SocketManager.socketThread.execute(task)
    }
    
    func executeInSocketThread(afterDelay: TimeInterval, execute: @escaping ()->()) {
        SocketManager.socketThread.execute(afterDelay: afterDelay, execute: execute)
    }
    
    private lazy var socket: ChatSocket = {
        let socket = ChatSocket.init(url: self.url)
        socket.delegate = self
        return socket
    }()
    
    private var isConnected = false {
        didSet {
            if isConnected == false {
                self.connectSocket(afterDelay: 2)
            }
            self.isConnectedSubject.onNext(isConnected)
        }
    }
    
    private var isAuth = false {
        didSet {
            if isConnected == true, isAuth == false {
                self.connectSocket(afterDelay: 2)
            }
            self.isAuthSubject.onNext(isAuth)
        }
    }
    
    var isAvailable: Bool {
        return self.isConnected && self.isAuth
    }
    
    let url: URL
    
    var firstTryConnect = true
    
    init(url: URL) {
        self.url = url
        super.init()
        
        self.systemConfigure()
        self.msgConfigure()
        self.connectSocket()
    }
    
    deinit {
        FZM_NotificationCenter.removeObserver(self)
        FZMLog("SocketManager deinit")
    }
    
    func connectSocket(afterDelay: TimeInterval = 0) {
        //判断网络情况，如果网络正常，可以执行重连
        if APP.shared().hasNetwork || firstTryConnect {
            //设置重连次数，解决无限重连问题
            reConnectTime = reConnectTime + 1
            
            var delayTimeInterval: TimeInterval = 0.2
            
            if reConnectTime < 10 {
                delayTimeInterval = 0.5
            } else if reConnectTime < 50 {
                delayTimeInterval = 2
            } else if reConnectTime < 100 {
                delayTimeInterval = 5
            } else if reConnectTime < 500 {
                delayTimeInterval = 10
            } else if reConnectTime < 1000 {
                delayTimeInterval = 30
            } else {
                delayTimeInterval = 60
            }
            
//            if reConnectTime < reConnectMaxTime {
                //添加重连延时执行，防止某个时间段，全部执行
                DispatchQueue.main.asyncAfter(deadline: .now() + delayTimeInterval) {
                    self.socket.disconnect()
                    guard LoginUser.shared().isLogin else { return }
                    self.socket.connect()
                    self.firstTryConnect = false
                    FZMLog("connectSocket 第--- \(self.reConnectTime) ---次重连")
                }
//            } else {
//                //提示重连失败
//                //wjhTODO
//                FZMLog("connectSocket 重连次数达到上限")
//            }
        } else {
            //提示无网络
            FZMLog("connectSocket  提示无网络")
        }
    }
    
    /*
     
     func connectSocket(afterDelay: TimeInterval = 0) {
         //判断网络情况，如果网络正常，可以执行重连
         if APP.shared().hasNetwork || firstTryConnect {
             //设置重连次数，解决无限重连问题
             reConnectTime =  reConnectTime + 1
             
             var delayTimeInterval: TimeInterval = 0.2
             
             if reConnectTime < 10 {
                 delayTimeInterval = 0.5
             } else if reConnectTime < 50 {
                 delayTimeInterval = 2
             } else if reConnectTime < 100 {
                 delayTimeInterval = 5
             } else if reConnectTime < 500 {
                 delayTimeInterval = 10
             } else if reConnectTime < 1000 {
                 delayTimeInterval = 30
             } else {
                 delayTimeInterval = 60
             }
             
     //            if reConnectTime < reConnectMaxTime {
                 //添加重连延时执行，防止某个时间段，全部执行
     //                DispatchQueue.main.asyncAfter(deadline: .now() + afterDelay) {
                 DispatchQueue.main.asyncAfter(deadline: .now() + delayTimeInterval) {
                     self.socket.disconnect()
                     guard LoginUser.shared().isLogin else { return }
                     self.socket.connect()
                     self.firstTryConnect = false
                     FZMLog("connectSocket 第--- \(self.reConnectTime) ---次重连")
                 }
     //            } else {
     //                //提示重连失败
     //                //wjhTODO
     //                FZMLog("connectSocket 重连次数达到上限")
     //            }
         } else {
             //提示无网络
             FZMLog("connectSocket  提示无网络")
         }
     //        DispatchQueue.main.asyncAfter(deadline: .now() + afterDelay) {
     //            self.socket.disconnect()
     //            guard LoginUser.shared().isLogin else { return }
     //            self.socket.connect()
     //        }
     }
     */
    
    func disconnectSocket() {
        self.invalidateHeartBeatTimer()
        self.socket.disconnect()
        self.socket.delegate = nil
    }
    
    func write(data: SocketData.WrapData) {
        self.socket.write(data: data)
    }
}

//MARK - Handle Receive Data
extension SocketManager {
    func handleReceive(_ data: SocketData.UnWrapData) {
        switch data.op {
        case PbSkt_Op.authReply.rawValue:
            if data.body.count > 0, let pbMsg = try? PbMsg_ActionEndpointLogin.init(serializedData: data.body) {
                let uuid = pbMsg.uuid
                
                if uuid != k_DeviceUUID {// 不是同一台设备
                    // 显示退出通知提示框
                    DispatchQueue.main.async {
                        APP.shared().endpointLoginAction(pbMsg)
                    }
                } else {
                    FZMLog("websocket 鉴权成功 \(self.url)")
                    self.isAuth = true
                }
            } else {
                FZMLog("websocket 鉴权成功 \(self.url)")
                self.isAuth = true
            }
            
        case PbSkt_Op.sendMsgReply.rawValue:
            FZMLog("websocket 收到sendMsgReply----\(data)")
            self.sendMsgReply(data: data)
        case PbSkt_Op.receiveMsg.rawValue:
            // 回ack
            let wrapData = SocketData.wrapData(with: PbSkt_Op.receiveMsgReply.rawValue, seq: 0, ack: data.seq, body: Data.init())
            self.write(data: wrapData)
            
            guard let event = try? PbMsg_event.init(serializedData: data.body) else { return }
            FZMLog("websocket 收到receiveMsg  event----\(data)")
            
            switch event.eventType {
            case .message://普通消息
                //ReceiveMsgAck
                
                guard let pbMsg = try? PbMsg_msg.init(serializedData: event.body) else { return }
                
                // 消息通道 0 私聊 1 群聊
                let address = pbMsg.channelType == 0 ? (pbMsg.from == LoginUser.shared().address ? pbMsg.target : pbMsg.from) : pbMsg.target
                ChatManager.getPublickey(by: address, isGetUserKey: pbMsg.channelType == 0, chatServerUrl: self.url.httpUrl) { (pubkey) in
//                    self.handleReceiveMsg(pbMsg: pbMsg, publickey: pubkey.finalKey)
                    self.getInvolvedUsersInfo(pbMsg, publickey: pubkey.finalKey)
                }
            case .messageAck://消息回复
                FZMLog("收到消息 --- 消息回复.")
            case .notice://通知信令
                guard let event = try? PbMsg_NotifyMsg.init(serializedData: event.body) else { return }
                FZMLog("收到消息 --- 通知信令. event----\(event.action)")
                
                self.handleReceiveNotifyMsg(event: event)
            default:
                break
            }
        case PbSkt_Op.syncMsgReply.rawValue:
            FZMLog("websocket 收到 syncMsgReply 开始sync消息")
        default:
            break
        }
    }
    
    // 查询收到的消息中涉及到的用户的信息，如果本地没有会从区块链上获取一次用户信息
    private func getInvolvedUsersInfo(_ pbMsg: PbMsg_msg, publickey: String) {
        var addressArr = [String]()
        
        let address = pbMsg.channelType == 0 ? pbMsg.from : pbMsg.target
        addressArr.append(address)
        
        var newPbMsg = pbMsg
        
        if !publickey.isBlank {// 有公钥则解密消息
            // 消息通道 0 私聊 1 群聊
            let decryptMsg = ChatManager.decryptMsgData(newPbMsg.msg, publickey: publickey, isEncryptPersionChatData: newPbMsg.channelType == 0)
            newPbMsg.msg = decryptMsg
        }
        
        // 如果是群聊的通知消息类型，先获取用户信息(群消息则再查询群成员信息)
        if newPbMsg.channelType == 1 && newPbMsg.msgType == .notification, let notiMsg = try? PbMsg_NotificationMsg.init(serializedData: pbMsg.msg) {
            // 查询收到的消息中涉及到的用户的信息，如果本地没有会从区块链上获取一次用户信息
            
            switch notiMsg.type {
            case .notiUpdateGroupName://修改群名
                if let notifyMsg = try? PbMsg_AlertUpdateGroupName.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.operator)
                }
            case .notiSignInGroup://加群
                if let notifyMsg = try? PbMsg_AlertSignInGroup.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.inviter)
                    addressArr += notifyMsg.members
                }
            case .notiSignOutGroup://退群
                if let notifyMsg = try? PbMsg_AlertSignOutGroup.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.operator)
                }
            case .notikickOutGroup://踢群
                if let notifyMsg = try? PbMsg_AlertkickOutGroup.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.operator)
                    addressArr += notifyMsg.members
                }
            case .notiDeleteGroup://删群
                if let notifyMsg = try? PbMsg_AlertDeleteGroup.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.operator)
                }
            case .notiUpdateGroupMuted://群禁言模式更改
                if let notifyMsg = try? PbMsg_AlertUpdateGroupMuted.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.operator) }
            case .notiUpdateGroupMemberMutedTime://更改禁言名单
                if let notifyMsg = try? PbMsg_AlertUpdateGroupMemberMutedTime.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.operator)
                    addressArr += notifyMsg.members }
            case .notiUpdateGroupOwner://更换群主
                if let notifyMsg = try? PbMsg_AlertUpdateGroupOwner.init(serializedData: notiMsg.body) {
                    addressArr.append(notifyMsg.newOwner)
                }
            default:
                break
            }
        }
        
        let myGroup = DispatchGroup.init()
        
        // 查询用户信息
        addressArr.forEach { address in
            myGroup.enter()
            UserManager.shared().getUser(by: address) { (_) in
                myGroup.leave()
            }
        }
        
        // 群聊时再查询群成员信息
        if newPbMsg.channelType == 1 {
            let groupId = newPbMsg.target.intEncoded
            let serverUrl = self.url.httpUrl
            
            addressArr.forEach { (address) in
                myGroup.enter()
                GroupManager.shared().getMember(by: groupId, memberId: address, serverUrl: serverUrl) { (_) in
                    myGroup.leave()
                }
            }
        }
        
        myGroup.notify(queue: .main) {
            FZMLog("***接收到通知消息--涉及的用户信息查询结束")
            
            self.handleReceiveMsg(pbMsg: newPbMsg, publickey: publickey)
        }
    }
    
    // 接收到普通消息处理
    private func handleReceiveMsg(pbMsg: PbMsg_msg, publickey: String) {
        let msg = Message.init(pbMsg: pbMsg, publickey: publickey)
        FZMLog("websocket 收到Message:  \(msg)")
        // 通知 (群聊内灰色文字通知消息) 自己解散了群聊不发出收到消息通知
        if msg.msgType.rawValue.value == 7, msg.msgType.operatorId == LoginUser.shared().address, msg.msgType.text.contains("解散了群聊") {
            FZMLog("websocket 收到自己解散了群聊的通知消息")
            return
        }
        if msg.fromId == LoginUser.shared().address, msg.targetId == LoginUser.shared().address {
            FZMLog("websocket 收到自己的消息")
            return
        }
        let msgInDB: [MessageDB] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.msgId.is(msg.msgId)
        })
        let isNewMsg = msgInDB.isEmpty
        guard isNewMsg else { FZMLog("websocket 收到重复的Message!!!!"); return }
        
        // 处理图片消息，如果加密则先解密，语音、视频、文件类型加密消息点击时再解密？？
        switch msg.kind {
        case .photo(let mediaItem):
            // 判断是否为私聊，url是否包含加密标识，如果包含则需解密（群消息不加密）
    
            if let urlStr = mediaItem.url, urlStr.contains(encryptFlgStr) {
                var address = msg.targetId
                if msg.sessionId.isPersonChat {
                    address = msg.fromId == LoginUser.shared().address ? msg.targetId : msg.fromId
                }
                ChatManager.getPublickey(by: address, isGetUserKey: msg.sessionId.isPersonChat) { (pubkey) in
                    guard !pubkey.isBlank else {// 没有公钥不解密
                        self.receiveMsgsSubject.onNext([msg])
                        return
                    }
                    guard let url = URL(string: urlStr) else { return }
                    do {
                        let data = try Data(contentsOf: url)
                        let imgData = ChatManager.decryptUploadData(data, publickey: pubkey, isEncryptPersionChatData: msg.sessionId.isPersonChat)
                        if imgData.count > 0, let image = UIImage(data: imgData) {
                            // 图片缓存到本地
                            let cacheKey = String.uuid()
                            ImageCache.default.store(image, forKey: cacheKey)
                            
                            // 更新消息数据源，保存已解密的图片数据
                            let msgType = Message.MsgType.init(image: urlStr, cacheKey: cacheKey, width: Double(image.size.width), height: Double(image.size.height))
                            var newMsg = msg
                            newMsg.msgType = msgType
                            // 判断是否为gif图
                            if urlStr.contains(".gif") {
                                newMsg.gifData = imgData
                            }
                            
                            self.receiveMsgsSubject.onNext([newMsg])
                        } else {// 解密失败也发出收到消息订阅通知
                            self.receiveMsgsSubject.onNext([msg])
                        }
                    }catch let error as NSError {
                        print(error)
                        // 解密失败也发出收到消息订阅通知
                        self.receiveMsgsSubject.onNext([msg])
                    }
                }
            } else {// 不包含加密标识不解密
                self.receiveMsgsSubject.onNext([msg])
            }
        default:
            self.receiveMsgsSubject.onNext([msg])
        }
    }
    
    /// 通知信令消息处理
    func handleReceiveNotifyMsg(event: PbMsg_NotifyMsg) {
        FZMLog("websocket 收到NotifyMsg :  \(event.action)")
        switch event.action {
        case .received:/** ** 送达 发消息对方已接收 ** **/
            
            guard let pbMsg = try? PbMsg_ActionReceived.init(serializedData: event.body) else { return }
            let logids = pbMsg.logs.compactMap { Int($0) }
            let delivered = SendMsgStatus.delivered(logIds: logids)
            self.sendMsgStatusSubject.onNext(delivered)
            
        case .revoke:// 撤回
            //wjhTODO
            guard let pbMsg = try? PbMsg_ActionRevoke.init(serializedData: event.body) else { return }
            let logId = pbMsg.logID
            let operatorId = pbMsg.operator
            FZMLog("撤回消息 logId：\(logId) operator: \(operatorId)")
            
        case .endpointLogin:// 多端登录
            guard let pbMsg = try? PbMsg_ActionEndpointLogin.init(serializedData: event.body) else { return }
            let uuid = pbMsg.uuid
            
            if uuid != k_DeviceUUID, (pbMsg.device == .ios || pbMsg.device == .android) {// 不是同一台设备
                // 显示退出通知提示框
                DispatchQueue.main.async {
                    APP.shared().endpointLoginAction(pbMsg)
                }
            }
            
        case .signInGroup:/** ** 加群 ** **/
            
            // 接收加群通知信息处理
            func handleSignInGroup(_ pbMsg: PbMsg_ActionSignInGroup) {
                let memberIds = pbMsg.uid
                let groupId: Int = Int(pbMsg.group)
                var members: [GroupMember] = []
                
                // 更新自己是否在群标识(本地没有群信息则会从服务器获取)
                GroupManager.shared().updateDBGroupIsInFlg(groupId: groupId, chatServerUrl: self.url.httpUrl, isInGroup: true)
                
                var isIncludeMe = false// 是否包含自己flg
                
                memberIds.forEach { (memberId) in
                    // 用户角色，2=群主，1=管理员，0=群员，10=退群
                    let member = GroupMember.init(memberId: memberId, memberMuteTime: 0, memberName: nil, memberType: 0, groupId: groupId)
                    members.append(member)
                    if memberId == LoginUser.shared().address {
                        isIncludeMe = true
                    }
                    
                    // 获取用户信息（本地没有则从网络获取一次）
                    UserManager.shared().getUser(by: memberId, userInfoBlock: nil)
                }
                // 添加新群成员到本地数据库
                GroupManager.shared().saveDBGroupMembers(members)
                
                // 发出群详情信息更新通知
                FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
                
                if isIncludeMe == true {
                    // 发出加入群通知
                    FZM_NotificationCenter.post(name: FZM_Notify_GroupSignin, object: groupId)
                }
            }
            
            guard let pbMsg = try? PbMsg_ActionSignInGroup.init(serializedData: event.body) else { return }
            
            let groupId: Int = Int(pbMsg.group)
            
            if let _ = GroupManager.shared().getDBGroup(by: groupId) {// 本地有群信息则更新本地数据
                // 接收加群通知信息处理
                handleSignInGroup(pbMsg)
            } else {
                // 获取群信息请求
                GroupManager.shared().getGroupInfo(serverUrl: self.url.httpUrl, groupId: groupId) { (group) in
                    // 接收加群通知信息处理
                    handleSignInGroup(pbMsg)
                } failureBlock: { (error) in
                    FZMLog("通知信令消息 加群 获取群信息请求失败")
                }
            }
            
        case .signOutGroup:/** ** 退群 ** **/
            
            guard let pbMsg = try? PbMsg_ActionSignOutGroup.init(serializedData: event.body) else { return }
            
            let memberIds = pbMsg.uid
            let groupId: Int = Int(pbMsg.group)
            if memberIds.count > 0 {
                // 删除部分群成员
                GroupManager.shared().deleteDBGroupMembers(with: groupId, memberIds: memberIds)
            }
            
            if memberIds.contains(LoginUser.shared().address) {// 判断退群人员是否包含自己
                // 更新自己是否在群标识（被踢出群聊）
                GroupManager.shared().updateDBGroupIsInFlg(groupId: groupId, isInGroup: false)
                
                // 踢出群聊通知
                FZM_NotificationCenter.post(name: FZM_Notify_GroupSignout, object: groupId)
            } else {
                // 发送详情信息更新通知
                FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            }
            
        case .deleteGroup:/** ** 删群 ** **/
            
            guard let pbMsg = try? PbMsg_ActionDeleteGroup.init(serializedData: event.body) else { return }
            
            let groupId: Int = Int(pbMsg.group)
            
            // 更新自己是否在群标识（群主/管理员解散了群聊）
            GroupManager.shared().updateDBGroupIsInFlg(groupId: groupId, isInGroup: false)
            
            // 解散群聊通知
            FZM_NotificationCenter.post(name: FZM_Notify_GroupDelete, object: groupId)
            
        case .updateGroupJoinType:/** ** 更新加群权限 ** **/
            
            guard let pbMsg = try? PbMsg_ActionUpdateGroupJoinType.init(serializedData: event.body) else { return }
            let groupId: Int = Int(pbMsg.group)
            let joinType = pbMsg.type.rawValue
            
            // 更新群加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群 2=需要审批
            GroupManager.shared().updateDBGroupJoinType(groupId: groupId, joinType: joinType)
            
            // 发送详情信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            
        case .updateGroupFriendType:/** ** 更新群加好友权限 ** **/
            
            guard let pbMsg = try? PbMsg_ActionUpdateGroupFriendType.init(serializedData: event.body) else { return }
            let groupId: Int = Int(pbMsg.group)
            let friendType = pbMsg.type.rawValue
            
            // 更新群加好友限制， 0=群内可加好友，1=群内禁止加好友
            GroupManager.shared().updateDBGroupFriendType(groupId: groupId, friendType: friendType)
            
            // 发送详情信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            
        case .updateGroupMuteType:/** ** 更新群禁言类型 ** **/
            
            guard let pbMsg = try? PbMsg_ActionUpdateGroupMuteType.init(serializedData: event.body) else { return }
            let groupId: Int = Int(pbMsg.group)
            let muteType = pbMsg.type.rawValue
            
            // 更新群禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
            GroupManager.shared().updateDBGroupMuteType(groupId: groupId, muteType: muteType)
            
            // 发送详情信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            
        case .updateGroupMemberType:/** ** 更新群成员（管理权限变化） ** **/
            
            guard let pbMsg = try? PbMsg_ActionUpdateGroupMemberType.init(serializedData: event.body) else { return }
            let groupId: Int = Int(pbMsg.group)
            let memberId = pbMsg.uid
            let type = pbMsg.type.rawValue// 0.normal 1.admin 2.owner
            
            guard var group = GroupManager.shared().getDBGroup(by: groupId) else { return }
            // 如果是自己
            if memberId == LoginUser.shared().address {
                if var person = group.person, person.memberId == memberId {
                    // 群信息存在个人信息
                    person.memberType = type
                    group.person = person
                    GroupManager.shared().updateDBGroup(group)
                } else {
                    // 完善群信息的个人信息
                    let newMember = GroupMember.init(memberId: memberId, memberMuteTime: 0, memberName: nil, memberType: type, groupId: groupId)
                    group.person = newMember
                    GroupManager.shared().updateDBGroup(group)
                }
                
            } else {// 不是自己
                // 本地已有此群成员则更新信息
                GroupManager.shared().updateDBMemberType(memberId: memberId, memberType: type, groupId: groupId)
            }
            
            // 发送详情信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            
        case .updateGroupMemberMuteTime:/** ** 更新禁言列表 ** **/
            
            guard let pbMsg = try? PbMsg_ActionUpdateGroupMemberMuteTime.init(serializedData: event.body) else { return }
            let groupId: Int = Int(pbMsg.group)
            let memberIds = pbMsg.uid
            let muteTime = Int(pbMsg.muteTime)
            
            guard memberIds.count > 0 else { return }
            guard var group = GroupManager.shared().getDBGroup(by: groupId) else { return }
            
            if memberIds.contains(LoginUser.shared().address) {
                // 包含自己
                if var person = group.person {
                    // 群信息存在个人信息
                    person.memberMuteTime = muteTime
                    group.person = person
                    GroupManager.shared().updateDBGroup(group)
                } else {
                    // 完善群信息的个人信息
                    let newMember = GroupMember.init(memberId: LoginUser.shared().address, memberMuteTime: muteTime, memberName: nil, memberType: 0, groupId: groupId)
                    group.person = newMember
                    GroupManager.shared().updateDBGroup(group)
                }
            }
            
            memberIds.forEach { (memberId) in
                // 更新群成员禁言时间
                GroupManager.shared().updateDBMemberMuteTime(memberId: memberId, memberMuteTime: muteTime, groupId: groupId)
            }
            
            // 发送详情信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            
        case .updateGroupName:/** ** 更新群名 ** **/
            
            guard let pbMsg = try? PbMsg_ActionUpdateGroupName.init(serializedData: event.body) else { return }
            let groupId: Int = Int(pbMsg.group)
            GroupManager.shared().getGroupKey(by: groupId) { (key) in
                let name = EncryptManager.decryptGroupName(pbMsg.name, key: key)
                
                // 更新群名称
                GroupManager.shared().updateDBGroupName(groupId: groupId, name: name)
                // 更新会话列表的会话名称
                SessionManager.shared().updateSessionName(session: SessionID.group(groupId.string), name: name)
                
                // 发送详情信息更新通知
                FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            }
            
        case .updateGroupAvatar:/** ** 更新群头像 ** **/
            
            guard let pbMsg = try? PbMsg_ActionUpdateGroupAvatar.init(serializedData: event.body) else { return }
            let groupId: Int = Int(pbMsg.group)
            let avatar = pbMsg.avatar
            // 更新群头像
            GroupManager.shared().updateDBGroupAvatar(groupId: groupId, avatar: avatar)
            // 更新会话列表的会话头像
            SessionManager.shared().updateSessionAvatar(session: SessionID.group(groupId.string), avatarUrlStr: avatar)
            
            // 发送详情信息更新通知
            FZM_NotificationCenter.post(name: FZM_Notify_GroupDetailInfoChanged, object: groupId)
            
        case .startCall:/** ** 开始语音/视频通话 ** **/
            FZMLog("开始语音/视频通话")
        case .acceptCall:/** ** 接通了语音/视频通话 ** **/
            FZMLog("接通了语音/视频通话")
        case .stopCall:/** ** 结束语音/视频通话 ** **/
            FZMLog("结束语音/视频通话")
//        case .UNRECOGNIZED(_):// 未知
//            FZMLog("未知类型通知信令")
        default:
            FZMLog("未知类型通知信令")
            break
        }
    }
}

extension URL {
    var httpUrl: String {
        var urlStr = self.absoluteString
        if urlStr.contains("ws://") {
            urlStr = urlStr.replacingOccurrences(of: "ws://", with: "http://")
        } else if urlStr.contains("wss://") {
            urlStr = urlStr.replacingOccurrences(of: "wss://", with: "https://")
        }
        if urlStr.contains("/sub/") {
            urlStr = urlStr.replacingOccurrences(of: "/sub/", with: "")
        }
        
        return urlStr
    }
}

//MARK - WebSocketDelegate
extension SocketManager: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        self.executeInSocketThread {
            switch event {
            case .connected(let headers):
                FZMLog("websocket \(self.url) 已连接: \(headers)")
                self.isConnected = true
            case .disconnected(let reason, let code):
                FZMLog("websocket \(self.url) 断开连接: \(reason) with code: \(code)")
                self.isConnected = false
                self.isAuth = false
            case .text(let string):
                FZMLog("websocket \(self.url) 收到text:  \(string)")
            case .binary(let data):
                FZMLog("websocket \(self.url) 收到data")
                guard let socketData = SocketData.unwrap(data: data) else {
                    FZMLog("websocket \(self.url) data解析失败, 消息被丢弃")
                    break
                }
                self.handleReceive(socketData)
            case .ping(_):
                FZMLog("websocket 收到ping")
                break
            case .pong(_):
                FZMLog("websocket 收到pong")
                break
            case .viabilityChanged(_):
                FZMLog("websocket 收到viabilityChanged")
                break
            case .reconnectSuggested(_):
                FZMLog("websocket 收到reconnectSuggested")
                break
            case .cancelled:
                self.isConnected = false
                self.isAuth = false
                FZMLog("websocket \(self.url) 取消连接")
            case .error(let error):
                self.isConnected = false
                self.isAuth = false
                FZMLog("websocket \(self.url) 报错 \(String(describing: error))")
            case .peerClosed:
                self.isConnected = false
                self.isAuth = false
                FZMLog("websocket \(self.url) 取消连接")
            }
        }
    
    }
    
  
        
}

