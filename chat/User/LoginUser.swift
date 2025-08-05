//
//  LoginUser.swift
//  xls
//
//  Created by 陈健 on 2020/8/26.
//  Copyright © 2020 陈健. All rights reserved.
//

import UIKit
import SwiftyJSON
import SwifterSwift

final class LoginUser {
    
    private static let sharedInstance = UserDefaultsDB.loginUser ?? LoginUser.init()
    
    class func shared() -> LoginUser {
        return sharedInstance
    }
    private let bag = DisposeBag.init()
    
    private(set) var seed = ""
    var encryptedSeed = ""
    private(set) var privateKey = ""
    private(set) var publicKey = ""
    private(set) var address = ""
    
    var avatarUrl = ""
    var bnbAddr = ""
    var ethAddr = ""
    var btyAddr = ""
    
    private(set) lazy var chatServerGroupsSubject  = PublishSubject<[UserChatServerGroup]>.init()// 只会发送给当前已经订阅这个subject的订阅者，新的订阅者不会收到订阅之前发送的事件
//    private(set) lazy var chatServerGroupsSubject = BehaviorSubject<[UserChatServerGroup]>.init(value: [])// 会发送最近的一个next事件给新的订阅者
    
    // 我的聊天服务器地址数据
    var chatServerGroups = [UserChatServerGroup]() {
        didSet {
            
            self.chatServerGroups = self.chatServerGroups.withoutDuplicates(keyPath: \.id)
            self.chatServerGroupsSubject.onNext(self.chatServerGroups)
            
//            DispatchQueue.main.async {
//                MultipleSocketManager.shared().updateConnectedSockets()
//                self.chatServerGroupsSubject.onNext(self.chatServerGroups)
//            }
        }
    }
    
    // (服务器地址，是否已成功连接过flg) 记录手动登录时等待连接的serverURL
    var needConnectServers = [(URL, Bool)]()
    
    var nickName: UserInfoField? = nil
    var phone: UserInfoField? = nil
    
    var bindSeedPhone = ""
    var bindSeedEmail = ""
    
    var isLogin: Bool { return !seed.isEmpty }
    
    // 当前是否已在团队
    var isInTeam = UserDefaultsDB.IsInTeam ?? false {
        didSet {
            UserDefaultsDB.IsInTeam = isInTeam
        }
    }
    
    var signToken = ""
    
    var lastSignTime = 0
    
    // 我的员工信息订阅
    private(set) lazy var staffInfoSubject = BehaviorSubject<StaffInfo?>.init(value: nil)
    // 我的员工信息
    var myStaffInfo: StaffInfo? {
        didSet {
            DispatchQueue.main.async {
                self.staffInfoSubject.onNext(self.myStaffInfo)
            }
        }
    }
    
    // 我的企业信息订阅
    private(set) lazy var companyInfoSubject = BehaviorSubject<EnterPriseInfo?>.init(value: nil)
    // 我的企业信息
    var myCompanyInfo: EnterPriseInfo? {
        didSet {
            DispatchQueue.main.async {
                self.companyInfoSubject.onNext(self.myCompanyInfo)
            }
        }
    }
    
    var contactsName: String {
        guard let staffName = myStaffInfo?.name, !staffName.isBlank else {
            guard let alias = self.nickName?.value, !alias.isBlank else {
                return self.address.shortAddress
            }
            return alias
        }
        return staffName
    }
    
    private var hasServer = false // 合约上是否已有聊天服务器信息
    
    private var hasPublicKey = false // 合约上是否已有公钥
    
    private var isAddServerGroupRequesting = false
    
    private init() {
        
        // 自己聊天服务器地址变化订阅
        self.chatServerGroupsSubject.distinctUntilChanged().subscribe(onNext: {[weak self] (_) in
            guard let strongSelf = self else { return }
            
            // 判断服务器是首次连接/重连状态，websocket鉴权ext.connType字段需区分
            //wjhTODO
            let chatServers = strongSelf.chatServerGroups
            var bServers = strongSelf.needConnectServers
            let urls = bServers.compactMap({ $0.0 })// URL
            // 判断服务器连接状态数据源是否有需要添加的新数据
            chatServers.forEach { (server) in
                let urlStr = server.value.shortUrlStr
                let url = URL(string: urlStr)
                if let url = url, !urls.contains(url) {
                    bServers.append((url, false))
                }
            }
            strongSelf.needConnectServers = bServers
            
            if chatServers.count == 0 {
                // 断开所有websocket连接
                MultipleSocketManager.shared().disconnectSockets()
            } else {
                // 重置所有websocket连接
                MultipleSocketManager.shared().updateConnectedSockets()
                
                // 重新获取所有服务器上的群聊列表
                GroupManager.shared().getAllServersNetGroups()
            }
        }).disposed(by: self.bag)
    }
}

extension LoginUser {
    // 刷新我的员工信息和企业信息
    func refreshMyStaffInfoAndTeamInfo() {
        guard isLogin else { return }
        
        TeamManager.shared().getStaffInfo(address: self.address) { (info) in
            TeamManager.shared().getEnterPriseInfo(entId: info.entId)
        } failureBlock: { _ in
        }
    }
    
    // 刷新我的个人信息
    func refreshUserInfo(successBlock: (()->())? = nil, failureBlock: ((Error)->())? = nil) {
        guard self.isLogin else {
            failureBlock?(NSError.error(with: "未登录"))
            return
        }
        User.getUser(targetAddress: self.address, count: 100, index: "", successBlock: {[weak self] (json) in
            guard let strongSelf = self else { return }
            
//            let groups = json["groups"].arrayValue.compactMap { $0.stringValue }
            let chatServers = json["chatServers"].arrayValue.compactMap { UserChatServer.init(json: $0) }
            let fields = json["fields"].arrayValue.compactMap { UserInfoField.init(json: $0) }
            
            let chatServerGroups = chatServers.compactMap { UserChatServerGroup.init(userchatServer: $0) }// 服务器地址列表
            if chatServerGroups.count > 0 {
                strongSelf.hasServer = true
            }
            // 聊天服务器数据源赋值
            strongSelf.setMyChatServerGroups(chatServerGroups)
            
            var pubKey = ""
            for field in fields {
                if case .nickname = field.name {
                    strongSelf.nickName =  field
                }
                if case .phone = field.name {
                    strongSelf.phone =  field
                }
                if case .pubKey = field.name {
                    pubKey = field.value.finalKey
                }
                if case .avatar = field.name {
                    strongSelf.avatarUrl = field.value
                }
                if case .ETH = field.name {
                    strongSelf.ethAddr = field.value
                }
                if case .BNB = field.name {
                    strongSelf.bnbAddr = field.value
                }
                if case .BTY = field.name {
                    strongSelf.btyAddr = field.value
                }
            }
            
            // 未设置过IM服务器 连接默认IM服务器 并上传保存到服务端
            if !strongSelf.isAddServerGroupRequesting, strongSelf.chatServerGroups.isEmpty && !strongSelf.hasServer, let server = OfficialChatServers?.first {
                let chatServer = UserChatServerGroup.init(server: server)
                strongSelf.addServerGroup(server: chatServer)
                strongSelf.hasServer = true
            }
            
            if !pubKey.isBlank {
                strongSelf.hasPublicKey = true
            }
            
            // 没有publickey则上传publickey
            if pubKey.isEmpty, let keys = SeedManager.keyBy(seed: strongSelf.seed), !keys.priKey.isEmpty, !keys.pubKey.isEmpty, !EncryptManager.publicKeyToAddress(publicKey: keys.pubKey).isEmpty, !strongSelf.hasPublicKey {
                let pubkey = keys.pubKey.finalKey
                
                User.updateUserPublickKey(targetAddress: strongSelf.address, pubKey: pubkey) { (_) in
                    strongSelf.hasPublicKey = true
                    strongSelf.publicKey = pubkey
                    strongSelf.save()
                } failureBlock: { (error) in
                    FZMLog("没有publickey则上传publickey ERROR \(error)")
                }
            }
            
            // 没有地址则上传地址
            if strongSelf.ethAddr.isEmpty || strongSelf.bnbAddr.isEmpty || strongSelf.btyAddr.isEmpty
            {
                let arr = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID()
                if arr?.count == 0{
                    return
                }
                let coin = arr?.first as! LocalCoin
                let ethaddr = coin.coin_address
                let btyaddr = coin.coin_address
                let bnbaddr = coin.coin_address
                
                User.updateUserChainAddress(targetAddress: strongSelf.address, name: .eth, chainAddr: ethaddr!) { (_) in
                    strongSelf.ethAddr = ethaddr!
                    strongSelf.save()
                } failureBlock: { (error) in
                    
                }
                
                User.updateUserChainAddress(targetAddress: strongSelf.address, name: .bnb, chainAddr: bnbaddr!) { (_) in
                    strongSelf.bnbAddr = ethaddr!
                    strongSelf.save()
                } failureBlock: { (error) in
                    
                }
                
                User.updateUserChainAddress(targetAddress: strongSelf.address, name: .bty, chainAddr: btyaddr!) { (_) in
                    strongSelf.btyAddr = ethaddr!
                    strongSelf.save()
                } failureBlock: { (error) in
                    
                }

            }
            strongSelf.save()
            successBlock?()
        }, failureBlock: nil)
        
        Provider.request(BackupAPI.addressRetrieve(address: self.address), successBlock: { (json) in
            self.bindSeedPhone = json["phone"].stringValue
            self.bindSeedEmail = json["email"].stringValue
        }, failureBlock: nil)
    }
    
    // 重置我的聊天服务器数据源（如果没有变化则不重置，以免订阅者的后续操作）
    private func setMyChatServerGroups(_ chatServers: [UserChatServerGroup]) {
        var servers = chatServers
        // 在团队则添加团队IM服务器
        if let teamInfo = self.myCompanyInfo {
            let chatServer = UserChatServerGroup.init(id: teamInfo.id, name: teamInfo.name, value: teamInfo.imServer)
            servers = servers.filter({ $0.id != teamInfo.id }) + [chatServer]
        }
        
        let oldServers = self.chatServerGroups
        if oldServers.count > 0 && oldServers.count == servers.count {
            var isDifferent = false// 聊天服务是否有变化flg
            
            servers.forEach { serverGroup in
                let difServers = oldServers.filter { $0 != serverGroup }
                
                if difServers.count > 0 {
                    isDifferent = true
                    return
                }
            }
            
            if isDifferent {// 如有变化则更新数据
                self.chatServerGroups = servers
            }
        } else {
            self.chatServerGroups = servers
        }
        
        self.save()
    }
    
    // 查询我的聊天服务器地址信息
    func getMyServerGroup(successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        BlockchainHelper.getServerGroup(mainAddress: self.address, count: 100, index: "", successBlock: { [weak self] (json) in
            guard let strongSelf = self else { return }
            let chatServers = json["groups"].arrayValue.compactMap { UserChatServerGroup.init(json: $0) }
            if chatServers.count > 0 {
                strongSelf.setMyChatServerGroups(chatServers)
                strongSelf.hasServer = true
            }
            
            successBlock?(json)
        }, failureBlock: { (error) in
            FZMLog("getMyServerGroup失败:\(error)")
            failureBlock?(error)
        })
    }
    
    // 添加聊天服务器
    func addServerGroup(server: UserChatServerGroup, successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        isAddServerGroupRequesting = true
        BlockchainHelper.addServerGroup(name: server.name, value: server.value) { [weak self] (json) in
            guard let strongSelf = self else { return }
            // 合约有延迟，不能马上获取到最新的信息
//            self.refreshUserInfo()
            
            strongSelf.hasServer = true
            strongSelf.isAddServerGroupRequesting = false
            
            // 聊天服务器数据源赋值
            strongSelf.chatServerGroups = strongSelf.chatServerGroups + [server]
            
            successBlock?(json)
        } failureBlock: { [weak self] (error) in
            FZMLog("addServerGroup失败:\(error)")
            guard let strongSelf = self else { return }
            strongSelf.isAddServerGroupRequesting = false
            failureBlock?(error)
        }
    }
    
    // 删除聊天服务器
    func deleteServerGroup(server: Server, successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        BlockchainHelper.deleteServerGroup(id: server.id, name: server.name, value: server.value) { [weak self] (json) in
            guard let strongSelf = self else { return }
            
            strongSelf.chatServerGroups = strongSelf.chatServerGroups.filter { $0.id != server.id }
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("deleteServerGroup失败:\(error)")
            failureBlock?(error)
        }
    }
    
    // 更新聊天服务器信息
    func updateServerGroup(server: Server, successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        BlockchainHelper.updateServerGroup(id: server.id, name: server.name, value: server.value) { [weak self] (json) in
            guard let strongSelf = self else { return }
            
            strongSelf.chatServerGroups = strongSelf.chatServerGroups.filter { $0.id != server.id } + [UserChatServerGroup.init(server: server)]
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("updateServerGroup失败:\(error)")
            failureBlock?(error)
        }
    }
}

extension LoginUser {
    
    func login(seed: String, encSeed: String = "", priKey: String, pubKey: String, address: String, isLogin: Bool = true) {
        self.seed = seed
        self.encryptedSeed = encSeed
        self.privateKey = priKey.finalKey
        self.publicKey = pubKey.finalKey
        self.address = address
        self.save()
        self.refreshUserInfo()
        if isLogin {// 如果是手动登录则修改登录方式标记
            APP.shared().isAutoLogin = false
        }
    }
    
    // 登录
    func login() {
        // 离线通知开启
        AppDelegate.shared().umRegisterForRemoteNotifi()
        
        if let staffinfo = TeamManager.shared().getDBStaffInfo(address: self.address) {
            self.myStaffInfo = staffinfo
            if let teaminfo = TeamManager.shared().getDBTeamInfo(entId: staffinfo.entId) {
                self.myCompanyInfo = teaminfo
            }
        }
        
        // 刷新我的个人信息
        self.refreshUserInfo()
        
        // 更新数据源出发didSet方法
        var curServers = self.chatServerGroups
        
        if let server = TeamIMChatServer {
            // 获取IMServerUrl和chatServerGroups，合并后连接websocket
            let chatServer = UserChatServerGroup.init(server: server)
            curServers = curServers.filter({ $0.id != chatServer.id }) + [chatServer]
        }
        
        self.chatServerGroups = curServers
        
        // 发出登录通知
        FZM_NotificationCenter.post(name: FZM_Notify_UserLogin, object: self)
    }
    
    // 登出
    func logout() {
        // 离线通知关闭
        AppDelegate.shared().umUnregisterForRemoteNotifi()
        
        // 清空推送消息，app角标置为0
        FZMUIMediator.shared().setApplicationIconBadgeNumber(0)
        
        // 清除用户信息相关数据
        self.clear()
        
        // 发出登出通知
        FZM_NotificationCenter.post(name: FZM_Notify_UserLogout, object: self)
    }
    
    // 解散/退出团队
    func quitTeam() {
        
        if let server = TeamIMChatServer {
            // 断开团队的IM服务器
            self.chatServerGroups = self.chatServerGroups.filter( { $0.id != server.id } )
        }
        
        // 如果当前使用的区块链节点是团队的，退出团队则需重置区块链节点地址
        if let teaminfo = self.myCompanyInfo, let server = BlockchainServerInUse, server.id == teaminfo.id {
            // 如果有默认区块链节点
            if let server = OfficialBlockchainServers?.first {
                BlockchainServerInUse = server
            } else {
                // 如果有保存的节点
                if let blockchainServers = UserDefaultsDB.chainServerList, let server = blockchainServers.first {
                    BlockchainServerInUse = server
                } else {
                    APP.shared().getOfficialServerRequest { (json) in
                        let servers = json["nodes"].arrayValue.compactMap {
                            Server.init(name: $0["name"].stringValue, value: $0["address"].stringValue)
                        }
                        if let server = servers.first {
                            BlockchainServerInUse = server
                        }
                        
                    } failureBlock: { (error) in
                        
                    }
                }
            }
        }
        
        
        TeamIMChatServer = nil
        TeamBlockchainServer = nil
        TeamOAServerUrl = ""
        
        self.isInTeam = false
        self.myStaffInfo = nil
        self.myCompanyInfo = nil
        self.save()
        
        FZM_NotificationCenter.post(name: FZM_Notify_InTeamStatusChanged, object: false)
    }
}

extension LoginUser: Codable {
    
    func save() {
        UserDefaultsDB.loginUser = self
    }
    
    func clear() {
        self.seed = ""
        self.encryptedSeed = ""
        self.privateKey = ""
        self.publicKey = ""
        self.address = ""
        self.avatarUrl = ""
        self.btyAddr = ""
        self.ethAddr = ""
        self.bnbAddr = ""
        self.needConnectServers.removeAll()
        self.chatServerGroups.removeAll()
        self.nickName = nil
        self.phone = nil
        
        self.bindSeedEmail = ""
        self.bindSeedPhone = ""
        
        self.isInTeam = false
        self.myStaffInfo = nil
        self.myCompanyInfo = nil
        
        self.signToken = ""
        self.lastSignTime = 0
        
        self.hasPublicKey = false
        self.hasServer = false
        self.isAddServerGroupRequesting = false
        
        TeamIMChatServer = nil
        TeamBlockchainServer = nil
        TeamOAServerUrl = ""
        WalletServerUrl = ""
        
        UserDefaultsDB.loginUser = nil
        
        let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
        PWDataBaseManager.shared().deleteCoin(wallet)
        PWDataBaseManager.shared().delete(wallet)
        
    }
    
    private enum CodingKeys: CodingKey {
        case seed, encryptedSeed, privateKey, publicKey, address, avatarUrl, chatServerGroup, chatServers, nickName, phone, bindSeedPhone ,bindSeedEmail,bnbAddr,ethAddr,btyAddr
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seed, forKey: .seed)
        try container.encode(encryptedSeed, forKey: .encryptedSeed)
        try container.encode(privateKey, forKey: .privateKey)
        try container.encode(publicKey, forKey: .publicKey)
        try container.encode(address, forKey: .address)
        try container.encode(avatarUrl, forKey: .avatarUrl)
        try container.encode(chatServerGroups, forKey: .chatServerGroup)
        try container.encode(ethAddr, forKey: .ethAddr)
        try container.encode(bnbAddr, forKey: .bnbAddr)
        try container.encode(btyAddr, forKey: .btyAddr)
//        try container.encode(chatServers, forKey: .chatServers)
        try container.encode(nickName, forKey: .nickName)
        try container.encode(phone, forKey: .phone)
        try container.encode(bindSeedPhone, forKey: .bindSeedPhone)
        try container.encode(bindSeedEmail, forKey: .bindSeedEmail)
    }
    
    internal convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.seed = try container.decode(String.self, forKey: .seed)
        self.encryptedSeed = try container.decode(String.self, forKey: .encryptedSeed)
        self.privateKey = try container.decode(String.self, forKey: .privateKey)
        self.publicKey = try container.decode(String.self, forKey: .publicKey)
        self.address = try container.decode(String.self, forKey: .address)
        self.avatarUrl = try container.decode(String.self, forKey: .avatarUrl)
        self.ethAddr = try container.decode(String.self, forKey: .ethAddr)
        self.bnbAddr = try container.decode(String.self, forKey: .bnbAddr)
        self.btyAddr = try container.decode(String.self, forKey: .btyAddr)
//        self.chatServers = try container.decode([UserChatServer].self, forKey: .chatServers)
        self.chatServerGroups = try container.decode([UserChatServerGroup].self, forKey: .chatServerGroup)
        self.nickName = try? container.decode(UserInfoField.self, forKey: .nickName)
        self.phone = try? container.decode(UserInfoField.self, forKey: .phone)
        self.bindSeedPhone = try container.decode(String.self, forKey: .bindSeedPhone)
        self.bindSeedEmail = try container.decode(String.self, forKey: .bindSeedEmail)
    }
}

extension LoginUser {
    var fileDirectory: URL? {
        guard self.isLogin, !self.address.isEmpty else { return nil }
        return DocumentDirectory.appendingPathComponent(self.address + "/")
    }
}

extension LoginUser {
    
    var signature: String? {
        guard self.isLogin, !self.publicKey.isEmpty, !self.privateKey.isEmpty else {
            return nil
        }
        
        let timestamp = Date.timestamp
        
        guard timestamp - lastSignTime > 10*1000 else {
            return signToken
        }
        
        let random = String.random(ofLength: 8)
        let message = "\(timestamp)" + "*" + random
        
        guard let rawValue = message.data(using: .utf8)?.sha256(),
              let signature =  EncryptManager.signBase64(data: rawValue, privateKey: self.privateKey) else {
            return nil
        }
        signToken = signature.finalKey + "#" + message + "#" + self.publicKey
        lastSignTime = timestamp
        return signToken
    }
}
