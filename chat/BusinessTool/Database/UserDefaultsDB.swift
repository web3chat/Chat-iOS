//
//  UserDefaultsDB.swift
//  xls
//
//  Created by fzm on 2020/8/11.
//  Copyright © 2020 fzm. All rights reserved.
//

import Foundation
import Starscream

struct UserDefaultsDB {
    @WUserDefaults(key: "chat_save_user")
    static var loginUser: LoginUser?
    
    
    @WUserDefaults(key: "chat_save_OfficialIMChatServers")
    static var OfficialIMChatServers: [Server]?// 官方的IM聊天服务器地址
    
    @WUserDefaults(key: "chat_save_OfficialBlockchainServers")
    static var OfficialBlockchainServers: [Server]?// 官方的区块链节点服务器地址
    
    
    @WUserDefaults(key: "chat_save_IMChatServer")
    static var IMChatServer: Server?// 当前选择的IM聊天服务器地址
    
    @WUserDefaults(key: "chat_save_blockchainServer")
    static var blockchainServer: Server?// 当前的区块链节点
    
    @WUserDefaults(key: "chat_save_TeamIMChatServer")
    static var TeamIMChatServer: Server?// 当前团队的IM聊天服务器地址
    
    @WUserDefaults(key: "chat_save_IMTeamServer")
    static var TeamServer: String?// 当前团队的oa服务器地址
    
    @WUserDefaults(key: "chat_save_TeamBlockchainServerUrl")
    static var TeamBlockchainServerUrl: Server?// 当前团队的区块链节点
    
    @WUserDefaults(key: "chat_save_IsInTeam")
    static var IsInTeam: Bool?// 当前是否已加入团队
    
    @WUserDefaults(key: "chat_save_IMWalletServer")
    static var WalletServer: String?// 当前的钱包服务器地址
    
    
    
    @WUserDefaults(key: "chat_save_chatServerList")
    static var chatServerList: [Server]?// 未登录时添加的接收聊天服务器地址

    @WUserDefaults(key: "chat_save_chainServerList")
    static var chainServerList: [Server]?// 添加的区块链节点
    
    
    @WUserDefaults(key: "chat_save_deviceToken")
    static var deviceToken: String?// 当前的devicetoken
    
    @WUserDefaults(key: "chat_save_isFirstLaunchApp")
    static var isNotFirstLaunchApp: Bool?// app是否是新安装第一次启动

    /// 用户曾在「开启通知」引导弹窗中点击「取消」，之后不再弹出该引导（持久化）
    @WUserDefaults(key: "chat_user_dismissed_notification_settings_prompt")
    static var userDismissedNotificationSettingsPrompt: Bool?
    
    @WUserDefaults(key: "chat_save_userinfo")
    static var userInfo:[LoginUser]?

    
}

/**
 
 
 struct UserDefaultsDB {
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_user")
     static var loginUser: LoginUser?
     
     
     @WUserDefaults(key: "chat_save_OfficialIMChatServers")
     static var OfficialIMChatServers: [Server]?// 官方的IM聊天服务器地址
     
     @WUserDefaults(key: "chat_save_OfficialBlockchainServers")
     static var OfficialBlockchainServers: [Server]?// 官方的区块链节点服务器地址
     
     
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_IMChatServer")
     static var IMChatServer: Server?// 当前选择的IM聊天服务器地址
     
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_blockchainServer")
     static var blockchainServer: Server?// 当前的区块链节点
     
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_TeamIMChatServer")
     static var TeamIMChatServer: Server?// 当前团队的IM聊天服务器地址
     
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_IMTeamServer")
     static var TeamServer: String?// 当前团队的oa服务器地址
     
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_TeamBlockchainServerUrl")
     static var TeamBlockchainServerUrl: Server?// 当前团队的区块链节点
     
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_IsInTeam")
     static var IsInTeam: Bool?// 当前是否已加入团队
     
     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_IMWalletServer")
     static var WalletServer: String?// 当前的钱包服务器地址
     
     
     
     @WUserDefaults(key: "chat_save_chatServerList")
     static var chatServerList: [Server]?// 未登录时添加的接收聊天服务器地址

     @WUserDefaults(key: "\(LoginUser.shared().address)chat_save_chainServerList")
     static var chainServerList: [Server]?// 添加的区块链节点
 }
 */
