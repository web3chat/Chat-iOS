//
//  CodeAPI.swift
//  chat
//
//  Created by fzm on 2021/1/29.
//

import Foundation
import Moya

enum CodeAPI {
    case phoneSend(area: String, phone: String)
    case emailSend(email: String)
    
}

extension CodeAPI: XLSTargetType {
    
    var baseURL: URL {
        return URL.init(string: BackupURL) ?? UNCONFIGURED_SERVER_URL
    }
    
    var parameters: [String : Any] {
        switch self {
        case .phoneSend(let area, let phone):
            return ["area": area, "phone": phone]
        case .emailSend(let email):
            return ["email": email]
       
        }
    }
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .phoneSend:
            return "/backup/phone-send"
        case .emailSend:
            return "/backup/email-send"
       
        }
    }
}
