//
//  SocketManager+Msg.swift
//  chat
//
//  Created by 陈健 on 2021/1/20.
//

import Foundation


extension SocketManager {
    
    func msgConfigure() {
        self.isAuthSubject.subscribe(onNext: { (isAuth) in
            if isAuth {
                self.syncMsg()
            } else {
                self.cleanAckWithSendFailed()
            }
        }).disposed(by: self.bag)
    }
}


//MARK - Send Msg
extension SocketManager {
    
    private struct AssociationMsgKey {
        static var ackDic = "SocketManager_AssociationMsgKey_Ack_Dic"
    }
    
    //key -> seq, valeu -> msgId
    private var _ackDic: [Int: String] {
        set {
            objc_setAssociatedObject(self, &AssociationMsgKey.ackDic, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            if objc_getAssociatedObject(self, &AssociationMsgKey.ackDic) == nil {
                objc_setAssociatedObject(self, &AssociationMsgKey.ackDic, [Int: String](), .OBJC_ASSOCIATION_RETAIN)
            }
            return objc_getAssociatedObject(self, &AssociationMsgKey.ackDic) as! [Int: String]
        }
    }
    
    enum SendMsgStatus {
        case delivered(logIds: [Int])//已送达，接收方成功收到消息
        case success((msgId: String, logId: Int, datetime: Int))//已发送，发送消息成功
        case failed(msgId: String)//发送失败
    }
    
    func send(msg: Message, publickey: String) {
        guard self.isAvailable else {
            FZMLog("websocket \(self.url) 不可用, 发送msg失败")
            let sendFailed = SendMsgStatus.failed(msgId: msg.msgId)
            self.sendMsgStatusSubject.onNext(sendFailed)
            return
        }
        self.executeInSocketThread {
            // 序列化
            guard let pbEvent = PbMsg_event.init(with: msg, publickey: publickey),
                  let data = try? pbEvent.serializedData() else { return }
            
            var seq = Counter.increment()
            while self._ackDic[seq] != nil { seq = Counter.increment() }
            self._ackDic[seq] = msg.msgId
            let wrapData = SocketData.wrapData(with: PbSkt_Op.sendMsg.rawValue, seq: seq, ack: 0, body: data)
            FZMLog("websocket \(self.url) 发送msg:---\(msg)")
            self.write(data: wrapData)
            self.executeInSocketThread(afterDelay: 3) {
                let needResend = self._ackDic[seq] != nil
                guard needResend else { return }
                FZMLog("websocket \(self.url) 超时重发msg:---\(msg)")
                self.write(data: wrapData)
            }
            self.executeInSocketThread(afterDelay: 5) {
                let sendFailed = self._ackDic[seq] != nil
                guard sendFailed else { return }
                self.sendMsgStatusSubject.onNext(.failed(msgId: msg.msgId))
            }
        }
    }
    
    // 发送消息回执
    func sendMsgReply(data: SocketData.UnWrapData) {
        guard let msgId = self._ackDic[data.ack],
              let event = try? PbMsg_event.init(serializedData: data.body),
              let msgAck = try? PbMsg_SendMsgAck.init(serializedData: event.body) else { return }
        let sendSuccess = SendMsgStatus.success((msgId: msgId, logId: Int(msgAck.logID), datetime: Int(msgAck.datetime)))
        self.sendMsgStatusSubject.onNext(sendSuccess)
        self._ackDic.removeValue(forKey: data.ack)
    }
    
    private func cleanAckWithSendFailed() {
        guard !self._ackDic.isEmpty else { return }
        let allSendingMsgs = Array(self._ackDic.values)
        allSendingMsgs.forEach { (msgId) in
            self.sendMsgStatusSubject.onNext(.failed(msgId: msgId))
        }
        self._ackDic.removeAll()
    }
    
    //SyncMsg
    private func syncMsg() {
        guard self.isAvailable else {
            FZMLog("websocket \(self.url) 不可用, 发送syncMsg失败")
            
//            self.connectSocket()//wjhTODO
            return
        }
        var syncMsg = PbSkt_SyncMsg.init()
        syncMsg.logID = Int64(ChatManager.shared().getLatestMsg()?.logId ?? 0)
        guard let syncMsgData = try? syncMsg.serializedData() else { return }
        let data = SocketData.wrapData(with: PbSkt_Op.syncMsgReq.rawValue, seq: 0, ack: 0, body: syncMsgData)
        FZMLog("websocket \(self.url) 发送syncMsg")
        self.write(data: data)
    }
    
}

