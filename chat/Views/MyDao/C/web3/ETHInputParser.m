//
//  ETHInputParser.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2025/9/28.
//  Copyright © 2025 fzm. All rights reserved.
//

#import "ETHInputParser.h"

/// 将 64 位十六进制 ABI 字（小写、无 0x）转为十进制字符串，完整表示 uint256，避免 strtoull 截断。
static NSMutableString *ETHDecimalStringMultiplyUInt(NSString *decStr, unsigned mul) {
    NSMutableString *result = [NSMutableString string];
    unsigned carry = 0;
    for (NSInteger i = (NSInteger)decStr.length - 1; i >= 0; i--) {
        unsigned d = (unsigned)([decStr characterAtIndex:i] - '0') * mul + carry;
        carry = d / 10;
        [result insertString:[NSString stringWithFormat:@"%u", d % 10] atIndex:0];
    }
    while (carry > 0) {
        [result insertString:[NSString stringWithFormat:@"%u", carry % 10] atIndex:0];
        carry /= 10;
    }
    return result;
}

static void ETHAddSmallToDecimalString(NSMutableString *s, unsigned addend) {
    NSInteger carry = addend;
    for (NSInteger i = (NSInteger)s.length - 1; i >= 0; i--) {
        NSInteger d = ([s characterAtIndex:i] - '0') + carry;
        carry = d / 10;
        d = d % 10;
        [s replaceCharactersInRange:NSMakeRange((NSUInteger)i, 1) withString:[NSString stringWithFormat:@"%ld", (long)d]];
    }
    while (carry > 0) {
        [s insertString:[NSString stringWithFormat:@"%ld", (long)(carry % 10)] atIndex:0];
        carry /= 10;
    }
}

static NSString *ETHDecimalStringFromUInt256HexWord(NSString *word64Lower) {
    if (word64Lower.length != 64) {
        return @"0";
    }
    NSUInteger start = 0;
    while (start < word64Lower.length - 1 && [word64Lower characterAtIndex:start] == '0') {
        start++;
    }
    NSString *h = [word64Lower substringFromIndex:start];
    NSMutableString *dec = [NSMutableString stringWithString:@"0"];
    for (NSUInteger k = 0; k < h.length; k++) {
        unichar c = [h characterAtIndex:k];
        int v;
        if (c >= '0' && c <= '9') {
            v = (int)(c - '0');
        } else if (c >= 'a' && c <= 'f') {
            v = (int)(c - 'a' + 10);
        } else {
            return @"0";
        }
        NSMutableString *next = ETHDecimalStringMultiplyUInt(dec, 16);
        [dec setString:next];
        ETHAddSmallToDecimalString(dec, (unsigned)v);
    }
    return [dec copy];
}

@implementation ETHInputParser

+ (NSDictionary *)parseStaticABIWords:(NSString *)lower
                          selectorHex:(NSString *)selectorHex
                               result:(NSMutableDictionary *)result {
    NSMutableArray *params = [NSMutableArray array];
    NSUInteger dataLength = lower.length;

    if ([selectorHex isEqualToString:@"a9059cbb"] || [selectorHex isEqualToString:@"095ea7b3"]) {
        /// transfer(address,uint256) / approve(address,uint256)
        if (10 + 128 <= dataLength) {
            NSString *w0 = [lower substringWithRange:NSMakeRange(10, 64)];
            NSString *w1 = [lower substringWithRange:NSMakeRange(74, 64)];
            NSString *addr = [NSString stringWithFormat:@"0x%@", [w0 substringFromIndex:24]];
            NSString *amt = ETHDecimalStringFromUInt256HexWord(w1);
            [params addObject:@{@"type": @"address", @"value": addr, @"index": @0, @"is_dynamic_ref": @NO}];
            [params addObject:@{
                @"type": @"uint256",
                @"value": amt,
                @"index": @1,
                @"value_word_hex": [NSString stringWithFormat:@"0x%@", w1],
                @"is_dynamic_ref": @NO
            }];
        }
    } else if ([selectorHex isEqualToString:@"23b872dd"]) {
        /// transferFrom(address,address,uint256)
        if (10 + 192 <= dataLength) {
            NSString *w0 = [lower substringWithRange:NSMakeRange(10, 64)];
            NSString *w1 = [lower substringWithRange:NSMakeRange(74, 64)];
            NSString *w2 = [lower substringWithRange:NSMakeRange(138, 64)];
            NSString *fromA = [NSString stringWithFormat:@"0x%@", [w0 substringFromIndex:24]];
            NSString *toA = [NSString stringWithFormat:@"0x%@", [w1 substringFromIndex:24]];
            NSString *amt = ETHDecimalStringFromUInt256HexWord(w2);
            [params addObject:@{@"type": @"address", @"value": fromA, @"index": @0, @"is_dynamic_ref": @NO}];
            [params addObject:@{@"type": @"address", @"value": toA, @"index": @1, @"is_dynamic_ref": @NO}];
            [params addObject:@{
                @"type": @"uint256",
                @"value": amt,
                @"index": @2,
                @"value_word_hex": [NSString stringWithFormat:@"0x%@", w2],
                @"is_dynamic_ref": @NO
            }];
        }
    } else if ([selectorHex isEqualToString:@"df791e50"]) {
        /// swap(address,address,uint256)
        if (10 + 192 <= dataLength) {
            NSString *w0 = [lower substringWithRange:NSMakeRange(10, 64)];
            NSString *w1 = [lower substringWithRange:NSMakeRange(74, 64)];
            NSString *w2 = [lower substringWithRange:NSMakeRange(138, 64)];
            NSString *a0 = [NSString stringWithFormat:@"0x%@", [w0 substringFromIndex:24]];
            NSString *a1 = [NSString stringWithFormat:@"0x%@", [w1 substringFromIndex:24]];
            NSString *amt = ETHDecimalStringFromUInt256HexWord(w2);
            [params addObject:@{@"type": @"address", @"value": a0, @"index": @0, @"is_dynamic_ref": @NO}];
            [params addObject:@{@"type": @"address", @"value": a1, @"index": @1, @"is_dynamic_ref": @NO}];
            [params addObject:@{
                @"type": @"uint256",
                @"value": amt,
                @"index": @2,
                @"value_word_hex": [NSString stringWithFormat:@"0x%@", w2],
                @"is_dynamic_ref": @NO
            }];
        }
    } else if ([selectorHex isEqualToString:@"2e1a7d4d"]) {
        /// withdraw(uint256) — WETH/金库等提币、赎回 shares
        if (10 + 64 <= dataLength) {
            NSString *w0 = [lower substringWithRange:NSMakeRange(10, 64)];
            NSString *amt = ETHDecimalStringFromUInt256HexWord(w0);
            [params addObject:@{
                @"type": @"uint256",
                @"value": amt,
                @"index": @0,
                @"value_word_hex": [NSString stringWithFormat:@"0x%@", w0],
                @"is_dynamic_ref": @NO
            }];
        }
    } else {
        return nil;
    }

    if (params.count == 0) {
        return nil;
    }
    result[@"parameters"] = [params copy];
    [self benefyAttachERC20SemanticFields:result selector:selectorHex parameters:params];
    return [result copy];
}

+ (NSDictionary *)parseInputData:(NSString *)inputHex {
    if (inputHex.length < 10) {
        return @{@"error": @"Invalid input data format"};
    }
    NSString *lower = [inputHex lowercaseString];
    if (![lower hasPrefix:@"0x"]) {
        return @{@"error": @"Invalid input data format"};
    }
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSString *selectorHex = [lower substringWithRange:NSMakeRange(2, 8)];
    result[@"function_selector"] = selectorHex;
    
    NSDictionary *knownSelectors = @{
        @"a9059cbb": @"transfer(address,uint256)",
        @"23b872dd": @"transferFrom(address,address,uint256)",
        @"095ea7b3": @"approve(address,uint256)",
        /// 常见 DEX / Router（4byte.directory 可查）
        @"df791e50": @"swap(address,address,uint256)",
        @"d0e30db0":@"deposit()",
        @"2e1a7d4d":@"withdraw(uint256)",
        @"af9b3109":@"swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline)",
        /// 与 af9b3109 参数布局相同（Uniswap V2 / Pancake 等）
        @"38ed1739":@"swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline)",
        @"48d27b0e":@"swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, address[] path, address to, uint256 deadline)",
        @"7ff36ab5":@"swapExactETHForTokens(uint256,address[],address,uint256)",
        @"18cbafe5":@"swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
        @"8803dbee":@"swapTokensForExactTokens(uint256,uint256,address[],address,uint256)",
        @"b6f9de95":@"swapExactTokensForETHSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)"
    };
    if (knownSelectors[selectorHex]) {
        result[@"function_name"] = knownSelectors[selectorHex];
    } else {
        /// 未收录的选择器仍返回可读占位，便于日志与 UI
        result[@"function_name"] = [NSString stringWithFormat:@"unknown(0x%@)", selectorHex];
    }
    
    /// 说明：ERC20 的「代币合约地址」在交易的 `to` 字段，不在 `input` calldata 里；calldata 里只有函数参数。
    result[@"note"] = @"token_contract_is_tx_to_not_in_calldata";

    /// transfer / approve / transferFrom / 简单 swap：按 ABI 固定布局解析 uint256 为完整十进制字符串，避免启发式 + strtoull 截断或误判。
    NSDictionary *staticParsed = [self parseStaticABIWords:lower selectorHex:selectorHex result:result];
    if (staticParsed) {
        return staticParsed;
    }

    NSMutableArray *params = [NSMutableArray array];
    NSUInteger paramStart = 10;
    NSUInteger idx = 0;
    NSUInteger dataLength = lower.length;
    NSUInteger headerWordsEnd = paramStart; // 记录头部参数结束位置

    // 第一遍：解析头部参数（静态类型）
    while (paramStart + 64 <= dataLength) {
        NSString *paramHex = [lower substringWithRange:NSMakeRange(paramStart, 64)];
        NSLog(@"paramHex[%lu] -> %@", (unsigned long)idx, paramHex);

        if ([paramHex hasPrefix:@"000000000000000000000000"]) {
            if ([paramHex hasPrefix:@"00000000000000000000000000"]) {
                unsigned long long value = strtoull([paramHex UTF8String], NULL, 16);
                [params addObject:@{
                    @"type": @"uint256",
                    @"value": @(value),
                    @"index": @(idx),
                    @"value_word_hex": [NSString stringWithFormat:@"0x%@", paramHex],
                    @"is_dynamic_ref": @NO
                }];
            } else {
                NSString *address = [NSString stringWithFormat:@"0x%@", [paramHex substringFromIndex:24]];
                [params addObject:@{
                    @"type": @"address",
                    @"value": address,
                    @"index": @(idx),
                    @"is_dynamic_ref": @NO
                }];
            }
        } else {
            // 可能是动态类型的偏移指针
            unsigned long long offset = strtoull([paramHex UTF8String], NULL, 16);
            if (offset > 0 && offset < (dataLength - 10) / 2) {
                [params addObject:@{
                    @"type": @"dynamic_offset",
                    @"offset": @(offset),
                    @"index": @(idx),
                    @"value_word_hex": [NSString stringWithFormat:@"0x%@", paramHex],
                    @"is_dynamic_ref": @YES
                }];
            } else {
                // 普通数值
                unsigned long long value = strtoull([paramHex UTF8String], NULL, 16);
                [params addObject:@{
                    @"type": @"uint256",
                    @"value": @(value),
                    @"index": @(idx),
                    @"value_word_hex": [NSString stringWithFormat:@"0x%@", paramHex],
                    @"is_dynamic_ref": @NO
                }];
            }
        }
        idx += 1;
        paramStart += 64;
        headerWordsEnd = paramStart;
    }

    // 第二遍：解析动态数组参数（如 address[]）
    for (NSUInteger i = 0; i < params.count; i++) {
        NSMutableDictionary *param = [params[i] mutableCopy];
        if ([param[@"is_dynamic_ref"] boolValue]) {
            NSUInteger offset = (NSUInteger)[param[@"offset"] unsignedLongLongValue];
            NSUInteger arrayStart = 10 + offset * 2; // offset 是字节位置，转字符位置

            if (arrayStart + 64 <= dataLength) {
                // 读取数组长度
                NSString *lengthHex = [lower substringWithRange:NSMakeRange(arrayStart, 64)];
                unsigned long long arrayLength = strtoull([lengthHex UTF8String], NULL, 16);

                NSMutableArray *arrayElements = [NSMutableArray array];
                NSUInteger elementStart = arrayStart + 64;

                for (NSUInteger j = 0; j < arrayLength && elementStart + 64 <= dataLength; j++) {
                    NSString *elemHex = [lower substringWithRange:NSMakeRange(elementStart, 64)];
                    if ([elemHex hasPrefix:@"000000000000000000000000"]) {
                        NSString *address = [NSString stringWithFormat:@"0x%@", [elemHex substringFromIndex:24]];
                        [arrayElements addObject:address];
                    }
                    elementStart += 64;
                }

                param[@"type"] = @"address[]";
                param[@"array_length"] = @(arrayLength);
                param[@"array_elements"] = [arrayElements copy];
                // path 的第一个和最后一个地址分别作为 token_in 和 token_out
                if (arrayElements.count > 0) {
                    param[@"first_element"] = arrayElements[0];
                    param[@"last_element"] = arrayElements[arrayElements.count - 1];
                }
                params[i] = [param copy];
            }
        }
    }
    
    result[@"parameters"] = [params copy];
    [self benefyAttachERC20SemanticFields:result selector:selectorHex parameters:params];
    return [result copy];
}

/// 按 ABI 语义写入顶层键，避免多个 address 混用同一变量、只保留最后一个的问题
+ (void)benefyAttachERC20SemanticFields:(NSMutableDictionary *)result
                               selector:(NSString *)selectorHex
                             parameters:(NSArray *)params {
    if (params.count == 0) {
        return;
    }
    if ([selectorHex isEqualToString:@"a9059cbb"]) {
        /// transfer(address,uint256)
        if (params.count >= 2) {
            result[@"recipient"] = params[0][@"value"];
            result[@"amount"] = params[1][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"095ea7b3"]) {
        /// approve(address,uint256)
        if (params.count >= 2) {
            result[@"spender"] = params[0][@"value"];
            result[@"allowance"] = params[1][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"23b872dd"]) {
        /// transferFrom(address,address,uint256)
        if (params.count >= 3) {
            result[@"from_address"] = params[0][@"value"];
            result[@"to_address"] = params[1][@"value"];
            result[@"amount"] = params[2][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"df791e50"]) {
        /// swap(address,address,uint256) — 多为 tokenIn / tokenOut / amount（具体以合约为准）
        if (params.count >= 3) {
            result[@"swap_token_in"] = params[0][@"value"];
            result[@"swap_token_out"] = params[1][@"value"];
            result[@"amount"] = params[2][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"2e1a7d4d"]) {
        /// withdraw(uint256) — 与 Sheet / 广播共用 `amount` 键
        if (params.count >= 1) {
            result[@"amount"] = params[0][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"af9b3109"] || [selectorHex isEqualToString:@"38ed1739"]) {
        /// swapExactTokensForTokens（0xaf9b3109）/ swapExactTokensForTokensSupportingFeeOnTransferTokens（0x38ed1739）— ABI 相同
        if (params.count >= 5) {
            // amountIn
            result[@"amount_in"] = params[0][@"value"];
            // amountOutMin
            result[@"amount_out_min"] = params[1][@"value"];
            // path (address[])
            NSDictionary *pathParam = params[2];
            if ([pathParam[@"type"] isEqualToString:@"address[]"]) {
                result[@"swap_token_in"] = pathParam[@"first_element"];
                result[@"swap_token_out"] = pathParam[@"last_element"];
                result[@"path"] = pathParam[@"array_elements"];
            }
            // to (接收地址)
            result[@"to_address"] = params[3][@"value"];
            // deadline
            result[@"deadline"] = params[4][@"value"];
            // 兼容旧字段
            result[@"amount"] = params[0][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"48d27b0e"]) {
        /// swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, address[] path, address to, uint256 deadline)
        if (params.count >= 4) {
            // amountOutMin
            result[@"amount_out_min"] = params[0][@"value"];
            // path (address[])
            NSDictionary *pathParam = params[1];
            if ([pathParam[@"type"] isEqualToString:@"address[]"]) {
                result[@"swap_token_in"] = pathParam[@"first_element"];
                result[@"swap_token_out"] = pathParam[@"last_element"];
                result[@"path"] = pathParam[@"array_elements"];
            }
            // to
            result[@"to_address"] = params[2][@"value"];
            // deadline
            result[@"deadline"] = params[3][@"value"];
            // ETH 作为输入，amount 取 amountOutMin 作为参考
            result[@"amount"] = params[0][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"7ff36ab5"]) {
        /// swapExactETHForTokens(uint256 amountOutMin, address[] path, address to, uint256 deadline)
        if (params.count >= 4) {
            // amountOutMin
            result[@"amount_out_min"] = params[0][@"value"];
            // path (address[])
            NSDictionary *pathParam = params[1];
            if ([pathParam[@"type"] isEqualToString:@"address[]"]) {
                result[@"swap_token_in"] = pathParam[@"first_element"];
                result[@"swap_token_out"] = pathParam[@"last_element"];
                result[@"path"] = pathParam[@"array_elements"];
            }
            // to
            result[@"to_address"] = params[2][@"value"];
            // deadline
            result[@"deadline"] = params[3][@"value"];
            result[@"amount"] = params[0][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"18cbafe5"]) {
        /// swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline)
        if (params.count >= 5) {
            // amountIn
            result[@"amount_in"] = params[0][@"value"];
            // amountOutMin
            result[@"amount_out_min"] = params[1][@"value"];
            // path (address[])
            NSDictionary *pathParam = params[2];
            if ([pathParam[@"type"] isEqualToString:@"address[]"]) {
                result[@"swap_token_in"] = pathParam[@"first_element"];
                result[@"swap_token_out"] = pathParam[@"last_element"];
                result[@"path"] = pathParam[@"array_elements"];
            }
            // to
            result[@"to_address"] = params[3][@"value"];
            // deadline
            result[@"deadline"] = params[4][@"value"];
            result[@"amount"] = params[0][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"8803dbee"]) {
        /// swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] path, address to, uint256 deadline)
        if (params.count >= 5) {
            // amountOut (期望获得数量)
            result[@"amount_out"] = params[0][@"value"];
            // amountInMax (最大输入)
            result[@"amount_in_max"] = params[1][@"value"];
            // path (address[])
            NSDictionary *pathParam = params[2];
            if ([pathParam[@"type"] isEqualToString:@"address[]"]) {
                result[@"swap_token_in"] = pathParam[@"first_element"];
                result[@"swap_token_out"] = pathParam[@"last_element"];
                result[@"path"] = pathParam[@"array_elements"];
            }
            // to
            result[@"to_address"] = params[3][@"value"];
            // deadline
            result[@"deadline"] = params[4][@"value"];
            result[@"amount"] = params[0][@"value"];
        }
    } else if ([selectorHex isEqualToString:@"b6f9de95"]) {
        /// swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline)
        if (params.count >= 5) {
            // amountIn
            result[@"amount_in"] = params[0][@"value"];
            // amountOutMin
            result[@"amount_out_min"] = params[1][@"value"];
            // path (address[])
            NSDictionary *pathParam = params[2];
            if ([pathParam[@"type"] isEqualToString:@"address[]"]) {
                result[@"swap_token_in"] = pathParam[@"first_element"];
                result[@"swap_token_out"] = pathParam[@"last_element"];
                result[@"path"] = pathParam[@"array_elements"];
            }
            // to
            result[@"to_address"] = params[3][@"value"];
            // deadline
            result[@"deadline"] = params[4][@"value"];
            result[@"amount"] = params[0][@"value"];
        }
    }
}

+ (NSString *)getFunctionSelector:(NSString *)functionSignature {
    const char *str = [functionSignature UTF8String];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    
    CC_SHA256(str, (CC_LONG)strlen(str), digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:8];
    for (int i = 0; i < 4; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}
@end
