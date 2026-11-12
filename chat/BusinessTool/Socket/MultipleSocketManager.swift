//
//  MultipleSocketManager.swift
//  chat
//
//  Created by 33 on 2021/3/3.
//

import UIKit
import RxSwift
import Alamofire
import SwifterSwift
import SwiftyJSON

enum SocketConnectStatus {
    case connected// 已连接
    case disConnected// 断开连接
    case unConnected// 未连接(未添加)
}

class MultipleSocketManager {
    
    private static let sharedInstance = MultipleSocketManager.init()
    static func shared() -> MultipleSocketManager { return sharedInstance }
    
    private var socketManages: [SocketManager] = []
    
    init() {
        self.networkListener()
        // ⚠️ `loginStatusConfigure()` 之前**全仓无人调用** ⇒ 登出时只能靠
        //    `LoginUser.clear()` 把 chatServerGroups 清空后间接触发 disconnectSockets，
        //    那条链一旦断（或改顺序），旧账号的 socket 就会活到下一个账号里继续收消息（串号）。
        //    这里补上直接监听，双保险。
        self.loginStatusConfigure()
    }
    
    // 网络状态监听
    func networkListener() {
        APP.shared().hasNetworkSubject.subscribe(onNext: {[weak self] (hasNetwork) in
            guard let strongSelf = self else {
                return
            }
            FZMLog("networkListener 收到网络变化 hasNetwork -- \(hasNetwork)")
            if hasNetwork {
                strongSelf.updateConnectedSockets()
            } else {
                strongSelf.disconnectSockets()
            }
        }).disposed(by: bag)
    }
    
    let bag = DisposeBag.init()
    
    private(set) lazy var receiveMsgsSubject = PublishSubject<[Message]>.init()// 收到消息订阅
    private(set) lazy var sendMsgStatusSubject = PublishSubject<SocketManager.SendMsgStatus>.init()// 消息发送结果订阅
    
    private(set) lazy var isAvailableSubject = BehaviorSubject<(URL, Bool)>.init(value: (URL.init(string: IMChatServerInUse?.value) ?? UNCONFIGURED_SERVER_URL, false))
    
    /// 按需连接的服务器（如刚加入的官方群服务器，不一定登记在用户 chatServerGroups）
    private var extraSocketURLs: [URL] = []
    
    private var socketURLs: [URL] {
        var urls = LoginUser.shared().chatServerGroups.compactMap { (item) -> URL? in
            let url = self.transformUrl(item.value)
            return url
        }
        urls += self.extraSocketURLs
        return urls.withoutDuplicates()
    }
    
    /// 确保连接某聊天服务器（进入群聊时调用，幂等）：
    /// 若该服务器尚未建立 socket（未登记在用户服务器列表，如官方群服务器），则补建连接；
    /// 已连接则直接返回。extraSocketURLs 会在后续 updateConnectedSockets 中一并保留，避免被清掉
    func ensureSocketConnected(serverUrl: String) {
        guard LoginUser.shared().isLogin, !serverUrl.isBlank else { return }
        let url = self.transformUrl(serverUrl)
        if !self.extraSocketURLs.contains(url) {
            self.extraSocketURLs.append(url)
        }
        if !self.socketManages.contains(where: { $0.url == url }) {
            self.updateConnectedSockets()
        }
    }

    /// 进入会话时调用（群聊）：确保该群的聊天服务器 socket 已建立，**并主动补拉一轮离线消息**。
    ///
    /// 群聊没有「服务端聊天记录」接口，离线期间的消息只能靠 socket 的 syncMsg 补；
    /// 而它原来只在鉴权成功时跑一次 ⇒ socket 一直连着时页面缺的消息补不回来，
    /// 用户只能反复退出重进（用户 2026-10-16 反馈）。幂等：已连接时只是重跑一次增量补拉。
    ///
    /// - Parameters:
    ///   - sessionId: 当前会话 id（用于「本次启动只补一次」的去重）
    ///   - sessionLogId: 该会话本地最大 logId。> 0 时先把服务器级断点回退到它再补拉 ——
    ///     找回「断点已越过、但本地没落库」的消息（断点推过它的 logId 后 syncMsg 永不再推）。
    ///   - sessionActiveRecently: 该会话最近是否聊过（最近没消息的会话不值当重拉，避免无谓流量）
    func ensureSocketConnectedAndSync(serverUrl: String,
                                      sessionId: String = "",
                                      sessionLogId: Int = 0,
                                      sessionActiveRecently: Bool = false) {
        guard LoginUser.shared().isLogin, !serverUrl.isBlank else { return }
        self.ensureSocketConnected(serverUrl: serverUrl)
        let url = self.transformUrl(serverUrl)
        // 刚补建的 socket 这时还没鉴权（那边鉴权成功后会自己 syncMsg），拿不到就跳过
        guard let socket = self.socketManages.first(where: { $0.url == url }) else { return }
        if sessionLogId > 0, sessionActiveRecently, !sessionId.isEmpty {
            let key = "\(url.absoluteString)|\(sessionId)"
            // 每个会话每次启动最多回退补拉一次：重拉是有代价的（服务端会把这段消息全推一遍）
            if !MultipleSocketManager.rewindTriedSessionKeys.contains(key) {
                MultipleSocketManager.rewindTriedSessionKeys.insert(key)
                socket.rewindSyncLogIdForSession(sessionLogId)
            }
        }
        socket.restartOfflineSync()
    }

    /// 本次启动里已经做过「断点回退补拉」的会话（`socketUrl|sessionId`）
    private static var rewindTriedSessionKeys = Set<String>()

    /// App 回到前台时调用：对所有已连接的聊天服务器补跑一轮离线消息同步。
    ///
    /// ⚠️ socket 一直连着（没有重连 / 没重新鉴权）时，`syncMsg` 不会自己再跑；
    ///    上一次同步链只要提前收尾，离线期间的消息就不会再自动补 ——
    ///    用户看到的就是「退到后台再回来 / 重进 App 才有新消息」。
    func restartAllOfflineSync() {
        guard LoginUser.shared().isLogin else { return }
        var count = 0
        for socket in self.socketManages where socket.isAvailable {
            socket.restartOfflineSync()
            count += 1
        }
        FZMLog("回到前台：对 \(count)/\(self.socketManages.count) 个连接补跑离线同步")
    }

    /// 手动「修复聊天记录」：对**所有聊天服务器**做一次断点回退重拉。
    ///
    /// 用于救「自动补拉覆盖不到」的缺口（会话中间缺一条：后面已经有本地消息了）。
    /// - Parameter days: 回退多少天
    /// - Returns: 是否至少有一台服务器真正开始了补拉（false = 还没有可用连接，已安排重试）
    @discardableResult
    func deepResyncAllServers(days: Int) -> Bool {
        // 先把所有已知聊天服务器都连上：不在 `socketManages` 里的服务器没人会去拉它的消息
        self.updateConnectedSockets()
        return self.performDeepResync(days: days, attempt: 0)
    }

    /// 逐个 socket 退断点。刚补建的连接还没鉴权（`isAvailable == false`）⇒ 隔一会儿重试。
    @discardableResult
    private func performDeepResync(days: Int, attempt: Int) -> Bool {
        var started = 0
        for socket in self.socketManages {
            let ok = socket.deepResync(days: days)
            if ok { started += 1 }
            FZMLog("手动修复聊天记录：\(socket.url.absoluteString) 回退 \(days) 天 结果=\(ok ? "已触发" : "跳过")")
        }
        FZMLog("手动修复聊天记录：回退 \(days) 天，socket=\(self.socketManages.count) 触发=\(started) 第\(attempt + 1)次")
        if self.socketManages.isEmpty || (started == 0 && attempt < 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                _ = self.performDeepResync(days: days, attempt: attempt + 1)
            }
        }
        return started > 0
    }
    
    func transformUrl(_ urlStr:String) -> URL {
        var socketURLString = ""
        if urlStr.contains("http://") {
            socketURLString = urlStr.replacingOccurrences(of: "http://", with: "ws://")
        } else if urlStr.contains("https://") {
            socketURLString = urlStr.replacingOccurrences(of: "https://", with: "wss://")
        } else {
            socketURLString = "ws://" + urlStr
        }
        socketURLString = socketURLString + "/sub/"
        return URL.init(string: socketURLString)!
    }
    
    /// 服务器地址归一化（判断「是不是同一台服务器」用）：
    /// `http://1.2.3.4:8061`、`ws://1.2.3.4:8061/sub/`、`1.2.3.4:8061` 都归一成 `1.2.3.4:8061`。
    /// 80/443 视为默认端口，避免 `host` 与 `host:443` 被当成两台服务器。
    static func serverKey(_ urlStr: String?) -> String {
        guard var str = urlStr?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return "" }
        if !str.contains("://") {
            str = "ws://" + str
        }
        if let url = URL(string: str), let host = url.host, !host.isEmpty {
            if let port = url.port, port != 80, port != 443 {
                return "\(host.lowercased()):\(port)"
            }
            return host.lowercased()
        }
        return str.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    // 获取所有已连接的服务器地址和状态
    func getAllSocketConnectStatus() -> [(URL, Bool)]? {
        let alreadyAddURL = self.socketManages.compactMap { ($0.url, $0.isAvailable) }
        return alreadyAddURL
    }

    /// 指定聊天服务器是否正在同步离线消息（聊天页据此显示「加载中」转圈）
    func isOfflineSyncing(chatServerUrl: String) -> Bool {
        guard !chatServerUrl.isBlank else { return false }
        let shortUrl = chatServerUrl.shortUrlStr
        return self.socketManages.contains {
            $0.url.absoluteString.contains(shortUrl) && $0.isOfflineSyncing
        }
    }

    /// 是否有任意服务器正在同步离线消息（会话列表页据此显示「加载中」）
    var isAnyOfflineSyncing: Bool {
        return self.socketManages.contains { $0.isOfflineSyncing }
    }
    
    // 获取单个服务器地址的状态
    func getSingleSocketConnectStatus(_ url:String) -> SocketConnectStatus {
        if url.isBlank {
            return .unConnected
        } else {
            let managers = self.socketManages.filter({ $0.url == self.transformUrl(url) })
            guard let manager = managers.first else {
                return .unConnected
            }
            // 主动重连（离线补洞换连接）期间保持「已连接」：这是我们自己断的，
            // 不是网络断了，界面不该闪红点（用户 2026-11-05 要求无感拉取）。
            if manager.isRecoveringConnection { return .connected }
            return manager.isAvailable ? .connected : .disConnected
        }
    }
    /*
    // 重置所有websocket连接
    func reConnectedAllSockets() {
        guard LoginUser.shared().isLogin else { return }
        
        let socketURLs = self.socketURLs
        
        socketManages.forEach { $0.disconnectSocket() }
        socketManages.removeAll()
        
        let needAddSocketManagers = socketURLs.compactMap { (url) -> SocketManager? in
            let socketManager = SocketManager.init(url: url)
//            socketManager.isDisconnected = false
            // 收到消息订阅
            socketManager.receiveMsgsSubject.subscribe(onNext: {[weak self] (msgs) in
                self?.receiveMsgsSubject.onNext(msgs)
            }).disposed(by: self.bag)
            // 消息发送结果订阅
            socketManager.sendMsgStatusSubject.subscribe(onNext: {[weak self] (status) in
                self?.sendMsgStatusSubject.onNext(status)
            }).disposed(by: self.bag)
            Observable.combineLatest(socketManager.isConnectedSubject, socketManager.isAuthSubject).subscribe {[weak self] (isConnected, isAuth) in
                FZMLog("websocket 连接状态变化-----   url： \(url)   ---   hasNetwork \(APP.shared().hasNetwork)  ---   isConnected \(isConnected)   ---   isAuth \(isAuth)")
                var isAvailable = false
                if isConnected && isAuth {
                    isAvailable = true
                }
                
                self?.isAvailableSubject.onNext((url, isAvailable))
            }.disposed(by: self.bag)
            return socketManager
        }
        self.socketManages = needAddSocketManagers
    }
    */
    
    // 更新所有websocket连接
    func updateConnectedSockets() {
        guard LoginUser.shared().isLogin else { return }
        
        let socketURLs = self.socketURLs
        let currentAddress = LoginUser.shared().address
        
        // 🔴 不属于**当前账号**的 socket 也要移除：切账号后它属于上一个账号，服务端还会按旧账号
        //    给它推消息（用户反馈「b 账号又看到了 a 的群聊消息」）。
        //    `authAddress` 为空 = 刚创建还没鉴权，保留。
        let needDeleteSocketManages = socketManages.filter {
            !socketURLs.contains($0.url) || !$0.isSameAccountAsCurrentLogin
        }
        needDeleteSocketManages.forEach { (manager) in
            if !manager.authAddress.isEmpty, manager.authAddress != currentAddress {
                FZMLog("移除其它账号的 socket：\(manager.url) 连接账号=\(manager.authAddress) 当前账号=\(currentAddress)")
            }
            self.discard(manager)
        }
        
        let needSaveSocketManages = socketManages.filter {
            socketURLs.contains($0.url) && $0.isSameAccountAsCurrentLogin
        }
//        needSaveSocketManages.forEach { $0.isDisconnected = false }
        self.socketManages = needSaveSocketManages
        
        let alreadyAddURL = self.socketManages.compactMap { $0.url }
        let needAddURL = socketURLs.filter { !alreadyAddURL.contains($0) }
        
        let needAddSocketManagers = needAddURL.compactMap { (url) -> SocketManager? in
            let socketManager = SocketManager.init(url: url)
//            socketManager.isDisconnected = false
            self.bind(socketManager)
            return socketManager
        }
        self.socketManages = self.socketManages + needAddSocketManagers
//        self.socketManages.forEach { $0.isDisconnected = false }
    }
    
    /// 断开并释放一个 socket（连同它的转发订阅）
    private func discard(_ socketManager: SocketManager) {
        socketManager.forwardDisposables.dispose()
        socketManager.disconnectSocket()
    }
    
    /// 把一个 socket 的转发订阅挂到**它自己**的 `CompositeDisposable` 上。
    ///
    /// 🔴 原来三个订阅都挂在 `self.bag` 上，而那个 bag 永不释放 ⇒ 旧 socket 的订阅一直活着：
    ///    切账号后旧连接只要再收到一条消息，就会直接流进当前账号的库（串号）。
    /// 这里再加一道**账号兜底**：连接鉴权时用的账号不是当前账号，消息一律不往后传。
    private func bind(_ socketManager: SocketManager) {
        let url = socketManager.url
        // 收到消息订阅
        _ = socketManager.forwardDisposables.insert(
            socketManager.receiveMsgsSubject.subscribe(onNext: { [weak self, weak socketManager] (msgs) in
                guard let socketManager = socketManager else { return }
                guard socketManager.isSameAccountAsCurrentLogin else {
                    FZMLog("丢弃其它账号 socket 的消息：\(url) 连接账号=\(socketManager.authAddress) 当前账号=\(LoginUser.shared().address)")
                    return
                }
                self?.receiveMsgsSubject.onNext(msgs)
            }))
        // 消息发送结果订阅
        _ = socketManager.forwardDisposables.insert(
            socketManager.sendMsgStatusSubject.subscribe(onNext: { [weak self] (status) in
                self?.sendMsgStatusSubject.onNext(status)
            }))
        _ = socketManager.forwardDisposables.insert(
            Observable.combineLatest(socketManager.isConnectedSubject, socketManager.isAuthSubject).subscribe { [weak self] (isConnected, isAuth) in
                FZMLog("websocket 连接状态变化-----   url： \(url)   ---   hasNetwork \(APP.shared().hasNetwork)  ---   isConnected \(isConnected)   ---   isAuth \(isAuth)")
                var isAvailable = false
                if isConnected && isAuth {
                    isAvailable = true
                    
                    // 连接成功且鉴权成功，连接状态server数据中包含本socket的url，则修改连接状态为true
                    //wjhTODO
                    var servers = LoginUser.shared().needConnectServers.filter( { $0.0 != url } )
                    servers.append((url, true))
                    LoginUser.shared().needConnectServers = servers
                }
                
                self?.isAvailableSubject.onNext((url, isAvailable))
            })
    }
    
    /// 推送 token 变化后（首次安装 / 恢复备份），让已鉴权的连接补一次鉴权把 token 交给服务器
    func refreshDeviceTokenForAllSockets() {
        self.socketManages.forEach { $0.refreshAuthForDeviceToken() }
    }
    
    // 断开所有连接
    func disconnectSockets() {
//        self.socketManages.forEach { $0.reConnectTime = $0.reConnectMaxTime; $0.disconnectSocket() }
        self.socketManages.forEach { self.discard($0) }
        self.socketManages.removeAll()
    }
}

extension MultipleSocketManager {
    
    // url格式：192.168.1.1:8888
    func send(msg: Message, chatServerUrl: String, publickey: String) {
        
        var isSend = false
        
        if !chatServerUrl.isBlank {
            self.socketManages.forEach { socketManager in
                let shortUrl = chatServerUrl.shortUrlStr

                if socketManager.url.absoluteString.contains(shortUrl) && socketManager.isAvailable == true {
                    socketManager.send(msg: msg, publickey: publickey)
                    isSend = true
                    return
                }
            }
        }
        
        // webscoket未连接，走http请求
        guard !chatServerUrl.isBlank else {
            FZMLog("当前聊天服务器地址为空, 发送msg失败")
            let sendFailed = SocketManager.SendMsgStatus.failed(msgId: msg.msgId)
            self.sendMsgStatusSubject.onNext(sendFailed)
            return
        }
        if !isSend {
            let socketStates = self.socketManages.map { "\($0.url.absoluteString) available=\($0.isAvailable)" }.joined(separator: "; ")
            FZMLog("websocket未匹配到可用连接, 改走HTTP push2. msgType=\(msg.msgType.intValue) chatServerUrl=\(chatServerUrl) 当前socket=[\(socketStates)]")
            let url = chatServerUrl + "/record/push2"
            
            // 使用http请求发送消息
            self.sendMsgHttpRequest(msg: msg, url: url, publickey: publickey)
        }
    }
    
    // 使用http请求发送消息
    private func sendMsgHttpRequest(msg: Message, url: String, publickey: String) {
        
        guard let pbEvent = PbMsg_event.init(with: msg, publickey: publickey),
              let data = try? pbEvent.serializedData() else {
                  FZMLog("消息发送失败 -- pbSktData 序列化失败")
                  // 发送消息失败
                  self.sendMsgFailed(msg)
                  return
              }
        let seq = Counter.increment()
        var pbSkt = PbSkt_Skt.init()
        pbSkt.ack = 1
        pbSkt.ver = 1
        pbSkt.seq = Int32(seq)
        pbSkt.body = data
        pbSkt.op = Int32(PbSkt_Op.sendMsg.rawValue)
        guard let pbSktData = try? pbSkt.serializedData() else {
            FZMLog("消息发送失败 -- pbSktData 序列化失败")
            // 发送消息失败
            self.sendMsgFailed(msg)
            return
        }
        var headers: HTTPHeaders {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let signature = LoginUser.shared().signature ?? ""
            return ["Content-type": "multipart/form-data",
                    "Content-Disposition" : "form-data",
                    "FZM-SIGNATURE": signature,
                    "FZM-VERSION": version,
                    "FZM-UUID": String.uuid(),
                    "FZM-DEVICE": "iOS",
                    "FZM-DEVICE-NAME": k_DeviceName
            ]
        }
        
        var response: DataResponse<Data?, AFError>?
        let multipartFormData = MultipartFormData.init()
        multipartFormData.append(pbSktData, withName: "message", fileName: "message")
        
        AF.upload(multipartFormData: multipartFormData, to: url, headers: headers).response { resp in
            response = resp
            if response?.result.isSuccess == true {// 上传成功
                FZMLog("消息发送请求成功 - response data -- \(String(describing: response?.data))")
                do{
                    if let jsonData = resp.data{
                        
                        let json = try JSON.init(data: jsonData)
                        FZMLog("response json -- \(json)")
                        guard let code = json["result"].int, code == 0 else {// result == 0为消息发送成功，其他则报错
                            let error = NSError.init(domain: "", code: json["result"].intValue, userInfo: [NSLocalizedDescriptionKey: json["message"].stringValue])
                            FZMLog("消息发送失败 -- error \(error)")
                            // 发送消息失败
                            self.sendMsgFailed(msg)
                            return
                        }
                        
                        let recordPush = RecordPush.init(json: json)
                        
                        // 消息发送成功订阅
                        self.sendMsgSuccess(msg, logId: recordPush.logId, datetime: recordPush.datetime)
                    }
                }catch{
                    let statusCode = resp.response?.statusCode ?? -1
                    let body = resp.data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    FZMLog("消息发送失败 -- HTTP状态码=\(statusCode) 响应非JSON, body=<<\(body.prefix(2000))>>")
                    // 发送消息失败
                    self.sendMsgFailed(msg)
                }
            } else {// 上传失败（消息发送失败）
                let statusCode = resp.response?.statusCode ?? -1
                FZMLog("消息发送失败 - HTTP状态码=\(statusCode) response data -- \(String(describing: resp.error))")
                // 发送消息失败
                self.sendMsgFailed(msg)
            }
        }
    }
    
    // 消息发送失败订阅传递
    func sendMsgFailed(_ msg: Message) {
        let sendFailed = SocketManager.SendMsgStatus.failed(msgId: msg.msgId)
        self.sendMsgStatusSubject.onNext(sendFailed)
    }
    
    // 消息发送成功订阅传递
    private func sendMsgSuccess(_ msg: Message, logId: Int, datetime: Int) {
        let sendSuccess = SocketManager.SendMsgStatus.success((msgId: msg.msgId, logId: logId, datetime: datetime))
        self.sendMsgStatusSubject.onNext(sendSuccess)
    }
}

extension MultipleSocketManager {
    func loginStatusConfigure() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogin), name: FZM_Notify_UserLogin, object: LoginUser.shared())
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogout), name: FZM_Notify_UserLogout, object: LoginUser.shared())
    }
    
    @objc private func userLogin() {
        // 重置所有websocket连接
        updateConnectedSockets()
    }
    
    @objc private func userLogout() {
        // 断开所有连接
        self.disconnectSockets()
    }
}
