//
//  ChatManager+Encryption.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/2.
//

import Foundation
import RxRelay
import SwiftProtobuf

/**
  如果加密则文件名拼上特殊字符串 "$ENC$"，解密时判断文件名是否包含此字符串以判断是否为加密上传的文件
 */
let encryptFlgStr = "$ENC$"

extension ChatManager {
    
    /// 从 临时数据源 或 数据库 或 链上 获取用户公钥/群密钥
    /// - Parameters:
    ///   - address: 用户/群地址
    ///   - isGetUserKey: 获取用户公钥或者群密钥标识flg
    ///   - publickeyBlock: 获取到密钥的回调
    class func getPublickey(by address: String, isGetUserKey: Bool, chatServerUrl: String? = "", publickeyBlock: StringBlock?) {
        if isGetUserKey {
            UserManager.shared().getUserPublickey(by: address) { (pubkey) in
                publickeyBlock?(pubkey)
            }
        } else {
            GroupManager.shared().getGroupKey(by: address.intEncoded, chatServerUrl: chatServerUrl) { (pubkey) in
                
                publickeyBlock?(pubkey)
            }
        }
    }
    
    /// 加密上传文件数据
    /// - Parameters:
    ///   - data: 需加密的源数据（图片、文件、视频、音频等需上传的文件数据）
    ///   - publickey: 加密所需的密钥（用户公钥/群密钥）
    ///   - isEncryptPersionChatData: 加密私聊发送/群消息发送flg
    /// - Returns: 返回加密后的数据（加密失败返回原数据）
    class func encryptUploadData(_ data: Data, publickey: String, isEncryptPersionChatData: Bool) -> Data {

//        guard let keyData = EncryptManager.generateDHSessionKeyData(privateKey: LoginUser.shared().privateKey, publicKey: publickey) else {return data}
        let keyData = isEncryptPersionChatData ? EncryptManager.generateDHSessionKeyData(privateKey: LoginUser.shared().privateKey, publicKey: publickey) : WalletapiHexTobyte(publickey)
        
        if isEncryptPersionChatData {
            return data.aesEncrypt(keyData: keyData!)
        } else {
            return data.aesEncrypt(keyData: keyData!)
        }
    }
    
    /// 解密收到的文件数据
    /// - Parameters:
    ///   - data: 需解密的源数据（图片、文件、视频、音频等需上传的文件数据）
    ///   - publickey: 解密所需的密钥（用户公钥/群密钥）
    ///   - isEncryptPersionChatData: 解密接收私聊/群消息文件flg
    /// - Returns: 返回解密后的数据（解密失败返回原数据）
    class func decryptUploadData(_ data: Data, publickey: String, isEncryptPersionChatData: Bool) -> Data {
       
//        guard let keyData = EncryptManager.generateDHSessionKeyData(privateKey: LoginUser.shared().privateKey, publicKey: publickey) else {return data}
        let keyData = isEncryptPersionChatData ? EncryptManager.generateDHSessionKeyData(privateKey: LoginUser.shared().privateKey, publicKey: publickey) : WalletapiHexTobyte(publickey)
        
        if isEncryptPersionChatData {
            return data.aesDecrypt(keyData: keyData!)

        } else {
            return data.aesDecrypt(keyData: keyData!
            )

        }
    }
    
    /// 加密消息体
    /// - Parameters:
    ///   - data: 需加密的消息体数据
    ///   - publickey: 加密用的用户公钥/群密钥
    ///   - isEncryptPersionChatData: 加密私聊发送/群消息发送flg
    /// - Returns: 返回加密后的数据（加密失败返回原数据）
    class func encryptMsgData(_ data: Data, publickey: String, isEncryptPersionChatData: Bool) -> Data {
        if isEncryptPersionChatData {
            return EncryptManager.encryptPersionChatMsgData(data, targetPublickey: publickey.finalKey)
        } else {
            return EncryptManager.encryptGroupData(data, publickey: publickey)
        }
    }
    
    /// 解密消息体
    /// - Parameters:
    ///   - data: 需解密的消息体数据
    ///   - publickey: 解密用的用户公钥/群密钥
    ///   - isEncryptPersionChatData: 解密私聊发送/群消息发送flg
    /// - Returns: 返回解密后的数据（解密失败返回原数据）
    class func decryptMsgData(_ data: Data, publickey: String, isEncryptPersionChatData: Bool) -> Data {
        if isEncryptPersionChatData {
            return EncryptManager.decryptPersionChatMsgData(data, targetPublickey: publickey.finalKey)
        } else {
            return EncryptManager.decryptGroupData(data, publicKey: publickey)
        }
    }
}
