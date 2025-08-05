//
//  SystemAPI.swift
//  chat
//
//  Created by 王俊豪 on 2021/6/15.
//

import Foundation
import Moya

enum SystemAPI {
    case update(versionCode: Int)
    case getModules
}

extension SystemAPI: XLSTargetType {
    
    var baseURL: URL {
        return URL.init(string: BackupURL) ?? URL.init(string: "https://api.unknow-error.com")!
    }
    
    var parameters: [String : Any] {
        switch self {
        case .update(let versionCode):
            return ["versionCode":versionCode]
        case .getModules:
            return [:]
        }
    }
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .update:
            return "/app/version/check"
        case .getModules:
            return "/app/modules/all"
        }
    }
}
