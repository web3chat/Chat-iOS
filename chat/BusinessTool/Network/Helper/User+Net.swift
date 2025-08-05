//
//  User+Net.swift
//  chat
//
//  Created by 陈健 on 2021/1/22.
//

import Foundation

extension User {
//    typealias GetUserBlock = ((groups: [String], chatServers: [UserChatServer], fields: [UserInfoField])) ->()
    static func getUser(targetAddress: String, count: Int, index: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?)  {
        
        BlockchainHelper.getUser(targetAddress: targetAddress, count: count, index: index, successBlock: successBlock, failureBlock: failureBlock)
    }
    
    // 更新自己的昵称
    static func updateUserNickname(targetAddress: String, nickname: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        BlockchainHelper.updateUserInfo(name: .nickname, value: nickname, level: .public, successBlock: successBlock, failureBlock: failureBlock)
    }
    
    // 更新自己的公钥
    static func updateUserPublickKey(targetAddress: String, pubKey: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        BlockchainHelper.updateUserInfo(name: .pubKey, value: pubKey, level: .public, successBlock: successBlock, failureBlock: failureBlock)
    }
    
    // 更新自己的头像
    static func updateUserAvatar(targetAddress: String, avatar: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        BlockchainHelper.updateUserInfo(name: .avatar, value: avatar, level: .public, successBlock: successBlock, failureBlock: failureBlock)
    }
    
    // 更新自己的地址
    static func updateUserChainAddress(targetAddress:String,name:BlockchainAPI.UpdateUserInfo,chainAddr:String,successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?){
        BlockchainHelper.updateUserInfo(name: name, value: chainAddr, level: .public, successBlock: successBlock, failureBlock: failureBlock)
    }
}
