//
//  Message+AlertMsgType.swift
//  chat
//
//  Created by 陈健 on 2021/1/18.
//

import Foundation
import Kingfisher
import CoreMedia

extension Message {
    enum AlertMsgType {
        typealias RawValue = (value: Int, json: JSON)
        case UpdateGroupNameAlert(RawValue) //0
        case SignInGroupAlert(RawValue)   //1
        case SignOutGroupAlert(RawValue)  //2
        case KickOutGroupAlert(RawValue)  //3
        case DeleteGroupAlert(RawValue)  //4
        case UpdateGroupMutedAlert(RawValue)   //5
        case UpdateGroupMemberMutedAlert(RawValue)   //6
        case UpdateGroupOwnerAlert(RawValue) //7
        case MsgRevoked(RawValue)//8
        case unknown(RawValue)
    }
}

extension Message.AlertMsgType {
    init(rawValue: RawValue) {
        switch rawValue.value {
        case 0:
            self = Message.AlertMsgType.UpdateGroupNameAlert(rawValue)
        case 1:
            self = Message.AlertMsgType.SignInGroupAlert(rawValue)
        case 2:
            self = Message.AlertMsgType.SignOutGroupAlert(rawValue)
        case 3:
            self = Message.AlertMsgType.KickOutGroupAlert(rawValue)
        case 4:
            self = Message.AlertMsgType.DeleteGroupAlert(rawValue)
        case 5:
            self = Message.AlertMsgType.UpdateGroupMutedAlert(rawValue)
        case 6:
            self = Message.AlertMsgType.UpdateGroupMemberMutedAlert(rawValue)
        case 7:
            self = Message.AlertMsgType.UpdateGroupOwnerAlert(rawValue)
        case 8:
            self = Message.AlertMsgType.MsgRevoked(rawValue)
        default:
            self = Message.AlertMsgType.unknown(rawValue)
        }
    }
    var rawValue: RawValue {
        switch self {
        case .UpdateGroupNameAlert(let value):
            return value
        case .SignInGroupAlert(let value):
            return value
        case .SignOutGroupAlert(let value):
            return value
        case .KickOutGroupAlert(let value):
            return value
        case .DeleteGroupAlert(let value):
            return value
        case .UpdateGroupMutedAlert(let value):
            return value
        case .UpdateGroupMemberMutedAlert(let value):
            return value
        case .UpdateGroupOwnerAlert(let value):
            return value
        case .MsgRevoked(let value):
            return value
        case .unknown(let value):
            return value
        }
    }
}

//MARK: - Convenience Init
extension Message.AlertMsgType {
    //PbMsg_AlertUpdateGroupName
    init(UpdateGroupName groupId: Double, operatorStr: String, name: String) {
        let dic = ["group": groupId as Any,
                   "operator": operatorStr,
                   "name": name]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (0, json)
        self.init(rawValue: rawValue)
    }
    //PbMsg_AlertSignInGroup
    init(SignInGroup groupId: Double, inviter: String, members: [String]) {
        let dic = ["group": groupId as Any,
                   "inviter": inviter,
                   "members": members]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (1, json)
        self.init(rawValue: rawValue)
    }
    //PbMsg_AlertSignOutGroup
    init(SignOutGroup groupId: Double, operatorStr: String) {
        let dic = ["group": groupId as Any,
                   "operator": operatorStr]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (2, json)
        self.init(rawValue: rawValue)
    }
    //PbMsg_AlertkickOutGroup
    init(kickOutGroup groupId: Double, operatorStr: String, members: [String]) {
        let dic = ["group": groupId as Any,
                   "operator": operatorStr,
                   "members": members]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (3, json)
        self.init(rawValue: rawValue)
    }
    // PbMsg_AlertDeleteGroup
    init(DeleteGroup groupId: Double, operatorStr: String) {
        let dic = ["group": groupId as Any,
                   "operator": operatorStr]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (4, json)
        self.init(rawValue: rawValue)
    }
    //PbMsg_AlertUpdateGroupMuted
    init(UpdateGroupMuted groupId: Double, operatorStr: String, type: PbMsg_MuteType) {
        let dic = ["group": groupId as Any,
                   "operator": operatorStr,
                   "type": type]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (5, json)
        self.init(rawValue: rawValue)
    }
    //PbMsg_AlertUpdateGroupMemberMutedTime
    init(UpdateGroupMemberMutedTime groupId: Double, operatorStr: String, members: [String]) {
        let dic = ["group": groupId as Any,
                   "operator": operatorStr,
                   "members": members]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (6, json)
        self.init(rawValue: rawValue)
    }
    //PbMsg_AlertUpdateGroupOwner
    init(UpdateGroupOwner groupId: Double, newOwner: String) {
        let dic = ["group": groupId as Any,
                   "newOwner": newOwner]
            as [String : Any]
        let json = JSON.init(dic)
        let rawValue = (7, json)
        self.init(rawValue: rawValue)
    }
}
