//
//  DAppRPCSettings.swift
//  chat
//
//  DApp 浏览器的 RPC 节点配置。
//
//  · 默认值 = 代码里原有的三个地址（`AppExploreWebRPC`），**不要改这里**，
//    否则会把线上默认节点换掉；
//  · 用户可以在「选择网络」页 → 右上角「编辑」里按网络覆盖，覆盖值存 UserDefaults（纯本地）；
//  · 留空 = 恢复默认。
//

import Foundation

enum DAppRPCSettings {

    /// UserDefaults key 前缀。按网络的 `rawValue` 分开存，切网络互不影响。
    private static let keyPrefix = "DAppRPCURL."

    /// 全部支持的网络，顺序与「选择网络」页（`PWLanguageViewController` ChangeNet）一致。
    static let supportedNets: [NetType] = [0, 1, 2].compactMap { NetType(rawValue: $0) }

    // MARK: - 默认值（= 代码里原有的硬编码地址）

    /// 与 `WebViewController.m` 的 `BTYRPCUrl` / `ETHRPCUrl` / `BNBRPCUrl` 一一对应。
    static func defaultURL(for net: NetType) -> URL {
        switch net.rawValue {
        case 0:  return AppExploreWebRPC.bty
        case 1:  return AppExploreWebRPC.eth
        case 2:  return AppExploreWebRPC.bnb
        default: return AppExploreWebRPC.bnb
        }
    }

    /// 与「选择网络」页显示的网络名保持一致（那页是硬编码英文，这里沿用同一套文案）。
    static func displayName(for net: NetType) -> String {
        switch net.rawValue {
        case 0:  return "BitYuan Mainnet"
        case 1:  return "Ethereum Mainnet"
        case 2:  return "BNB Smart Chain"
        default: return "BNB Smart Chain"
        }
    }

    // MARK: - 自定义值

    /// 用户填的自定义地址；没填（或被清空）时为 nil。
    static func customURLString(for net: NetType) -> String? {
        let raw = UserDefaults.standard.string(forKey: keyPrefix + String(net.rawValue))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    /// **当前生效**的 RPC 地址 = 自定义（合法时） ?? 默认。
    /// DApp 浏览器、`BlockchainRPC` 都从这里取，不要另外写死地址。
    static func currentURL(for net: NetType) -> URL {
        if let custom = customURLString(for: net), let url = validated(custom) {
            return url
        }
        return defaultURL(for: net)
    }

    // MARK: - 写入 / 恢复默认

    /// 保存自定义地址；`nil` / 纯空白 = 恢复默认。
    /// - Returns: 地址非法时返回 `false`（不写入），调用方负责提示用户。
    @discardableResult
    static func setCustomURLString(_ value: String?, for net: NetType) -> Bool {
        let key = keyPrefix + String(net.rawValue)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return true
        }
        guard validated(trimmed) != nil else { return false }
        UserDefaults.standard.set(trimmed, forKey: key)
        return true
    }

    // MARK: - 校验

    /// 只接受「http / https + 有 host」的完整地址（空串、其它 scheme、裸域名都不接受）。
    static func validated(_ string: String) -> URL? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s.count <= 2048 else { return nil }
        guard let url = URL(string: s),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
