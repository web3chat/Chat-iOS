//
//  ScanLoginAPI.swift
//  chat
//
//  扫码登录（PC 网页版）接口定义
//  对接文档：app-qr-login-integration.md §3 接口协议
//  注意：这里覆盖 validation，把「整个响应信封」交给 ScanLoginService 判定，
//       因为需要区分 HTTP 401（鉴权失败）与 result = -1（会话失效）两种提示。
//

import Foundation
import Moya
import Alamofire
import SwiftyJSON

enum ScanLoginAPI {
    /// 确认登录 POST /app/qr-login/confirm
    /// - `encryptedPrivateKey` = AES-GCM 密文 hex（v2: iv || 密文 || authTag）
    /// - `phonePubKey` = APP 临时公钥 hex（33 字节压缩）
    /// - `signature` = 请求头 FZM-SIGNATURE（由 ScanLoginCrypto 生成，只算一次，避免重复做 secp256k1 运算）
    case confirm(sessionId: String, address: String, encryptedPrivateKey: String, phonePubKey: String, signature: String)
    /// 取消登录 POST /app/qr-login/cancel
    case cancel(sessionId: String, signature: String)
}

extension ScanLoginAPI: XLSTargetType {

    var baseURL: URL {
        return URL.init(string: ScanLoginBaseURL) ?? UNCONFIGURED_SERVER_URL
    }

    var path: String {
        switch self {
        case .confirm:
            return "/app/qr-login/confirm"
        case .cancel:
            return "/app/qr-login/cancel"
        }
    }

    var method: Moya.Method {
        return .post
    }

    /// 全部走 JSON body（文档 §3.1）
    var parameters: [String: Any] {
        switch self {
        case .confirm(let sessionId, let address, let encryptedPrivateKey, let phonePubKey, _):
            return ["sessionId": sessionId,
                    "address": address,
                    "encryptedPrivateKey": encryptedPrivateKey,
                    "phonePubKey": phonePubKey]
        case .cancel(let sessionId, _):
            return ["sessionId": sessionId]
        }
    }

    var task: Task {
        return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
    }

    var headers: [String: String]? {
        let signature: String
        switch self {
        case .confirm(_, _, _, _, let value):
            signature = value
        case .cancel(_, let value):
            signature = value
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        var result: [String: String] = [
            "Content-Type": "application/json",
            "FZM-VERSION": version,
            "FZM-UUID": String.uuid(),
            "FZM-DEVICE": "iOS",
            "FZM-DEVICE-NAME": k_DeviceName
        ]
        if !signature.isEmpty {
            result["FZM-SIGNATURE"] = signature
        }
        return result
    }

    /// 覆盖基类实现：返回完整响应信封（result / message / data），业务码判定交给 ScanLoginService。
    /// ⚠️ 日志只打 path 与 result / message，**绝不打印参数**（里面有 encryptedPrivateKey）。
    func validation(_ result: Result<Moya.Response, MoyaError>) -> Result<JSON, Error> {
        switch result {
        case .success(let response):
            // 401 = 鉴权失败：签名不合法 / 重数不对 / 设备时间不同步（文档 §3.1 / §8）
            guard response.statusCode != 401 else {
                let serverMessage = (try? JSON.init(data: response.data))?["message"].string ?? ""
                FZMLog("扫码登录响应 \(path) HTTP 401 \(serverMessage)")
                let friendly = L("登录校验失败，请检查手机系统时间后重试")
                #if DEBUG
                // Debug 下把服务端原因（如「签名与公钥不匹配」/「恢复标识非法」/「签名已过期」）带出来，方便联调
                let message = serverMessage.isEmpty ? friendly : friendly + "（\(serverMessage)）"
                #else
                let message = friendly
                #endif
                let error = NSError.init(domain: "scanLogin", code: 401,
                                         userInfo: [NSLocalizedDescriptionKey: message])
                return Result<JSON, Error>.failure(error)
            }

            guard response.statusCode == 200 else {
                let body = String.init(data: response.data.prefix(200), encoding: .utf8) ?? ""
                FZMLog("扫码登录响应 \(path) HTTP \(response.statusCode) \(body)")
                let error = NSError.init(domain: "scanLogin", code: response.statusCode,
                                         userInfo: [NSLocalizedDescriptionKey: L("网络连接错误，请稍后再试")])
                return Result<JSON, Error>.failure(error)
            }

            guard let json = try? JSON.init(data: response.data) else {
                let error = NSError.init(domain: "scanLogin", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: L("数据解析失败，请稍后再试")])
                return Result<JSON, Error>.failure(error)
            }

            FZMLog("扫码登录响应 \(path) result=\(json["result"].int ?? -999) message=\(json["message"].string ?? "")")
            return Result<JSON, Error>.success(json)

        case .failure(let error):
            var errorInfo = ""
            switch error.errorCode {
            case NSURLErrorNotConnectedToInternet:
                errorInfo = L("无网络，请检查网络连接")
            case NSURLErrorTimedOut:
                errorInfo = L("请求超时，请检查网络连接")
            default:
                errorInfo = L("网络连接错误，请稍后再试")
            }
            FZMLog("扫码登录网络错误 \(path) code=\(error.errorCode)")
            let err = NSError.init(domain: "scanLogin", code: error.errorCode,
                                   userInfo: [NSLocalizedDescriptionKey: errorInfo])
            return Result<JSON, Error>.failure(err)
        }
    }
}
