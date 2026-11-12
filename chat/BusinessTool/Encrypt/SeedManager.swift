//
//  SeedManager.swift
//  chat
//
//  Created by fzm on 2020/12/9.
//

import Foundation
import Walletapi

class SeedManager: NSObject {

    /// 助记词分片 s2 的 Keychain 存储（shareKey2，按手机号作为 account key）
    private static let shardS2Keychain: KeychainSwift = {
        let k = KeychainSwift(keyPrefix: "com.chat.mnemonicShard.s2.")
        k.synchronizable = false
        return k
    }()

    /// 密聊登录：按手机号存储 `GoFunction.encpassword` 与 `GoFunction.enckey` 结果，用于后续校验密码与加密助记词
    private static let chatLoginKeychain: KeychainSwift = {
        let k = KeychainSwift(keyPrefix: "com.chat.chatLogin.")
        k.synchronizable = false
        return k
    }()

    @discardableResult
    class func saveChatLoginSecrets(forPhone phone: String, encPasswordHex: String, encMnemonicHex: String) -> Bool {
        let passOK = chatLoginKeychain.set(encPasswordHex, forKey: "encpasswd.\(phone)", withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        let mnemOK = chatLoginKeychain.set(encMnemonicHex, forKey: "encmnemonic.\(phone)", withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        return passOK && mnemOK
    }

    class func chatLoginEncPassword(forPhone phone: String) -> String? {
        chatLoginKeychain.get("encpasswd.\(phone)")
    }

    class func chatLoginEncMnemonic(forPhone phone: String) -> String? {
        chatLoginKeychain.get("encmnemonic.\(phone)")
    }

    class func removeChatLoginSecrets(forPhone phone: String) {
        chatLoginKeychain.delete("encpasswd.\(phone)")
        chatLoginKeychain.delete("encmnemonic.\(phone)")
    }

    /// 将 s2 写入 Keychain（`phone` 为唯一键，勿与业务外其他 Keychain 项混用）
    @discardableResult
    class func saveMnemonicShardS2(_ s2: String, forPhone phone: String) -> Bool {
        shardS2Keychain.set(s2, forKey: phone, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
    }

    /// 从 Keychain 读取当前手机号对应的 s2
    class func mnemonicShardS2(forPhone phone: String) -> String? {
        
        if let s2 = shardS2Keychain.get(phone) {
            return s2
        }
        return nil
    }

    /// 删除某手机号下的 s2（如注销、换绑等场景可调用）
    @discardableResult
    class func removeMnemonicShardS2(forPhone phone: String) -> Bool {
        shardS2Keychain.delete(phone)
    }
    class func createSeed(isChinses: Bool) -> String? {
        let seed = isChinses ? WalletapiNewMnemonicString(1, 160, nil) : WalletapiNewMnemonicString(0, 128, nil)
        return seed
    }
    
    class func spliteMnemonic(seed:String) -> WalletapiSpliteKey? {
        let splite = WalletapiSpliteMnemonic(seed, nil)
        return splite
    }
    
    class func recoverMnemonic(s1:String,s2:String) -> String? {
        let seed = WalletapiRecoverMnemonic(s1, s2, nil)
        return seed 
    }
    
    class func encrypt(seed: String, pwd: String) -> String? {
        guard let encSeed = WalletapiSeedEncKey(WalletapiEncPasswd(pwd), WalletapiStringTobyte(seed, nil), nil) else {
            return nil
        }
        let encString = WalletapiBytes2Hex(encSeed)
        return encString
    }
    
    class func decrypt(encSeed: String, pwd: String) -> String? {
        var error: NSError?
        let seed = WalletapiByteTostring(WalletapiSeedDecKey(WalletapiEncPasswd(pwd), WalletapiHexTobyte(encSeed), &error))
        return error == nil ? seed : nil
    }
    
    class func keyBy(seed: String) -> (priKey: String, pubKey: String)? {
        let seeds = seed.isIncludeChinese ? self.formatSeed(seed: seed) : seed
        guard let wallet = WalletapiNewWalletFromMnemonic_v2("BTY", seeds, nil),
            let pubKeyData = try? wallet.newKeyPub(0),
            let priKeyData = try? wallet.newKeyPriv(0) else {
            return nil
        }
        let priKey = WalletapiBytes2Hex(priKeyData)
        let pubKey = WalletapiBytes2Hex(pubKeyData)
        return (priKey,pubKey)
    }
    
    class  func formatSeed(seed: String) -> String? {
        let seeds = seed.withoutSpacesAndNewLines
        let mnemonicStr = NSMutableString.init()
        for i in 0 ..< seeds.count {
            mnemonicStr.append(seeds.substring(with: NSMakeRange(i, 1)))
            if i != seeds.count - 1 {
                mnemonicStr.append(" ")
            }
        }
        return mnemonicStr as String
    }
    
}


