//
//  MessageSigner.swift
//  chat
//
//  Copyright © 2026 fzm. All rights reserved.
//

import Foundation
import CryptoSwift
import Web3Core

/// 消息签名工具类
public class MessageSigner: NSObject {
    
    /// 单例实例
    @objc public static let shared = MessageSigner()
    
    private override init() {
        super.init()
    }
    
    /// 签名个人消息 (Personal Message)
    /// - Parameters:
    ///   - message: 要签名的消息字符串
    ///   - privateKey: 私钥字符串 (hex 格式)
    /// - Returns: 签名后的 hex 字符串
    @objc public func signPersonalMessage(message: String, privateKey: String) -> String? {
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        
        // Ethereum Signed Message 前缀
        let prefix = "\u{19}Ethereum Signed Message:\n\(messageData.count)".data(using: .utf8)!
        let sha3Data = prefix + messageData
        let hash = sha3Data.sha3(.keccak256)
        
        guard let privateKeyData = WalletapiHexTobyte(privateKey) else {
            return nil
        }
        
        guard let signedData = SECP256K1.signForRecovery(hash: hash, privateKey: privateKeyData).serializedSignature else {
            print("[MessageSigner] Sign error")
            return nil
        }
        return signedData.toHexString()
    }
    
    /// 签名个人消息 - 异步版本
    /// - Parameters:
    ///   - message: 要签名的消息字符串
    ///   - privateKey: 私钥字符串 (hex 格式)
    /// - Returns: 签名后的 hex 字符串
    @objc public func signPersonalMessage(message: String, privateKey: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.signPersonalMessage(message: message, privateKey: privateKey)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
