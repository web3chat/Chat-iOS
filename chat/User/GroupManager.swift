//
//  GroupManager.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/7.
//

import Foundation
import WCDBSwift
import SwifterSwift

class GroupManager {
    
    private static let sharedInstance = GroupManager.init()
    static func shared() -> GroupManager { return sharedInstance }
    
    // 所有群
    private(set) lazy var groupsSubject = BehaviorSubject<[Group]>.init(value: [])
    private(set) var groups = [Group]() {
        didSet {
            self.groups = self.groups.withoutDuplicates(keyPath: \.id)
            DispatchQueue.main.async {
                self.groupsSubject.onNext(self.groups)
            }
        }
    }
    
    private let disposeBag = DisposeBag.init()
    
    private init() {
        // 加载本地所有群数据和网络请求群列表
        self.loadAllGroupsInDBAndNet()
    }
    
    func clearGroups() {
        self.groups.removeAll()
    }
}

extension GroupManager {
    func handleBannedInfo(user: GroupMember, group: Group) -> (Bool, Int) {
        guard user.memberType == 0 else {
            return (false, 0)
        }
        var isBanned = false
        var distance : Int = 0
        if group.muteType == 0 {
            distance = (user.memberMuteTime - Date.timestamp) / 1000
//            if user.bannedType == .blackMap && distance > 0 {
                isBanned = true
//            }else {
//                distance = 0
//            }
        }else if group.muteType == 1 {
            isBanned = true
            distance = k_ForverBannedTime
        }
//        else if group.bannedType == .whiteMap {
//            if user.bannedType != .whiteMap {
//                isBanned = true
//                distance = forverBannedTime
//            }
//        }
        return (isBanned, distance)
    }
}

//MARK: - Group Net
extension GroupManager {
    /// 加载本地所有群数据和网络请求群列表
    func loadAllGroupsInDBAndNet() {
        if LoginUser.shared().isLogin {
            let _ = self.loadDBGroups()
//            self.getAllServersNetGroups()
        }
    }
    
    /// 查询所有自己已添加的聊天服务器地址下的群列表
    func getAllServersNetGroups() {
        let serverUrls = LoginUser.shared().chatServerGroups.compactMap({ $0.value }).withoutDuplicates()
        
        serverUrls.forEach { (chatServerUrl) in
            self.getNetGroups(serverUrl: chatServerUrl)
        }
    }
    
    /// 查询群列表
    func getNetGroups(serverUrl: String, successBlock: Provider.SuccessBlock? = nil, failureBlock: Provider.FailureBlock? = nil) {
        Provider.request(GroupAPI.groupList(chatServerUrl: serverUrl)) { (json) in
            let groups = json["groups"].arrayValue.compactMap{ (json) -> Group? in
                var group = Group.init(json: json, isIncludeAdminNum: false, isIncludeMembers: false)
                // 保留给群设置的是否置顶、免打扰状态（本地设置、云端没有保存）
                if let oldGroup = self.getDBGroup(by: group.id) {
                    group.adminNum = oldGroup.adminNum
                    group.members = oldGroup.members
                    group.isOnTop = oldGroup.isOnTop
                    group.isMuteNotification = oldGroup.isMuteNotification
                    group.isInGroup = oldGroup.isInGroup
                }
                group.chatServerUrl = serverUrl
                
                // 更新会话名称、头像和聊天服务器地址
                if let session = SessionManager.shared().getSingleLocalSession(by: SessionID.group(group.id.string)) {
                    SessionManager.shared().updateSessionNameAndImageURLStrAndChatServerUrl(session: session.id, name: !group.name.isBlank ? group.name : group.owner.memberId.shortAddress, imageURLStr: group.avatarURLStr, chatServerUrl: serverUrl)
                }
                
                // 更新群成员数据
                self.updateDBMember(group.owner, groupId: group.id)
                if let person = group.person {
                    self.updateDBMember(person, groupId: group.id)
                }
                
                return group
            }
            
//            self.deleteAllDBFriends()
            
            self.save(groups: groups)
            let _ = self.loadDBGroups()
            
            successBlock?(json)
            
        } failureBlock: { (error) in
            FZMLog("获取群列表失败:\(error)")
            failureBlock?(error)
        }
    }
    
    /// 遍历连接的服务器查询群信息
    func getGroupInfoInAllServer(groupId: Int) {
        LoginUser.shared().chatServerGroups.forEach { (chatServerItem) in
            // 获取群信息
            self.getGroupInfo(serverUrl: chatServerItem.value, groupId: groupId, successBlock: { (group) in
                // 获取群成员列表
                self.getGroupMemberList(serverUrl: chatServerItem.value, groupId: groupId)
            }, failureBlock: nil)
        }
    }
    
    /// 查询群信息
    func getGroupInfo(serverUrl: String, groupId: Int, successBlock: ((Group)->())? = nil, failureBlock: Provider.FailureBlock? = nil) {
        Provider.request(GroupAPI.groupInfo(chatServerUrl: serverUrl, groupId: groupId)) { (json) in
            // 群信息相关处理
            var group = Group.init(json: json)
            group.chatServerUrl = serverUrl
            
            // 保留给群设置的是否置顶、免打扰状态（本地设置、云端没有保存）
            if let oldGroup = self.getDBGroup(by: group.id) {
                group.isOnTop = oldGroup.isOnTop
                group.isMuteNotification = oldGroup.isMuteNotification
                group.isInGroup = oldGroup.isInGroup
            }
            
            // 群成员相关处理
            var members = group.members?.compactMap { (member) -> GroupMember in
                // 获取用户信息（本地没有则从网络获取一次）
                UserManager.shared().getUser(by: member.memberId, userInfoBlock: nil)
                
                // 给群成员赋值groupId
                var newMember = member
                newMember.groupId = groupId
                return newMember
            }
            
            if var list = members {
                var owner = group.owner
                owner.groupId = groupId
                list.append(owner)
                if var person = group.person {
                    person.groupId = groupId
                    list.append(person)
                }
                members = list
                // 保存最新群成员数据（先删除再添加）
                self.deleteAndSaveDBGroupAllMembers(groupId: groupId, members: list)
            } else {
                var owner = group.owner
                owner.groupId = groupId
                members?.append(owner)
                if var person = group.person {
                    person.groupId = groupId
                    members?.append(person)
                }
                
                // 更新群成员数据
                self.updateDBMember(group.owner, groupId: group.id)
                if let person = group.person {
                    self.updateDBMember(person, groupId: group.id)
                }
            }
            
            group.members = members
            
            /**
             GroupManager：
             保存owner和person

             ChatManager：
             getHistoryMsgs时message添加member

             MessagesDisplayDelegate：
             configureNameView
             */
            
            // 更新群信息
            self.updateDBGroup(group)
            
            // 更新会话名称、头像和聊天服务器地址
            if let session = SessionManager.shared().getSingleLocalSession(by: SessionID.group(groupId.string)) {
                SessionManager.shared().updateSessionNameAndImageURLStrAndChatServerUrl(session: session.id, name: !group.name.isBlank ? group.name : group.owner.memberId.shortAddress, imageURLStr: group.avatarURLStr, chatServerUrl: serverUrl)
            }
            
            successBlock?(group)
            
        } failureBlock: { (error) in
            FZMLog("查询群信息失败 getGroupInfo :\(error)")
            let error = error as NSError
            if abs(error.code) == 10015 {
                // 你已不在本群中
                // 更新自己是否在群标识（被踢出群聊）
                GroupManager.shared().updateDBGroupIsInFlg(groupId: groupId, isInGroup: false)
            }
            failureBlock?(error)
        }
    }
    
    /// 查询群公开信息
    func getGroupPubInfo(serverUrl: String, groupId: Int, successBlock: ((Group)->())? = nil, failureBlock: Provider.FailureBlock? = nil) {
        Provider.request(GroupAPI.groupPubInfo(chatServerUrl: serverUrl, groupId: groupId)) { (json) in
            // 群信息相关处理
            var group = Group.init(json: json, isIncludeAdminNum: false, isIncludeMembers: false, isIncludeKey: false)
            group.chatServerUrl = serverUrl
            
            // 保留给群设置的是否置顶、免打扰状态（本地设置、云端没有保存）
            if let oldGroup = self.getDBGroup(by: group.id) {
                group.adminNum = oldGroup.adminNum
                group.members = oldGroup.members
                group.isOnTop = oldGroup.isOnTop
                group.isMuteNotification = oldGroup.isMuteNotification
                group.isInGroup = oldGroup.isInGroup
                group.key = oldGroup.key
            }
            // 更新群信息
            if group.isInGroup ,let personId = group.person?.memberId,personId.count > 0 {
                self.updateDBGroup(group)
            }
            
            // 更新群成员数据
            self.updateDBMember(group.owner, groupId: group.id)
            if let person = group.person {
                self.updateDBMember(person, groupId: group.id)
            }
            
            // 更新会话名称、头像和聊天服务器地址
            if let session = SessionManager.shared().getSingleLocalSession(by: SessionID.group(groupId.string)) {
                SessionManager.shared().updateSessionNameAndImageURLStrAndChatServerUrl(session: session.id, name: !group.name.isBlank ? group.name : group.owner.memberId.shortAddress, imageURLStr: group.avatarURLStr, chatServerUrl: serverUrl)
            }
            
            successBlock?(group)
        } failureBlock: { (error) in
            FZMLog("获取群列表失败:\(error)")
            failureBlock?(error)
        }
    }
    
    /// 查询群成员信息
    func getGroupMemberInfo(serverUrl: String, groupId: Int, memberId: String, successBlock: ((GroupMember)->())? = nil, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupMemberInfo(chatServerUrl: serverUrl, groupId: groupId, memberId: memberId)) { (json) in
            let member = GroupMember.init(json: json, groupId: groupId)
            // 更新群成员信息
            self.updateDBMember(member, groupId: groupId)
            successBlock?(member)
        } failureBlock: { (error) in
            FZMLog("查询群成员信息 getGroupMemberInfo-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 查询群成员列表
    func getGroupMemberList(serverUrl: String, groupId: Int, successBlock: (([GroupMember])->())? = nil, failureBlock: Provider.FailureBlock? = nil) {
        Provider.request(GroupAPI.groupMemberList(chatServerUrl: serverUrl, groupId: groupId)) { (json) in
            let newMembers = json["members"].arrayValue.compactMap { GroupMember.init(json: $0, groupId: groupId) }
//            // 删除本群所有群成员
//            self.deleteDBGroupAllMembers(with: groupId)
//
//            // 更新群成员列表
//            self.saveDBGroupMembers(members)
            
            
//            // 群成员相关处理
//            let newMembers = members.compactMap { (member) -> GroupMember in
//                // 获取用户信息（本地没有则从网络获取一次）
//                UserManager.shared().getUser(by: member.memberId, userInfoBlock: nil)
//
//                // 给群成员赋值groupId
//                var newMember = member
//                newMember.groupId = groupId
//                return newMember
//            }
            
            var members = newMembers.compactMap { (member) -> GroupMember in
                // 获取用户信息（本地没有则从网络获取一次）
                UserManager.shared().getUser(by: member.memberId, userInfoBlock: nil)
                
                // 给群成员赋值groupId
                var newMember = member
                newMember.groupId = groupId
                return newMember
            }
            
            if let group = GroupManager.shared().getDBGroup(by: groupId) {
                var owner = group.owner
                owner.groupId = groupId
                if !members.contains(owner) {
                    members.append(owner)
                }
                if var person = group.person {
                    person.groupId = groupId
                    if !members.contains(person) {
                        members.append(person)
                    }
                }
            }
            
            // 保存最新群成员数据（先删除再添加）
            self.deleteAndSaveDBGroupAllMembers(groupId: groupId, members: newMembers)
            
            successBlock?(members)
            
        } failureBlock: { (error) in
            FZMLog("查询群成员列表 getGroupMemberList-\(error)")
            failureBlock?(error)
        }
    }
    
    //直接进群
    func joinGroup(serverUrl: String, groupId: Int, inviterId: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.joinGroup(chatServerUrl: serverUrl, groupId: groupId, inviterId: inviterId)) { (json) in
            successBlock?(json)
        } failureBlock: { (error) in
            failureBlock?(error)
        }

    }
    
    /// 更新群头像
    func updateGroupAvatar(serverUrl: String, groupId: Int, avatar: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updataGroupAvatar(chatServerUrl: serverUrl, groupId: groupId, avatarUrl: avatar)) { (json) in
            guard var group = self.getDBGroup(by: groupId) else { return }
            group.avatar = avatar
            self.updateDBGroup(group)
            
            // 更新会话头像
            SessionManager.shared().updateSessionAvatar(session: SessionID.group(groupId.string), avatarUrlStr: avatar)
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("更新群头像失败 updateGroupAvatar-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 更新群内加好友设置 friendType : 加好友限制， 0=群内可加好友，1=群内禁止加好友
    func updateFriendType(serverUrl: String, groupId: Int, friendType: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updateFriendType(chatServerUrl: serverUrl, groupId: groupId, friendType: friendType)) { (json) in
            guard var group = self.getDBGroup(by: groupId) else { return }
            group.friendType = friendType
            self.updateDBGroup(group)
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("更新群内加好友设置失败 updateFriendType-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 更新加群设置 joinType : 加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群
    func updateJoinType(serverUrl: String, groupId: Int, joinType: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updateJoinType(chatServerUrl: serverUrl, groupId: groupId, joinType: joinType)) {(json) in
            guard var group = self.getDBGroup(by: groupId) else { return }
            group.joinType = joinType
            self.updateDBGroup(group)
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("更新加群设置失败 updateJoinType-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 更新群禁言设置 muteType : 禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
    func updateMuteType(serverUrl: String, groupId: Int, muteType: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updateMuteType(chatServerUrl: serverUrl, groupId: groupId, muteType: muteType)) { (json) in
            guard var group = self.getDBGroup(by: groupId) else { return }
            group.muteType = muteType
            self.updateDBGroup(group)
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("更新群禁言设置失败 updateMuteType-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 更新群名称
    func updateGroupName(serverUrl: String, groupId: Int, name: String, publicName: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updateGroupName(chatServerUrl: serverUrl, groupId: groupId, name: name, publicName: publicName)) { (json) in
            guard var group = self.getDBGroup(by: groupId), let key = group.key else { return }
            if !name.isBlank {
                group.name = EncryptManager.decryptGroupName(name, key: key)
            }
            if !publicName.isBlank {
                group.publicName = publicName
            }
            self.updateDBGroup(group)
            
            // 更新会话名称
            SessionManager.shared().updateSessionName(session: SessionID.group(groupId.string), name: group.name)
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("更新群名称 updateGroupName-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 转让群主 memberId:被转让为群主的群成员 ID
    func updateGroupOwner(serverUrl: String, groupId: Int, memberId: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupChangeOwner(chatServerUrl: serverUrl, groupId: groupId, memberId: memberId)) { (json) in
            
            // 修改新群主信息
            self.updateDBMemberType(memberId: memberId, memberType: 2, groupId: groupId)
            
            // 修改我的信息 普通群成员
            self.updateDBMemberType(memberId: LoginUser.shared().address, memberType: 0, groupId: groupId)
            
            if var group = self.getDBGroup(by: groupId) {
                
                // 修改群成员数据中自己的信息
                var owner: GroupMember?
                if let member = self.getDBGroupMember(with: groupId, memberId: memberId) {
                    owner = member
                } else {
                    owner = GroupMember.init(memberId: memberId, memberMuteTime: 0, memberName: nil, memberType: 2, groupId: groupId)
                }
                
                // 修改群主和自己的信息
                if let owner = owner {
                    group.owner = owner
                    group.person?.memberType = 0
                    self.updateDBGroup(group)
                }
            }
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("转让群 updateGroupOwner-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 创建群
    func createGroup(serverUrl: String, name: String, introduce: String, avatarUrl: String, memberIds: [String], successBlock: ((Group)->())?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupCreate(chatServerUrl: serverUrl, name: name, avatarUrl: avatarUrl, introduce: introduce, memberIds: memberIds)) { (json) in
            // 群信息相关处理
            var group = Group.init(json: json, isIncludeAdminNum: false, isIncludePersion: false)
            group.chatServerUrl = serverUrl
            
            // 群成员相关处理
            let members = group.members?.compactMap { (member) -> GroupMember in
                // 给群成员赋值groupId
                var newMember = member
                newMember.groupId = group.id
                return newMember
            }
            group.members = members
            
            // 插入一个群到本地数据库
            self.save(groups: [group])
            
            if let list = members {
                // 保存本群多个群成员
                self.saveDBGroupMembers(list)
            }
            
            successBlock?(group)
        } failureBlock: { (error) in
            FZMLog("创建群 createGroup-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 解散群
    func disbandGroup(serverUrl: String, groupId: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupDisband(chatServerUrl: serverUrl, groupId: groupId)) { (json) in
            
            // 清除数据库会话记录，更新群isInGroup字段
            self.quitGroupAction(groupId)
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("解散群 disbandGroup-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 退群
    func exitGroup(serverUrl: String, groupId: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupExit(chatServerUrl: serverUrl, groupId: groupId)) { (json) in
            
            // 清除数据库会话记录，更新群isInGroup字段
            self.quitGroupAction(groupId)
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("退群 exitGroup-\(error)")
            failureBlock?(error)
        }
    }
    
    // 清除数据库会话记录，更新群isInGroup字段
    private func quitGroupAction(_ groupId: Int) {
        // 更新是否在群
        GroupManager.shared().updateDBGroupIsInFlg(groupId: groupId, isInGroup: false)
        
        // 删除会话
        SessionManager.shared().deleteSession(id: SessionID.group(String(groupId)))
    }
    
    /// 踢人
    func groupRemoveMembers(serverUrl: String, groupId: Int, memberIds: [String], successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupRemove(chatServerUrl: serverUrl, groupId: groupId, memberIds: memberIds)) { (json) in
            // 成功被踢的成员列表
            let removeMembers = GroupRemove.init(json: json)
            
            // 删除本群部分群成员
            self.deleteDBGroupMembers(with: groupId, memberIds: removeMembers.memberIds)
            
            if var group = self.getDBGroup(by: groupId) {
                group.memberNum = removeMembers.memberNum
                // 更新群信息
                self.updateDBGroup(group)
            }
            
            successBlock?(json)
            
        } failureBlock: { (error) in
            FZMLog("踢人 groupRemoveMembers-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 邀请新群员
    func inviteGroupMembers(serverUrl: String, groupId: Int, memberIds: [String], successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupInviteMembers(chatServerUrl: serverUrl, groupId: groupId, memberIds: memberIds)) { (json) in
            
            if var group = self.getDBGroup(by: groupId) {
                let memberNum = json["memberNum"].intValue
                group.memberNum = memberNum
                
                let members = memberIds.compactMap { (memerId) -> GroupMember? in
                    if let friend = UserManager.shared().friend(by: memerId) {
                        let member = GroupMember.init(memberId: memerId, memberMuteTime: 0, memberName: friend.contactsName, memberType: 0, groupId: groupId)
                        return member
                    } else {
                        return nil
                    }
                }
                if members.count > 0 {
                    if let oldMembers = group.members {
                        group.members = oldMembers + members
                    } else {
                        group.members = members
                    }
                }
                
                // 更新群信息
                self.updateDBGroup(group)
            }
            
            successBlock?(json)
            
        } failureBlock: { (error) in
            FZMLog("邀请新群员 inviteGroupMembers-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 更新群成员名称（自己的群昵称）
    func updateGroupMemberName(serverUrl: String, groupId: Int, memberName: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updateMemberName(chatServerUrl: serverUrl, groupId: groupId, memberName: memberName)) { (json) in
            // 更新自己的群昵称
            self.updateDBMemberName(memberName: memberName, groupId: groupId)
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("更新群成员名称 updateGroupMemberName-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 设置管理员 用户角色 0=群员, 1=管理员
    func updateMemberType(serverUrl: String, groupId: Int, memberId: String, memberType: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updateMemberType(chatServerUrl: serverUrl, groupId: groupId, memberId: memberId, memberType: memberType)) { (json) in
            
            // 更新群成员管理权限（管理员、普通群员）
            self.updateDBMemberType(memberId: memberId, memberType: memberType, groupId: groupId)
            successBlock?(json)
            
        } failureBlock: { (error) in
            FZMLog("设置管理员 updateMemberType-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 更新群成员禁言时间
    func updateMemberMuteTime(serverUrl: String, groupId: Int, muteTime: Int, memberIds: [String], successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.updateMemberMuteTime(chatServerUrl: serverUrl, groupId: groupId, memberIds: memberIds, muteTime: muteTime)) { (json) in
            let members = json["members"].arrayValue.compactMap { GroupMember.init(json: $0, groupId: groupId) }
//            let memberIds = members.compactMap { $0.memberId }
//            // 删除本群部分群成员
//            self.deleteDBGroupMembers(with: groupId, memberIds: memberIds)
//
//            // 保存本群多个群成员
//            self.saveDBGroupMembers(members)
            
            // 更新部分群成员信息
            self.updateDBMembers(members, groupId: groupId)
            
            successBlock?(json)
        } failureBlock: { (error) in
            FZMLog("更新群成员禁言时间 updateMemberMuteTime-\(error)")
            failureBlock?(error)
        }
    }
    
    /// 获取群成员禁言时间
    func getMemberMuteTime(serverUrl: String, groupId: Int, successBlock : (([GroupMember])->())? = nil, failureBlock: Provider.FailureBlock?) {
        Provider.request(GroupAPI.groupMuteMemberList(chatServerUrl: serverUrl, groupId: groupId)) { (json) in
            let members = json["members"].arrayValue.compactMap { GroupMember.init(json: $0, groupId: groupId) }
//            let memberIds = members.compactMap { $0.memberId }
//            // 删除本群部分群成员
//            self.deleteDBGroupMembers(with: groupId, memberIds: memberIds)
//
//            // 保存本群多个群成员
//            self.saveDBGroupMembers(members)
            
            // 更新部分群成员信息
            self.updateDBMembers(members, groupId: groupId)
            
            successBlock?(members)
        } failureBlock: { (error) in
            FZMLog("获取群成员禁言时间 getMemberMuteTime-\(error)")
            failureBlock?(error)
        }
    }
}


//MARK: - DB GroupMember
extension GroupManager {
    // 从 数据库 或 服务器 获取群成员信息
    func getMember(by groupId: Int, memberId: String,serverUrl: String, memberInfoBlock: ((GroupMember?) ->())?) {
        var dbMember: GroupMember?
        if let member = self.getDBGroupMember(with: groupId, memberId: memberId) {
            dbMember = member
        }
        if dbMember == nil {
            DispatchQueue.global().async {
                self.getGroupMemberInfo(serverUrl: serverUrl, groupId: groupId, memberId: memberId) { (member) in
                    memberInfoBlock?(member)
                } failureBlock: { _ in
                    memberInfoBlock?(nil)
                }
            }
        } else {
            memberInfoBlock?(dbMember)
        }
    }
    
    /// 获取本群所有群成员
    func getDBGroupMembers(with groupId: Int) -> [GroupMember] {
        let members: [GroupMember] = DBManager.shared().getObjects(fromTable: .groupUserInfo, constraintBlock: { (constraint) in
            constraint.condition = GroupMemberDB.Properties.groupId.in(groupId)
        }).compactMap{ GroupMember.init(with: $0) }
//        FZMLog("getDBGroupMembers members --- \(members)")
        return members
    }
    
    /// 删除本群所有群成员
    func deleteDBGroupAllMembers(with groupId: Int) {
        if var group = self.getDBGroup(by: groupId) {
            group.members = nil
            self.groups = self.groups.filter { $0.id != groupId } + [group]
        }
        DBManager.shared().delete(fromTable: .groupUserInfo) { (constraint) in
            constraint.condition = GroupMemberDB.Properties.groupId.is(groupId)
        }
    }
    
    /// 删除本群部分群成员
    func deleteDBGroupMembers(with groupId: Int, memberIds: [String]) {
        if var group = self.getDBGroup(by: groupId), let members = group.members {
            group.members = members.filter { !memberIds.contains($0.memberId) }
            self.groups = self.groups.filter { $0.id != groupId } + [group]
        }
        
        DBManager.shared().delete(fromTable: .groupUserInfo) { (constraint) in
            constraint.condition = GroupMemberDB.Properties.id.is(groupId) && GroupMemberDB.Properties.memberId.in(memberIds)
        }
    }
    
    /// 保存本群多个群成员
    func saveDBGroupMembers(_ members: [GroupMember]) {
        let groupMemberDBs = members.compactMap { GroupMemberDB.init(with: $0) }
        DBManager.shared().insertOrReplace(intoTable: .groupUserInfo, list: groupMemberDBs)
    }
    
    // 保存最新群成员数据（先删除再添加）
    private func deleteAndSaveDBGroupAllMembers(groupId: Int, members:[GroupMember]) {
        if var group = self.getDBGroup(by: groupId) {
            group.members = members
            self.groups = self.groups.filter { $0.id != groupId } + [group]
        }
        // 删除
        DBManager.shared().delete(fromTable: .groupUserInfo) { (constraint) in
            constraint.condition = GroupMemberDB.Properties.groupId.in(groupId)
        }
        
        // 添加
        let groupMemberDBs = members.compactMap { GroupMemberDB.init(with: $0) }
        DBManager.shared().insertOrReplace(intoTable: .groupUserInfo, list: groupMemberDBs)
    }
    
    /// 获取本群单个群成员
    func getDBGroupMember(with groupId: Int, memberId: String) -> GroupMember? {
        let members: [GroupMember] = DBManager.shared().getObjects(fromTable: .groupUserInfo, constraintBlock: { (constraint) in
            constraint.condition = GroupMemberDB.Properties.groupId.is(groupId) && GroupMemberDB.Properties.memberId.is(memberId)
            constraint.limit = 1
        }).compactMap{ GroupMember.init(with: $0) }
        let member = members.filter { $0.groupId == groupId && $0.memberId == memberId }.first
        return member
    }
    
    /// 更新自己的群昵称
    func updateDBMemberName(memberName: String, groupId: Int)  {
        guard var member = self.getDBGroupMember(with: groupId, memberId: LoginUser.shared().address) else { return }
        member.memberName = memberName
        self.updateDBMember(member, groupId: groupId)
    }
    
    /// 更新群成员管理权限（管理员、普通群员）
    func updateDBMemberType(memberId: String, memberType: Int, groupId: Int)  {
        guard var member = self.getDBGroupMember(with: groupId, memberId: memberId) else {
            // 本地没有新增一条群成员数据
            let newMember = GroupMember.init(memberId: memberId, memberMuteTime: 0, memberName: nil, memberType: memberType, groupId: groupId)
            self.saveDBGroupMembers([newMember])
            return
        }
        member.memberType = memberType
        // 更新群成员信息
        self.updateDBMember(member, groupId: groupId)
        /*
        if var group = self.getDBGroup(by: groupId) {
            var needUpdate = false
//            var owner = group.owner
            if group.owner.memberType != memberType {
                group.owner.memberType = memberType
                needUpdate = true
                
//                // 更新群信息中的群主的信息
//                self.updateDBGroupOwnerInfo(groupId: groupId, owner: owner)
            }
            
            // 如果自己的信息改变了
            if let person = group.person, person.memberType != memberType {
                group.person!.memberType = memberType
                needUpdate = true
                
//                // 更新群信息中的自己的信息
//                self.updateDBGroupPersonInfo(groupId: groupId, person: person)
            }
            
            if needUpdate {
                // 更新群信息中的群主/自己的信息
                self.updateDBGroup(group)
            }
        }
         */
    }
    
    /// 更新群成员禁言时间
    func updateDBMemberMuteTime(memberId: String, memberMuteTime: Int, groupId: Int)  {
        guard var member = self.getDBGroupMember(with: groupId, memberId: memberId) else { return }
        member.memberMuteTime = memberMuteTime
        // 更新群成员信息
        self.updateDBMember(member, groupId: groupId)
        
        if var group = self.getDBGroup(by: groupId) {
            
            // 如果自己的信息改变了
            if let person = group.person, person.memberId == memberId, person.memberMuteTime != memberMuteTime {
                group.person!.memberMuteTime = memberMuteTime
                
                // 更新群信息中的自己的信息
                self.updateDBGroup(group)
                
//                // 更新群信息中的自己的信息
//                self.updateDBGroupPersonInfo(groupId: groupId, person: person)
            }
        }
    }
    
    /// 更新群成员信息
    func updateDBMember(_ member: GroupMember, groupId: Int) {
        guard let oldMember = self.getDBGroupMember(with: groupId, memberId: member.memberId) else {
            // 保存本群多个群成员
            self.saveDBGroupMembers([member])
            
            // 更新临时数据源中群信息数据
            let _ = self.getDBGroupInTable(groupId: groupId)
            return
        }
        
        var updatePropertys = [PropertyConvertible]()
        
        if oldMember.memberMuteTime != member.memberMuteTime {
            updatePropertys.append(GroupMemberDB.Properties.memberMuteTime)
        }
        if oldMember.memberName != member.memberName {
            updatePropertys.append(GroupMemberDB.Properties.memberName)
        }
        if oldMember.memberType != member.memberType {
            updatePropertys.append(GroupMemberDB.Properties.memberType)
        }
        
        guard updatePropertys.count > 0 else { return }
        
        let memberDB = GroupMemberDB.init(with: member)
        DBManager.shared().update(table: .groupUserInfo, on: updatePropertys, with: memberDB) { (constraint) in
            constraint.condition = GroupMemberDB.Properties.memberId == memberDB.memberId && GroupMemberDB.Properties.groupId == memberDB.groupId
        }
        
        // 更新临时数据源中群信息数据
        let _ = self.getDBGroupInTable(groupId: groupId)
    }
    
    /// 更新部分群成员信息
    func updateDBMembers(_ members: [GroupMember], groupId: Int) {
        members.forEach { (member) in
            guard let oldMember = self.getDBGroupMember(with: groupId, memberId: member.memberId) else {
                // 保存本群多个群成员
                self.saveDBGroupMembers([member])
                
                // 更新临时数据源中群信息数据
                let _ = self.getDBGroupInTable(groupId: groupId)
                return
            }
            
            var updatePropertys = [PropertyConvertible]()
            
            if oldMember.memberMuteTime != member.memberMuteTime {
                updatePropertys.append(GroupMemberDB.Properties.memberMuteTime)
            }
            if oldMember.memberName != member.memberName {
                updatePropertys.append(GroupMemberDB.Properties.memberName)
            }
            if oldMember.memberType != member.memberType {
                updatePropertys.append(GroupMemberDB.Properties.memberType)
            }
            
            guard updatePropertys.count > 0 else { return }
            
            let memberDB = GroupMemberDB.init(with: member)
            DBManager.shared().update(table: .groupUserInfo, on: updatePropertys, with: memberDB) { (constraint) in
                constraint.condition = GroupMemberDB.Properties.memberId == memberDB.memberId && GroupMemberDB.Properties.groupId == memberDB.groupId
            }
        }
        
        // 更新临时数据源中群信息数据
        let _ = self.getDBGroupInTable(groupId: groupId)
    }
}


//MARK: - DB Group
extension GroupManager {
    
    /// 获取本地数据库所有群
    func loadDBGroups() -> [Group] {
        let groups: [Group] = DBManager.shared().getObjects(fromTable: .grouplist) {  (constraint) in
            constraint.condition = GroupDB.Properties.isInGroup.is(true)
        }.compactMap { Group.init(with: $0) }
        let newGroups = groups.compactMap { (group) -> Group in
            var curGroup = group
            curGroup.members = self.getDBGroupMembers(with: group.id)
            return curGroup
        }
        self.groups = newGroups
        return newGroups
    }
    
    /// 删除数据库一个服务器地址下的所有群
    private func deleteDBGroups(with chatServerUrl: String) {
        self.groups.removeAll { $0.chatServerUrl == chatServerUrl }
        DBManager.shared().delete(fromTable: .grouplist) { (constraint) in
            constraint.condition = GroupDB.Properties.chatServerUrl.is(chatServerUrl)
        }
    }
    
    /// 删除数据库单个群
    func deleteDBGroup(_ groupId: Int) {
        self.groups.removeAll { $0.id == groupId }
        DBManager.shared().delete(fromTable: .grouplist) { (constraint) in
            constraint.condition = GroupDB.Properties.id.is(groupId)
        }
    }
    
    /// 从数据源获取群信息
    func getDBGroup(by groupId: Int) -> Group? {
        var dbGroup: Group?
        if let group = self.groups.filter({ $0.id == groupId }).first  {
            dbGroup = group
        } else if let group = self.getDBGroupInTable(groupId: groupId) {
            if group.isInGroup {
                self.groups.append(group)
            }
            dbGroup = group
        }
//        if let group = dbGroup {
//            FZMLog("getDBGroup group --- \(group)")
//        }
        return dbGroup
    }
    
    /// 从数据库获取群信息
    func getDBGroupInTable(groupId: Int, onlyInquire: Bool? = false) -> Group? {
        let dbGroup: Group? = DBManager.shared().getObjects(fromTable: .grouplist) { (constraint) in
            constraint.condition = GroupDB.Properties.id.is(groupId)
        }.compactMap { Group.init(with: $0) }.first
        if var group = dbGroup {
            // 获取本群所有群成员
            let list = self.getDBGroupMembers(with: group.id)
            group.members = list
            
            if let flg = onlyInquire, flg == true {
                
            } else {
                // groups缓存添加新数据
                self.addGroupsInCacheWithOutRepeat(groups: [group])
            }
            
            return group
        } else {
            return nil
        }
    }
    
    /// groups缓存添加新数据（已有群先删除老数据再添加新数据）
    private func addGroupsInCacheWithOutRepeat(groups : [Group]) {
        guard !groups.isEmpty else { return }
        var temtGroups = self.groups
        groups.forEach { item in
            temtGroups = temtGroups.filter({ $0.id != item.id })
            if item.isInGroup{
                temtGroups += [item]
            }
        }
        
        self.groups = temtGroups
    }
    
    /// 插入一个群到本地数据库
    func save(groups: [Group]) {
        // groups缓存添加新数据
        self.addGroupsInCacheWithOutRepeat(groups: groups)
        
        let groupDBs = groups.compactMap { GroupDB.init(with: $0) }
        DBManager.shared().insertOrReplace(intoTable: .grouplist, list: groupDBs)
    }
    
    /// 更新群名称
    func updateDBGroupName(groupId: Int, name: String)  {
        guard var group = self.getDBGroup(by: groupId) else { return }
        group.name = name
        self.updateDBGroup(group)
    }
    
    /// 更新群头像
    func updateDBGroupAvatar(groupId: Int, avatar: String)  {
        guard var group = self.getDBGroup(by: groupId) else { return }
        group.avatar = avatar
        self.updateDBGroup(group)
    }
    
    /// 更新群加好友限制， 0=群内可加好友，1=群内禁止加好友
    func updateDBGroupFriendType(groupId: Int, friendType: Int)  {
        guard var group = self.getDBGroup(by: groupId) else { return }
        group.friendType = friendType
        self.updateDBGroup(group)
    }
    
    /// 更新群加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群 2=需要审批
    func updateDBGroupJoinType(groupId: Int, joinType: Int)  {
        guard var group = self.getDBGroup(by: groupId) else { return }
        group.joinType = joinType
        self.updateDBGroup(group)
    }
    
    /// 更新群禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
    func updateDBGroupMuteType(groupId: Int, muteType: Int)  {
        guard var group = self.getDBGroup(by: groupId) else { return }
        group.muteType = muteType
        self.updateDBGroup(group)
    }
    
    /// 更新自己是否在群标识
    func updateDBGroupIsInFlg(groupId: Int, chatServerUrl: String? = "", isInGroup: Bool)  {
        self.getGroupInfo(by: groupId, chatServerUrl: chatServerUrl) { (group) in
            if var group = group {
                group.isInGroup = isInGroup
                if let chatServerUrl = chatServerUrl, !chatServerUrl.isBlank {
                    group.chatServerUrl = chatServerUrl
                }
                self.updateDBGroup(group)
            }
        }
    }
    
    /// 更新群会话免打扰状态
    func updateDBGroupMuteNotifacation(groupId: Int, isMuteNoti: Bool)  {
        guard var group = self.getDBGroup(by: groupId) else { return }
        group.isMuteNotification = isMuteNoti
        self.updateDBGroup(group)
    }
    
    /// 更新群会话置顶状态
    func updateDBGroupIsOnTop(groupId: Int, isOnTop: Bool)  {
        guard var group = self.getDBGroup(by: groupId) else { return }
        group.isOnTop = isOnTop
        self.updateDBGroup(group)
    }
    
    /// 更新群信息
    func updateDBGroup(_ group: Group) {
        guard let oldGroup = self.getDBGroup(by: group.id) else {
            if group.isInGroup {
                self.groups.append(group)
            }
            self.save(groups: [group])
            return
        }
        
        var updatePropertys = [PropertyConvertible]()
        
        if let url = group.chatServerUrl, !url.isBlank, url != oldGroup.chatServerUrl {
            updatePropertys.append(GroupDB.Properties.chatServerUrl)
        }
        if oldGroup.adminNum != group.adminNum {
            updatePropertys.append(GroupDB.Properties.adminNum)
        }
        if oldGroup.avatar != group.avatar {
            updatePropertys.append(GroupDB.Properties.avatar)
        }
        if oldGroup.createTime != group.createTime {
            updatePropertys.append(GroupDB.Properties.createTime)
        }
        if oldGroup.friendType != group.friendType {
            updatePropertys.append(GroupDB.Properties.friendType)
        }
        if oldGroup.introduce != group.introduce {
            updatePropertys.append(GroupDB.Properties.introduce)
        }
        if oldGroup.joinType != group.joinType {
            updatePropertys.append(GroupDB.Properties.joinType)
        }
        if oldGroup.markId != group.markId {
            updatePropertys.append(GroupDB.Properties.markId)
        }
        if oldGroup.maximum != group.maximum {
            updatePropertys.append(GroupDB.Properties.maximum)
        }
        if oldGroup.memberNum != group.memberNum {
            updatePropertys.append(GroupDB.Properties.memberNum)
        }
        if oldGroup.muteNum != group.muteNum {
            updatePropertys.append(GroupDB.Properties.muteNum)
        }
        if oldGroup.muteType != group.muteType {
            updatePropertys.append(GroupDB.Properties.muteType)
        }
        if oldGroup.name != group.name {
            updatePropertys.append(GroupDB.Properties.name)
        }
        if oldGroup.publicName != group.publicName {
            updatePropertys.append(GroupDB.Properties.publicName)
        }
        if oldGroup.owner != group.owner {
            updatePropertys.append(GroupDB.Properties.owner)
        }
        if oldGroup.person != group.person {
            updatePropertys.append(GroupDB.Properties.person)
        }
        if oldGroup.status != group.status {
            updatePropertys.append(GroupDB.Properties.status)
        }
        if oldGroup.isOnTop != group.isOnTop {
            updatePropertys.append(GroupDB.Properties.isOnTop)
        }
        if oldGroup.isMuteNotification != group.isMuteNotification {
            updatePropertys.append(GroupDB.Properties.isMuteNotification)
        }
        if oldGroup.isInGroup != group.isInGroup {
            updatePropertys.append(GroupDB.Properties.isInGroup)
        }
        
        guard updatePropertys.count > 0 else { return }
        
//        self.groups = self.groups.filter({ $0.id != oldGroup.id }) + [group]
        
        var tempGroups = self.groups.filter({ $0.id != oldGroup.id })
        if group.isInGroup {
            tempGroups = tempGroups + [group]
        }
        
        self.groups = tempGroups
        
        let groupDB = GroupDB.init(with: group)
        DBManager.shared().update(table: .grouplist, on: updatePropertys, with: groupDB) { (constraint) in
            constraint.condition = GroupDB.Properties.id == groupDB.id
        }
    }
    
    // 从 临时数据源 或 数据库 或 链上 获取群信息
    func getGroupInfo(by groupId: Int, chatServerUrl: String? = "", groupInfoBlock: ((Group?) -> ())?) {
        var groupDB: Group?
        if let group = self.groups.filter({ $0.id == groupId }).first {
            groupDB = group
        } else if let group = self.getDBGroupInTable(groupId: groupId) {
            self.groups.append(group)
            groupDB = group
        }
        
        if groupDB == nil {
            if let serverUrl = chatServerUrl {
                self.getGroupInfo(serverUrl: serverUrl, groupId: groupId) { (group) in
                    groupInfoBlock?(group)
                } failureBlock: { _ in
                    groupInfoBlock?(groupDB)
                }
            } else {
                let myGroup = DispatchGroup.init()
                LoginUser.shared().chatServerGroups.forEach { (chatServerItem) in
                    if let _ = groupDB {
                        return
                    }
                    myGroup.enter()
                    // 获取群信息
                    self.getGroupInfo(serverUrl: chatServerItem.value, groupId: groupId) { (group) in
                        groupDB = group
                        
                        myGroup.leave()
                    } failureBlock: { _ in
                        myGroup.leave()
                    }
                }
                
                myGroup.notify(queue: .main) {
                    FZMLog("遍历结束")
                }
                groupInfoBlock?(groupDB)
            }
        } else {
            groupInfoBlock?(groupDB)
        }
    }
    
    // 从 临时数据源 或 数据库 或 链上 获取群密钥
    func getGroupKey(by groupId: Int, chatServerUrl: String? = "", groupKeyBlock: StringBlock?) {
        GroupManager.shared().getGroupInfo(by: groupId, chatServerUrl: chatServerUrl) { (group) in
            var publicKey = ""
            if let pubKey = group?.key, !pubKey.isBlank {
                publicKey = pubKey
            }
            groupKeyBlock?(publicKey)
        }
    }
}


