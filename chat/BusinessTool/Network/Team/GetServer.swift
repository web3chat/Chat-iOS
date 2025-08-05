//
//  GetServer.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/11.
//  /v1/common/get-server 获得默认 IM 服务器和区块链服务器

import Foundation

struct GetServer {
    var IMServer: String// IM聊天服务器
    var nodeServer: String// 区块链服务器
}

extension GetServer {
    init(json: JSON) {
        self.IMServer = json["IMServer"].stringValue
        self.nodeServer = json["nodeServer"].stringValue
    }
}

