//
//  IMNotifyEvent.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/10.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import Foundation

enum IMNotifyEventType: Int {
    case appState //app进入后台或者活跃
    case socketConnect //socket的连接消息
    case chatMessage //socket聊天消息
    case user //用户登录登出改信息
    case voicePlayer // 音频播放
    case contact //通讯录用户信息修改
    case group //群信息修改
    case groupUser //群用户信息修改
    case groupBanned //群禁言和解禁
    case burnAfterRead //阅后即焚
    case upload
    case download
}

enum IMNotifyPostEventType {
    case appBackground
    case appWillEnterForeground
    case userLogin
    case userFirstLogin
    case userLogout
    case userInfoRefresh
    case socketConnect //socket连接
    case socketDisconnect //socket断开
    case receiveMessage(msg: Message, isLocal: Bool) //接收到聊天消息
    case receiveHistoryMsgList(msgs: [Message], isUnread: Bool) //接收到历史聊天消息数组
    case failSendMessage(msg: Message) //发送聊天消息失败
    case voiceStartPaly(url: String, path :String) //音频开始播放
    case voiceFinishPaly(url: String, path :String) //音频播放结束
    case voiceFailPaly(url: String, path :String) //音频播放失败
    case contactInfoChange(userId: String)
    case groupInfoChange(groupId: String)
    case userGroupInfoChange(groupId: String, userId: String)
    case groupBanned(groupId: String, type: Int, deadline: Double)
    case burnMessage(msg: Message)
    case uploadProgress(msgSendID:String, progress: Float)
    case downloadProgress(msgID:String, progress: Float)
}

//MARK: App进入后台或者唤醒  class -> AnyObject
protocol AppActiveDelegate: AnyObject {
    func appEnterBackground()
    func appWillEnterForeground()
}
class WeakAppActiveDelegate: NSObject {
    weak var delegate: AppActiveDelegate?
    required init(delegate: AppActiveDelegate?) {
        self.delegate = delegate
        super.init()
    }
}


//MARK: socket聊天消息
protocol UserInfoChangeDelegate: AnyObject {
    func userLogin()
    func userFirstLogin()
    func userLogout()
    func userInfoChange()
}

extension UserInfoChangeDelegate {
    func userFirstLogin() {
        
    }
}

class WeakUserInfoChangeDelegate: NSObject {
    weak var delegate: UserInfoChangeDelegate?
    required init(delegate: UserInfoChangeDelegate?) {
        self.delegate = delegate
        super.init()
    }
}


//MARK: 好友用户信息编辑
protocol ContactInfoChangeDelegate: AnyObject {
    func contactUserInfoChange(with userId: String)
}
class WeakContactInfoChangeDelegate: NSObject {
    weak var delegate: ContactInfoChangeDelegate?
    required init(delegate: ContactInfoChangeDelegate?) {
        self.delegate = delegate
        super.init()
    }
}

//MARK: 群信息编辑
protocol GroupInfoChangeDelegate: AnyObject {
    func groupInfoChange(with groupId: String)
}
class WeakGroupInfoChangeDelegate: NSObject {
    weak var delegate: GroupInfoChangeDelegate?
    required init(delegate: GroupInfoChangeDelegate?) {
        self.delegate = delegate
        super.init()
    }
}

//MARK: 群用户信息编辑
protocol UserGroupInfoChangeDelegate: AnyObject {
    func userGroupInfoChange(groupId: String, userId: String)
}
class WeakUserGroupInfoChangeDelegate: NSObject {
    weak var delegate: UserGroupInfoChangeDelegate?
    required init(delegate: UserGroupInfoChangeDelegate?) {
        self.delegate = delegate
        super.init()
    }
}

//MARK: 群用户信息编辑
protocol UserGroupBannedChangeDelegate: AnyObject {
    func groupBanned(groupId: String, type: Int, deadline: Double)
}
class WeakUserGroupBannedChangeDelegate: NSObject {
    weak var delegate: UserGroupBannedChangeDelegate?
    required init(delegate: UserGroupBannedChangeDelegate?) {
        self.delegate = delegate
        super.init()
    }
}


//MARK: 阅后即焚消息删除
protocol BurnAfterReadDelegate: AnyObject {
    func burnMessage(_ msg: Message)
}
class WeakBurnAfterReadDelegate: NSObject {
    weak var delegate: BurnAfterReadDelegate?
    required init(delegate: BurnAfterReadDelegate?) {
        self.delegate = delegate
        super.init()
    }
}

protocol UploadDelegate: AnyObject {
    func uploadProgress(_ sendMsgID:String, _ progress: Float)
}
class WeakUploadDelegate: NSObject {
    weak var delegate: UploadDelegate?
    required init(delegate: UploadDelegate?) {
        self.delegate = delegate
        super.init()
    }
}

protocol DownloadDelegate: AnyObject {
    func downloadProgress(_ sendMsgID:String, _ progress: Float)
}
class WeakDownloadDelegate: NSObject {
    weak var delegate: DownloadDelegate?
    required init(delegate: DownloadDelegate?) {
        self.delegate = delegate
        super.init()
    }
}
