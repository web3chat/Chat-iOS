//
//  SeedManager.swift
//  chat
//
//  Created by 陈健 on 2020/12/9.
//

import Foundation
import Walletapi

class SeedManager: NSObject {
    class func createSeed(isChinses: Bool) -> String? {
        let seed = isChinses ? WalletapiNewMnemonicString(1, 160, nil) : WalletapiNewMnemonicString(0, 128, nil)
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


