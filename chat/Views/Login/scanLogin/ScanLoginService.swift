//
//  ScanLoginService.swift
//  chat
//
//  扫码登录（PC 网页版）数据门面：
//  - 私钥只在本机完成 AES-GCM 加密，出网的永远只有密文（文档 §1 / §9）
//  - 回调都在主线程（Provider 的 callbackQueue 为 main）
//  - 错误统一归一成 ScanLoginFailure，方便界面决定「提示后关闭」还是「留在页面重试」
//

import Foundation
import Moya
import SwiftyJSON

final class ScanLoginService {

    static let shared = ScanLoginService()

    private init() {}

    // MARK: - 确认登录

    /// 确认登录：读本地私钥 → AES-GCM 加密 → 生成签名 → POST /app/qr-login/confirm
    @discardableResult
    func confirm(_ payload: ScanLoginQRPayload,
                 completion: @escaping (Result<Void, ScanLoginFailure>) -> Void) -> Cancellable? {

        // 未登录不发请求，避免服务端按无效签名返回 401 造成误判
        let user = LoginUser.shared()
        guard user.isLogin, !user.address.isEmpty else {
            completion(.failure(.notLogin))
            return nil
        }

        let privateKey = user.privateKey.finalKey
        let publicKey = user.publicKey.finalKey
        guard !privateKey.isEmpty, !publicKey.isEmpty else {
            FZMLog("扫码登录：本地私钥 / 公钥为空，终止提交")
            completion(.failure(.privateKeyUnavailable))
            return nil
        }

        guard let signature = ScanLoginCrypto.signatureToken(privateKey: privateKey, publicKey: publicKey) else {
            completion(.failure(.server(L("登录校验失败，请检查手机系统时间后重试"))))
            return nil
        }

        // 私钥读取 / 加密失败时本地报错，不发起请求（文档 §6）
        // v2：与二维码里的 PC 临时公钥做 ECDH，本地生成 iv
        guard let result = ScanLoginCrypto.encryptPrivateKeyV2(privateKey,
                                                               pcPublicKeyHex: payload.pcPublicKeyHex) else {
            completion(.failure(.privateKeyUnavailable))
            return nil
        }
        let encryptedPrivateKey = result.encryptedPrivateKey
        let phonePubKey = result.phonePubKey

        FZMLog("扫码登录：提交确认 session=\(payload.sessionId) version=v2(ECDH) address=\(user.address.shortAddress) 密文长度=\(encryptedPrivateKey.count)")

        let api = ScanLoginAPI.confirm(sessionId: payload.sessionId,
                                       address: user.address,
                                       encryptedPrivateKey: encryptedPrivateKey,
                                       phonePubKey: phonePubKey,
                                       signature: signature)

        return Provider.request(api, successBlock: { json in
            let code = json["result"].int ?? -1
            guard code == 0 else {
                FZMLog("扫码登录：确认失败 result=\(code) message=\(json["message"].string ?? "")")
                completion(.failure(ScanLoginFailure(envelope: json.dictionaryObject ?? [:])))
                return
            }
            FZMLog("扫码登录：确认成功 session=\(payload.sessionId)")
            completion(.success(()))
        }, failureBlock: { error in
            FZMLog("扫码登录：确认请求失败 \(error.localizedDescription)")
            completion(.failure(ScanLoginFailure(error: error)))
        })
    }

    // MARK: - 取消登录

    /// 取消登录（文档 §3.2，可选调用）：失败也不打扰用户，PC 端会等待会话过期
    @discardableResult
    func cancel(_ payload: ScanLoginQRPayload, completion: ((Bool) -> Void)? = nil) -> Cancellable? {
        let user = LoginUser.shared()
        guard user.isLogin, !user.privateKey.isEmpty, !user.publicKey.isEmpty else {
            completion?(false)
            return nil
        }
        guard let signature = ScanLoginCrypto.signatureToken(privateKey: user.privateKey.finalKey,
                                                            publicKey: user.publicKey.finalKey) else {
            completion?(false)
            return nil
        }

        let api = ScanLoginAPI.cancel(sessionId: payload.sessionId, signature: signature)
        return Provider.request(api, successBlock: { json in
            let ok = (json["result"].int ?? -1) == 0
            FZMLog("扫码登录：取消登录\(ok ? "成功" : "失败（会话已确认或已过期）")")
            completion?(ok)
        }, failureBlock: { error in
            FZMLog("扫码登录：取消登录请求失败 \(error.localizedDescription)")
            completion?(false)
        })
    }
}
