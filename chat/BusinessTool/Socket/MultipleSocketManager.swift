//
//  MultipleSocketManager.swift
//  chat
//
//  Created by 陈健 on 2021/3/3.
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
    
    private(set) lazy var isAvailableSubject = BehaviorSubject<(URL, Bool)>.init(value: (URL.init(string: IMChatServerInUse?.value) ?? URL.init(string: "https://api.unknow-error.com")!, false))
    
    private var socketURLs: [URL] {
        return LoginUser.shared().chatServerGroups.compactMap { (item) -> URL? in
            let url = self.transformUrl(item.value)
            return url
        }.withoutDuplicates()
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
    
    // 获取所有已连接的服务器地址和状态
    func getAllSocketConnectStatus() -> [(URL, Bool)]? {
        let alreadyAddURL = self.socketManages.compactMap { ($0.url, $0.isAvailable) }
        return alreadyAddURL
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
        
        let needDeleteSocketManages = socketManages.filter { !socketURLs.contains($0.url) }
        needDeleteSocketManages.forEach { $0.disconnectSocket() }
        
        let needSaveSocketManages = socketManages.filter { socketURLs.contains($0.url) }
//        needSaveSocketManages.forEach { $0.isDisconnected = false }
        self.socketManages = needSaveSocketManages
        
        let alreadyAddURL = self.socketManages.compactMap { $0.url }
        let needAddURL = socketURLs.filter { !alreadyAddURL.contains($0) }
        
        let needAddSocketManagers = needAddURL.compactMap { (url) -> SocketManager? in
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
                    
                    // 连接成功且鉴权成功，连接状态server数据中包含本socket的url，则修改连接状态为true
                    //wjhTODO
                    var servers = LoginUser.shared().needConnectServers.filter( { $0.0 != url } )
                    servers.append((url, true))
                    LoginUser.shared().needConnectServers = servers
                }
                
                self?.isAvailableSubject.onNext((url, isAvailable))
            }.disposed(by: self.bag)
            return socketManager
        }
        self.socketManages = self.socketManages + needAddSocketManagers
//        self.socketManages.forEach { $0.isDisconnected = false }
    }
    
    // 断开所有连接
    func disconnectSockets() {
//        self.socketManages.forEach { $0.reConnectTime = $0.reConnectMaxTime; $0.disconnectSocket() }
        self.socketManages.forEach { $0.disconnectSocket() }
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
                    FZMLog("消息发送失败 -- error message json 解析失败")
                    // 发送消息失败
                    self.sendMsgFailed(msg)
                }
            } else {// 上传失败（消息发送失败）
                FZMLog("消息发送失败 - response data -- \(String(describing: resp.error))")
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
