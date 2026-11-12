//
//  GroupAPI.swift
//  chat
//
//  Created by 王俊豪 on 2021/8/10.
//

import Foundation
import Moya

enum GroupAPI {
    // 群信息
    case updataGroupAvatar(chatServerUrl: String, groupId: Int, avatarUrl: String)// 更新群头像
    case updateFriendType(chatServerUrl: String, groupId: Int, friendType: Int)// 更新群内加好友设置 加好友限制， 0=群内可加好友，1=群内禁止加好友
    case groupInfo(chatServerUrl: String, groupId: Int)// 查询群信息
    case groupList(chatServerUrl: String)// 群列表
    case groupPubInfo(chatServerUrl: String, groupId: Int)// 查询群公开信息
    case updateJoinType(chatServerUrl: String, groupId: Int, joinType: Int)// 更新加群设置 加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群
    case updateMuteType(chatServerUrl: String, groupId: Int, muteType: Int)// 更新群禁言设置 禁言， 0=全员可发言， 1=全员禁言(除群主和管理员)
    case updateGroupName(chatServerUrl: String, groupId: Int, name: String, publicName: String)// 更新群名称
    case joinGroup(chatServerUrl: String, groupId: Int,inviterId:String)//直接进群
    
    // 入群申请（加群方式 joinType == 2「入群需审核」，见《审批入群_App对接文档》）
    // 注意：这几个接口的群ID 字段名是 id、类型是 string（与其它群接口的 int64 不同）
    case createGroupApply(chatServerUrl: String, groupId: String, applyNote: String)// 提交入群申请
    case groupApplyList(chatServerUrl: String, groupId: String, count: Int, offset: Int)// 查询入群申请列表（分页）
    case acceptGroupApply(chatServerUrl: String, groupId: String, applyId: String)// 通过入群申请
    case rejectGroupApply(chatServerUrl: String, groupId: String, applyId: String, rejectReason: String)// 拒绝入群申请
    
    // 群动作
    case groupChangeOwner(chatServerUrl: String, groupId: Int, memberId: String)// 转让群
    case groupCreate(chatServerUrl: String, name: String, avatarUrl: String, introduce: String, memberIds: [String])//创建群
    case groupDisband(chatServerUrl: String, groupId: Int)// 解散群
    case groupExit(chatServerUrl: String, groupId: Int)// 退群
    case groupRemove(chatServerUrl: String, groupId: Int, memberIds: [String])// 踢人
    case groupInviteMembers(chatServerUrl: String, groupId: Int, memberIds: [String])// 邀请新群友
    
    // 群成员信息
    case groupMemberInfo(chatServerUrl: String, groupId: Int, memberId: String)// 群成员信息
    case groupMemberList(chatServerUrl: String, groupId: Int)// 群成员列表
    case updateMemberName(chatServerUrl: String, groupId: Int, memberName: String)// 更新群成员名称
    case updateMemberType(chatServerUrl: String, groupId: Int, memberId: String, memberType: Int)// 设置管理员 用户角色 0=群员, 1=管理员
    
    // 禁言
    case updateMemberMuteTime(chatServerUrl: String, groupId: Int, memberIds: [String], muteTime: Int)// 更新群成员禁言时间
    case groupMuteMemberList(chatServerUrl: String, groupId: Int)// 群内被禁言成员列表
    
    case revoke(chatServerUrl:String,type:Int,logId:Int) // 撤回消息 type-消息渠道 0=私聊 1=群聊 logid 服务区生成的消息id
}

extension GroupAPI: XLSTargetType {
    
    var baseURL: URL {
        switch self {
        case .updataGroupAvatar(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .updateFriendType(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupInfo(let chatServerUrl, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupList(let chatServerUrl):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupPubInfo(let chatServerUrl, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .updateJoinType(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .updateMuteType(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .updateGroupName(let chatServerUrl, _, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupChangeOwner(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupCreate(let chatServerUrl, _, _, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupDisband(let chatServerUrl, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupExit(let chatServerUrl, groupId: _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupRemove(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupInviteMembers(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupMemberInfo(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupMemberList(let chatServerUrl, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .updateMemberName(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .updateMemberType(let chatServerUrl, _, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .updateMemberMuteTime(let chatServerUrl, _, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupMuteMemberList(let chatServerUrl, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .joinGroup(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        // 入群申请接口：与其它群接口同前缀 /group/app，寻址用群自己的 chatServerUrl
        case .createGroupApply(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .groupApplyList(let chatServerUrl, _, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .acceptGroupApply(let chatServerUrl, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .rejectGroupApply(let chatServerUrl, _, _, _):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        case .revoke(let chatServerUrl,_,_):
            return URL.init(string: chatServerUrl) ?? UNCONFIGURED_SERVER_URL
        }
    }
    
    var parameters: [String : Any] {
        switch self {
        case .updataGroupAvatar(_, groupId: let groupId, avatarUrl: let avatarUrl):
            return ["id": groupId, "avatar": avatarUrl]
        case .updateFriendType(_, groupId: let groupId, friendType: let friendType):
            return ["id": groupId, "friendType": friendType]
        case .groupInfo(_, groupId: let groupId):
            return ["id": groupId]
        case .groupList:
            return [:]
        case .groupPubInfo(_, groupId: let groupId):
            return ["id": groupId]
        case .updateJoinType(_, groupId: let groupId, joinType: let joinType):
            return ["id": groupId, "joinType": joinType]
        case .updateMuteType(_, groupId: let groupId, muteType: let muteType):
            return ["id": groupId, "muteType": muteType]
        case .updateGroupName(_, groupId: let groupId, name: let name, publicName: let publicName):
            return ["id": groupId, "name": name, "publicName": publicName]
        case .groupChangeOwner(_, groupId: let groupId, memberId: let memberId):
            return ["id": groupId, "memberId": memberId]
        case .groupCreate(_, name: let name, avatarUrl: let avatarUrl, introduce: let introduce, memberIds: let memberIds):
            return ["avatar": avatarUrl, "introduce": introduce, "memberIds": memberIds, "name": name]
        case .groupDisband(_, groupId: let groupId):
            return ["id": groupId]
        case .groupExit(_, groupId: let groupId):
            return ["id": groupId]
        case .groupRemove(_, groupId: let groupId, memberIds: let memberIds):
            return ["id": groupId, "memberIds": memberIds]
        case .groupInviteMembers(_, groupId: let groupId, memberIds: let memberIds):
            return ["id": groupId, "newMemberIds": memberIds]
        case .groupMemberInfo(_, groupId: let groupId, memberId: let memberId):
            return ["id": groupId, "memberId": memberId]
        case .groupMemberList(_, groupId: let groupId):
            return ["id": groupId]
        case .updateMemberName(_, groupId: let groupId, memberName: let memberName):
            return ["id": groupId, "memberName": memberName]
        case .updateMemberType(_, groupId: let groupId, memberId: let memberId, memberType: let memberType):
            return ["id": groupId, "memberId": memberId, "memberType": memberType]
        case .updateMemberMuteTime(_, groupId: let groupId, memberIds: let memberIds, muteTime: let muteTime):
            return ["id": groupId, "memberIds": memberIds, "muteTime": muteTime]
        case .groupMuteMemberList(_, groupId: let groupId):
            return ["id": groupId]
        case .joinGroup(_, groupId: let groupId,let inviterId):
            return ["id": groupId,"inviterId":inviterId]
        case .createGroupApply(_, groupId: let groupId, applyNote: let applyNote):
            // 群ID 同时传 id / idStr，服务端优先 idStr
            var params: [String: Any] = ["id": groupId, "idStr": groupId]
            if !applyNote.isBlank {
                params["applyNote"] = applyNote
            }
            return params
        case .groupApplyList(_, groupId: let groupId, count: let count, offset: let offset):
            return ["id": groupId, "idStr": groupId, "count": count, "offset": offset]
        case .acceptGroupApply(_, groupId: let groupId, applyId: let applyId):
            return ["id": groupId, "idStr": groupId, "applyId": applyId]
        case .rejectGroupApply(_, groupId: let groupId, applyId: let applyId, rejectReason: let rejectReason):
            var params: [String: Any] = ["id": groupId, "idStr": groupId, "applyId": applyId]
            if !rejectReason.isBlank {
                params["rejectReason"] = rejectReason
            }
            return params
        case .revoke(_,type: let type, logId: let logId):
            return ["type":type,"logId":logId]
        }
    }
    
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .updataGroupAvatar:
            return "/group/app/avatar"
        case .updateFriendType:
            return "/group/app/friendType"
        case .groupInfo:
            return "/group/app/group-info"
        case .groupList:
            return "/group/app/group-list"
        case .groupPubInfo:
            return "/group/app/group-pub-info"
        case .updateJoinType:
            return "/group/app/joinType"
        case .updateMuteType:
            return "/group/app/muteType"
        case .updateGroupName:
            return "/group/app/name"
        case .groupChangeOwner:
            return "/group/app/change-owner"
        case .groupCreate:
            return "/group/app/create-group"
        case .groupDisband:
            return "/group/app/group-disband"
        case .groupExit:
            return "/group/app/group-exit"
        case .groupRemove:
            return "/group/app/group-remove"
        case .groupInviteMembers:
            return "/group/app/invite-group-members"
        case .groupMemberInfo:
            return "/group/app/group-member-info"
        case .groupMemberList:
            return "/group/app/group-member-list"
        case .updateMemberName:
            return "/group/app/member/name"
        case .updateMemberType:
            return "/group/app/member/type"
        case .updateMemberMuteTime:
            return "/group/app/member/muteTime"
        case .groupMuteMemberList:
            return "/group/app/mute-list"
        case .joinGroup:
            return "/group/app/join-group"
        // 入群申请：与其它群接口同前缀 /group/app
        case .createGroupApply:
            return "/group/app/create-group-apply"
        case .groupApplyList:
            return "/group/app/get-group-applys"
        case .acceptGroupApply:
            return "/group/app/accept-group-apply"
        case .rejectGroupApply:
            return "/group/app/reject-group-apply"
        case .revoke:
            return "app/record/revoke"
        }
    }
}
