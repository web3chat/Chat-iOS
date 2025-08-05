//
//  IMNotifyCenter.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/10.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

import UIKit

//各类型消息收发中心
public class IMNotifyCenter: NSObject {
    
    private static let sharedInstance = IMNotifyCenter()
    
    class func shared() -> IMNotifyCenter {
        return sharedInstance
    }
    
    private var appStateArr = [WeakAppActiveDelegate]()
    private var socketConnectArr = [WeakSocketConnectDelegate]()
    private var socketChatMsgArr = [WeakSocketChatMsgDelegate]()
    private var userInfoChangeArr = [WeakUserInfoChangeDelegate]()
    private var voicePlayerArr = [WeakVoicePlayerDelegate]()
    private var contactInfoChangeArr = [WeakContactInfoChangeDelegate]()
    private var groupInfoChangeArr = [WeakGroupInfoChangeDelegate]()
    private var userGroupInfoChangeArr = [WeakUserGroupInfoChangeDelegate]()
    private var userGroupBannedArr = [WeakUserGroupBannedChangeDelegate]()
    private var burnAfterReadArr = [WeakBurnAfterReadDelegate]()
    private var uploadArr = [WeakUploadDelegate]()
     private var downloadArr = [WeakDownloadDelegate]()
    
    private let queue = DispatchQueue(label: "com.notify")
    private let receiverLock = DispatchSemaphore(value: 1)
    
    func addReceiver(receiver: AnyObject, type: IMNotifyEventType) {
        DispatchQueue.main.async {
            self.receiverLock.wait()
            switch type {
            case .appState:
                if let receiver = receiver as? AppActiveDelegate {
                    self.appStateArr.append(WeakAppActiveDelegate(delegate: receiver))
                }
            case .socketConnect:
                if let receiver = receiver as? SocketConnectDelegate {
                    self.socketConnectArr.append(WeakSocketConnectDelegate(delegate: receiver))
                }
            case .chatMessage:
                if let receiver = receiver as? SocketChatMsgDelegate {
                    self.socketChatMsgArr.append(WeakSocketChatMsgDelegate(delegate: receiver))
                }
            case .user:
                if let receiver = receiver as? UserInfoChangeDelegate {
                    self.userInfoChangeArr.append(WeakUserInfoChangeDelegate(delegate: receiver))
                }
            case .voicePlayer:
                if let receiver = receiver as? VoicePlayerDelegate {
                    self.voicePlayerArr.append(WeakVoicePlayerDelegate(delegate: receiver))
                }
            case .contact:
                if let receiver = receiver as? ContactInfoChangeDelegate {
                    self.contactInfoChangeArr.append(WeakContactInfoChangeDelegate(delegate: receiver))
                }
            case .group:
                if let receiver = receiver as? GroupInfoChangeDelegate {
                    self.groupInfoChangeArr.append(WeakGroupInfoChangeDelegate(delegate: receiver))
                }
            case .groupUser:
                if let receiver = receiver as? UserGroupInfoChangeDelegate {
                    self.userGroupInfoChangeArr.append(WeakUserGroupInfoChangeDelegate(delegate: receiver))
                }
            case .groupBanned:
                if let receiver = receiver as? UserGroupBannedChangeDelegate {
                    self.userGroupBannedArr.append(WeakUserGroupBannedChangeDelegate(delegate: receiver))
                }
            case .burnAfterRead:
                if let receiver = receiver as? BurnAfterReadDelegate {
                    self.burnAfterReadArr.append(WeakBurnAfterReadDelegate(delegate: receiver))
                }
            case .upload:
                if let receiver = receiver as? UploadDelegate {
                    self.uploadArr.append(WeakUploadDelegate(delegate: receiver))
                }
            case .download:
                if let receiver = receiver as? DownloadDelegate {
                    self.downloadArr.append(WeakDownloadDelegate(delegate: receiver))
                }
            }
            self.receiverLock.signal()
        }
    }
    
    func removeReceiver(receiver: AnyObject, type: IMNotifyEventType) {
        switch type {
        case .appState:
            guard let receiver = receiver as? AppActiveDelegate else { return }
            self.appStateArr = self.appStateArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .socketConnect:
            guard let receiver = receiver as? SocketConnectDelegate else { return }
            self.socketConnectArr = self.socketConnectArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .chatMessage:
            guard let receiver = receiver as? SocketChatMsgDelegate else { return }
            self.socketChatMsgArr = self.socketChatMsgArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .user:
            guard let receiver = receiver as? UserInfoChangeDelegate else { return }
            self.userInfoChangeArr = self.userInfoChangeArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .voicePlayer:
            guard let receiver = receiver as? VoicePlayerDelegate else { return }
            self.voicePlayerArr = self.voicePlayerArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .contact:
            guard let receiver = receiver as? ContactInfoChangeDelegate else { return }
            self.contactInfoChangeArr = self.contactInfoChangeArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .group:
            guard let receiver = receiver as? GroupInfoChangeDelegate else { return }
            self.groupInfoChangeArr = self.groupInfoChangeArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .groupUser:
            guard let receiver = receiver as? UserGroupInfoChangeDelegate else { return }
            self.userGroupInfoChangeArr = self.userGroupInfoChangeArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .groupBanned:
            guard let receiver = receiver as? UserGroupBannedChangeDelegate else { return }
            self.userGroupBannedArr = self.userGroupBannedArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .burnAfterRead:
            guard let receiver = receiver as? BurnAfterReadDelegate else { return }
            self.burnAfterReadArr = self.burnAfterReadArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .upload:
            guard let receiver = receiver as? UploadDelegate else { return }
            self.uploadArr = self.uploadArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        case .download:
            guard let receiver = receiver as? DownloadDelegate else { return }
            self.downloadArr = self.downloadArr.filter({ (delegator) -> Bool in
                guard let delegate = delegator.delegate else {
                    return false
                }
                return delegate !== receiver
            })
        }
    }
}

//MARK: 发送消息
extension IMNotifyCenter {
    func postMessage(event: IMNotifyPostEventType) {
        DispatchQueue.main.async {
            switch event {
            case .userLogin:
                self.userInfoChangeArr.forEach { (delegator) in
                    delegator.delegate?.userLogin()
                }
            case .userFirstLogin:
                self.userInfoChangeArr.forEach { (delegator) in
                    delegator.delegate?.userFirstLogin()
                }
            case .userLogout:
                self.userInfoChangeArr.forEach { (delegator) in
                    delegator.delegate?.userLogout()
                }
            case .userInfoRefresh:
                self.userInfoChangeArr.forEach { (delegator) in
                    delegator.delegate?.userInfoChange()
                }
            case .socketConnect:
                self.socketConnectArr.forEach { (delegator) in
                    delegator.delegate?.socketConnect()
                }
            case .socketDisconnect:
                self.socketConnectArr.forEach { (delegator) in
                    delegator.delegate?.socketDisConnect()
                }
            case .receiveMessage(let msg, let isLocal):
                self.socketChatMsgArr.forEach { (delegator) in
                    delegator.delegate?.receiveMessage(with: msg, isLocal: isLocal)
                }
            case .receiveHistoryMsgList(let msgs, let isUnread):
                self.socketChatMsgArr.forEach { (delegator) in
                    delegator.delegate?.receiveHistoryMsgList(with: msgs, isUnread: isUnread)
                }
            case .failSendMessage(let msg):
                self.socketChatMsgArr.forEach { (delegator) in
                    delegator.delegate?.failSendMessage(with: msg)
                }
            case .voiceStartPaly(let url, let path):
                self.voicePlayerArr.forEach { (delegator) in
                    delegator.delegate?.voiceDidStartPlay(url: url, path: path)
                }
            case .voiceFinishPaly(let url, let path):
                self.voicePlayerArr.forEach { (delegator) in
                    delegator.delegate?.voiceDidFinishPlay(url: url, path: path)
                }
            case .voiceFailPaly(let url, let path):
                self.voicePlayerArr.forEach { (delegator) in
                    delegator.delegate?.voiceDidFailPlay(url: url, path: path)
                }
            case .contactInfoChange(let userId):
                self.contactInfoChangeArr.forEach { (delegator) in
                    delegator.delegate?.contactUserInfoChange(with: userId)
                }
            case .groupInfoChange(let groupId):
                self.groupInfoChangeArr.forEach { (delegator) in
                    delegator.delegate?.groupInfoChange(with: groupId)
                }
            case .appBackground:
                self.appStateArr.forEach { (delegator) in
                    delegator.delegate?.appEnterBackground()
                }
            case .appWillEnterForeground:
                self.appStateArr.forEach { (delegator) in
                    delegator.delegate?.appWillEnterForeground()
                }
            case .userGroupInfoChange(let groupId, let userId):
                self.userGroupInfoChangeArr.forEach { (delegator) in
                    delegator.delegate?.userGroupInfoChange(groupId: groupId, userId: userId)
                }
            case .groupBanned(let groupId, let type, let deadline):
                self.userGroupBannedArr.forEach { (delegator) in
                    delegator.delegate?.groupBanned(groupId: groupId, type: type, deadline: deadline)
                }
            case .burnMessage(let msg):
                self.burnAfterReadArr.forEach({ (delegator) in
                    delegator.delegate?.burnMessage(msg)
                })
            case .uploadProgress(let sendMsgID,let progress):
                self.uploadArr.forEach({ (delegator) in
                    delegator.delegate?.uploadProgress(sendMsgID, progress)
                })
            case .downloadProgress(let sendMsgID,let progress):
                self.downloadArr.forEach({ (delegator) in
                    delegator.delegate?.downloadProgress(sendMsgID, progress)
                })
            }
        }
    }
}


//MARK: socket连接消息
class WeakSocketConnectDelegate: NSObject {
    weak var delegate: SocketConnectDelegate?
    required init(delegate: SocketConnectDelegate?) {
        self.delegate = delegate
        super.init()
    }
}

//MARK: socket聊天消息
class WeakSocketChatMsgDelegate: NSObject {
    weak var delegate: SocketChatMsgDelegate?
    required init(delegate: SocketChatMsgDelegate?) {
        self.delegate = delegate
        super.init()
    }
}
