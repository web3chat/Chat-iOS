//
//  TeamAPI.swift
//  chat
//
//  Created by 王俊豪 on 2021/9/11.
//

import Foundation
import Moya

enum TeamAPI {
    case getServer// 获得默认 IM 服务器和区块链服务器
    case enterpriseInfo(teamId: String)// 查询企业信息
    case getStaff(address: String)// 获取员工信息
    case getBind(address: String)// 获取绑定信息
}

extension TeamAPI: XLSTargetType {
    
    var baseURL: URL {
        return URL.init(string: TeamOAServerUrl)!
    }
    
    var parameters: [String : Any] {
        switch self {
        case .getServer:
            return [:]
        case .enterpriseInfo(let teamId):
            return ["id": teamId]
        case .getStaff(let address):
            return ["id": address]
        case .getBind(let address):
            return ["id": address]
        }
    }
    
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .getServer:
            return "/v1/common/get-server"
        case .enterpriseInfo:
            return "/v1/enterprise/info"
        case .getStaff:
            return "/v1/staff/get-staff"
        case .getBind:
            return "/v1/account/get-bind"
        }
    }
}
