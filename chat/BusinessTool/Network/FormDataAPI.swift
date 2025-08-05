//
//  FormDataAPI.swift
//  chat
//
//  Created by 王俊豪 on 2022/3/2.
//

import Foundation
import Moya

enum FormDataAPI {
    case sendMsg(data: Data)
}

extension FormDataAPI: XLSTargetType {
    var parameters: [String : Any] {
        return [:]
    }
    
    var baseURL: URL {
        return URL(string: "")!
    }
    
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        return ""
    }
}
