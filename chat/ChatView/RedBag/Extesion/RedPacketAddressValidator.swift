//
//  RedPacketAddressValidator.swift
//  chat
//
//  红包相关：链上地址（0x + 40 位十六进制）基础校验
//  用于专属红包领取人地址校验，避免把昵称/空串当地址上链
//

import Foundation

extension String {
    /// 是否为合法 EVM 地址字符串（0x + 40 位十六进制）
    var isValidEthereumAddressString: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 42, trimmed.lowercased().hasPrefix("0x") else { return false }
        return trimmed.dropFirst(2).allSatisfy { $0.isHexDigit }
    }
}
