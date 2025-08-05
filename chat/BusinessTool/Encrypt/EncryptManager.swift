//
//  FZMEncryptManager.swift
//  隐私
//
//  Created by 陈健 on 2019/5/21.
//  Copyright © 2019 陈健. All rights reserved.
//

import Foundation
import SwiftyJSON
import Walletapi
import CryptoSwift
import CommonCrypto
import CryptoKit
import SwifterSwift
import SwiftUI

class EncryptManager: NSObject {
    
    /// 加密群聊消息
    /// - Parameters:
    ///   - data: 群聊消息内容
    ///   - publickey: 群聊加密密钥
    /// - Returns: 加密后的data
   class func encryptGroupData(_ data: Data, publickey: String) -> Data {
       guard !publickey.isBlank else { return data }
       guard !data.isEmpty else { return data }
       
//       // 生成16位随机字符串
//       let iv = String.randomStringWithLength(len: 16)
       let ivB: Array<UInt8> = AES.randomIV(AES.blockSize)// 生成长度为16字节的随机值数组
       
       guard let keyData = WalletapiHexTobyte(publickey.finalKey) else {
           return data
       }
       let key = Array(keyData)
       
       // byte 数组
       //FIXME: 加密非常耗时
       var encrypted: [UInt8] = []
       do {
//           encrypted = try AES(key: key, blockMode: CBC(iv: iv.bytes), padding: .pkcs5).encrypt(data.bytes)
           encrypted = try AES(key: key, blockMode: CBC(iv: ivB), padding: .pkcs7).encrypt(data.bytes)
           
       } catch {
           return data
       }
       
//       let finalData = iv.data(using: .utf8)! + Data(encrypted)
       let finalData = Data(ivB) + Data(encrypted)
       
       return finalData
   }
    
    /// 解密群聊相关数据
    /// - Parameters:
    ///   - data: 需解密的数据源
    ///   - publicKey: 群密钥
    /// - Returns: 返回解密后的数据（解密失败返回原数据）
   class func decryptGroupData(_ data: Data, publicKey: String) -> Data {
       guard !publicKey.isBlank else { return data }
       guard !data.isEmpty else { return data }
       guard data.count > 16 else {
           return data
       }
       let ivData = data.subdata(in: Range.init(NSRange(location: 0, length: 16))!)
       
       guard let keyData = WalletapiHexTobyte(publicKey.finalKey) else {
           return data
       }
       let key = Array(keyData)
       let count = data.count
       
       let encryptData = data.subdata(in: Range.init(NSRange(location: 16, length: count - 16))!)
       
       let encryptDatacount = encryptData.count
       var encrypt:[UInt8] = []
       // 把data转为byte数组
       for i in 0..<encryptDatacount {
           var temp:UInt8 = 0
           (encryptData as NSData).getBytes(&temp, range: NSRange(location: i,length:1))
           encrypt.append(temp)
       }

       var decrypted: [UInt8] = []
       
       do {
           decrypted = try AES(key: key, blockMode: CBC(iv: ivData.bytes), padding: .pkcs7).decrypt(encrypt)
       } catch {
           return data
       }
       
       // byte 转换成NSData
       let encoded = Data(decrypted)
       
       return encoded
   }
    
    /// 加密群名
    /// - Parameters:
    ///   - name: 需加密的群名
    ///   - key: 群加密私钥
    /// - Returns: 返回ASCII格式的字符串
    class func encryptGroupName(_ name: String, key: String) -> String {
        guard !key.isBlank, !key.isBlank, !name.isBlank else {
            return name
        }
        guard let nameData = name.data(using: .utf8) else {
            return name
        }
        guard let keyData = WalletapiHexTobyte(key.finalKey) else {
            return name
        }
        let keyAES = Array(keyData)
        
        // 生成16位随机字符串
//        let iv = String.randomStringWithLength(len: 16)
        let ivB: Array<UInt8> = AES.randomIV(AES.blockSize)// 生成长度为16字节的随机值数组
        
        // byte 数组
        var encrypted: [UInt8] = []
        do {
//            encrypted = try AES(key: keyAES, blockMode: CBC(iv: iv.bytes), padding: .pkcs5).encrypt(nameData.bytes)
            encrypted = try AES(key: keyAES, blockMode: CBC(iv: ivB), padding: .pkcs7).encrypt(nameData.bytes)
        } catch {
            return name
        }
        
//        let finalData = iv.data(using: .utf8)! + Data(encrypted)
        let finalData = Data(ivB) + Data(encrypted)
        
        guard finalData.count > 0, let finalName = finalData.base64EncodedData(options: .init(rawValue: 0)).stringASCII else {
            return name
        }
        
        return finalName
    }
    
    
    /// 解密群名
    /// - Parameters:
    ///   - name: 需解密的群名
    ///   - key: 群加密私钥
    /// - Returns: 返回解密后的群名
    class func decryptGroupName(_ name: String, key: String) -> String {
        guard !key.isBlank, !name.isBlank else {
            return name
        }
        guard let nameData = name.data(using: .ascii), let nameDataBase64 = Data(base64Encoded: nameData), nameDataBase64.count > 16 else {
            return name
        }
        guard nameDataBase64.count > 16 else {
            return name
        }
        let ivData = nameDataBase64.subdata(in: Range.init(NSRange(location: 0, length: 16))!)
        
        guard let keyData = WalletapiHexTobyte(key.finalKey) else {
            return name
        }
        let keyAES = Array(keyData)
        
        let count = nameDataBase64.count
        
        let encryptData = nameDataBase64.subdata(in: Range.init(NSRange(location: 16, length: count - 16))!)
        
        let encryptDatacount = encryptData.count
        var encrypt:[UInt8] = []
        // 把data转为byte数组
        for i in 0..<encryptDatacount {
            var temp:UInt8 = 0
            (encryptData as NSData).getBytes(&temp, range: NSRange(location: i,length:1))
            encrypt.append(temp)
        }
        var decrypted: [UInt8] = []
        
        do {
            decrypted = try AES(key: keyAES, blockMode: CBC(iv: ivData.bytes), padding: .pkcs7).decrypt(encrypt)
        } catch {
            return name
        }
        // byte 转换成NSData
        let encoded = Data(decrypted)
        guard encoded.count > 0, let finalName = encoded.stringUTF8 else {
            return name
        }
        return finalName
    }
    
    /**
     * 上传服务端的数据加密
     * 加密规则 *
     *
     * 加密使用的key：使用go包内的generateDHSessionKey方法生成加密使用的key，使用对方的公钥和自己的私钥作为参数生成
     * 加密使用的iv：随机生成的字符串（大小写字母+数字 a-zA-Z0-9）
     * 使用AES的CBC pkcs5加密
     * 在加密完的data前拼接上转为长度为 16 bytes的Data类型数据的iv
     *
     * 解密使用的iv：从接收的data中截取前面16 bytes，并转化为string类型作为解密的iv
     */
    /// 上传服务端的数据加密
    /// - Parameters:
    ///   - data: 需加密的data数据
    ///   - publickey: 对方用户的公钥
    /// - Returns: 加密后的data数据
    class func encryptFileData(_ data: Data, publickey: String) -> Data {
        guard !publickey.isBlank else { return data }
        guard !data.isEmpty else { return data }
        
//        [self desencrypt(data, publickey: publickey)];
        
        
        // FIXME: 加密问题
        
        // 生成16位随机字符串
//        let iv = String.randomStringWithLength(len: 16)
        let ivB: Array<UInt8> = AES.randomIV(AES.blockSize)
        
        guard let keyData = self.generateDHSessionKeyData(privateKey: LoginUser.shared().privateKey, publicKey: publickey) else { return data }
        
//        let encryptData = data.aesEncrypt(keyData: keyData)
//        return encryptData
        
        
        let key = Array(keyData)

        // byte 数组
        var encrypted: [UInt8] = []
        do {
//            encrypted = try AES(key: key, blockMode: CBC(iv: iv.bytes), padding: .pkcs5).encrypt(data.bytes)
//            encrypted = try AES(key: key, blockMode: CBC(iv: ivB), padding: .pkcs7).encrypt(data.bytes)
            let aes = try AES(key: key, blockMode: CBC(iv: ivB), padding: .pkcs7)
//            encrypted = try aes.encrypt(data.bytes)
            var encryptor = try aes.makeEncryptor()
            encrypted += try encryptor.update(withBytes: data.bytes)
            encrypted += try encryptor.finish()
            
        } catch {
            return data
        }
        
//        let finalData = iv.data(using: .utf8)! + Data(encrypted)
        let finalData = Data(ivB) + Data(encrypted)

        return finalData
    }
    
    /// DES 加密
    /// - Parameters:
    ///   - data: 需要加密的数据
    ///   - key: 加密 密钥 8 位长度
    /// - Returns: 加密后的数据
   @objc class func desencrypt(_ data:Data, publickey:String) -> Data{
        guard !publickey.isBlank else { return data }
        guard !data.isEmpty else { return data }
        let key = String.randomStringWithLength(len: 8)
//        let ivB: Array<UInt8> = AES.randomIV(AES.blockSize)
       
        let keyLength = kCCKeySizeDES + 1
            
            var keyPtr:Array<CChar> = []

            for _:Int in 0 ..< keyLength {
                keyPtr.append(CChar(0))
            }
            
            if key.getCString(&keyPtr, maxLength: keyLength, encoding: .utf8) {
                
                let dataLength:Int = data.count
                
                let bufferSize:Int = dataLength + kCCBlockSizeDES
                
                let buffer = malloc(bufferSize)
                
                var numBytesEncrypted:Int = 0
                
                let bytes = [UInt8](data)
                
                let cryptStatus:CCCryptorStatus = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmDES), CCOptions(ccPKCS7Padding | kCCModeECB) , keyPtr, kCCKeySizeDES, nil, bytes, dataLength, buffer, bufferSize, &numBytesEncrypted)
                
                var outData:Data?
                
                if cryptStatus == kCCSuccess {
                    
                    outData = Data.init(bytes: buffer!, count: numBytesEncrypted)
                }
                
                free(buffer)
                
                let data:Data = key.data(using: .utf8)!
                
                return data + outData!
            }
        
        
        
        return data
    }
    
    /// DES 解密
    /// - Parameters:
    ///   - data: 需要解密的数据
    ///   - key: 解密的密钥 8位
    /// - Returns: 解密后的数据
     class func desdecrypt(_ data:Data,publickey:String) -> Data {

        guard !publickey.isBlank else { return data }
        guard !data.isEmpty else { return data }
        
        guard data.count > 8 else {
            return data
        }
       
        let keyData = data.subdata(in: Range.init(NSRange(location: 0, length: 8))!)
        let count = data.count
        let encryptData = data.subdata(in: Range.init(NSRange(location: 8, length: count - 8))!)
        let key : String = String.init(data: keyData, encoding: .utf8)!
        
        let keyLength = kCCKeySizeDES + 1
        
        var keyPtr:Array<CChar> = []
        
        for _:Int in 0 ..< keyLength {
            keyPtr.append(CChar(0))
        }

        if key.getCString(&keyPtr, maxLength: keyLength, encoding: .utf8) {
            
            let dataLength:Int = encryptData.count
            
            let bufferSize:Int = dataLength + kCCBlockSizeDES
            
            let buffer = malloc(bufferSize)
            
            var numBytesDecrypted:Int = 0
            
            let bytes = [UInt8](encryptData)
            
            let cryptStatus:CCCryptorStatus = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmDES), CCOptions(ccPKCS7Padding | kCCModeECB) , keyPtr, kCCKeySizeDES, nil, bytes, dataLength, buffer, bufferSize, &numBytesDecrypted)
            
            var outData:Data?
            
            if cryptStatus == kCCSuccess {
                
                outData = Data.init(bytes: buffer!, count: numBytesDecrypted)
            }
            
            free(buffer)

            return outData!
        }
        
        return data
    }
    
    
    /**
     * 接收服务端的数据解密
     * 解密规则 *
     *
     * 解密使用的key：使用go包内的generateDHSessionKey方法生成加密使用的key，使用对方的公钥和自己的私钥作为参数生成
     * 解密使用的iv：在接收到的data前截取长度为 16 bytes的Data类型数据作为iv
     * 截取完长度为 16 bytes的Data类型数据再用AES的CBC pkcs5解密
     *
     */
    class func decryptFileData(_ data: Data, publicKey: String) -> Data{
        guard !publicKey.isBlank else { return data }
        guard !data.isEmpty else { return data }
        
        guard data.count > 16 else {
            return data
        }
       
        let ivData = data.subdata(in: Range.init(NSRange(location: 0, length: 16))!)
        
        guard let keyData = self.generateDHSessionKeyData(privateKey: LoginUser.shared().privateKey, publicKey: publicKey) else { return data }
        
//        let decryptData = data.aesDecrypt(keyData: keyData)
//        return decryptData
        
        let key = Array(keyData)
        let count = data.count

        let encryptData = data.subdata(in: Range.init(NSRange(location: 16, length: count - 16))!)

        let encryptDatacount = encryptData.count
        var encrypt:[UInt8] = []
        // 把data转为byte数组
        for i in 0..<encryptDatacount {
            var temp:UInt8 = 0
            (encryptData as NSData).getBytes(&temp, range: NSRange(location: i,length:1))
            encrypt.append(temp)
        }

        var decrypted: [UInt8] = []

        do {
            
//            decrypted = try AES(key: key, blockMode: CBC(iv: ivData.bytes), padding: .pkcs7).decrypt(encrypt)
            let aes = try AES(key: key, blockMode: CBC(iv: ivData.bytes), padding: .pkcs7)
            var decryptor = try aes.makeDecryptor()
            decrypted += try decryptor.update(withBytes: encrypt)
            decrypted += try decryptor.finish()
            
//            decrypted = try aes.decrypt(encrypt)
        } catch {
            return data
        }

        // byte 转换成NSData
        let encoded = Data(decrypted)

        return encoded
    }
    
    /// 加密私聊消息体
    /// - Parameters:
    ///   - data: 私聊消息体数据
    ///   - targetPublickey: 用户公钥
    /// - Returns: 加密后的消息体数据（加密失败返回原数据）
    class func encryptPersionChatMsgData(_ data: Data, targetPublickey: String) -> Data {
        let privateKey = LoginUser.shared().privateKey
        var error: NSError?
        if let msgData = WalletapiEncryptWithDHKeyPair(privateKey, targetPublickey, data, &error),
           error == nil {
            return msgData
        }
        return data
    }
    
    /// 解密私聊消息体
    /// - Parameters:
    ///   - data: 私聊消息体数据
    ///   - targetPublickey: 用户公钥
    /// - Returns: 解密后的消息体数据（解密失败返回原数据）
    class func decryptPersionChatMsgData(_ data: Data, targetPublickey: String) -> Data {
        let privateKey = LoginUser.shared().privateKey
        var error: NSError?
        if let msgData = WalletapiDecryptWithDHKeyPair(privateKey, targetPublickey, data, &error),
           error == nil {
            return msgData
        }
        return data
    }
    
    class func encryptSymmetric(privateKey: String, publicKey: String, plaintext: Data) -> Data? {
        if let symmetricKey = EncryptManager.generateDHSessionKey(privateKey: privateKey, publicKey: publicKey), let ciphertext = EncryptManager.encryptSymmetric(key: symmetricKey, plaintext: plaintext) {
            return ciphertext
        }
        return nil
    }
    
    class func decryptSymmetric(privateKey: String, publicKey: String, ciphertext: Data) -> Data? {
        if let symmetricKey = EncryptManager.generateDHSessionKey(privateKey: privateKey, publicKey: publicKey), let plaintext = EncryptManager.decryptSymmetric(key: symmetricKey, ciphertext: ciphertext) {
            return plaintext
        }
        return nil
    }
    
    class func generateDHSessionKey(privateKey: String, publicKey: String) -> String? {
        var error: NSError?
        if let keyData = WalletapiGenerateDHSessionKey(privateKey, publicKey, &error),
            error == nil {
            let symmetricKey = WalletapiBytes2Hex(keyData)
            return symmetricKey
        }
        return nil
    }
    
    class func generateDHSessionKeyData(privateKey: String, publicKey: String) -> Data? {
        var error: NSError?
        if let keyData = WalletapiGenerateDHSessionKey(privateKey, publicKey, &error),
            error == nil  {
            return keyData
        }
        return nil
    }
    
    class func encryptSymmetric(key: String, plaintext: Data) -> Data? {
        var error: NSError?
        if let ciphertext = WalletapiEncryptSymmetric(key, plaintext, &error),
            error == nil {
            return ciphertext
        }
        return nil
    }
    
    class func decryptSymmetric(key: String, ciphertext: Data) -> Data? {
        var error: NSError?
        if let plaintext = WalletapiDecryptSymmetric(key, ciphertext, &error),
            error == nil {
            return plaintext
        }
        return nil
    }
    
    class func publicKeyToAddress(publicKey: String) -> String {
       
        return WalletapiPubToAddress_v2("BTY",Data.init(hex: publicKey), nil)
    }
    
    class func sign(data: Data, privateKey: String) -> String? {
        var error: NSError?
        if let result = WalletapiChatSign(data, Data.init(hex: privateKey), &error), error == nil {
            let resultStr = WalletapiBytes2Hex(result)
            return resultStr
        }
        return nil
    }
    
    class func signBase64(data: Data, privateKey: String) -> String? {
        var error: NSError?
        guard let result = WalletapiChatSign(data, Data.init(hex: privateKey), &error),
              error == nil else { return nil }
        return result.base64EncodedString()
    }
}
