//
//  TokenAPI.swift
//  chat
//
//  Created by 陈健 on 2021/1/29.
//

import Foundation
import Moya

enum TokenAPI {
    case OSSToken//阿里云
    case OBSToken//华为云
}

extension TokenAPI: XLSTargetType {
    
    var baseURL: URL {
        return URL.init(string: BackupURL) ?? URL.init(string: "https://api.unknow-error.com")!
    }
    
    var parameters: [String : Any] {
        switch self {
        case .OSSToken:
            return [:]
        case .OBSToken:
            return [:]
        }
    }
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .OSSToken:
            return "/oss/get-token"
        case .OBSToken:
            return "/oss/get-huaweiyun-token"
        }
    }
}
