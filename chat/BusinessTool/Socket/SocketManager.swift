//
//  SocketManager.swift
//  chat
//
//  Created by fzm on 2021/1/15.
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
            if isAuth == true {
                // 主动重连已经连上并鉴权完成 ⇒ 恢复正常显示
                self.isRecoveringConnection = false
                // ⚠️ 鉴权成功 = 这条连接真的可用 ⇒ 把重连退避计数归零。
                //    原来 `reConnectTime` 只增不减：只要断过几次，之后每次重连都要等
                //    5 / 10 / 30 / 60 秒（表现为「进来半天收不到消息 / 一直连不上」）。
                self.reConnectTime = 0
            }
            self.isAuthSubject.onNext(isAuth)
        }
    }
    
    var isAvailable: Bool {
        return self.isConnected && self.isAuth
    }

    /// 是否正在「主动重连换连接」（离线同步补洞用的那一套）。
    ///
    /// 这期间 socket 必然短暂不可用，但这是**我们自己断的**，不是网络断了 ——
    /// 界面（会话列表右侧的绿点）不该因此闪成红点。
    /// 用户 2026-11-05：「群聊消息每次断线重拉，会话列表的绿点都会变红点，要无感」。
    private(set) var isRecoveringConnection = false
    
    let url: URL
    
    var firstTryConnect = true
    
    /// 最近一次鉴权时实际送给服务器的推送 token。
    /// 用于 token 迟到（首次安装点完「允许通知」才拿到）时判断要不要补一次鉴权。
    var lastAuthedDeviceToken = ""

    /// 到这个时间点之前触发的重连**跳过退避**、立刻连。
    /// 只给「离线同步补洞」用：那条路径本来就在快速循环里换连接，
    /// 再等 0.5 秒纯属白等（用户 2026-11-05 要求去掉）。
    private var fastReconnectUntil: TimeInterval = 0

    /// 最近一次**鉴权时用的账号地址**（`auth()` 里写入）。
    ///
    /// 🔴 用途：切账号后这条连接属于**上一个账号**，服务端仍然会按旧账号推消息。
    ///    绝不允它把消息写进当前账号的库（用户反馈「b 账号能看到 a 的群聊消息」）。
    ///    空串 = 还没鉴过权（刚创建）⇒ 不拦。
    private(set) var authAddress = ""

    /// `MultipleSocketManager` 把本 socket 的转发订阅挂在这里，移除 socket 时统一 dispose。
    /// ⚠️ 不要挂到 `MultipleSocketManager.bag`（那个 bag 永不释放，旧 socket 的订阅会一直活着）。
    let forwardDisposables = CompositeDisposable()

    /// 这条连接是否属于**当前登录账号**：没鉴过权时按「是」处理（在连/在鉴权中）。
    var isSameAccountAsCurrentLogin: Bool {
        guard !authAddress.isEmpty else { return true }
        let current = LoginUser.shared().address
        return !current.isEmpty && authAddress == current
    }

    /// 记下本次鉴权使用的账号（`auth()` 里调）
    func noteAuthAddress(_ address: String) {
        guard !address.isEmpty else { return }
        authAddress = address
    }
    
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

            // 离线同步补洞：这段时间内的重连不等退避，立刻连（握手/鉴权本身还要一会儿，
            // 再叠 0.5~2 秒退避就是纯浪费 —— 用户 2026-11-05 要求）
            if Date().timeIntervalSince1970 < self.fastReconnectUntil {
                delayTimeInterval = 0.02
            } else if reConnectTime < 10 {
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

    /// 离线同步兜底：主动断开当前连接，让自动重连流程换一条**新连接**。
    ///
    /// 🔴 服务端只在「新连接」上重扫待投递队列：同一条连接上重复发 `syncMsgReq`
    ///    只会把「已经推过的那些」再推一遍，被跳过的消息永远不下来。
    ///    用户 2026-11-05 日志实证：第 1 次连接推 27 条、中间跳掉 11 条；
    ///    重启 App 换连接后，那 11 条（logId 全都小于断点）一次补回。
    ///
    /// ⚠️ 不能用 `disconnectSocket()`：它会把 delegate 置 nil，之后再也收不到重连回调。
    ///    这里只断开 socket，`isConnected` 置 false 会触发既有的自动重连。
    func forceReconnectForOfflineSync() {
        FZMLog("websocket \(self.url) 主动断开连接（让服务端重扫离线队列）")
        // 接下来 2 秒内的重连都跳过退避，立刻连
        self.fastReconnectUntil = Date().timeIntervalSince1970 + 2.0
        // 这期间界面按「仍在连接」显示，不要闪成红点
        self.isRecoveringConnection = true
        // 兜底：万一一直没连上（断网 / 服务端挂了），10 秒后恢复真实状态显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, !self.isAvailable else { return }
            self.isRecoveringConnection = false
        }
        self.socket.disconnect()
    }
    
    func write(data: SocketData.WrapData) {
        self.socket.write(data: data)
    }
}

//MARK - Handle Receive Data
extension SocketManager {
    func handleReceive(_ data: SocketData.UnWrapData) {
        // 🔴 帧序号连续性检查：服务端的 seq 是「这个连接上所有下发帧」的递增编号
        //    （通知信令 / 消息 共用一个计数器，日志里 seq=1 就是 endpointLogin 通知）。
        //    跳号 = 中间有几帧**本机根本没收到**：这些帧里的消息不会落库、也不会被 ack，
        //    而客户端完全无感（2026-11-03 日志实测：seq 16 → 23 缺 6 帧、25 → 27 缺 1 帧，
        //    紧接着服务端回的 syncMsgReply 是空 = 它认为已经推完了，断点又跳过了那一段）。
        //    ⇒ 一旦跳号，把同步断点回退到「缺口前最后一条消息」重拉一次。
        self.trackFrameSeq(data)

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
            // 🔴 账号兜底：这条连接鉴权时用的账号已经不是当前账号 ⇒ 它推来的消息一条都不能要
            //    （否则会落进当前账号的库、还会建出会话：用户反馈「b 账号又看到了 a 的群聊消息」）。
            //    不 ack、直接断开这条连接 —— 它属于上一个账号，留着只会继续串号。
            guard self.isSameAccountAsCurrentLogin else {
                FZMLog("websocket \(self.url) 丢弃其它账号的 socket 消息：连接账号=\(self.authAddress) 当前账号=\(LoginUser.shared().address)")
                self.disconnectSocket()
                return
            }
            // ⚠️ 先解析成功再回 ack：解析失败时故意不回 ack，让服务端后续重推。
            guard let event = try? PbMsg_event.init(serializedData: data.body) else {
                FZMLog("websocket 收到receiveMsg 事件体解析失败，不回ack（等服务端重推）")
                return
            }
            var parsedMsg: PbMsg_msg?
            if event.eventType == .message {
                guard let pbMsg = try? PbMsg_msg.init(serializedData: event.body) else {
                    FZMLog("receiveMsg 解析 PbMsg_msg 失败，不回ack（等服务端重推）")
                    return
                }
                parsedMsg = pbMsg
            }
            FZMLog("websocket 收到receiveMsg  event----\(data)")

            // 🔴 ack 时机：**消息真正落库之后**才回（2026-11-02 改）。
            //    服务端的 syncMsg 是「待投递队列」：只有**没 ack 过**的消息才会重推。
            //    原来解析完就立刻 ack ⇒ 之后任何一步丢了（解密失败 / 逻辑 bug / 崩溃）
            //    服务端都认为已送达，这条就永久缺失（群聊没有服务端历史接口可回补）。
            //    ⇒ 现在由 `handleReceiveMsg` 在每个终止分支上回调 `ack`。
            let ackSeq = data.seq
            let ackLock = NSLock()
            var didAck = false
            let ackOnce: () -> Void = { [weak self] in
                ackLock.lock()
                if didAck {
                    ackLock.unlock()
                    return
                }
                didAck = true
                ackLock.unlock()
                guard let self = self else { return }
                self.executeInSocketThread {
                    let wrapData = SocketData.wrapData(with: PbSkt_Op.receiveMsgReply.rawValue, seq: 0, ack: ackSeq, body: Data.init())
                    self.write(data: wrapData)
                }
                FZMLog("websocket \(self.url) 回 receiveMsg ack seq=\(ackSeq)")
            }

            switch event.eventType {
            case .message://普通消息
                guard let pbMsg = parsedMsg else {
                    ackOnce()
                    return
                }
                // ⚠️ 断点**不在这里**推进：收到 ≠ 落库。这里一推进，「缺群 / 不属于本账号」等
                //    分支丢弃的消息也会把断点推过它的 logId ⇒ 服务端认为已投递、永不再推，
                //    这条就永久缺失（用户 2026-11-03：离线消息要打开 3 次才加载完，根因就在这）。
                //    断点统一在 `handleReceiveMsg` 里、消息确定要落库时再推进。
                // 🔴 「在途」去重：只查库不够 —— 消息从「收到」到「落库」之间有窗口
                //    （用户/群成员查询、图片下载解密，最久几秒），服务端在这段时间重推
                //    同一条就会**重复走一遍处理链路**：未读数 +2、界面插两条
                //    （用户 2026-11-02 反馈「6 条消息显示成 12 条」正是如此）。
                //    ⚠️ 命中在途重复时**不 ack**：这份还没落库，等第一份处理完再靠库去重 ack。
                // 🔴 「已落库」快速通道：服务端重推的消息绝大多数本地已经有了。
                //    以前它们也要走「查公钥 + 查用户/群成员」，每条白等好几秒
                //    （日志里成片的「用户/群成员信息查询超时」就是这么来的）。
                let existing: [MessageDB] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
                    constraint.condition = MessageDB.CodingKeys.msgId.is(pbMsg.msgID)
                })
                // 排查「其它端（web）发到群里的消息，本机拉不全」用的诊断日志
                if pbMsg.from == LoginUser.shared().address {
                    FZMLog("【自己发的消息】收到 msgId=\(pbMsg.msgID) logId=\(pbMsg.logID) channel=\(pbMsg.channelType) target=\(pbMsg.target) 本地已存在=\(!existing.isEmpty)")
                }
                if !existing.isEmpty {
                    // channel/target/type 一起打出来：排查「服务端推了 32 条、界面只显示 21 条」时，
                    // 能直接看出这 32 条是「同一个会话」还是「分散在多个会话 / 混着通知消息」。
                    FZMLog("websocket 收到重复的Message（快速通道）msgId=\(pbMsg.msgID) logId=\(pbMsg.logID) channel=\(pbMsg.channelType) target=\(pbMsg.target) type=\(pbMsg.msgType.rawValue)")
                    ackOnce()
                    return
                }
                guard self.markMsgIdHandled(pbMsg.msgID) else {
                    // 这份是「在途重复」：第一份正在处理中（很快会落库并 ack）。
                    // 🔴 这里必须 ack —— 不 ack 的话服务端会不停重推这一条（每 ~1.5s 一次），
                    //    把同步链拖进「重复消息风暴」、轮次烧光后卡住
                    //    （用户 2026-11-02：「加载卡在某个进度，要重进 App 才加载完」）。
                    FZMLog("websocket 收到重复的Message（在途去重）msgId=\(pbMsg.msgID) logId=\(pbMsg.logID)")
                    ackOnce()
                    return
                }
                // 确认是「本机没处理过的新消息」⇒ 立刻计数（不等落库）。
                // 同步链靠它判断「这轮服务端还推了东西没有」，从而不必死等断点前进。
                self.noteIncomingMessage()
                // 兜底：20s 还没 ack（公钥 / 群成员查询的回调一直不来）时不能盲目强 ack ——
                // 🔴 一 ack 服务端就认为「已投递」、永不再推，这条就永久丢了
                //    （用户 2026-11-03「发了 26 条只收到 20 条」：缺的那段 8 秒里 6 条就是这么被 ack 掉的）。
                //    ⇒ 先查库：**落库了才 ack**；没落库说明还在处理（或 app 被挂起），
                //       撤销在途标记后**不 ack**，等服务端重推。
                DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                    guard let self = self else { return }
                    let inDB: [MessageDB] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
                        constraint.condition = MessageDB.CodingKeys.msgId.is(pbMsg.msgID)
                    })
                    if !inDB.isEmpty {
                        ackOnce()
                        return
                    }
                    // 撤销在途标记：否则服务端重推时会被「在途去重」挡住（ack 但不落库）
                    self.unmarkMsgIdHandled(pbMsg.msgID)
                    FZMLog("websocket \(self.url) 【未落库不 ack】20s 仍未落库 msgId=\(pbMsg.msgID) logId=\(pbMsg.logID)，等服务端重推")
                }
                // 消息通道 0 私聊 1 群聊
                let address = pbMsg.channelType == 0 ? (pbMsg.from == LoginUser.shared().address ? pbMsg.target : pbMsg.from) : pbMsg.target
                ChatManager.getPublickey(by: address, isGetUserKey: pbMsg.channelType == 0, chatServerUrl: self.url.httpUrl) { (pubkey) in
                    self.getInvolvedUsersInfo(pbMsg, publickey: pubkey.finalKey, ack: ackOnce)
                }
            case .messageAck://消息回复
                FZMLog("收到消息 --- 消息回复.")
                ackOnce()
            case .notice://通知信令
                // 通知信令不涉及「消息落库」，先 ack 再处理
                ackOnce()
                guard let event = try? PbMsg_NotifyMsg.init(serializedData: event.body) else { return }
                FZMLog("收到消息 --- 通知信令. event----\(event.action)")
                self.handleReceiveNotifyMsg(event: event)
            default:
                ackOnce()
            }
        case PbSkt_Op.syncMsgReply.rawValue:
            // 服务端一次只推一批离线消息：这里按最新断点继续补拉，
            // 避免「一次进 App 只拿到一批、要反复重进才收全」
            var replyLogId: Int64 = -1
            if data.body.count > 0, let replyMsg = try? PbSkt_SyncMsg.init(serializedData: data.body) {
                replyLogId = replyMsg.logID
            }
            FZMLog("websocket \(self.url) 收到 syncMsgReply body=\(data.body.count)B replyLogId=\(replyLogId)")
            self.handleSyncMsgReply(replyLogId: replyLogId)
        default:
            break
        }
    }
    
    // 查询收到的消息中涉及到的用户的信息，如果本地没有会从区块链上获取一次用户信息
    /// - Parameter ack: 消息处理完成后回调（真正落库后才回 ack，见 `receiveMsg` 处注释）
    private func getInvolvedUsersInfo(_ pbMsg: PbMsg_msg, publickey: String, ack: @escaping () -> Void) {
        var addressArr = [String]()
        
        // 🔴 要查的是「发送者」，不是会话 id。
        //    ⚠️ 原来群聊取 `pbMsg.target`，而群聊的 target 是**群 id** ——
        //    拿群 id 去 `getUser` / `getMember` 必然失败（服务端报 "Address too short"），
        //    而且每条消息都要等这个失败请求超时（以前 8s）才落库
        //    ⇒ 离线消息整批卡住，表现为「一次加载不完 / 重进才慢慢出来」
        //      （用户 2026-11-02 日志：每条消息都打「用户/群成员信息查询超时」）。
        let address = pbMsg.from.isEmpty ? pbMsg.target : pbMsg.from
        addressArr.append(address)
        
        var newPbMsg = pbMsg

        // 有密文就要解密/校验：公钥为空（群密钥没拿到）同样算解密失败，
        // 绝不能把密文原样交给 `Message(pbMsg:)` 去解析。
        if !newPbMsg.msg.isEmpty {
            let cipher = newPbMsg.msg
            // 消息通道 0 私聊 1 群聊
            let decrypted = publickey.isBlank
                ? cipher
                : ChatManager.decryptMsgData(cipher, publickey: publickey, isEncryptPersionChatData: newPbMsg.channelType == 0)

            // ⚠️ 解密失败时解密函数会**原样返回密文**，不能用 `decrypted.isEmpty` 判断
            //    （见 `ChatManager.isMsgDecryptFailed`）。2026-11-09 之前这里判不出来 ⇒
            //    密文被 protobuf 解析成空正文落库成 `{"content":""}`，原始密文也丢失。
            // 🔴 这里**绝对不能同步重拉密钥重试**：重拉要等网络（最多 3s/条），
            //    会把 socket 线程卡住 ⇒ 同步链被判超时收尾、后面的离线消息拉不全
            //    （2026-11-05 用户反馈「22 条只加载 15 条，中间漏 7 条」）。
            //    改成：先暂存密文 + 落可重试的文本占位，**异步**重试（不阻塞接收链路）。
            if ChatManager.isMsgDecryptFailed(cipher: cipher, decrypted: decrypted) {
                // ⚠️ 服务端的群通知 / 系统消息是**明文**（服务端没有群密钥，无法加密），
                //    解密必然「失败」。不能一律当坏消息：先按原 msgType 解析一遍，
                //    解析出有效内容就按明文使用（旧逻辑就是直接当明文解析，通知才能显示）。
                if Message.isUsablePlaintextPayload(newPbMsg, publickey: publickey) {
                    FZMLog("【解密失败】msgId=\(pbMsg.msgID) logId=\(pbMsg.logID) channel=\(pbMsg.channelType) 密文=\(cipher.count)B 公钥=\(publickey.isBlank ? "空" : "有")，但按明文解析出有效内容，按明文处理")
                    newPbMsg.msg = cipher
                } else {
                    FZMLog("【解密失败】msgId=\(pbMsg.msgID) logId=\(pbMsg.logID) channel=\(pbMsg.channelType) 密文=\(cipher.count)B 公钥=\(publickey.isBlank ? "空" : "有")，暂存密文并落可重试占位，等本轮同步结束再统一重试")
                    ChatManager.shared().saveUnparsedMsg(pbMsg, cipher: cipher)
                    newPbMsg.msg = Data()
                    // 统一成文本空正文：所有消息类型都能显示「该消息内容无法显示，点击重试」；
                    // 原始 msgType 已暂存在 `unparsed_msg_cipher`，重试成功后恢复原类型与正文。
                    newPbMsg.msgType = .text
                }
            } else {
                newPbMsg.msg = decrypted
            }
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
        
        // 后台预热用户信息（本地没有才走网络，不阻塞落库）
        addressArr.forEach { address in
            UserManager.shared().getUser(by: address) { _ in }
        }
        if newPbMsg.channelType == 1 {
            let groupId = newPbMsg.target.intEncoded
            let serverUrl = self.url.httpUrl
            addressArr.forEach { address in
                GroupManager.shared().getMember(by: groupId, memberId: address, serverUrl: serverUrl) { _ in }
            }
        }

        // 🔴 立刻处理：消息优先，昵称/头像之后由 `ChatVC.getMsgsUsers` 上屏时补。
        //    原来这里用 DispatchGroup 等用户/群成员查询，每条消息最久要等几秒，
        //    图片消息又再等下载 ⇒ 消息长时间不出现（用户 2026-11-02 反复反馈）。
        self.handleReceiveMsg(pbMsg: newPbMsg, publickey: publickey, ack: ack)
    }
    
    // 接收到普通消息处理
    /// - Parameter ack: 处理完成（消息已交给下游落库 / 已确定丢弃）后回调一次，用于回 receiveMsg ack
    private func handleReceiveMsg(pbMsg: PbMsg_msg, publickey: String, ack: @escaping () -> Void) {
        let msg = Message.init(pbMsg: pbMsg, publickey: publickey)
        FZMLog("websocket 收到Message:  \(msg)")

        // 【引用诊断】web 端发来的消息在 app 里是空气泡（用户 2026-11-04 反馈）：
        // 这里把**解密并解析后**的消息体 JSON 打出来，用来确认是不是 JSON 结构与 app 不一致
        // （`pbMsg.msg` 此时还是密文，打了也没用）。
        if pbMsg.hasReference || msg.msgType.isEmptyText {
            let json = msg.msgType.rawValue.json.rawString() ?? "nil"
            FZMLog(
                "【消息诊断】msgId=\(pbMsg.msgID) type=\(msg.msgType.rawValue.value) hasRef=\(pbMsg.hasReference) ref=\(pbMsg.reference.ref) topic=\(pbMsg.reference.topic) cipher=\(pbMsg.msg.count)B textLen=\(msg.msgType.textValue.count) json=\(json.prefix(400))"
            )
        }
        // 手动「修复聊天记录」期间：把服务端重推回来的每条消息都打一行（含被后续逻辑丢掉的）
        // ⇒ 能直接看出「这条到底有没有回来」以及「回来的为什么没落库」
        if self.isInDeepResyncWindow {
            FZMLog("【深度补拉】收到 msgId=\(msg.msgId) logId=\(msg.logId ?? -1) from=\(msg.fromId) target=\(msg.targetId) type=\(msg.msgType.rawValue.value) datetime=\(msg.datetime)")
        }
        // 图片消息单独打一条关键信息，方便定位「这条图片到底有没有到客户端 / 卡在哪一步」
        // （排查用：msgId、logId、会话、URL 是否加密）
        if case .image = msg.msgType {
            let urlStr = msg.msgType.url ?? "nil"
            FZMLog("【图片消息】msgId=\(msg.msgId) logId=\(msg.logId ?? -1) sessionId=\(msg.sessionId.idValue) 加密=\(urlStr.contains(encryptFlgStr)) url=\(urlStr)")
        }
        // 🔴 私聊兜底：消息的收发双方必须有一个是当前账号。
        //    上一个账号的连接/延迟响应把别人的私聊推过来时，这一条就能挡住
        //    （群聊没法这么判，走下面那段「本地是否有这个群」的兜底）。
        if msg.sessionId.isPersonChat {
            let me = LoginUser.shared().address
            if me.isEmpty || (msg.fromId != me && msg.targetId != me) {
                FZMLog("丢弃不属于当前账号的私聊消息：from=\(msg.fromId) target=\(msg.targetId) 当前账号=\(me) msgId=\(msg.msgId)")
                ack()   // 确定不要它，ack 掉，否则服务端会一直重推
                return
            }
        }
        // ⚠️ 群消息兜底：本地没有这个群、或本地标记「已不在群里」时直接丢弃。
        //    典型场景：切账号后 syncMsg / 服务端把上一个账号的群消息推给当前账号，
        //    消息会写进当前账号的库并顺手建出会话（用户反馈「b 账号能看到 a 的群，还能收到消息」）。
        //    丢弃前顺手清掉可能已经存在的脏会话，并**刷新一次本服务器的群列表**
        //    （真是刚被拉进的新群，群列表里会有它，落库后后续消息就正常了）。
        // 🔴 这里**绝对不能**改成 `getGroupInfoInAllServer`：群信息接口对「非成员」也可能返回成功，
        //    而 `Group.isInGroup` 默认是 true ⇒ 落库后这个群反而被「洗白」，后续消息全部放行（串号根源）。
        if !msg.sessionId.isPersonChat {
            let groupId = msg.sessionId.idValue.intEncoded
            let group = GroupManager.shared().getDBGroupInTable(groupId: groupId, onlyInquire: true)
            // 🔴 群密钥已经拿到（publickey 非空）⇒ 这个群确实存在、当前账号能访问，
            //    不能因为「本地群列表还没落库」就把消息丢掉。
            //    冷启动 / 刚被拉进群时最常命中：同一个群的 5 条离线消息里，只有部分消息
            //    赶上「群已落库」之后才被处理，其余被丢弃 ⇒ 表现「要打开 3 次才陆续拿到 2 条 + 3 条」。
            //    真正「不在这个群」（切账号残留 / 已退群）时 `getGroupKey` 也拿不到密钥、
            //    publickey 为空 ⇒ 仍然走下面的丢弃分支，防串号不受影响。
            let hasGroupKey = !publickey.isBlank
            let missingGroup = (group == nil && !hasGroupKey)
            if missingGroup || group?.isInGroup == false {
                FZMLog("丢弃非本群消息：groupId=\(groupId) 本地\(missingGroup ? "没有该群" : "已不在群")，msgId=\(msg.msgId) 有群密钥=\(hasGroupKey)")

                // 🔴 分两种情况：
                //    ① 本地**还没有这个群**（冷启动 / 群列表未同步完 / 刚被拉进群）
                //       ⇒ **不能 ack**！不 ack 服务端会把这条留在待投递队列里，
                //         等群列表刷新后再 syncMsg 就能重推回来。
                //         以前这里 ack 了 ⇒ 这条就永久没了（就是用户反馈「要重进几次 app 才齐全」）。
                //    ② **已不在群**（退群后的残留推送）⇒ 真的不要，ack 掉。
                if !missingGroup {
                    ack()
                } else {
                    // 「本地还没有这个群」：我们**不 ack**，要把在途标记也撤掉，
                    // 否则服务端重推时会被在途去重挡住，这条就再也下不来了。
                    self.unmarkMsgIdHandled(msg.msgId)
                    self.markSkippedLogId(msg.logId)
                }

                let sessionId = msg.sessionId
                DispatchQueue.main.async {
                    SessionManager.shared().deleteSession(id: sessionId)
                }
                // 只刷新「本服务器的群列表」（它只包含当前账号真正在的群），不写群信息
                GroupManager.shared().getNetGroups(serverUrl: self.url.httpUrl, successBlock: { [weak self] (_) in
                    // 群列表落库 / 内存更新后再补拉一轮（回退的断点此时才有效）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.restartOfflineSync()
                    }
                }, failureBlock: { (_) in
                    FZMLog("群列表刷新失败 groupId=\(groupId)，等下次进入会话再补拉")
                })
                return
            }
        }
        // 通知 (群聊内灰色文字通知消息) 自己解散了群聊不发出收到消息通知
        if msg.msgType.rawValue.value == 7, msg.msgType.operatorId == LoginUser.shared().address, msg.msgType.text.contains(L("解散了群聊")) {
            FZMLog("websocket 收到自己解散了群聊的通知消息")
            ack()
            return
        }
        if msg.fromId == LoginUser.shared().address, msg.targetId == LoginUser.shared().address {
            FZMLog("websocket 收到自己的消息")
            ack()
            return
        }
        let msgInDB: [MessageDB] = DBManager.shared().getObjects(fromTable: .message, constraintBlock: { (constraint) in
            constraint.condition = MessageDB.CodingKeys.msgId.is(msg.msgId)
        })
        let isNewMsg = msgInDB.isEmpty
        guard isNewMsg else {
            FZMLog("websocket 收到重复的Message!!!! msgId=\(msg.msgId) logId=\(msg.logId ?? -1)")
            // 本地已有 = 这条消息「确实拿到了」⇒ 断点可以放心前进。
            self.noteReceivedLogId(msg.logId)
            ack()
            return
        }
        
        // 这台服务器「已经给到」的最大 logId：作为该服务器 syncMsg 的断点
        // （多服务器不能共用全库最大值，否则会把别的服务器的 logId 当成自己的断点）
        self.noteReceivedLogId(msg.logId)
        
        // 处理图片消息，如果加密则先解密，语音、视频、文件类型加密消息点击时再解密？？
        switch msg.kind {
        case .photo(let mediaItem):
            // 判断是否为私聊，url是否包含加密标识，如果包含则需解密（群消息不加密）
    
            if let urlStr = mediaItem.url, urlStr.contains(encryptFlgStr) {
                var address = msg.targetId
                if msg.sessionId.isPersonChat {
                    address = msg.fromId == LoginUser.shared().address ? msg.targetId : msg.fromId
                }

                // 🔴 先落库、再回 ack、最后后台解密补图：
                //    原来要等「下载 + 解密」（最久 8s）才落库 ⇒ 这段时间气泡压根不存在，
                //    用户看到的就是「图没了」（用户 2026-11-02 反复反馈）。
                //    现在气泡**立即出现**（占位/菊花），图片解密完成后写回 cacheKey 并刷新。
                self.receiveMsgsSubject.onNext([msg])
                ack()

                ChatManager.getPublickey(by: address, isGetUserKey: msg.sessionId.isPersonChat, chatServerUrl: self.url.httpUrl) { (pubkey) in
                    // 拿不到密钥 / URL 非法：气泡已经在库里、也已经上屏，但不会有图。
                    // 必须发一次刷新通知，让 cell 从「菊花」切成「加载失败」占位图 ——
                    // 否则这条气泡会一直转圈，用户以为「这张图丢了」（实际是解密链没走完）。
                    guard !pubkey.isBlank, let url = URL(string: urlStr) else {
                        FZMLog("收到图片无法解密 msgId=\(msg.msgId) 密钥为空=\(pubkey.isBlank) url=\(urlStr)")
                        DispatchQueue.main.async {
                            FZM_NotificationCenter.post(name: FZM_Notify_ChatMsgContentUpdated, object: msg.msgId)
                        }
                        return
                    }
                    DispatchQueue.global(qos: .userInitiated).async {
                        // ⚠️ 不能用 `Data(contentsOf:)`：没有超时
                        let raw = ChatManager.fetchImageData(from: url)
                        let imgData = raw.map {
                            ChatManager.decryptUploadData($0, publickey: pubkey, isEncryptPersionChatData: msg.sessionId.isPersonChat)
                        } ?? Data()
                        // 用降采样 + 立即解码，别把未解码的 JPEG 存进缓存
                        guard imgData.count > 0, let image = UIImage.safeDecodedImage(data: imgData, maxPixelSize: 2048) else {
                            FZMLog("收到图片解密失败 msgId=\(msg.msgId) url=\(urlStr) 原始=\(raw?.count ?? -1)B")
                            // 解密/解码失败也要刷新一次：让气泡显示「加载失败」占位图，不留空白、不一直转圈
                            DispatchQueue.main.async {
                                FZM_NotificationCenter.post(name: FZM_Notify_ChatMsgContentUpdated, object: msg.msgId)
                            }
                            return
                        }
                        // ⚠️ 复用消息自带的 cacheKey：cell 的 `loadEncryptedImage` 也按这个 key 找图，
                        //    同 key 写同一份，避免重复下载、避免 DB 里 cacheKey 变来变去。
                        let cacheKey = msg.msgType.mediaCachekey ?? String.uuid()
                        if FZM_EnableImageSaveMode {
                            ChatMediaCache.store(image, original: imgData, forKey: cacheKey)
                        } else {
                            ChatMediaCache.store(image, forKey: cacheKey)
                        }
                        DispatchQueue.main.async {
                            // 图片已入缓存：通知聊天页刷新这条气泡（reload 后直接命中，不用再下载）
                            FZM_NotificationCenter.post(name: FZM_Notify_ChatMsgContentUpdated, object: msg.msgId)
                        }
                    }
                }
            } else {// 不包含加密标识不解密
                self.receiveMsgsSubject.onNext([msg])
                ack()
            }
        default:
            self.receiveMsgsSubject.onNext([msg])
            ack()
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
            let logId = Int(pbMsg.logID)
            let operatorId = pbMsg.operator
            
            FZMLog("撤回消息 logId：\(logId) operator: \(operatorId) reason: \(pbMsg.reason)")
            // 发出撤回消息通知
            FZM_NotificationCenter.post(name: FZM_Notify_RevokeMsg, object: pbMsg)
            
        case .deleteMessages:// 其他设备删除聊天记录（多端同步）
            guard let pbMsg = try? PbMsg_ActionDeleteMessages.init(serializedData: event.body) else { return }
            
            FZMLog("收到删除聊天记录同步通知 sessionId: \(pbMsg.sessionId) msgIds: \(pbMsg.msgIds) before: \(pbMsg.before) clearAll: \(pbMsg.clearAll)")
            // 发出删除聊天记录同步通知
            FZM_NotificationCenter.post(name: FZM_Notify_DeleteMessages, object: pbMsg)
            
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
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        self.executeInSocketThread {
            switch event {
            case .connected(let headers):
                FZMLog("websocket \(self.url) 已连接: \(headers)")
                self.isConnected = true
                // 新连接 = 新的帧序号空间（seq 从 1 重新开始），必须清零基线
                self.resetFrameSeqBaseline()
            case .disconnected(let reason, let code):
                FZMLog("websocket \(self.url) 断开连接: \(reason) with code: \(code)")
                self.isConnected = false
                self.isAuth = false
                self.resetFrameSeqBaseline()
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
                self.resetFrameSeqBaseline()
                FZMLog("websocket \(self.url) 取消连接")
            case .error(let error):
                self.isConnected = false
                self.isAuth = false
                self.resetFrameSeqBaseline()
                FZMLog("websocket \(self.url) 报错 \(String(describing: error))")
            case .peerClosed:
                self.isConnected = false
                self.isAuth = false
                self.resetFrameSeqBaseline()
                FZMLog("websocket \(self.url) 取消连接")
            }
        }
    
    }
    
  
        
}

