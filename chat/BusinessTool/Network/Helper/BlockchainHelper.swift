//
//  BlockchainHelper.swift
//  chat
//
//  Created by 陈健 on 2021/1/4.
//

import Foundation

extension NSError {
    class var signError: NSError {
        let error = NSError.init(domain: "com.local.blockchain.sign.error", code: 778, userInfo: [NSLocalizedDescriptionKey: "签名错误"])
        return error
    }
}

//MARK:合约
class BlockchainHelper {
    //构造并发送不收手续费交易
    class func createNoBalanceTransaction(txHex: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = BlockchainPriKey
        Provider.request(BlockchainAPI.createNoBalanceTransaction(privateKey: privateKey, txHex: txHex), successBlock: successBlock, failureBlock: failureBlock)
    }
    
    //签名
    class func sign(privateKey: String, txHex: String, fee: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(BlockchainAPI.sign(privateKey: privateKey, txHex: txHex, fee: fee), successBlock: successBlock, failureBlock: failureBlock)
    }
    
    //发送交易
    class func sendTransaction(data: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        Provider.request(BlockchainAPI.sendTransaction(data: data), successBlock: successBlock, failureBlock: failureBlock)
    }
    
    //签名并发送交易
    class func signAndSendTransaction(privateKey: String, txHex: String, fee: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        self.sign(privateKey: privateKey, txHex: txHex, fee: fee, successBlock:  { (json) in
            if let data = json.string {
                self.sendTransaction(data: data, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    //构造不收手续费交易, 签名并发送交易
    class func createAndSignAndSendTransaction(privateKey: String, txHex: String, fee: Int, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        self.createNoBalanceTransaction(txHex: txHex, successBlock: { (json) in
            if let data = json.string {
                self.signAndSendTransaction(privateKey: privateKey, txHex: data, fee: fee, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    //MARK: - 好友
    
    //添加/更新好友列表
    class func addOrUpdateFriends(addressAndGroups: [(address: String, groups: [String])], successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        
        let privateKey = LoginUser.shared().privateKey
        
        let friends = addressAndGroups.compactMap { ["friendAddress": $0.address, "type": 1, "groups": $0.groups]}
        let params = ["friends": friends] as [String: Any]
        
        Provider.request(BlockchainAPI.updateFriends(params: [params]), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    //删除好友
    class func deleteFriends(addressAndGroups: [(address: String, groups: [String])], successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        
        let friends = addressAndGroups.compactMap { ["friendAddress": $0.address, "type": 2, "groups": $0.groups]}
        let params = ["friends": friends] as [String: Any]
        Provider.request(BlockchainAPI.updateFriends(params: [params]), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    //从合约拉取好友列表
    class func getFriends(count: Int, index: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        
        let publicKey = LoginUser.shared().publicKey
        let privateKey = LoginUser.shared().privateKey
        
        let mainAddress = EncryptManager.publicKeyToAddress(publicKey: publicKey)
        let time = Int(Date.timestamp)
        //按照字典key升序排序拼接字符串
        //拼接结果 "count=10000&index=&mainAddress=1NQSfNVefAf7yxQZEGxSbqc8NFBQRbRLWj&time=1581676678815"
        let dic = (["index": index, "mainAddress": mainAddress, "time": time,"count": count] as [String : Any])
        let str = dic.sorted { $0.key < $1.key }.compactMap { "\($0.key)=\($0.value)"}.joined(separator: "&")
        
        guard let rawValue = str.data(using: .utf8)?.sha256(),
              let signature =  EncryptManager.sign(data: rawValue, privateKey: privateKey) else {
            failureBlock?(NSError.signError)
            return
        }
        
        Provider.request(BlockchainAPI.getFriends(mainAddress: mainAddress, count: count, index: index, time: time, publicKey: publicKey, signature: signature), successBlock: successBlock, failureBlock: failureBlock)
        
    }
    
    //MARK: - 黑名单
    //添加黑名单
    class func addBlackList(address: [String], successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        
        let friends = address.compactMap { ["targetAddress": $0, "type": 1]}
        let params = ["list": friends] as [String: Any]
        
        Provider.request(BlockchainAPI.updateBlackList(params: [params]), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    //删除黑名单
    class func deleteBlackList(address: [String], successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        
        let friends = address.compactMap { ["targetAddress": $0, "type": 2]}
        let params = ["list": friends] as [String: Any]
        
        Provider.request(BlockchainAPI.updateBlackList(params: [params]), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    //从合约拉取黑名单列表
    class func getBlackList(count: Int, index: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        
        let publicKey = LoginUser.shared().publicKey
        let privateKey = LoginUser.shared().privateKey
        
        let mainAddress = EncryptManager.publicKeyToAddress(publicKey: publicKey)
        let time = Int(Date.timestamp)
        //按照字典key升序排序拼接字符串
        //拼接结果 "count=10000&index=&mainAddress=1NQSfNVefAf7yxQZEGxSbqc8NFBQRbRLWj&time=1581676678815"
        let dic = (["index": index, "mainAddress": mainAddress, "time": time,"count": count] as [String : Any])
        let str = dic.sorted { $0.key < $1.key }.compactMap { "\($0.key)=\($0.value)"}.joined(separator: "&")
        
        guard let rawValue = str.data(using: .utf8)?.sha256(),
              let signature =  EncryptManager.sign(data: rawValue, privateKey: privateKey) else {
            failureBlock?(NSError.signError)
            return
        }
        Provider.request(BlockchainAPI.getBlackList(mainAddress: mainAddress, count: count, index: index, time: time, publicKey: publicKey, signature: signature), successBlock: successBlock, failureBlock: failureBlock)
    }
    
    //MARK: - UpdateServerGroup
    class func  getServerGroup(mainAddress: String, count: Int, index: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let publicKey = LoginUser.shared().publicKey
        let privateKey = LoginUser.shared().privateKey
        
        let mainAddress = EncryptManager.publicKeyToAddress(publicKey: publicKey)
        let time = Int(Date.timestamp)
        //按照字典key升序排序拼接字符串
        //拼接结果 "count=10000&index=&mainAddress=1NQSfNVefAf7yxQZEGxSbqc8NFBQRbRLWj&time=1581676678815"
        let dic = (["index": index, "mainAddress": mainAddress, "time": time,"count": count] as [String : Any])
        let str = dic.sorted { $0.key < $1.key }.compactMap { "\($0.key)=\($0.value)"}.joined(separator: "&")
        
        guard let rawValue = str.data(using: .utf8)?.sha256(),
              let signature =  EncryptManager.sign(data: rawValue, privateKey: privateKey) else {
            failureBlock?(NSError.signError)
            return
        }
        Provider.request(BlockchainAPI.getServerGroup(mainAddress: mainAddress,count: count, index: index, time: time, publicKey: publicKey, signature: signature), successBlock: successBlock, failureBlock: failureBlock)
    }
    
    // 新增服务器
    class func addServerGroup(name: String, value: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        Provider.request(BlockchainAPI.updateServerGroup(id: "", type: 1, name: name, value: value), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    // 删除服务器
    class func deleteServerGroup(id: String, name: String, value: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        Provider.request(BlockchainAPI.updateServerGroup(id: id, type: 2, name: name, value: value), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    class func updateServerGroup(id: String, name: String, value: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        Provider.request(BlockchainAPI.updateServerGroup(id: id, type: 3, name: name, value: value), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    //MARK: - GetUserInfo
    class func getUser(targetAddress: String, count: Int, index: String, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let publicKey = LoginUser.shared().publicKey
        let privateKey = LoginUser.shared().privateKey
        
        let mainAddress = EncryptManager.publicKeyToAddress(publicKey: publicKey)
        let time = Int(Date.timestamp)
        //按照字典key升序排序拼接字符串
        //拼接结果 "count=10000&index=&mainAddress=1NQSfNVefAf7yxQZEGxSbqc8NFBQRbRLWj&time=1581676678815"
        let dic = (["index": index, "mainAddress": mainAddress, "time": time,"count": count, "targetAddress": targetAddress] as [String : Any])
        let str = dic.sorted { $0.key < $1.key }.compactMap { "\($0.key)=\($0.value)"}.joined(separator: "&")
        
        guard let rawValue = str.data(using: .utf8)?.sha256(),
              let signature =  EncryptManager.sign(data: rawValue, privateKey: privateKey) else {
            failureBlock?(NSError.signError)
            return
        }
        Provider.request(BlockchainAPI.getUser(mainAddress: mainAddress, targetAddress: targetAddress, count: count, index: index, time: time, publicKey: publicKey, signature: signature), successBlock: successBlock, failureBlock: failureBlock)
    }
    
    //MARK: - UpdateUserInfo
    
    class func updateUserInfo(name: BlockchainAPI.UpdateUserInfo, value: String, level: BlockchainAPI.UpdateUserLevel, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        Provider.request(BlockchainAPI.updateUser(name: name, type: 1, value: value, level: level), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
    
    class func deleteUserInfo(name: BlockchainAPI.UpdateUserInfo, value: String, level: BlockchainAPI.UpdateUserLevel, successBlock: Provider.SuccessBlock?, failureBlock: Provider.FailureBlock?) {
        let privateKey = LoginUser.shared().privateKey
        Provider.request(BlockchainAPI.updateUser(name: name, type: 2, value: value, level: level), successBlock: { (json) in
            if let result = json.string {
                self.createAndSignAndSendTransaction(privateKey: privateKey, txHex: result, fee: 0, successBlock: successBlock, failureBlock: failureBlock)
            }
        }, failureBlock: failureBlock)
    }
}
