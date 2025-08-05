//
//  UserManager.swift
//  chat
//
//  Created by 陈健 on 2021/1/14.
//

import Foundation
import WCDBSwift

class UserManager {
    
    private static let sharedInstance = UserManager.init()
    static func shared() -> UserManager { return sharedInstance }
    
    // 所有用户
    private(set) lazy var allusersSubject = BehaviorSubject<[User]>.init(value: [])
    private(set) var users = [User]() {
        didSet {
            DispatchQueue.main.async {
                self.allusersSubject.onNext(self.users)
            }
        }
    }
    
    // 好友用户
    private(set) lazy var friendsSubject = BehaviorSubject<[User]>.init(value: [])
    private(set) var friends = [User]() {
        didSet {
            DispatchQueue.main.async {
                self.friendsSubject.onNext(self.friends)
            }
        }
    }
    
    private let disposeBag = DisposeBag.init()
    
    private init() {
        self.addLoginObserver()
        if LoginUser.shared().isLogin {
            let _ = self.loadDBFriends()
            
            self.getBlackList()
            
            self.getNetFriends()
        }
    }
}


//MARK: - User Net
extension UserManager {
    
    // 加入黑名单
    func addShieldUser(by address: String, successBlock: ((User)->())?, failureBlock: Provider.FailureBlock?) {
        // 写入合约
        BlockchainHelper.addBlackList(address: [address], successBlock: { (json) in
            var user = User.init(shieldUser: json)
            if let dbUser = self.getDBUser(with: user.address) {
//                user.alias = dbUser.alias
//                user.isFriend = dbUser.isFriend
//                user.isShield = true
//                user.isOnTop = dbUser.isOnTop
//                user.isMuteNotification = dbUser.isMuteNotification
                user = dbUser
                user.isShield = true
            }
            
            // 更新用户黑名单标识
            self.updateUserIsShield(address: address, isShield: true)
            
            // 如果原本是好友则加入好友数据源
            self.friends.removeAll { $0.address == address }
            
            successBlock?(user)
        }, failureBlock: failureBlock)
    }
    
    // 移出黑名单
    func deleteShieldUser(by address: String, successBlock: (()->())?, failureBlock: Provider.FailureBlock?) {
        let addresses = (address)
        BlockchainHelper.deleteBlackList(address: [addresses], successBlock: { (json) in
            
            // 更新用户黑名单标识
            self.updateUserIsShield(address: address, isShield: false)
            
            // 如果原本是好友则加入好友数据源
            if var user = self.getDBUser(with: address), user.isFriend == true {
                user.isShield = false
                self.friends += [user]
            }
            
            successBlock?()
        }, failureBlock: failureBlock)
    }
    
    // 获取用户信息
    func getNetUser(targetAddress: String, successBlock: ((User) ->())? = nil, failureBlock: Provider.FailureBlock? = nil) {
        User.getUser(targetAddress: targetAddress, count: 100, index: "", successBlock: { (json) in
            
            var user = User.init(user: targetAddress, json: json)
            if let dbUser = self.getDBUser(with: user.address) {
                user.alias = dbUser.alias
                user.isFriend = dbUser.isFriend
                user.isShield = dbUser.isShield
                user.isOnTop = dbUser.isOnTop
                user.isMuteNotification = dbUser.isMuteNotification
            }
            
            if user.isFriend == true && user.isShield == false {
                if let dbFriend = self.friends.filter({ $0.address == targetAddress }).first {
                    if user.avatarURLStr != dbFriend.avatarURLStr || user.nickname != dbFriend.nickname {
                        var allFriends = self.friends
                        allFriends.removeAll { $0.address == targetAddress }
                        allFriends += [user]
                        self.friends = allFriends
                    }
                }
            }
            
            // 保存用户到数据库
            self.updateDBUser(user)
            
            // 更新会话名称和头像
            var contactName = user.contactsName
            if let dbUser = self.user(by: targetAddress) {
                // 如果用户已存在本地数据库则重新获取name（给好友设置了备注名）
                contactName = dbUser.contactsName
            }
            SessionManager.shared().updateSessionNameAndImageURLStr(session: user.sessionID, name: contactName, imageURLStr: user.avatarURLStr)
            
            successBlock?(user)
        }, failureBlock: failureBlock)
    }
    
    // 获取好友信息
    func getNetFriends(successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        BlockchainHelper.getFriends(count: 100000, index: "") { (json) in
            let friends = json["friends"].arrayValue.compactMap { (json) -> User in
                var user = User.init(friend: json)
                if let dbUser = self.getDBUser(with: user.address) {
//                    user.alias = dbUser.alias
//                    user.isShield = dbUser.isShield
//                    user.isFriend = dbUser.isFriend
//                    user.isOnTop = dbUser.isOnTop
//                    user.isMuteNotification = dbUser.isMuteNotification
                    user = dbUser
                    user.isFriend = true
                }
                self.updateDBUser(user)
                return user
            }
            let _ = self.loadDBFriends()
            
            self.refreshUsersInfo(friends)
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("获取合约好友列表失败:\(error)")
            failureBlock?(error)
        }
    }
    
    // 获取黑名单列表
    func getBlackList(successBlock: (([User]) ->())? = nil, failureBlock: Provider.FailureBlock? = nil) {
        BlockchainHelper.getBlackList(count: 100000, index: "") { (json) in
            let shieldUsers = json["list"].arrayValue.compactMap { (json) -> User in
                var user = User.init(shieldUser: json)
                if let dbUser = self.getDBUser(with: user.address) {
//                    user.alias = dbUser.alias
//                    user.isFriend = dbUser.isFriend
//                    user.isShield = dbUser.isShield
//                    user.isOnTop = dbUser.isOnTop
//                    user.isMuteNotification = dbUser.isMuteNotification
                    user = dbUser
                    user.isShield = true
                }
                self.updateDBUser(user)
                return user
            }
            
            let _ = self.loadDBFriends()
            
            self.refreshUsersInfo(shieldUsers)
            
            successBlock?(shieldUsers)
        } failureBlock: { (error) in
            FZMLog("获取黑名单列表失败:\(error)")
            failureBlock?(error)
        }
    }
    
    /// 刷新好友用户信息-获取用户详情请求
    func refreshUsersInfo(_ contacts: [Contacts]) {
        DispatchQueue.global().async {
            contacts.forEach { (item) in
                self.getNetUser(targetAddress: item.sessionID.idValue, successBlock: nil, failureBlock: nil)
            }
        }
    }
    
    // 加好友
    func addFriend(by address: String, successBlock: ((User)->())?, failureBlock: Provider.FailureBlock?) {
        // 已加好友时直接返回
        if let friend = self.friend(by: address) {
            successBlock?(friend)
            return
        }
        var groups = [String]()
        
        // 自己的接收聊天服务器地址
        let chatServerGroups = LoginUser.shared().chatServerGroups
        if !chatServerGroups.isEmpty {
            // 好友有chatServer时
            if let user = self.user(by: address), !user.chatServers.isEmpty {
                // 判断自己连接的与好友连接的chatServer是否有重合，有则给好友分配该地址
                chatServerGroups.forEach { server in
                    if user.chatServers.contains(server.value) {
                        groups = [server.id]
                        return
                    }
                }
            }
            
            // 自己连接的chatServer好友连接的chatServer没有一个相同时，分配给好友一个默认的接收地址
            if groups.isEmpty {
                groups = [chatServerGroups.first!.id]
            }
        }
        
        let addressAndGroups = (address: address, groups: groups)
        BlockchainHelper.addOrUpdateFriends(addressAndGroups: [addressAndGroups], successBlock: { (json) in
            
            var user = User.init(friend: json)
            
            // 更新用户好友标识
            self.updateUserIsFriend(address: address, isFriend: true)
            if let dbUser = self.getDBUser(with: address) {
//                user.alias = dbUser.alias
//                user.isShield = dbUser.isShield
//                user.isFriend = true
//                user.isOnTop = dbUser.isOnTop
//                user.isMuteNotification = dbUser.isMuteNotification
                user = dbUser
                user.isFriend = true
            }
            self.friends += [user]
            
            
            successBlock?(user)
        }, failureBlock: failureBlock)
    }
    
    // 删除好友
    func deleteFriend(by address: String, successBlock: (()->())?, failureBlock: Provider.FailureBlock?) {
        let addressAndGroups = (address: address, groups: [String]())
        BlockchainHelper.deleteFriends(addressAndGroups: [addressAndGroups], successBlock: { (json) in
            // 更新用户好友标识
            self.updateUserIsFriend(address: address, isFriend: false)
            self.friends.removeAll { $0.address == address }
            successBlock?()
        }, failureBlock: failureBlock)
    }
}

//MARK: - DB User
extension UserManager {
    // 更新会话免打扰状态
    func updateUserMuteNotifacation(address: String, isMuteNoti: Bool)  {
        guard var user = self.user(by: address) else { return }
        user.isMuteNotification = isMuteNoti
        self.updateDBUser(user)
    }

    // 更新会话置顶状态
    func updateUserIsOnTop(address: String, isOnTop: Bool)  {
        guard var user = self.user(by: address) else { return }
        user.isOnTop = isOnTop
        self.updateDBUser(user)
    }
    
    // 更新用户好友标识
    func updateUserIsFriend(address: String, isFriend: Bool)  {
        guard var user = self.user(by: address) else { return }
        user.isFriend = isFriend
        self.updateDBUser(user)
    }
    
    // 更新用户黑名单标识
    func updateUserIsShield(address: String, isShield: Bool)  {
        guard var user = self.user(by: address) else { return }
        user.isShield = isShield
        self.updateDBUser(user)
    }
    
    // 从 临时数据源 或 数据库 获取用户信息
    func user(by address: String) -> User? {
        if let user = self.users.filter({ $0.address == address }).first  {
            return user
        }
        guard let user = self.getDBUser(with: address) else {
            return nil }
        self.users.append(user)
        return user
    }
    
    // 从 临时数据源 或 数据库 或 链上 获取用户信息
    func getUser(by address: String, userInfoBlock: ((User?) ->())?) {
        var dbUser: User?
        if let user = self.users.filter({ $0.address == address }).first  {
            dbUser = user
        } else if let user = self.getDBUser(with: address) {
            self.users.append(user)
            dbUser = user
        }
        if dbUser == nil {
            DispatchQueue.global().async {
                self.getNetUser(targetAddress: address) { (user) in
                    userInfoBlock?(user)
                } failureBlock: { _ in
                    userInfoBlock?(nil)
                }
            }
        } else {
            userInfoBlock?(dbUser)
        }
    }
    
    // 从 临时数据源 或 数据库 或 链上 获取用户公钥
    func getUserPublickey(by address: String, userPublickeyBlock: StringBlock?) {
        UserManager.shared().getUser(by: address) { (user) in
            var publicKey = ""
            if let pubkey = user?.publicKey, !pubkey.isBlank {
                publicKey = pubkey
            }
            userPublickeyBlock?(publicKey)
        }
    }
    
    // 从数据库获取用户信息
    private func getDBUser(with address: String) -> User? {
        let users: [User] = DBManager.shared().getObjects(fromTable: .user) { (constraint) in
            constraint.condition = UserDB.Properties.address.in(address)
        }.compactMap { User.init(with: $0) }
        guard let user = users.first else {
            return nil
        }
        
        // users缓存添加新数据
        self.addUsersInCacheWithOutRepeat(users: [user])
        
        return user
    }
    
    // users缓存添加新数据（已有用户先删除老数据再添加新数据）
    private func addUsersInCacheWithOutRepeat(users : [User]) {
        guard !users.isEmpty else { return }
        
        var allFriends = self.friends
        var isFriendsDataChanged = false
        
        users.forEach { item in
            self.users = self.users.filter({ $0.address != item.address }) + [item]
            
            if let _ = allFriends.filter({ $0.address == item.address }).first {
                allFriends = allFriends.filter({ $0.address != item.address }) + [item]
                isFriendsDataChanged = true
            }
        }
        
        if isFriendsDataChanged {
            self.friends = allFriends
        }
    }
    
    // 保存用户信息
    func saveUsersInDB(_ users: [User]) {
        guard users.count > 0 else { return }
        // users缓存添加新数据
        self.addUsersInCacheWithOutRepeat(users: users)
        
        let userDBs = users.compactMap { UserDB.init(with: $0) }
        DBManager.shared().insertOrReplace(intoTable: .user, list: userDBs)
    }
    
    // 更新用户信息
    func updateDBUser(_ user: User) {
        guard let oldUser = self.getDBUser(with: user.address) else {
            self.saveUsersInDB([user])
            return
        }
        
        var updatePropertys = [PropertyConvertible]()
        
        if oldUser.publicKey != user.publicKey {
            updatePropertys.append(UserDB.Properties.publicKey)
        }
        if oldUser.imageURLStr != user.imageURLStr {
            updatePropertys.append(UserDB.Properties.imageURLStr)
        }
        if oldUser.nickname != user.nickname {
            updatePropertys.append(UserDB.Properties.nickname)
        }
        if oldUser.phone != user.phone {
            updatePropertys.append(UserDB.Properties.phone)
        }
        if oldUser.chatServers != user.chatServers {
            updatePropertys.append(UserDB.Properties.chatServers)
        }
        if oldUser.createTime != user.createTime {
            updatePropertys.append(UserDB.Properties.createTime)
        }
        if oldUser.groups != user.groups {
            updatePropertys.append(UserDB.Properties.groups)
        }
        if oldUser.alias != user.alias {
            updatePropertys.append(UserDB.Properties.alias)
        }
        if oldUser.isOnTop != user.isOnTop {
            updatePropertys.append(UserDB.Properties.isOnTop)
        }
        if oldUser.isMuteNotification != user.isMuteNotification {
            updatePropertys.append(UserDB.Properties.isMuteNotification)
        }
        if oldUser.isFriend != user.isFriend {
            updatePropertys.append(UserDB.Properties.isFriend)
        }
        if oldUser.isShield != user.isShield {
            updatePropertys.append(UserDB.Properties.isShield)
        }
        guard !updatePropertys.isEmpty else { return }
        
        // users缓存添加新数据
        self.addUsersInCacheWithOutRepeat(users: [user])
        
        let userDB = UserDB.init(with: user)
        DBManager.shared().update(table: .user, on: updatePropertys, with: userDB) { (constraint) in
            constraint.condition = UserDB.Properties.address == userDB.address
        }        
    }
}


//MARK: - 处理用户数据返回通讯录可使用数据
extension UserManager {// 按用户名称首字母分组成通讯录数据
    func divideGroup(_ contactsArr: [Group]) -> [(serverUrl: String, value: [(title: String, value: [ContactViewModel])])] {
        
//        let groupDic = contactsArr.reduce(into: Dictionary<String, [Group]>.init()) { (dic, group) in
//            let key = group.chatServerUrl ?? "unknow"
//            if dic[key] == nil {
//                var arr = Array<Group>.init()
//                arr.append(group)
//                dic[key] = arr
//            } else {
//                dic[key]?.append(group)
//            }
//        }
        
        var groupDic = [String:Array<Group>]()
        LoginUser.shared().chatServerGroups.forEach { (chatServerItem) in
            let serverUrl = chatServerItem.value
            var arrGroup = Array<Group>.init()
            contactsArr.forEach { (group) in
                if group.chatServerUrl == serverUrl{
                    arrGroup.append(group)
                }
            }

            groupDic += [serverUrl:arrGroup]
        }
        
        var finalList = [(serverUrl: String, value: [(title: String, value: [ContactViewModel])])]()
        
        for item in groupDic {
            let contactsList = item.value.compactMap { ContactViewModel.init(with: $0) }
            if contactsList.count > 0 {
                var divideContacts = contactsList.reduce(into: Dictionary<String,[ContactViewModel]>.init()) { (dic, contacts) in
                    let key = contacts.name.firstLetter()
                    if dic[key] == nil {
                        var arr = Array<ContactViewModel>.init()
                        arr.append(contacts)
                        dic[key] = arr
                    } else {
                        dic[key]?.append(contacts)
                    }
                }.compactMap { (title: $0.key, value: $0.value) }.sorted { $0.title < $1.title }
                
                if divideContacts.first?.title == "#" {
                    divideContacts.append(divideContacts.removeFirst())
                }
                finalList.append((serverUrl: item.key, value: divideContacts))
            }else{
                finalList.append((serverUrl: item.key, value: []))
            }
        }
        
        finalList = finalList.sorted { $0.serverUrl < $1.serverUrl }
        
        
        return finalList
    }
    
    // 按群成员首字母分组成通讯录数据
    func divideGroupMember(_ contactsArr: [GroupMember]) -> [(title: String, value: [ContactViewModel])] {
        let contactsList = contactsArr.compactMap { (member) -> ContactViewModel? in
            return ContactViewModel.init(with: member)
        }
        
        var divideContacts = contactsList.reduce(into: Dictionary<String,[ContactViewModel]>.init()) { (dic, contacts) in
            let key = contacts.name.firstLetter()
            if dic[key] == nil {
                var arr = Array<ContactViewModel>.init()
                arr.append(contacts)
                dic[key] = arr
            } else {
                dic[key]?.append(contacts)
            }
        }.compactMap { (title: $0.key, value: $0.value) }.sorted { $0.title < $1.title }
        
        // 同一分组内再次排序
        var tempContacts = divideContacts
        if tempContacts.count > 0 {
            for i in 0..<tempContacts.count {
                tempContacts[i].value = tempContacts[i].value.sorted { $0.sessionIDStr < $1.sessionIDStr }
            }
            divideContacts = tempContacts
        }
        
        return divideContacts
    }
    
    // 按群成员首字母分组成通讯录数据
    func normalGroupMember(_ contactsArr: [GroupMember]) -> [(title: String, value: [ContactViewModel])] {
        let contactsList = contactsArr.compactMap { (member) -> ContactViewModel? in
            return ContactViewModel.init(with: member)
        }
        
        var divideContacts = contactsList.reduce(into: Dictionary<String,[ContactViewModel]>.init()) { (dic, contacts) in
            if contacts.groupMember?.memberType == 1 || contacts.groupMember?.memberType == 2 {
                //群主和管理员不参与排序
                let key = ""
                if dic[key] == nil {
                    var arr = Array<ContactViewModel>.init()
                    arr.append(contacts)
                    dic[key] = arr
                } else {
                    dic[key]?.append(contacts)
                }
                
            }else{
                let key = contacts.name.firstLetter()
                if dic[key] == nil {
                    var arr = Array<ContactViewModel>.init()
                    arr.append(contacts)
                    dic[key] = arr
                } else {
                    dic[key]?.append(contacts)
                }
            }
            
            
        }.compactMap { (title: $0.key, value: $0.value) }.sorted { $0.title < $1.title }
        
        // 同一分组内再次排序
        var tempContacts = divideContacts
        if tempContacts.count > 0 {
            for i in 0..<tempContacts.count {
                tempContacts[i].value = tempContacts[i].value.sorted { $0.sessionIDStr < $1.sessionIDStr }
            }
            divideContacts = tempContacts
        }
        
        return divideContacts
    }
    
    
    // 按用户名称首字母分组成通讯录数据
    func divideUser(_ contactsArr: [User]) -> [(title: String, value: [ContactViewModel])] {
        let contactsList = contactsArr.compactMap { ContactViewModel.init(with: $0) }
        guard contactsList.count > 0 else { return [] }
        var divideContacts = contactsList.reduce(into: Dictionary<String,[ContactViewModel]>.init()) { (dic, contacts) in
            let key = contacts.name.firstLetter()
            if dic[key] == nil {
                var arr = Array<ContactViewModel>.init()
                arr.append(contacts)
                dic[key] = arr
            } else {
                dic[key]?.append(contacts)
            }
        }.compactMap { (title: $0.key, value: $0.value) }.sorted { $0.title < $1.title }
        
        // 同一分组内再次排序
        var tempContacts = divideContacts
        if tempContacts.count > 0 {
            for i in 0..<tempContacts.count {
                tempContacts[i].value = tempContacts[i].value.sorted { $0.sessionIDStr < $1.sessionIDStr }
            }
            divideContacts = tempContacts
        }
        if divideContacts.first?.title == "#" {
            divideContacts.append(divideContacts.removeFirst())
        }
        return divideContacts
    }
}


//MARK: - DB Friend
extension UserManager {
    // 从 临时数据源 或 数据库 获取好友信息
    func friend(by address: String) -> User? {
        var dbFriend: User?
        if let friend = self.friends.filter({ $0.address == address }).first {
            dbFriend = friend
        } else if let friend = self.getDBFriend(with: address) {
            self.friends.append(friend)
            dbFriend = friend
        }
        return dbFriend
    }
    
    /// 从数据库获取单个好友信息
    private func getDBFriend(with address: String) -> User? {
        let users: [User] = DBManager.shared().getObjects(fromTable: .user) { (constraint) in
            constraint.condition = UserDB.Properties.address.in(address) && UserDB.Properties.isFriend == true && UserDB.Properties.isShield == false
        }.compactMap { User.init(with: $0) }
        
        guard let user = users.first else { return nil }
        
        // users缓存添加新数据
        self.addUsersInCacheWithOutRepeat(users: [user])
        
        return user
    }
    
    /// 获取数据库所有好友
    func loadDBFriends() -> [User] {
        let friends: [User] = DBManager.shared().getObjects(fromTable: .user) { (constraint) in
            constraint.condition = UserDB.Properties.isFriend == true && UserDB.Properties.isShield == false
        }.compactMap { User.init(with: $0) }
        self.friends = friends
        return friends
    }
    
    //获取数据库所有用户除黑名单外（简称活跃用户）
    private func loadDBAllActiveuser() -> [User]{
        let users: [User] = DBManager.shared().getObjects(fromTable: .user) { (constraint) in
            constraint.condition =  UserDB.Properties.isShield == false
        }.compactMap { User.init(with: $0) }
        return users
    }
}

//MARK: - DB ShieldUser
extension UserManager {
    /// 获取所有黑名单用户
    func getDBShieldUsers() -> [User] {
        let users: [User] = DBManager.shared().getObjects(fromTable: .user) { (constraint) in
            constraint.condition = UserDB.Properties.isShield == true
        }.compactMap { User.init(with: $0) }
        
        return users
    }
}

//MARK: - User Login
extension UserManager {
    private func addLoginObserver() {
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogin), name: FZM_Notify_UserLogin, object: LoginUser.shared())
        FZM_NotificationCenter.addObserver(self, selector: #selector(userLogout), name: FZM_Notify_UserLogout, object: LoginUser.shared())
    }
    
    @objc private func userLogin() {
        let _ = self.loadDBFriends()
        self.getBlackList()
        self.getNetFriends()
        
        GroupManager.shared().loadAllGroupsInDBAndNet()
    }
    
    @objc private func userLogout() {
        self.clearUsers()
    }
    
    private func clearUsers() {
        self.users.removeAll()
        self.friends.removeAll()
        
        GroupManager.shared().clearGroups()
    }
}
