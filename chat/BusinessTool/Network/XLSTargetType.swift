//
//  TargetType+Base.swift
//  xls
//
//  Created by 陈健 on 2020/8/21.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import Moya
import SwiftyJSON


public protocol XLSTargetType: TargetType {
    var parameters: [String: Any] { get }
    func validation(_ result: Result<Moya.Response, MoyaError>) -> Result<JSON, Error>
}

extension XLSTargetType {
    /// The target's base `URL`.
    var baseURL: URL {
        return URL.init(string: IMChatServerInUse?.value) ?? URL.init(string: "https://api.unknow-error.com")!
    }

    /// The HTTP method used in the request.
    var method: Moya.Method {
        return .post
    }

    /// Provides stub data for use in testing.
    var sampleData: Data {
        return Data.init()
    }

    /// The type of HTTP task to be performed.
    var task: Task {
        return Task.requestParameters(parameters: parameters, encoding: JSONEncoding.default)
    }

    /// The headers to be used in the request.
    var headers: [String: String]? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let signature = LoginUser.shared().signature ?? ""
        return [
                "FZM-SIGNATURE": signature,
                "FZM-VERSION": version,
                "FZM-UUID": String.uuid(),
                "FZM-DEVICE": "iOS",
                "FZM-DEVICE-NAME": k_DeviceName
        ]
    }
    /// The type of validation to perform on the request. Default is `.none`.
    var validationType: ValidationType {
        return .none
    }
    
    func validation(_ result: Result<Moya.Response, MoyaError>) -> Result<JSON, Error> {
        switch result {
        case .success(let response):
            let json = JSON.init((try? response.mapJSON()) as Any)
            
            guard response.statusCode == 200 else {
                let error = NSError.init(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: response.description])
                return Result<JSON, Error>.failure(error)
            }
          
            // 查询是否绑定团队，未绑定错误代码13001
            guard let code = json["result"].int ?? json["code"].int, code != 13001 else {
                if let _ = json["result"].int {
                    return Result<JSON, Error>.success(json["result"])
                }
                return Result<JSON, Error>.success(json["code"])
            }
            guard let code = json["result"].int ?? json["code"].int, code == 0 else {
                var msg = json["message"].stringValue
                if msg.isEmpty {
                    msg = json["msg"].stringValue
                }
                var codeIntValue: Int = 0
                if let codeInt = json["result"].int ?? json["code"].int {
                    codeIntValue = codeInt
                }
                let error = NSError.init(domain: "", code: codeIntValue, userInfo: [NSLocalizedDescriptionKey: msg] )
                return Result<JSON, Error>.failure(error)
            }
            return Result<JSON, Error>.success(json["data"])
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
}
