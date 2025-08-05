//
//  Blockchain.swift
//  chat
//
//  Created by 陈健 on 2021/1/4.
//

import Foundation
import Moya

enum BlockchainAPI {
    //去中心化
    // 构造并发送不收手续费交易
    case createNoBalanceTransaction(privateKey: String, txHex: String)
    //签名 https://chain.33.cn/document/93
    case sign(privateKey: String, txHex: String, fee: Int)
    //发送交易
    case sendTransaction(data: String)
    //更新好友 https://gitlab.33.cn/contract/addrbook
    case updateFriends(params: [[String:Any]])
    //获取合约上的好友 index 索引开始地址
    case getFriends(mainAddress: String, count: Int, index: String, time: Int, publicKey: String, signature: String)
    //通过uid(地址)批量获取用户信息
    //更新黑名单 https://gitlab.33.cn/contract/addrbook
    case updateBlackList(params: [[String:Any]])
    //获取合约上的黑名单 index 索引开始地址
    case getBlackList(mainAddress: String, count: Int, index: String, time: Int, publicKey: String, signature: String)
    case getUser(mainAddress: String, targetAddress: String, count: Int, index: String, time: Int, publicKey: String, signature: String)
    
    case getServerGroup(mainAddress: String, count: Int, index: String, time: Int, publicKey: String, signature: String)
    
    //更新分组信息 type 1->新增；2->删除；3->修改
    case updateServerGroup(id: String, type: Int, name: String, value: String)
    
    //UpdateUser(更新用户信息) 1->新增/修改；2->删除 , level 0 = [private]、1 = [protect]、2 = [public]
    enum UpdateUserInfo: String {
        case nickname = "nickname"
        case phone = "phone"
        case pubKey = "pubKey"
        case avatar = "avatar"
        case eth = "chain.ETH"
        case bnb = "chain.BNB"
        case bty = "chain.BTY"
    }
    
    enum UpdateUserLevel: String {
        case `private` = "private"
        case protect = "protect"
        case `public`  = "public"
    }
    case updateUser(name: UpdateUserInfo, type: Int, value: String, level: UpdateUserLevel)
}

extension BlockchainAPI: XLSTargetType {
    
    var baseURL: URL {
        return URL.init(string: BlockchainServerInUse?.value)  ?? URL.init(string: "http://57.180.61.19:8058")!
    }
    
    var path: String {
        return ""
    }
    
    
    var method: Moya.Method {
        return .post
    }
    
    func validation(_ result: Result<Moya.Response, MoyaError>) -> Result<JSON, Error> {
        switch result {
        case .success(let response):
            guard response.statusCode == 200 else {
                let error = NSError.init(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: response.description])
                return Result<JSON, Error>.failure(error)
            }
            
            let json = JSON.init((try? response.mapJSON()) as Any)
            print("user json",json)
            let error = json["error"].stringValue
            guard error.isEmpty else {
                let error = NSError.init(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
                return Result<JSON, Error>.failure(error)
            }
            return Result<JSON, Error>.success(json["result"])
        case .failure(let error):
            var errorInfo = ""
            switch error.errorCode {
            case NSURLErrorNotConnectedToInternet:
                errorInfo = "无网络，请检查网络连接"
            case NSURLErrorTimedOut:
                errorInfo = "请求超时，请检查网络连接"
            default:
                errorInfo = "网络连接错误，请稍后再试"
            }
            let error = NSError.init(domain: "", code: error.errorCode, userInfo: [NSLocalizedDescriptionKey: errorInfo])
            return Result<JSON, Error>.failure(error)
        }
    }
    
    var parameters: [String : Any] {
        switch self {
        case .createNoBalanceTransaction(let privateKey, let txHex):
            return ["jsonrpc": "2.0",
                    "id":1,
                    "method": "Chain33.CreateNoBalanceTransaction",
                    "params":[["privkey": privateKey,
                               "txHex": txHex,
                               "index":0]]]
        case .sign(let privateKey, let txHex, let fee):
            return ["jsonrpc": "2.0",
                    "id":1,
                    "method": "Chain33.SignRawTx",
                    "params":[["privkey": privateKey,
                               "txHex": txHex,
                               "expire": "2h45m",
                               "fee": fee,
                               "index":2]]]
        case .sendTransaction(let data):
            return ["jsonrpc": "2.0",
                    "id":1,
                    "method": "Chain33.SendTransaction",
                    "params":[["data": data]]]
        case .updateFriends(let params):
            return ["jsonrpc": "2.0",
                    "id":1,
                    "method": "chat.CreateRawUpdateFriendTx",
                    "params":params]
        case .getFriends(let mainAddress, let count, let index, let time, let publicKey, let signature):
            let params = ["execer": "chat",
                          "funcName": "GetFriends",
                          "payload":["mainAddress":mainAddress,
                                     "count": count,
                                     "index": index,
                                     "time":time,
                                     "sign":["publicKey": publicKey,
                                             "signature": signature]]] as [String : Any]
            return ["jsonrpc": "2.0",
                    "id":1,
                    "method": "Chain33.Query",
                    "params":[params]]
        case .updateBlackList(let params):
            return ["jsonrpc": "2.0",
                    "method": "chat.CreateRawUpdateBlackTx",
                    "id": 1,
                    "params":params]
        case .getBlackList(let mainAddress, let count, let index, let time, let publicKey, let signature):
            let params = ["execer": "chat",
                          "funcName": "GetBlackList",
                          "payload":["mainAddress":mainAddress,
                                     "count": count,
                                     "index": index,
                                     "time":time,
                                     "sign":["publicKey": publicKey,
                                             "signature": signature]]] as [String : Any]
            return ["jsonrpc": "2.0",
                    "method": "Chain33.Query",
                    "id": 1,
                    "params":[params]]
            
        case .getUser(let mainAddress, let targetAddress, let count, let index, let time, let publicKey, let signature):
            let params = ["execer": "chat",
                          "funcName": "GetUser",
                          "payload":["mainAddress":mainAddress,
                                     "targetAddress": targetAddress,
                                     "count": count,
                                     "index": index,
                                     "time":time,
                                     "sign":["publicKey": publicKey,
                                             "signature": signature]]] as [String : Any]
            return ["jsonrpc": "2.0",
                    "method": "Chain33.Query",
                    "id": 1,
                    "params":[params]]
            
        case .getServerGroup(let mainAddress, let count, let index, let time, let publicKey, let signature):
            let params = ["execer": "chat",
                          "funcName": "GetServerGroup",
                          "payload":["mainAddress":mainAddress,
                                     "count": count,
                                     "index": index,
                                     "time":time,
                                     "sign":["publicKey": publicKey,
                                             "signature": signature]]] as [String : Any]
            return ["jsonrpc": "2.0",
                    "method": "Chain33.Query",
                    "params":[params]]
        case .updateServerGroup(let id, let type, let name, let value):
            let groups = ["id": id, "type": type, "name": name, "value": value] as [String : Any]
            let params = ["groups": [groups]] as [String : Any]
            return ["jsonrpc": "2.0",
                    "id":1,
                    "method": "chat.CreateRawUpdateServerGroupTx",
                    "params":[params]]
            
        case .updateUser(let name, let type, let value, let level):
            let dic = ["name": name.rawValue, "type": type, "value": value, "level": level.rawValue] as [String : Any]
            let fields = ["fields": [dic]]
            return ["jsonrpc": "2.0",
                    "id":1,
                    "method": "chat.CreateRawUpdateUserTx",
                    "params":[fields]]
        }
    }
    
    
}


