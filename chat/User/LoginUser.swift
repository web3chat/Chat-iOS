//
//  LoginUser.swift
//  xls
//
//  Created by fzm on 2020/8/26.
//  Copyright © 2020 fzm. All rights reserved.
//

import UIKit
import SwiftyJSON
import SwifterSwift

final class LoginUser {
    
    /// 「上次登录的地址」持久化 key。
    /// 登录页 `UserLoginVC` 退出登录后回到本页时，用它决定默认选中哪个账号。
    /// 注意：所有登录入口（账号密码页/手机号/重置助记词/S2/导入助记词/备份助记词/切换账号）都走
    /// `login(seed:encSeed:priKey:pubKey:address:encPasswd:)`，logout 走 `logout()`，
    /// 故只在这两处维护，避免某个入口漏写导致页面显示成「其它账号」。
    static let lastLoginAddressKey = "last_login_address"
    
    private static let sharedInstance = UserDefaultsDB.loginUser ?? LoginUser.init()
    
    class func shared() -> LoginUser {
        return sharedInstance
    }
    private let bag = DisposeBag.init()
    
    private(set) var seed = ""
    var encryptedSeed = ""
    var encryptedPasswd = ""
    private(set) var privateKey = ""
    private(set) var publicKey = ""
    private(set) var address = ""
    
    var avatarUrl = ""
    var bnbAddr = ""
    var ethAddr = ""
    var btyAddr = ""
    var polAddr = ""
    
    
    private(set) lazy var chatServerGroupsSubject  = PublishSubject<[UserChatServerGroup]>.init()// 只会发送给当前已经订阅这个subject的订阅者，新的订阅者不会收到订阅之前发送的事件
//    private(set) lazy var chatServerGroupsSubject = BehaviorSubject<[UserChatServerGroup]>.init(value: [])// 会发送最近的一个next事件给新的订阅者
    
    // 我的聊天服务器地址数据
    var chatServerGroups = [UserChatServerGroup]() {
        didSet {
            
            // 两级去重：
            //  1. 按 id —— 同一条服务器记录（原来只做了这一步）
            //  2. 按 value（服务器地址）—— 服务端 chatServers 里可能返回多条「同名同地址」的节点，
            //     只按 id 去重去不掉，服务器列表里就会出现好几个一模一样的服务器
            //     （顺带也会重复建立 socket 连接，MultipleSocketManager 直接用这个数组）
            self.chatServerGroups = self.chatServerGroups
                .withoutDuplicates(keyPath: \.id)
                .withoutDuplicates(keyPath: \.value)
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
    
    var bindSeedPhone = "" // 登录的手机号
    var bindPhone = "" //绑定的手机号
    var bindSeedEmail = ""
    var bindWechat = ""
    var bindXiaohongshu = ""
    var bindDouyin = ""
    
    /// 登录态：**不能用 `seed` 判断** —— 明文助记词已不参与持久化，冷启动后内存里是空串。
    /// 用「地址 + 私钥」判断：三者（seed / privateKey / address）在 `login(...)` 里同时写入、
    /// 在 `clear()` 里同时清空，语义与原来一致。
    var isLogin: Bool { return !address.isEmpty && !privateKey.isEmpty }
    
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
        guard FZM_EnableEnterpriseFeature else { return }// 企业号功能关闭，不发员工/企业信息请求
        guard isLogin else { return }
        
        TeamManager.shared().getStaffInfo(address: self.address) { (info) in
            TeamManager.shared().getEnterPriseInfo(entId: info.entId)
        } failureBlock: { _ in
        }
    }
    
    // 刷新我的个人信息
    func refreshUserInfo(successBlock: (()->())? = nil, failureBlock: ((Error)->())? = nil) {
        guard self.isLogin else {
            failureBlock?(NSError.error(with: L("未登录")))
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
                if case .POL = field.name {
                    strongSelf.polAddr = field.value
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
            // ⚠️ 明文助记词已不落盘：冷启动时 `seed` 是空串（不会再有历史值），
            //    这时回落到登录时持久化下来的 `publicKey` —— 它就是 `SeedManager.keyBy(seed:)` 的派生结果。
            let localPubKey: String
            if !strongSelf.seed.isEmpty, let keys = SeedManager.keyBy(seed: strongSelf.seed) {
                localPubKey = keys.pubKey
            } else {
                localPubKey = strongSelf.publicKey
            }
            if pubKey.isEmpty, !localPubKey.isEmpty, !EncryptManager.publicKeyToAddress(publicKey: localPubKey).isEmpty, !strongSelf.hasPublicKey {
                let pubkey = localPubKey.finalKey
                
                User.updateUserPublickKey(targetAddress: strongSelf.address, pubKey: pubkey) { (_) in
                    strongSelf.hasPublicKey = true
                    strongSelf.publicKey = pubkey
                    strongSelf.save()
                } failureBlock: { (error) in
                    FZMLog("没有publickey则上传publickey ERROR \(error)")
                }
            }
            
            // 没有地址则上传地址
            if strongSelf.ethAddr.isEmpty || strongSelf.polAddr.isEmpty
            {
                // 没有币种 / 币没有地址时以前会强解包崩溃；取不到就跳过地址上传，继续缓存登录数据
                let arr = PWDataBaseManager.shared().queryCoinArrayBasedOnSelectedWalletID() as? [LocalCoin] ?? []
                if let coin = arr.first,
                   let ethaddr = coin.coin_address?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !ethaddr.isEmpty {
                    User.updateUserChainAddress(targetAddress: strongSelf.address, name: .eth, chainAddr: ethaddr) { (_) in
                        strongSelf.ethAddr = ethaddr
                        strongSelf.save()
                    } failureBlock: { (error) in
                        
                    }
                    
                    User.updateUserChainAddress(targetAddress: strongSelf.address, name: .pol, chainAddr: ethaddr) { (_) in
                        strongSelf.polAddr = ethaddr
                        strongSelf.save()
                    } failureBlock: { (error) in
                        
                    }
                }
            }
            // 缓存登录过的数据
            _ = PWDataBaseManager.shared().addUserInfo(withPhone:strongSelf.bindSeedPhone,
                                                       address: strongSelf.address,
                                                       address0x: strongSelf.ethAddr.isEmpty ? strongSelf.address : strongSelf.ethAddr,
                                                       avatarurl: strongSelf.avatarUrl,
                                                       name: strongSelf.nickName?.value ?? strongSelf.address,
                                                       encryptedRemembercode: strongSelf.encryptedSeed,
                                                       encryptedPassword: strongSelf.encryptedPasswd)
            
            strongSelf.save()
            successBlock?()
        }, failureBlock: nil)
        
//        Provider.request(BackupAPI.addressRetrieve(address: self.address), successBlock: { (json) in
//            self.bindSeedPhone = json["phone"].stringValue
//            self.bindSeedEmail = json["email"].stringValue
//        }, failureBlock: nil)
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
    
    func login(seed: String, encSeed: String, priKey: String, pubKey: String, address: String, isLogin: Bool = true,encPasswd:String) {
        self.seed = seed
        self.encryptedSeed = encSeed
        self.encryptedPasswd = encPasswd
        self.privateKey = priKey.finalKey
        self.publicKey = pubKey.finalKey
        self.address = address
        // 统一记录「当前登录的地址」：退出登录回到账号密码页时默认选中本账号
        UserDefaults.standard.set(address, forKey: LoginUser.lastLoginAddressKey)
        self.save()
        self.refreshUserInfo()
        if isLogin {// 如果是手动登录则修改登录方式标记
            APP.shared().isAutoLogin = false
        }
        
        // 重新登录后把推送注册补回来（logout() 会注销推送，不再登录就永远是关的）
        AppDelegate.shared().syncPushRegistration()
    }
    
    // 登录
    func login() {
        // ⚠️ 这里不再注册推送：本方法在启动流程里（launch → getRootVC）就会走到，
        //    早于 umPushConfig() 里的 UMConfigure 初始化；而且它不看「离线通知」开关，
        //    用户关掉通知后重启 App 会被它默默注册回来。
        //    现在统一由 AppDelegate.syncPushRegistration() 负责
        //    （启动后 / 手动登录后 / 设置页开关切换时都走它）。
        
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
        
        // 查询服务端账号绑定状态（手机号/微信/小红书）
        self.queryBindStatus()
        
        // 发出登录通知
        FZM_NotificationCenter.post(name: FZM_Notify_UserLogin, object: self)
    }
    
    /// 登录后查询服务端绑定的手机号/微信/小红书账号
    private func queryBindStatus() {
        let addr = address
        FZMLog("queryBindStatus 开始查询，address: \(addr)")
        guard !addr.isEmpty else {
            FZMLog("queryBindStatus 跳过：address 为空")
            return
        }
        let api = S1BackUpAPI.queryAccounts(chataddress: addr)
        Provider.request(api, successBlock: { [weak self] json in
            guard let self = self else { return }
            FZMLog("queryBindStatus 成功: \(json)")
            let data = json["data"]
            let phone = data["phone"].stringValue
            let wechat = data["wechat_id"].stringValue
            let xiaohongshu = data["xiaohongshu_id"].stringValue
            
            var needSave = false
            if !phone.isEmpty {
                self.bindPhone = phone
                needSave = true
            }
            if !wechat.isEmpty {
                self.bindWechat = wechat
                needSave = true
            }
            if !xiaohongshu.isEmpty {
                self.bindXiaohongshu = xiaohongshu
                needSave = true
            }
            let douyin = data["douyin_id"].stringValue
            if !douyin.isEmpty {
                self.bindDouyin = douyin
                needSave = true
            }
            if needSave {
                self.save()
            }
        }, failureBlock: { error in
            FZMLog("queryBindStatus 失败: \(error.localizedDescription)")
        })
    }
    
    // 登出
    func logout() {
        // 记录本次退出的账号：退出后回到账号密码页时默认选中它，避免显示成其它账号
        // （logout 内部会 clear 掉 address，所以这里必须先记）
        if !self.address.isEmpty {
            UserDefaults.standard.set(self.address, forKey: LoginUser.lastLoginAddressKey)
        }
        
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
        
        self.saveLoginUsersInfo()
        
        self.seed = ""
        self.encryptedSeed = ""
        self.encryptedPasswd = ""
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
        self.bindPhone = ""
        self.bindWechat = ""
        self.bindXiaohongshu = ""
        self.bindDouyin = ""
        
        self.isInTeam = false
        self.myStaffInfo = nil
        self.myCompanyInfo = nil
        
        // 和 `signature` 用同一把锁：登出/换账号时清零签名缓存，避免和正在签名的线程撞上
        loginUserSignLock.lock()
        self.signToken = ""
        self.lastSignTime = 0
        loginUserSignLock.unlock()
        
        self.hasPublicKey = false
        self.hasServer = false
        self.isAddServerGroupRequesting = false
        
        TeamIMChatServer = nil
        TeamBlockchainServer = nil
        TeamOAServerUrl = ""
        WalletServerUrl = ""
        
        UserDefaultsDB.loginUser = nil
        
    }
    
    func saveLoginUsersInfo() {
        let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
        
//        let userDict = ["wallet":wallet?.wallet_remembercode as Any,
//                        "useravatar":self.avatarUrl,
//                        "userNickName":self.nickName?.value as Any,
//                        "addr":self.address] as [String : Any] // 缓存数据：钱包 用户数据 地址（唯一性）
//        let userDict = ["wallet":wallet?.wallet_remembercode as Any,
//                        "user":self,
//                        "addr":self.address] as [String : Any] // 缓存数据：钱包 用户数据 地址（唯一性）
        
        
        let walletre = wallet?.wallet_remembercode
        let userAvatar = self.avatarUrl.count == 0 ? "no":self.avatarUrl
        let nickName = self.nickName?.value ?? self.address
        let address = self.address
        let passwd = wallet?.wallet_password
        
        let userInfo1 = walletre! + "&" + userAvatar + "&"
        let userInfo2 =  nickName + "&" + address
        let userInfo = userInfo1 + userInfo2 + "&" + passwd!
        
//        let userAddrArr = NSMutableArray.init()
       
        let  userLoginInfoArr = UserDefaults.standard.array(forKey: "user_login_infos")
        
        var userLoginInfoMarry = NSMutableArray.init()
        if userLoginInfoArr != nil {
            userLoginInfoMarry =  NSMutableArray(array: userLoginInfoArr!)
        }
        
        if  userLoginInfoMarry.count == 0 {
            userLoginInfoMarry.add(userInfo)
        }else{
            
            for item in userLoginInfoMarry {
                if let info = item as? String{
                    let infoarr = info.components(separatedBy: "&")
                    let addr = infoarr[3]
                    if self.address == addr{
                        userLoginInfoMarry.remove(item)
                        break
                    }
                }
            }
            userLoginInfoMarry.add(userInfo)
            
        }
       
        let userArr = NSArray(array: userLoginInfoMarry)
        UserDefaults.standard.set(userArr, forKey: "user_login_infos")
        // 多账号下本地 wallet/coin 需持久保留，切换/登出会话清理不应删除库内钱包，否则切回账号后自定义币种会丢失。
    }
    
    /// ⚠️ `seed`（**明文助记词**）不参与持久化，只活在内存里。
    ///
    /// 落盘（`UserDefaults(key: "chat_save_user")`）只保留密文 / hash：
    /// `encryptedSeed`（密聊密码加密后的助记词）、`encryptedPasswd`（加盐 hash）。
    /// 历史版本把明文助记词一起写进过这份 JSON，改完以后由 `save()` 重写整块数据自然抹掉
    /// （App 启动时也会主动重写一次，见 `APP.didFinishLaunching()`），所以**不要**再把 `seed` 加回来。
    private enum CodingKeys: CodingKey {
        case encryptedSeed, privateKey, publicKey, address, avatarUrl, chatServerGroup, chatServers, nickName, phone, bindSeedPhone,bindPhone ,bindSeedEmail, bindWechat, bindXiaohongshu, bindDouyin, bnbAddr, ethAddr, btyAddr, encryptedPasswd
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(encryptedSeed, forKey: .encryptedSeed)
        try container.encode(encryptedPasswd, forKey: .encryptedPasswd)
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
        try container.encode(bindPhone, forKey: .bindPhone)
        try container.encode(bindSeedEmail, forKey: .bindSeedEmail)
        try container.encode(bindWechat, forKey: .bindWechat)
        try container.encode(bindXiaohongshu, forKey: .bindXiaohongshu)
        try container.encode(bindDouyin, forKey: .bindDouyin)
    }
    
    internal convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 不读取明文助记词（历史数据里即便残留也直接忽略），密文照旧
        self.encryptedSeed = try container.decode(String.self, forKey: .encryptedSeed)
        self.encryptedPasswd = try container.decode(String.self, forKey: .encryptedPasswd)
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
        self.bindPhone = try container.decode(String.self, forKey: .bindPhone)
        self.bindSeedEmail = try container.decode(String.self, forKey: .bindSeedEmail)
        self.bindWechat = (try? container.decode(String.self, forKey: .bindWechat)) ?? ""
        self.bindXiaohongshu = (try? container.decode(String.self, forKey: .bindXiaohongshu)) ?? ""
        self.bindDouyin = (try? container.decode(String.self, forKey: .bindDouyin)) ?? ""
    }
}

extension LoginUser {
    var fileDirectory: URL? {
        guard self.isLogin, !self.address.isEmpty else { return nil }
        return DocumentDirectory.appendingPathComponent(self.address + "/")
    }
}

/// 签名缓存（`signToken` / `lastSignTime`）的互斥锁。
///
/// `signature` 会被**主线程**（页面 `viewDidLoad` 里发请求）和**后台线程**（socket / 上传 / 轮询）
/// 同时调用，而它内部会读写单例上的 `signToken`（一个 Swift `String`）。
/// 并发写 String 会把它的缓冲区踩坏，随后在任意一次 retain/release 里崩 —— 崩溃栈形如：
///     XLSTargetType.headers.getter → libswiftCore
/// （静默期在 10 秒内时更是频繁）所以这里把读写全串起来。取值逻辑不变。
private let loginUserSignLock = NSLock()

extension LoginUser {
    
    var signature: String? {
        loginUserSignLock.lock()
        defer { loginUserSignLock.unlock() }

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
