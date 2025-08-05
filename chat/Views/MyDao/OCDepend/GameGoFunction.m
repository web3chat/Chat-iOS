//
//  GameGoFunction.m
//  PWallet
//
//  Created by 宋刚 on 2018/8/15.
//  Copyright © 2018年 陈健. All rights reserved.
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
    for (LocalCoin *coin in coinArray) {
        if ([coin.coin_type isEqualToString:chain]) {
            fromAddress = coin.coin_address;
            break;
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
