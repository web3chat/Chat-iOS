//
//  Message+PbMsg.swift
//  chat
//
//  Created by fzm on 2021/1/20.
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
        // ⚠️ `pbMsg.reference` 是 protobuf 的**默认值 getter**（不是 optional）：不带引用时返回 `{ref: 0, topic: 0}`。
        //    原来无条件写进 `self.reference`，等于给**每一条收到的消息**都塞了一个假引用 ⇒
        //    ① 回复对方消息时继承到 `topic = 0`，发出去的 reference 非法，web 端渲染不出引用；
        //    ② UI 层会对每条消息都按 `refId = 0` 反查一次原消息（滚动时一直查库）。
        //    必须同时看 `hasReference` + `ref > 0` 才算真的有引用。
        if pbMsg.hasReference, pbMsg.reference.ref > 0 {
            self.reference = Message.Reference.init(
                ref: Int(pbMsg.reference.ref), topic: Int(pbMsg.reference.topic))
        }
        
        // 阅后即焚：从 Source.burn 解析（无 Source 时按普通消息）
        self.isBurn = pbMsg.hasSource ? pbMsg.source.burn : false
        
        
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
                // 【诊断】空正文：要么对端发了空消息，要么解密失败（密文非空但解出来是空）
                if textMsg.content.isEmpty {
                    FZMLog("【解析】text 消息正文为空 msgId=\(pbMsg.msgID) logId=\(pbMsg.logID) 密文=\(msgData.count)B 公钥=\(publickey.isBlank ? "空" : "有") mention=\(textMsg.mention.count)")
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
        case PbMsg_MsgType.redPacket:
            if let redPacketMsg = try? PbMsg_RedPacketMsg.init(serializedData: msgData) {
                self.msgType = MsgType.init(
                    redPacket: redPacketMsg.txHash,
                    coinName: redPacketMsg.coinName,
                    exec: redPacketMsg.exec,
                    packetType: redPacketMsg.packetType.rawValue,
                    remark: redPacketMsg.remark,
                    expire: redPacketMsg.expire
                )
            } else {
                self.msgType = unknownMsgType
            }
        case PbMsg_MsgType.notification:// 通知消息
            if let notiMsg = try? PbMsg_NotificationMsg.init(serializedData: msgData) {
                
                var text = ""//通知消息具体内容文字
                var operatorName = ""
                var memberStr = ""
                
                // 获取操作者名称
                func getOperatorName(operatorId: String, groupId: Int) -> String {
                    if operatorId == LoginUser.shared().address {
                        return L("你")
                    }
                    // 查不到昵称时回落「短地址」而不是完整地址：进群/退群/踢人等通知里，
                    // 这个人往往还没同步进本地群成员表 / 用户表，原来直接显示一长串完整地址。
                    var operatorName = operatorId.shortAddress
                    if let member = GroupManager.shared().getDBGroupMember(with: groupId, memberId: operatorId) {
                        operatorName = member.contactsName
                    } else if let user = UserManager.shared().user(by: operatorId) {
                        operatorName = user.contactsName
                    }
                    // 不要写成 "\(operatorName) "：末尾那个空格会变成「“张三 ” 修改了…」这种多余空格
                    return "\"\(operatorName)\""
                }
                
                // 获取成员名称
                func getMemberNames(_ memberIds: [String], groupId: Int) -> String {
                    var memberNames: [String] = []
                    memberIds.forEach { (memberId) in
                        if memberId == LoginUser.shared().address {
                            // 成员里有自己：用「你」而不用服务端存的名字，
                            // 否则会出现「你 邀请 自己 加入了群聊」这种读起来很怪的句子
                            memberNames.append(L("你"))
                        } else if let member = GroupManager.shared().getDBGroupMember(with: groupId, memberId: memberId) {
                            memberNames.append("\"\(member.contactsName)\"")
                        } else if let user = UserManager.shared().user(by: memberId) {
                            memberNames.append("\"\(user.contactsName)\"")
                        } else {
                            memberNames.append("\"\(memberId.shortAddress)\"")
                        }
                    }
                    // 逐个人名加引号（旧实现是整个字符串套一对引号，且引号里多一个空格）
                    return memberNames.joined(separator: "、")
                }
                
                
                switch notiMsg.type {
                case .notiUpdateGroupName://修改群名
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupName.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        var groupName = notifyMsg.name
                        if !publickey.isBlank {
                            groupName = EncryptManager.decryptGroupName(notifyMsg.name, key: publickey)
                        }
                        text = "\(operatorName) "+L("修改群名为")+" \(groupName)"
                        
                        self.msgType = MsgType.init(notify: text, type:0, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: notifyMsg.name, inviter: nil, members: nil, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiSignInGroup://加群
                    if let notifyMsg = try? PbMsg_AlertSignInGroup.init(serializedData: notiMsg.body) {
                        let groupId = Int(notifyMsg.group)
                        let myAddress = LoginUser.shared().address
                        // 扫码进群 / 自己进群时，服务端给的邀请人和加入人是同一个人（都是进群的人），
                        // 原来的文案会拼成「你 邀请 自己 加入了群聊」→ 这种情况不写「邀请」，直接说「加入」
                        let inviterIsJoiner = notifyMsg.members.count == 1 && notifyMsg.members.first == notifyMsg.inviter
                        if notifyMsg.members.count > 0 {
                            if inviterIsJoiner {
                                // 自己：你加入了群聊；别人看到的是：加入的那位「加入了群聊」
                                text = notifyMsg.inviter == myAddress
                                    ? L("你加入了群聊")
                                    : getMemberNames(notifyMsg.members, groupId: groupId) + " " + L("加入了群聊")
                            } else {
                                operatorName = getOperatorName(operatorId: notifyMsg.inviter, groupId: groupId)
                                memberStr = getMemberNames(notifyMsg.members, groupId: groupId)
                                text = "\(operatorName) "+L("邀请")+" \(memberStr) "+L("加入了群聊")
                            }
                        } else {
                            operatorName = getOperatorName(operatorId: notifyMsg.inviter, groupId: groupId)
                            text = "\(operatorName) "+L("创建了群聊")
                        }
                        self.msgType = MsgType.init(notify: text, type:1, groupId: Int(notifyMsg.group), operatorId: nil, groupname: nil, inviter: notifyMsg.inviter, members: notifyMsg.members, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiSignOutGroup://退群
                    if let notifyMsg = try? PbMsg_AlertSignOutGroup.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) "+L("退出了群聊")
                        
                        self.msgType = MsgType.init(notify: text, type:2, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notikickOutGroup://踢群
                    if let notifyMsg = try? PbMsg_AlertkickOutGroup.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        memberStr = getMemberNames(notifyMsg.members, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) "+L("把")+" \(memberStr) "+L("踢出了群聊")
                        
                        self.msgType = MsgType.init(notify: text, type:3, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: notifyMsg.members, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiDeleteGroup://删群
                    if let notifyMsg = try? PbMsg_AlertDeleteGroup.init(serializedData: notiMsg.body) {
                        
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) "+L("解散了群聊")
                        self.msgType = MsgType.init(notify: text, type:4, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiUpdateGroupMuted://群禁言模式更改
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupMuted.init(serializedData: notiMsg.body) {
                        
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        let mutetype = notifyMsg.type.rawValue
                        let muteStr = mutetype == 1 ? L("开启了全员禁言") : L("关闭了全员禁言")
                        text = "\(operatorName) \(muteStr) "
                        self.msgType = MsgType.init(notify: text, type:5, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: nil, mutetype: notifyMsg.type.rawValue, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiUpdateGroupMemberMutedTime://更改禁言名单
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupMemberMutedTime.init(serializedData: notiMsg.body) {
                        operatorName = getOperatorName(operatorId: notifyMsg.operator, groupId: Int(notifyMsg.group))
                        memberStr = getMemberNames(notifyMsg.members, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) "+L("更改了")+" \(memberStr) "+L("的禁言状态")
                        self.msgType = MsgType.init(notify: text, type:6, groupId: Int(notifyMsg.group), operatorId: notifyMsg.operator, groupname: nil, inviter: nil, members: notifyMsg.members, mutetype: nil, newOwner: nil)
                    } else { self.msgType = unknownMsgType }
                case .notiUpdateGroupOwner://更换群主
                    if let notifyMsg = try? PbMsg_AlertUpdateGroupOwner.init(serializedData: notiMsg.body) {
                        
                        operatorName = getOperatorName(operatorId: notifyMsg.newOwner, groupId: Int(notifyMsg.group))
                        text = "\(operatorName) "+L("成为了新群主")
                        self.msgType = MsgType.init(notify: text, type:7, groupId: Int(notifyMsg.group), operatorId: nil, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: notifyMsg.newOwner)
                    } else { self.msgType = unknownMsgType }
                case .msgRevoked:
                    if let notifiyMsg = try? PbMsg_ActionRevoke.init(serializedData: notiMsg.body){
                        operatorName = notifiyMsg.operator
                        
                        text = notifiyMsg.self_p ? L("你撤回了一条消息") : "\(operatorName) " + L("撤回了一条消息")
                        self.msgType = MsgType.init(notify: text, type: 8, groupId: Int(), operatorId: operatorName, groupname: nil, inviter: nil, members: nil, mutetype: nil, newOwner: nil)
                    }else {
                        self.msgType = unknownMsgType
                    }
                
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
        case PbMsg_MsgType.forward:// 合并转发
            if let forwardMsg = try? PbMsg_ForwardMsg.init(serializedData: msgData) {
                let items = forwardMsg.items.map { item in
                    return MsgType.ForwardItem(avatar: item.avatar,
                                               name: item.name,
                                               msgType: Int(item.msgType),
                                               msg: item.msg,
                                               datetime: Int(item.datetime))
                }
                self.msgType = items.isEmpty ? unknownMsgType : MsgType.init(forwardItems: items)
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

    /// 解密失败时，判断原始消息体是不是**未加密的明文**。
    ///
    /// 服务端生成的群通知（进群 / 退群 / 改名 / 禁言 / 撤回…）和部分系统消息没有群密钥，
    /// 下发的是**明文**；客户端发出的聊天消息才是密文。所以「解密函数返回原数据」不能一律
    /// 当成坏消息 —— 旧逻辑正是把明文直接当正文解析，通知才能正常显示。
    ///
    /// 这里按原 `msgType` 完整解析一遍，**只有解析出有效内容**才算明文；
    /// 随机密文（可能被 protobuf 宽松解析成空正文/未知类型）不会通过。
    static func isUsablePlaintextPayload(_ pbMsg: PbMsg_msg, publickey: String) -> Bool {
        let msg = Message(pbMsg: pbMsg, publickey: publickey)
        switch msg.msgType {
        case .unknown:
            return false
        case .text, .system:
            return !msg.msgType.textValue.isBlank
        case .notify:
            return !msg.msgType.text.isBlank
        case .image, .audio, .video, .file:
            return !(msg.msgType.url ?? "").isBlank
        case .transfer, .redPacket:
            return !(msg.msgType.txHash ?? "").isBlank
        case .contactCard:
            return !(msg.msgType.contactId ?? "").isBlank
        case .forward:
            return !(msg.msgType.forwardItems ?? []).isEmpty
        case .collect, .RTCCall:
            // 没有可校验的关键字段（且当前版本未构造），能解析出非 unknown 就保持旧逻辑
            return true
        }
    }
}
