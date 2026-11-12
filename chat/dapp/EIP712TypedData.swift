//
//  EIP712TypedData.swift
//  chat
//
//  EIP-712 结构化数据（`eth_signTypedData` / `eth_signTypedData_v3` / `eth_signTypedData_v4`）
//  的解析、摘要计算与签名。
//
//  实现严格按 EIP-712 规范：
//    hashStruct(s)      = keccak256(typeHash ‖ encodeData(s))
//    typeHash           = keccak256(encodeType(typeName))
//    encodeType(t)      = "T(type1 name1,type2 name2,...)" + 依赖类型（按名字字典序）
//    digest             = keccak256(0x19 ‖ 0x01 ‖ domainSeparator ‖ hashStruct(primaryType, message))
//
//  ⚠️ 不支持的输入一律**抛错**，绝不返回"看起来像签名"的假数据
//     （旧 `WebViewMetaMaskCoordinator` 里返回空串的占位实现会让 dApp 拿到无效签名且无从排查）。
//

import Foundation
import BigInt
import CryptoSwift
import Web3Core

// MARK: - 错误

enum EIP712Error: LocalizedError {
    case invalidJSON
    case missingPrimaryType
    case unknownType(String)
    case missingField(String)
    case invalidValue(String)
    case unsupportedType(String)
    case signFailed

    var errorDescription: String? {
        switch self {
        case .signFailed:
            return L("签名失败")
        default:
            return L("结构化签名参数无效")
        }
    }

    /// 给日志用的具体原因（不展示给 dApp 用户，便于排查是哪一步失败）。
    var debugReason: String {
        switch self {
        case .invalidJSON: return "invalidJSON"
        case .missingPrimaryType: return "missingPrimaryType"
        case .unknownType(let t): return "unknownType(\(t))"
        case .missingField(let f): return "missingField(\(f))"
        case .invalidValue(let f): return "invalidValue(\(f))"
        case .unsupportedType(let t): return "unsupportedType(\(t))"
        case .signFailed: return "signFailed"
        }
    }
}

// MARK: - 模型

struct EIP712Field {
    let name: String
    let type: String
}

struct EIP712TypedData {

    let types: [String: [EIP712Field]]
    let primaryType: String
    let domain: [String: Any]
    let message: [String: Any]
    /// 参数里携带的签名地址（部分 dApp 会传，用于校验是否与当前钱包一致）
    let declaredAddress: String?

    // MARK: 解析

    /// 兼容 dApp 的几种常见传参：
    ///  1. `[address, jsonString]`（最常见）
    ///  2. `[address, jsonObject]`（少数库直接传对象）
    ///  3. `[jsonString]` / `[jsonObject]`（不带地址）
    /// v1 的 `[[{type,name,value}]]` 结构**不支持**，会返回 nil。
    static func parse(params: [Any]?) -> EIP712TypedData? {
        guard let params, !params.isEmpty else { return nil }

        var declaredAddress: String?
        var jsonObject: [String: Any]?

        for item in params {
            if let dict = item as? [String: Any] {
                if jsonObject == nil { jsonObject = dict }
                continue
            }
            guard let raw = item as? String else { continue }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("{") {
                if jsonObject == nil,
                   let data = text.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    jsonObject = obj
                }
            } else if text.hasPrefix("0x") || text.hasPrefix("0X") {
                // 0x + 40 位 hex 才是地址；其余按非法处理
                if text.count == 42, declaredAddress == nil {
                    declaredAddress = text
                }
            }
        }

        guard let obj = jsonObject,
              let primaryType = obj["primaryType"] as? String,
              let rawTypes = obj["types"] as? [String: Any] else { return nil }

        var types: [String: [EIP712Field]] = [:]
        for (name, value) in rawTypes {
            guard let list = value as? [[String: Any]] else { continue }
            types[name] = list.compactMap { entry in
                guard let fieldName = entry["name"] as? String,
                      let fieldType = entry["type"] as? String else { return nil }
                return EIP712Field(name: fieldName, type: fieldType)
            }
        }
        guard !primaryType.isEmpty else { return nil }

        return EIP712TypedData(
            types: types,
            primaryType: primaryType,
            domain: obj["domain"] as? [String: Any] ?? [:],
            message: obj["message"] as? [String: Any] ?? [:],
            declaredAddress: declaredAddress
        )
    }

    // MARK: 摘要与签名

    /// EIP-712 最终摘要（32 字节）。
    func digest() throws -> Data {
        let domainFields = types["EIP712Domain"] ?? Self.canonicalDomainFields(domain)
        let domainSeparator = try hashStruct(typeName: "EIP712Domain", fields: domainFields, value: domain)

        guard let messageFields = types[primaryType] else { throw EIP712Error.unknownType(primaryType) }
        let messageHash = try hashStruct(typeName: primaryType, fields: messageFields, value: message)

        var data = Data([0x19, 0x01])
        data.append(domainSeparator)
        data.append(messageHash)
        return data.sha3(.keccak256)
    }

    /// 直接返回 `0x` 开头的 65 字节签名（r ‖ s ‖ v，v = 27/28）。
    func sign(privateKey: Data) throws -> String {
        let hash = try digest()
        guard let signature = SECP256K1.signForRecovery(hash: hash, privateKey: privateKey, useExtraEntropy: false).serializedSignature else {
            throw EIP712Error.signFailed
        }
        return "0x" + signature.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: 展示信息（授权弹窗用）

    var domainName: String? {
        Self.stringValue(domain["name"])
    }

    var verifyingContract: String? {
        Self.stringValue(domain["verifyingContract"])
    }

    /// 是否是「授权动用资产」类签名（Permit / Permit2 等）——用于弹窗高危提示。
    var isAssetAuthorization: Bool {
        let lowered = primaryType.lowercased()
        if lowered.contains("permit") { return true }
        // Permit2 的 spender/amount 在嵌套的 `details` 里，必须递归找。
        return Self.containsSensitiveKey(message)
    }

    private static func containsSensitiveKey(_ value: Any?) -> Bool {
        if let dict = value as? [String: Any] {
            for (key, child) in dict {
                let lowered = key.lowercased()
                if lowered == "spender" || lowered == "operator" || lowered == "approved" {
                    return true
                }
                if containsSensitiveKey(child) { return true }
            }
        } else if let array = value as? [Any] {
            return array.contains { containsSensitiveKey($0) }
        }
        return false
    }

    /// 按 `primaryType` 的字段顺序展开 message，供弹窗逐行展示。
    func displayRows(limit: Int = 24, valueLimit: Int = 512) -> [(label: String, value: String)] {
        var rows: [(String, String)] = []
        let fields = types[primaryType] ?? []
        for field in fields.prefix(limit) {
            rows.append((field.name, Self.describe(message[field.name], limit: valueLimit)))
        }
        // 兜底：types 里没有 primaryType（极端情况）时仍把 message 展示出来
        if rows.isEmpty {
            for (key, value) in message.sorted(by: { $0.key < $1.key }).prefix(limit) {
                rows.append((key, Self.describe(value, limit: valueLimit)))
            }
        }
        return rows
    }

    // MARK: - 编码

    private func hashStruct(typeName: String, fields: [EIP712Field], value: [String: Any]) throws -> Data {
        let typeHash = encodeType(typeName).data(using: .utf8)!.sha3(.keccak256)
        var encoded = Data()
        for field in fields {
            guard let raw = value[field.name], !(raw is NSNull) else {
                throw EIP712Error.missingField(field.name)
            }
            encoded.append(try encodeValue(type: field.type, value: raw))
        }
        var out = typeHash
        out.append(encoded)
        return out.sha3(.keccak256)
    }

    /// `T(type1 name1,type2 name2,...)` + 所有被引用的结构体类型（按名字字典序）
    private func encodeType(_ primary: String) -> String {
        var dependencies = Set<String>()
        collectDependencies(primary, into: &dependencies)
        dependencies.remove(primary)

        var result = "\(primary)(\(fieldsDescription(primary)))"
        for name in dependencies.sorted() {
            result += "\(name)(\(fieldsDescription(name)))"
        }
        return result
    }

    private func fieldsDescription(_ typeName: String) -> String {
        (types[typeName] ?? [])
            .map { "\($0.type) \($0.name)" }
            .joined(separator: ",")
    }

    private func collectDependencies(_ typeName: String, into set: inout Set<String>) {
        guard let fields = types[typeName] else { return }
        for field in fields {
            let base = Self.baseType(field.type)
            guard types[base] != nil, !set.contains(base), base != typeName else { continue }
            set.insert(base)
            collectDependencies(base, into: &set)
        }
    }

    private func encodeValue(type: String, value: Any) throws -> Data {
        // 数组：**定长与动态都是 keccak256(concat(...))**。
        // EIP-712 原文：「数组值编码为其元素 encodeData 拼接的 keccak256 哈希
        // （即 SomeType[5] 的编码与「含 5 个 SomeType 成员的结构体」相同）」
        // ⇒ 定长数组同样要再哈希一次，**不能**直接返回拼接结果。
        if type.hasSuffix("]"), let bracket = type.lastIndex(of: "[") {
            let elementType = String(type[type.startIndex..<bracket])
            let suffix = String(type[bracket...])   // "[]" 或 "[N]"
            guard let elements = Self.arrayValue(value) else {
                throw EIP712Error.invalidValue(type)
            }
            var concat = Data()
            for element in elements {
                concat.append(try encodeValue(type: elementType, value: element))
            }
            if suffix != "[]" {
                let lengthText = suffix.dropFirst().dropLast()
                guard let expected = Int(lengthText), expected == elements.count else {
                    throw EIP712Error.invalidValue(type)
                }
            }
            return concat.sha3(.keccak256)
        }

        // 结构体：递归求 hashStruct
        if let nestedFields = types[type] {
            guard let dict = value as? [String: Any] else {
                throw EIP712Error.invalidValue(type)
            }
            return try hashStruct(typeName: type, fields: nestedFields, value: dict)
        }

        return try encodeAtomic(type: type, value: value)
    }

    private func encodeAtomic(type: String, value: Any) throws -> Data {
        switch type {
        case "string":
            guard let text = Self.stringValue(value) else { throw EIP712Error.invalidValue(type) }
            return Data(text.utf8).sha3(.keccak256)

        case "bytes":
            return try Self.bytesValue(value).sha3(.keccak256)

        case "address":
            guard let text = Self.stringValue(value),
                  let data = Self.hexData(text), data.count == 20 else {
                throw EIP712Error.invalidValue(type)
            }
            var word = Data(repeating: 0, count: 12)
            word.append(data)
            return word

        case "bool":
            return Self.word(Self.boolValue(value) ? 1 : 0)

        default:
            break
        }

        if type.hasPrefix("bytes"), let size = Int(type.dropFirst("bytes".count)) {
            var data = try Self.bytesValue(value)
            if data.isEmpty {
                data = Data(repeating: 0, count: size)
            }
            guard data.count <= size else { throw EIP712Error.invalidValue(type) }
            var word = data
            word.append(Data(repeating: 0, count: 32 - data.count))
            return word
        }

        if type.hasPrefix("uint") || type.hasPrefix("int") {
            guard let text = Self.stringValue(value), !text.isEmpty else {
                throw EIP712Error.invalidValue(type)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("-") {
                guard type.hasPrefix("int"),
                      let signed = BigInt(trimmed, radix: 10), signed < 0 else {
                    throw EIP712Error.invalidValue(type)
                }
                let modulus = BigUInt(1) << 256
                return Self.word(modulus - signed.magnitude)
            }
            if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
                guard let value = BigUInt(String(trimmed.dropFirst(2)), radix: 16) else {
                    throw EIP712Error.invalidValue(type)
                }
                return Self.word(value)
            }
            guard let magnitude = BigUInt(trimmed, radix: 10) else {
                throw EIP712Error.invalidValue(type)
            }
            return Self.word(magnitude)
        }

        throw EIP712Error.unsupportedType(type)
    }

    // MARK: - 取值工具

    /// 没有 `types.EIP712Domain` 时，按规范规定的固定顺序回推字段。
    private static func canonicalDomainFields(_ domain: [String: Any]) -> [EIP712Field] {
        let order: [(String, String)] = [
            ("name", "string"),
            ("version", "string"),
            ("chainId", "uint256"),
            ("verifyingContract", "address"),
            ("salt", "bytes32"),
        ]
        return order
            .filter { domain[$0.0] != nil }
            .map { EIP712Field(name: $0.0, type: $0.1) }
    }

    private static func baseType(_ type: String) -> String {
        var result = type
        while result.hasSuffix("]"), let index = result.lastIndex(of: "[") {
            result = String(result[result.startIndex..<index])
        }
        return result
    }

    private static func arrayValue(_ value: Any) -> [Any]? {
        if let array = value as? [Any] { return array }
        if let array = value as? NSArray { return array.map { $0 } }
        return nil
    }

    /// ⚠️ `JSONSerialization` 会把数字解成 `NSNumber`；直接 `String(describing:)` 会得到 `1e+18`
    /// 这种科学计数法并丢精度，所以统一走 `NSDecimalNumber`。
    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let text as String:
            return text
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "1" : "0"
            }
            return NSDecimalNumber(decimal: number.decimalValue).stringValue
        case let data as Data:
            return data.map { String(format: "%02x", $0) }.joined()
        default:
            return nil
        }
    }

    static func boolValue(_ value: Any) -> Bool {
        if let text = value as? String {
            let lowered = text.lowercased()
            return lowered == "true" || lowered == "1"
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return false
    }

    static func bytesValue(_ value: Any) throws -> Data {
        if let data = value as? Data { return data }
        guard let text = value as? String else { throw EIP712Error.invalidValue("bytes") }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            guard let data = hexData(trimmed) else { throw EIP712Error.invalidValue("bytes") }
            return data
        }
        return Data(trimmed.utf8)
    }

    static func hexData(_ text: String) -> Data? {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("0x") || body.hasPrefix("0X") { body = String(body.dropFirst(2)) }
        if body.isEmpty { return Data() }
        guard body.count % 2 == 0 else { return nil }
        var output = Data(capacity: body.count / 2)
        var index = body.startIndex
        while index < body.endIndex {
            let next = body.index(index, offsetBy: 2)
            guard let byte = UInt8(body[index..<next], radix: 16) else { return nil }
            output.append(byte)
            index = next
        }
        return output
    }

    static func word(_ value: BigUInt) -> Data {
        var output = Data(repeating: 0, count: 32)
        var remaining = value
        var index = 31
        while remaining > 0 && index >= 0 {
            output[index] = UInt8(truncatingIfNeeded: remaining)
            remaining = remaining >> 8
            index -= 1
        }
        return output
    }

    private static func describe(_ value: Any?, limit: Int) -> String {
        switch value {
        case .none:
            return "—"
        case is NSNull:
            return "—"
        case let text as String:
            return truncate(text, limit: limit)
        case let number as NSNumber:
            return stringValue(number) ?? "—"
        case let dict as [String: Any]:
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                return truncate(text, limit: limit)
            }
            return "—"
        case let array as [Any]:
            if let data = try? JSONSerialization.data(withJSONObject: array, options: []),
               let text = String(data: data, encoding: .utf8) {
                return truncate(text, limit: limit)
            }
            return "—"
        default:
            return truncate(String(describing: value!), limit: limit)
        }
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<index]) + "…"
    }
}
