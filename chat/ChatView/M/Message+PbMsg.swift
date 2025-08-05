//
//  Message+PbMsg.swift
//  chat
//
//  Created by 陈健 on 2021/1/20.
//  反序列化消息结构
//

import Foundation

extension Message {
    init(pbMsg: PbMsg_msg, publickey: String) {
        self.msgId = pbMsg.msgID
        self.fromId = pbMsg.from
        self.targetId = pbMsg.target
        self.channelType = ChannelType.init(rawValue: Int(pbMsg.channelType))
        self.logId = Int(pbMsg.logID)
        self.datetime = Int(pbMsg.datetime)
        self.status = .sent
        // 引用
        let ref = Message.Reference.init(ref: Int(pbMsg.reference.ref), topic: Int(pbMsg.reference.topic))
        self.reference = ref
        
        
        // 消息为群聊时加上群成员信息
        if Int(pbMsg.channelType) == 1 {// 0 私聊 1 群聊
            self.member = GroupManager.shared().getDBGroupMember(with: pbMsg.target.intEncoded, memberId: pbMsg.from)
        }
        
        let msgData = pbMsg.msg
        
        let unknownMsgType = MsgType.unknown((Int(pbMsg.msgType.rawValue), JSON.init("")))
        
        switch pbMsg.msgType {
        case PbMsg_MsgType.system:
            if let textMsg = try? PbMsg_TextMsg.init(serializedData: msgData) {
                self.msgType = MsgType.init(system: textMsg.content)
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.text:
            if let textMsg = try? PbMsg_TextMsg.init(serializedData: msgData) {
                self.msgType = MsgType.init(text: textMsg.content)
                // @列表
                if Int(pbMsg.channelType) == 1 {// 0 私聊 1 群聊
                    self.mentionIds = textMsg.mention
                }
                
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.image:
            if let imageMsg = try? PbMsg_ImageMsg.init(serializedData: msgData) {
                let cacheKey = String.uuid()
                self.msgType = MsgType.init(image: imageMsg.mediaURL, cacheKey: cacheKey, width: Double(imageMsg.width), height: Double(imageMsg.height))
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.audio:
            if let audioMsg = try? PbMsg_AudioMsg.init(serializedData: msgData) {
                let cacheKey = String.uuid()
                self.msgType = MsgType.init(audio: audioMsg.mediaURL, duration: Double(audioMsg.time), cacheKey: cacheKey, width: 0, height: 0)
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.video:
            if let videoMsg = try? PbMsg_VideoMsg.init(serializedData: msgData) {
                self.msgType = MsgType.init(video: videoMsg.mediaURL, cacheKey: String.uuid(), duration: Double(videoMsg.time), width: Double(videoMsg.width), height: Double(videoMsg.height))
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.file:
            if let fileMsg = try? PbMsg_FileMsg.init(serializedData: msgData) {
                let cacheKey = String.uuid()
                self.msgType = MsgType.init(file: fileMsg.mediaURL, cacheKey: cacheKey, name: fileMsg.name, md5: fileMsg.md5, size: Double(fileMsg.size))
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.transfer:
            if let transferMsg = try? PbMsg_TransferMsg.init(serializedData: msgData){
                self.msgType = MsgType.init(transfer: transferMsg.coinName , txHash: transferMsg.txHash)
            }else{
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.notification:// 通知消息
            if let notiMsg = try? PbMsg_NotificationMsg.init(serializedData: msgData) {
                
                var text = ""//通知消息具体内容文字
                var operatorName = ""
                var memberStr = ""
                
                // 获取操作者名称
                func getOperatorName(operatorId: String, groupId: Int) -> String {
                    var operatorName = operatorId
                    if operatorId == LoginUser.shared().address {
                        operatorName = "你"
                    } else {
                        if let member = GroupManager.shared().getDBGroupMember(with: groupId, memberId: operatorId) {
                            operatorName = member.contactsName
                        } else if let user = UserManager.shared().user(by: operatorId) {
                            operatorName = user.contactsName
                        }
                        operatorName = "\"\(operatorName)\""
                    }
                    return operatorName
                }
                
                // 获取成员名称
                func getMemberNames(_ memberIds: [String], groupId: Int) -> String {
                    var memberStr = ""
                    
                    var memberNames: [String] = []
                    memberIds.forEach { (memberId) in
//                        if memberId == LoginUser.shared().address {
//                            memberNames.append("我")
//                        } else {
                            if let member = GroupManager.shared().getDBGroupMember(with: groupId, memberId: memberId) {
                                memberNames.append(member.contactsName)
                            } else if let user = UserManager.shared().user(by: memberId) {
                                memberNames.append(user.contactsName)
                            } else {
                                memberNames.append(memberId)
                            }
//                        }
                        
                    }
                    memberStr = memberNames.joined(separator: "、")
                    memberStr = "\"\(memberStr)\""
                    return memberStr
                }
                
                
                switch notiMsg.type {
                case .notiUpdateGroupName://修改群名
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupName.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        var groupName = notifyMsg.name
                        if !publickey.isBlank {
                            groupName = EncryptManager.decryptGroupName(notifyMsg.name, key: publickey)
                        }
                        text = "\(operatorName) 修改群名为 \(groupName)"
                        
                        self.msgType = MsgType.init(notify: text, type:0, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: notifyMsg.name, inviter: nil, members: nil, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiSignInGroup://加群
                    if let notifyMsg = try? PbMsg_AlertSignInGroup.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.inviter, groupId: Int(notifyMsg.group))
                        if notifyMsg.members.count > 0 {
                            memberStr = getMemberNames(notifyMsg.members, groupId: Int(notifyMsg.group))
                            text = "\(operatorName) 邀请 \(memberStr) 加入了群聊"
                        } else {
                            text = "\(operatorName) 创建了群聊"
                        }
                        self.msgType = MsgType.init(notify: text, type:1, groupId: Int(notifyMsg.group), operatorId: nil, groupname: nil, inviter: notifyMsg.inviter, members: notifyMsg.members, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiSignOutGroup://退群
                    if let notifyMsg = try? PbMsg_AlertSignOutGroup.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) 退出了群聊"
                        
                        self.msgType = MsgType.init(notify: text, type:2, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notikickOutGroup://踢群
                    if let notifyMsg = try? PbMsg_AlertkickOutGroup.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        memberStr = getMemberNames(notifyMsg.members, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) 把 \(memberStr) 踢出了群聊"
                        
                        self.msgType = MsgType.init(notify: text, type:3, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: notifyMsg.members, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiDeleteGroup://删群
                    if let notifyMsg = try? PbMsg_AlertDeleteGroup.init(serializedData: notiMsg.body) {
                        
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) 解散了群聊"
                        self.msgType = MsgType.init(notify: text, type:4, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiUpdateGroupMuted://群禁言模式更改
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupMuted.init(serializedData: notiMsg.body) {
                        
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        let mutetype = notifyMsg.type.rawValue
                        let muteStr = mutetype == 1 ? "开启了全员禁言" : "关闭了全员禁言"
                        text = "\(operatorName) \(muteStr) "
                        self.msgType = MsgType.init(notify: text, type:5, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: nil, mutetype: notifyMsg.type.rawValue, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiUpdateGroupMemberMutedTime://更改禁言名单
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupMemberMutedTime.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        memberStr = getMemberNames(notifyMsg.members, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) 更改了 \(memberStr) 的禁言状态"
                        self.msgType = MsgType.init(notify: text, type:6, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: notifyMsg.members, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiUpdateGroupOwner://更换群主
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupOwner.init(serializedData: notiMsg.body) {
                        
                        operatorName = getOperatorName(operatorId: notifyMsg.newOwner, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) 成为了新群主"
                        self.msgType = MsgType.init(notify: text, type:7, groupId: Int(notifyMsg.group), operatorId: nil, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: notifyMsg.newOwner)
                    } else { self.msgType = unknownMsgType }
//                case .msgRevoked:// 收到撤销通知信令时把消息类型改为此类型
//                    if let pbMsg = try? PbMsg_Alertmsg.init(serializedData: notiMsg.body) {
//
//                    } else { self.msgType = unknownMsgType }
//                case .UNRECOGNIZED(_):
//                    <#code#>
                default:
                    self.msgType = unknownMsgType
                    break
                }
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.contactCard:// 名片
            if let contactCardMsg = try? PbMsg_ContactCardMsg.init(serializedData: msgData) {
                self.msgType = MsgType.init(contactCard: contactCardMsg.id, name: contactCardMsg.name, avatar: contactCardMsg.avatar, type: contactCardMsg.type.rawValue)
            } else {
                self.msgType = unknownMsgType
            }
//        case PbMsg_MsgType.forward://合并转发
//            if let contactCardMsg = try? PbMsg_ForwardMsg.init(serializedData: msgData) {
//                let items = contactCardMsg.items
//                self.msgType = MsgType.init(contactCard: contactCardMsg.id, name: contactCardMsg.name, avatar: contactCardMsg.avatar, type: contactCardMsg.type.rawValue)
//            } else {
//                self.msgType = unknownMsgType
//            }
        default:
            self.msgType = unknownMsgType
        }
    }
}
