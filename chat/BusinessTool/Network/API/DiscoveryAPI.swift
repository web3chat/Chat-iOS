//
//  DiscoveryAPI.swift
//  chat
//
//  Created by fzm on 2021/1/27.
//

import Foundation
import Moya

enum DiscoveryAPI {
    case disc
}

extension DiscoveryAPI: XLSTargetType {
    
    var baseURL: URL {
        return URL.init(string: BackupURL) ?? UNCONFIGURED_SERVER_URL
    }
    
    var parameters: [String : Any] {
        switch self {
        case .disc:
            return [:]
        }
    }
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .disc:
            return "/disc/nodes"
        }
    }
}
