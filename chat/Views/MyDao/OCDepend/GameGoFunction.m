//
//  GameGoFunction.m
//  PWallet
//
//  Created by 宋刚 on 2018/8/15.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "GameGoFunction.h"
#import "LocalWallet.h"
#import "LocalCoin.h"
#import "PWDataBaseManager.h"

@implementation GameGoFunction


/**
 * 获取当前钱包BTY地址
 */
+ (NSString *)querySelectedBtyAddress
{
    NSString *fromAddress = @"";
    NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    for (LocalCoin *coin in coinArray) {
        if ([coin.coin_type isEqualToString:@"BTY"] && [coin.coin_chain isEqualToString:@"BTY"]) {
            fromAddress = coin.coin_address;
            break;
        }
    }
    return fromAddress == nil ? @"" : fromAddress;
}

+ (NSString *)queryAddressByChain:(NSString *)chain
{
    NSString *fromAddress = @"";
    NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    /// BitYuan 主网 Web3 与 `PWUtils getEthBtyAddress` 一致：原生币为 coin_type=BTY、coin_chain=ETH（EVM）
    if ([chain isEqualToString:@"BTY"]) {
        for (LocalCoin *coin in coinArray) {
            if ([coin.coin_type isEqualToString:@"BTY"] && [coin.coin_chain isEqualToString:@"ETH"]) {
                fromAddress = coin.coin_address;
                break;
            }
        }
    } else if ([chain isEqualToString:@"ETH"]) {
        for (LocalCoin *coin in coinArray) {
            if ([coin.coin_type isEqualToString:@"ETH"] && [coin.coin_chain isEqualToString:@"ETH"]) {
                fromAddress = coin.coin_address;
                break;
            }
        }
    } else {
        for (LocalCoin *coin in coinArray) {
            if ([coin.coin_type isEqualToString:chain]) {
                fromAddress = coin.coin_address;
                break;
            }
        }
    }
    return fromAddress == nil ? @"" : fromAddress;
}


+(NSArray *)getPwalletSelectdAddress
{
    NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    if (coinArray.count == 0) {
        return [NSArray array];
    }
    NSMutableArray *marray = [[NSMutableArray alloc] init];
    for (LocalCoin *coin in coinArray) {
        if ([coin.coin_type isEqualToString:coin.coin_chain]) {
            NSString *chainStr = [NSString stringWithFormat:@"%@,%@",coin.coin_chain,coin.coin_address];
            [marray addObject:chainStr];
        }
    }
  
    NSArray *array = [NSArray arrayWithArray:marray];
    return array;
}

/**
 * 获取当前钱包BTY余额
 */
+ (CGFloat)querySelectedBtyBalance
{
    CGFloat balance = 0;
    NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    for (LocalCoin *coin in coinArray) {
        if ([coin.coin_type isEqualToString:@"BTY"]) {
            balance = coin.coin_balance;
            break;
        }
    }
    return balance;
}

@end
