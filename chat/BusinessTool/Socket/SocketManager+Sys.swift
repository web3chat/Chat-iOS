//
//  SocketManager+Sys.swift
//  chat
//
//  Created by fzm on 2021/1/17.
//

import Foundation
import UIKit
import SwifterSwift
import RxSwift

extension SocketManager {
    func systemConfigure() {
        // 连接结果订阅
        self.isConnectedSubject.subscribe(onNext: { (isConnected) in
            guard isConnected else { return }
            // 开始鉴权
            self.auth()
        }).disposed(by: self.bag)
        
        // 鉴权结果订阅
        self.isAuthSubject.subscribe(onNext: { (isAuth) in
            // 发送心跳包
            self.heartbeat(isAvailable: isAuth)
            
            // 定时删除聊天记录：Socket 重连鉴权成功后执行
            if isAuth {
                ChatManager.shared().autoDeleteExpiredMessages()
            }
        }).disposed(by: self.bag)
    }
}

//MARK: - Heartbeat
extension SocketManager {
    private struct AssociationSysKey {
        static var heartbeatTimer = "SocketManager_AssociationSysKey_HeartbeatTimer"
    }
    
    private var _heartbeatTimer: Timer {
        get {
            // 用 `as?` 兑底，不用 `as!`（关联对象为 nil / 类型不符时 `as!` 直接 trap）
            if let timer = objc_getAssociatedObject(self, &AssociationSysKey.heartbeatTimer) as? Timer {
                return timer
            }
            let timer = Timer.scheduledTimer(withTimeInterval: reConnectIntervalTime, repeats: true) {[weak self] (_) in
                self?.sendHeartbeat()
            }
            objc_setAssociatedObject(self, &AssociationSysKey.heartbeatTimer, timer, .OBJC_ASSOCIATION_RETAIN)
            // 返回真正存进去的那个（并发时可能是别的线程先存的，避免多出一个计时器）
            return (objc_getAssociatedObject(self, &AssociationSysKey.heartbeatTimer) as? Timer) ?? timer
        }
    }
    
    @objc private func sendHeartbeat() {
        guard self.isAvailable else {
            FZMLog("websocket \(self.url) 不可用, 发送心跳失败")
            return
        }
        let data = SocketData.wrapData(with: PbSkt_Op.heartbeat.rawValue, seq: 0, ack: 0, body: Data.init())
        FZMLog("websocket \(self.url) 发送心跳")
        self.write(data: data)
    }
    
    private func heartbeat(isAvailable: Bool) {
        if isAvailable {
            self._heartbeatTimer.fireDate = Date.init()
            self._heartbeatTimer.fire()
        } else {
            self._heartbeatTimer.fireDate = Date.distantFuture// 计时器暂停
        }
    }
    
    func invalidateHeartBeatTimer() {
        self._heartbeatTimer.invalidate() // 计时器销毁
    }
}


//MARK: - Auth
extension SocketManager {
    // 鉴权
     private func auth() {
        guard let authBody = self.authBody() else { return }
        let data = SocketData.wrapData(with: PbSkt_Op.auth.rawValue, seq: 0, ack: 0, body: authBody)
        FZMLog("websocket \(self.url) 发送鉴权")
        // 记下这次实际送出去的 token，供 refreshAuthForDeviceToken 判断是否需要补发
        self.lastAuthedDeviceToken = APPDeviceToken
        // 记下这次鉴权用的账号：之后账号一变，这条连接推来的消息一律丢弃
        self.noteAuthAddress(LoginUser.shared().address)
        self.write(data: data)
    }
    
    /// 推送 token 变化后补一次鉴权，让服务器拿到最新 token。
    /// 首次安装时用户要先点「允许通知」才拿到 token，通常晚于登录 + 鉴权（那次上送的是空串），
    /// 而服务器只会用最近一次鉴权里的 token 推送。
    func refreshAuthForDeviceToken() {
        guard LoginUser.shared().isLogin, self.isAvailable else { return }
        guard self.lastAuthedDeviceToken != APPDeviceToken else { return }
        FZMLog("websocket \(self.url) 推送 token 变化，补发一次鉴权")
        self.auth()
    }
    
    private func authBody() -> Data? {
        guard LoginUser.shared().isLogin,
              let token = LoginUser.shared().signature
        else { return nil }
        
        let appId = APPID
        var ext = PbMsg_Login.init()
        ext.device = .ios
        ext.username = LoginUser.shared().nickName?.value ?? ""
        ext.deviceToken = APPDeviceToken
        ext.deviceName = k_DeviceName
        ext.uuid = k_DeviceUUID
        
        // 判断连接状态server数据中是否包含本socket的url，已包含且已连接过则socket连接状态为reconnect重连
        //wjhTODO
        var connType: PbMsg_Login.ConnType = .connect
        if APP.shared().isAutoLogin {
            connType = .reconnect
        } else {
            let servers = LoginUser.shared().needConnectServers
            servers.forEach { (url, hasConnected) in
                if url == self.url, hasConnected {
                    connType = .reconnect
                }
            }
        }
        
        ext.connType = connType// connect:手动登录，reconnect:重连
        
        var extData = Data.init()
        if let data = try? ext.serializedData() {
            extData = data
        }
        
        var authMsg = PbSkt_AuthMsg.init()
        authMsg.appID = appId
        authMsg.ext = extData
        authMsg.token = token
        
        guard let data = try? authMsg.serializedData() else {
            return nil
        }
        return data
    }
}

