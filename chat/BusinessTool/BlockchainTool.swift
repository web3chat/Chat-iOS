//
//  BlockchainTool.swift
//  chat
//
//  Created by 郑晨 on 2025/3/5.
//

@objc class BlockchainTool:NSObject {
    
    @objc  func getBlockChain() -> NSString {
        var str : NSString = ""
//        if let server = OfficialBlockchainServers?.first {
//            BlockchainServerInUse = server
//        } else {
            // 如果有保存的节点
        if let blockchainServers = UserDefaultsDB.chainServerList, let server = blockchainServers.first {
            BlockchainServerInUse = server
        } else {
            APP.shared().getOfficialServerRequest { (json) in
                let servers = json["nodes"].arrayValue.compactMap {
                    Server.init(name: $0["name"].stringValue, value: $0["address"].stringValue)
                }
                if let server = servers.first {
                    BlockchainServerInUse = server
                }
                
            } failureBlock: { (error) in
                
            }
        }
//        }
        if BlockchainServerInUse != nil {
            let block = (BlockchainServerInUse?.value)!
            str = block as NSString
        }else{
            str = GoNodeUrl as NSString
        }
        
        return str
    }
    
    @objc func getSessionId() -> NSString {
        var str : NSString = ""
        
        str = LoginUser.shared().address as NSString
        
        return str
    }
}
