//
//  ETHInputParser.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2025/9/28.
//  Copyright © 2025 fzm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>
NS_ASSUME_NONNULL_BEGIN

@interface ETHInputParser : NSObject

/// 解析 input data。常见方法会附带语义字段（与 `parameters` 并行）：
/// - transfer: `recipient`, `amount`（`amount` 为十进制字符串，完整 uint256，非 NSNumber）
/// - approve: `spender`, `allowance`（`allowance` 同上）
/// - transferFrom: `from_address`, `to_address`, `amount`（`amount` 同上）
/// - swap: `swap_token_in`, `swap_token_out`, `amount`（selector 0xdf791e50 等；Router 类含 0xaf9b3109、0x38ed1739 等）
/// - withdraw: `amount`（`withdraw(uint256)`，selector 0x2e1a7d4d，完整 uint256 十进制）
/// 未在库中的选择器：`function_name` 为 `unknown(0x........)`。
/// 代币合约地址在交易的 `to`，不在 calldata；见 `note`。
+ (NSDictionary *)parseInputData:(NSString *)inputHex;

// 计算函数选择器（Keccak256哈希前4字节）
+ (NSString *)getFunctionSelector:(NSString *)functionSignature;

@end

NS_ASSUME_NONNULL_END
