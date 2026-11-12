//
//  ScanLoginCrypto.swift
//  chat
//
//  扫码登录（PC 网页版）—— 私钥加密 + 请求签名
//  对接文档：app-qr-login-integration.md §5 关键算法（务必逐字节对齐）
//

import Foundation
import CryptoKit
import Web3Core
import secp256k1

enum ScanLoginCrypto {

    // MARK: - v2：ECDH 派生密钥 + AES-256-GCM 加密（扫码登录 ECDH 方案 §2.2）

    /// v2 加密：用 ECDH 与二维码里的 PC 临时公钥协商出 AES 密钥，再加密私钥
    ///
    /// 步骤（与协议文档 §2.2 逐字节对齐）：
    /// 1. 本地生成临时密钥对 `b` / `B`（secp256k1，`B` 输出 33 字节压缩 hex）
    /// 2. `shared` = ECDH(b, A) 的 **x 坐标**（32 字节大端，不足 32 字节左补零）
    /// 3. `aesKey` = SHA256(shared)
    /// 4. `iv` = 随机 12 字节；`cipher` = AES-256-GCM(privateKeyHex 的 UTF-8 字节)
    /// 5. 输出 `hex(iv(12) || ciphertext || authTag(16))`，同时返回 `phonePubKey`（`B` 的 hex）
    ///
    /// **iv 由 APP 生成并前缀在密文里**（`iv(12) || ciphertext || authTag`）。
    /// ⚠️ 不能直接用 libsecp256k1 的 `secp256k1_ecdh`：当前依赖版本里它返回的是
    ///    `SHA256(0x02/0x03 || x)`（压缩点哈希），不是文档要求的 x 坐标。
    ///    这里用 `ec_pubkey_tweak_mul` 求 `b·A`，再序列化压缩公钥取后 32 字节即 x 坐标。
    static func encryptPrivateKeyV2(_ privateKeyHex: String,
                                    pcPublicKeyHex: String) -> (encryptedPrivateKey: String, phonePubKey: String)? {
        let normalizedPublicKey = ScanLoginQRPayload.strippingHexPrefix(pcPublicKeyHex)
        guard let pcPublicKey = hexData(normalizedPublicKey),
              pcPublicKey.count == 33 || pcPublicKey.count == 65,
              let plaintext = privateKeyHex.data(using: .utf8) else {
            FZMLog("扫码登录：v2 加密参数非法")
            return nil
        }

        guard let phonePrivateKey = randomPrivateKey(),
              let phonePublicKey = SECP256K1.privateToPublic(privateKey: phonePrivateKey, compressed: true),
              let shared = ecdhXCoordinate(privateKey: phonePrivateKey, publicKey: pcPublicKey) else {
            FZMLog("扫码登录：v2 ECDH 密钥协商失败")
            return nil
        }

        // aesKey = SHA256(shared)，32 字节
        let aesKey = SymmetricKey(data: Data(SHA256.hash(data: shared)))
        let ivData = randomBytes(12)

        do {
            let sealed = try AES.GCM.seal(plaintext,
                                          using: aesKey,
                                          nonce: AES.GCM.Nonce(data: ivData))
            // 输出顺序：iv || ciphertext || authTag（文档 §2.2 第 5 步）
            let encrypted = (ivData + sealed.ciphertext + sealed.tag).toHexString()
            return (encrypted, phonePublicKey.toHexString())
        } catch {
            FZMLog("扫码登录：v2 私钥加密失败 \(error)")
            return nil
        }
    }

    // MARK: - ECDH

    /// secp256k1 上下文（仅用于 v2 的 ECDH 运算，进程内复用）
    private static let ecdhContext: OpaquePointer? = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))

    /// 计算 ECDH 共享点 `b·A` 的 x 坐标
    ///
    /// 压缩公钥固定为 `1 字节前缀 + 32 字节 x`，所以取后 32 字节即完整的 x 坐标，
    /// 天然满足「不足 32 字节需左补零」（库不会去掉前导零）。
    private static func ecdhXCoordinate(privateKey: Data, publicKey: Data) -> Data? {
        guard let ctx = ecdhContext,
              privateKey.count == 32,
              publicKey.count == 33 || publicKey.count == 65 else { return nil }

        var pubkey = secp256k1_pubkey()
        let parsed = publicKey.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> Int32 in
            guard let rawPointer = rawBufferPointer.baseAddress, rawBufferPointer.count > 0 else { return 0 }
            let pointer = rawPointer.assumingMemoryBound(to: UInt8.self)
            return withUnsafeMutablePointer(to: &pubkey) { pubkeyPtr -> Int32 in
                secp256k1_ec_pubkey_parse(ctx, pubkeyPtr, pointer, publicKey.count)
            }
        }
        guard parsed == 1 else { return nil }

        let multiplied = privateKey.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> Int32 in
            guard let rawPointer = rawBufferPointer.baseAddress, rawBufferPointer.count > 0 else { return 0 }
            let pointer = rawPointer.assumingMemoryBound(to: UInt8.self)
            return withUnsafeMutablePointer(to: &pubkey) { pubkeyPtr -> Int32 in
                secp256k1_ec_pubkey_tweak_mul(ctx, pubkeyPtr, pointer)
            }
        }
        guard multiplied == 1 else { return nil }

        var serialized = [UInt8](repeating: 0, count: 33)
        var keyLength = 33
        let serializedOK = serialized.withUnsafeMutableBufferPointer { (buffer: inout UnsafeMutableBufferPointer<UInt8>) -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return withUnsafeMutablePointer(to: &keyLength) { keyPtr -> Int32 in
                withUnsafeMutablePointer(to: &pubkey) { pubkeyPtr -> Int32 in
                    secp256k1_ec_pubkey_serialize(ctx, base, keyPtr, pubkeyPtr, UInt32(SECP256K1_EC_COMPRESSED))
                }
            }
        }
        guard serializedOK == 1, keyLength == 33 else { return nil }

        // 压缩公钥 = 0x02/0x03 || x(32)
        return Data(serialized[1..<33])
    }

    /// 生成合法的 secp256k1 临时私钥（32 字节）
    private static func randomPrivateKey() -> Data? {
        guard let ctx = ecdhContext else { return nil }
        for _ in 0..<16 {
            let candidate = randomBytes(32)
            let valid = candidate.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> Bool in
                guard let rawPointer = rawBufferPointer.baseAddress else { return false }
                return secp256k1_ec_seckey_verify(ctx, rawPointer.assumingMemoryBound(to: UInt8.self)) == 1
            }
            if valid { return candidate }
        }
        return nil
    }

    /// 密码学安全随机字节（CryptoKit 的 SymmetricKey 底层走系统 CSPRNG）
    private static func randomBytes(_ count: Int) -> Data {
        var data = Data()
        while data.count < count {
            let chunk = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            data.append(chunk)
        }
        return Data(data.prefix(count))
    }

    // MARK: - FZM-SIGNATURE（文档 §5.1）

    /// 生成请求头 `FZM-SIGNATURE`
    ///
    /// 服务端（scan-node）实测要求 —— 逐条都已验证过，任一条不满足都会被 401 挡下：
    /// - `message = String(Date.now()) + "*"`（**毫秒**时间戳，不带 appId、不带随机串）
    /// - 对 message **只做一次 SHA256**，底层直接对该 digest 签名（多哈希一次会「签名与公钥不匹配」）
    /// - ECDSA 必须是**低 s 规范**（高 s 同样被判「签名与公钥不匹配」）
    /// - **recid 必须与签名匹配**（给错 recid 会报「恢复标识非法」或验签失败）
    /// - `signature = r(32) || s(32) || recid(1)`，共 65 字节 → Base64
    /// - 公钥必须是 **33 字节压缩公钥 hex**
    ///
    /// ⚠️ 这里**没有**复用 `EncryptManager.signBase64`（聊天签名）：它的字节布局/规范化规则由
    /// Walletapi 的 Go 实现决定，实测与 scan-node 要求的 `r‖s‖recid` 不一致（会 401）。
    /// 改用工程内已在用的 `SECP256K1.signForRecovery`：libsecp256k1 天然输出低 s，
    /// 且其内部会自行 ecrecover 校验 recid 正确性 —— 正好满足上面全部条件。
    static func signatureToken(privateKey: String, publicKey: String) -> String? {
        let privateKeyHex = privateKey.finalKey
        guard privateKeyHex.count == 64,
              let privateData = hexData(privateKeyHex), privateData.count == 32 else {
            FZMLog("扫码登录：私钥格式非法，无法签名（长度 \(privateKeyHex.count)）")
            return nil
        }

        let message = "\(Date.timestamp)" + "*"
        guard let msgHash = message.data(using: .utf8)?.sha256() else {
            FZMLog("扫码登录：签名原文编码失败")
            return nil
        }

        // serializedSignature = r(32) || s(32) || v(1)，其中 v = 27 + recid
        guard let serialized = SECP256K1.signForRecovery(hash: msgHash, privateKey: privateData).serializedSignature,
              serialized.count == 65 else {
            FZMLog("扫码登录：secp256k1 签名失败")
            return nil
        }

        var signatureBytes = [UInt8](serialized)
        let v = signatureBytes[64]
        guard v == 0x1b || v == 0x1c else {
            FZMLog("扫码登录：签名恢复标识异常 \(v)")
            return nil
        }
        signatureBytes[64] = v - 0x1b          // 27/28 → recid 0/1（文档要求裸 recid）

        // 公钥现场由私钥推导，保证「签名 ↔ 公钥」一定匹配；本地公钥仅作一致性告警
        var publicKeyHex = publicKey.finalKey
        if let compressed = SECP256K1.privateToPublic(privateKey: privateData, compressed: true)?.toHexString() {
            if !publicKeyHex.isEmpty, publicKeyHex.lowercased() != compressed.lowercased() {
                FZMLog("扫码登录：本机公钥与私钥推导不一致（本地 \(publicKeyHex.count) 位，改用推导值）")
            }
            publicKeyHex = compressed
        }
        guard !publicKeyHex.isEmpty else {
            FZMLog("扫码登录：公钥为空，无法签名")
            return nil
        }

        #if DEBUG
        // 诊断：对比聊天签名（Walletapi）的字节布局，用于确认接入期 401 的根因，确认后可删
        if let legacy = EncryptManager.signBase64(data: msgHash, privateKey: privateKeyHex),
           let legacyData = Data(base64Encoded: legacy.finalKey.replacingOccurrences(of: " ", with: "")),
           legacyData.count == 65 {
            let legacyBytes = [UInt8](legacyData)
            FZMLog("扫码登录签名对比：本实现 r‖s‖recid 末字节=\(signatureBytes[64])；Walletapi 首字节=\(legacyBytes[0]) 末字节=\(legacyBytes[64])")
        }
        #endif

        return Data(signatureBytes).base64EncodedString() + "#" + message + "#" + publicKeyHex
    }

    // MARK: - 工具

    /// 严格 hex → Data（长度非法 / 含非法字符返回 nil）
    static func hexData(_ hex: String) -> Data? {
        let text = hex.hasPrefix("0x") || hex.hasPrefix("0X") ? String(hex.dropFirst(2)) : hex
        guard !text.isEmpty, text.count % 2 == 0 else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard text.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return Data(hex: text)
    }
}
