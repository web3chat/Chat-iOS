//
//  PreCoin.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/7/18.
//  Copyright © 2023 fzm. All rights reserved.
//

#import "PreCoin.h"
#import "Depend.h"

@implementation PreCoin

+ (NSArray*)getPreCoinArr
{
    NSMutableDictionary *edict = [NSMutableDictionary dictionary];
    [edict setValue:@"ETH" forKey:@"chain"];
    [edict setValue:@"http://bqbwallet.oss-cn-shanghai.aliyuncs.com/upload/application/dd069dfef3b7d7af31cf75d610b2a109.png" forKey:@"icon"];
    [edict setValue:@"90" forKey:@"id"];
    [edict setValue:@" "forKey:@"introduce"];
    [edict setValue:@"ETH" forKey:@"name"];
    [edict setValue:@"以太坊" forKey:@"nickname"];
    [edict setValue:@"ethereum" forKey:@"platform"];
    [edict setValue:@"1" forKey:@"treaty"];
    [edict setValue:@"2" forKey:@"coin_type_nft"];
    
    NSMutableDictionary *bityuan0xdict = [NSMutableDictionary dictionary];
    [bityuan0xdict setValue:@"ETH" forKey:@"chain"];
    [bityuan0xdict setValue:@"http://bqbwallet.oss-cn-shanghai.aliyuncs.com/upload/application/73e0db6c89a2c019f995fb6b47d00474.png" forKey:@"icon"];
    [bityuan0xdict setValue:@"732" forKey:@"id"];
    [bityuan0xdict setValue:@"" forKey:@"introduce"];
    [bityuan0xdict setValue:@"BTY" forKey:@"name"];
    [bityuan0xdict setValue:@"Bityuan-0x" forKey:@"nickname"];
    [bityuan0xdict setValue:@"ethereum" forKey:@"platform"];
    [bityuan0xdict setValue:@"1" forKey:@"treaty"];
    [bityuan0xdict setValue:@"2" forKey:@"coin_type_nft"];
    
    NSMutableDictionary *bnbdict = [NSMutableDictionary dictionary];
    [bnbdict setValue:@"BNB" forKey:@"chain"];
    [bnbdict setValue:@"http://bqbwallet.oss-cn-shanghai.aliyuncs.com/upload/application/834b12284a6a5cee9ed5d1937e292b70.png" forKey:@"icon"];
    [bnbdict setValue:@"641" forKey:@"id"];
    [bnbdict setValue:@"bnb" forKey:@"introduce"];
    [bnbdict setValue:@"BNB" forKey:@"name"];
    [bnbdict setValue:@"Binance" forKey:@"nickname"];
    [bnbdict setValue:@"bnb" forKey:@"platform"];
    [bnbdict setValue:@"1" forKey:@"treaty"];
    [bnbdict setValue:@"2" forKey:@"coin_type_nft"];
    
    NSMutableDictionary *bnbudict = [NSMutableDictionary dictionary];
    [bnbudict setValue:@"BNB" forKey:@"chain"];
    [bnbudict setValue:@"http://bqbwallet.oss-cn-shanghai.aliyuncs.com/upload/application/cad48c7bc2573ac159d01ed6e82fd54d.jpeg" forKey:@"icon"];
    [bnbudict setValue:@"694" forKey:@"id"];
    [bnbudict setValue:@"usdt" forKey:@"introduce"];
    [bnbudict setValue:@"USDT" forKey:@"name"];
    [bnbudict setValue:@"BEP20" forKey:@"nickname"];
    [bnbudict setValue:@"bnb" forKey:@"platform"];
    [bnbudict setValue:@"1" forKey:@"treaty"];
    [bnbudict setValue:@"2" forKey:@"coin_type_nft"];
    
    NSArray *array = @[edict,bityuan0xdict,bnbdict,bnbudict];

    
    return array;
}

- (BOOL)addWalletIntoDB:(NSString *)rememberCode
{
    LocalWallet *wallet = [[LocalWallet alloc] init];
    //下面使用kvc是为了不产生警告
    wallet.wallet_name = @"助记词钱包";
    wallet.wallet_password = @"";
    wallet.wallet_remembercode = @"我是助记词";
    wallet.wallet_totalassets = 0;
    wallet.wallet_issmall = 1;
    
    LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    selectedWallet.wallet_isselected = 0;
   
    [[PWDataBaseManager shared] updateWallet:selectedWallet];
    wallet.wallet_isbackup = 1;
    wallet.wallet_isselected = 1;
    wallet.wallet_issetpwd = 1;
    return [[PWDataBaseManager shared] addWallet:wallet];
}

/**
 * 添加币到钱包
 */
- (void)addCoinIntoW:(NSString *)rememberCode
{
//    NSString *rememberCode = rememberdict[@"remeber"];
    NSLog(@"seed is:%@",rememberCode);
    if ([self addWalletIntoDB:rememberCode]) {
        
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            return ;
        });
    }
    
    NSArray *array = [PreCoin getPreCoinArr];
    [self addCoinDetailOperation:array code:rememberCode];
}

/**
 * 获取到推荐币种后的操作
 */
- (void)addCoinDetailOperation:(NSArray *)coinArray  code:(NSString *)rememberCode
{
    
    __block NSError *error;
    __block BOOL state = YES;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        // 先拿第一个币种来创建一下钱包，然后导入其他的币
        NSDictionary *dict = coinArray[0];
        NSString *chain = dict[@"chain"];
        WalletapiHDWallet *hdWallets = [GoFunction goCreateHDWallet:chain rememberCode:rememberCode];
        if (hdWallets == nil || [hdWallets isEqual:[NSNull null]])
        {
            // 助记词不正确
            dispatch_async(dispatch_get_main_queue(), ^{
            });
            state = NO;
            return;
        }
        
        for (int i = 0; i < coinArray.count; i++) {
            
            NSDictionary *dic = [coinArray objectAtIndex:i];
            NSString *coinStr = dic[@"name"];
            NSString *chains = dic[@"chain"];
            NSString *platStr = dic[@"platform"];
            NSInteger treaty = [dic[@"treaty"] integerValue];
            WalletapiHDWallet *hdWallet = [GoFunction goCreateHDWallet:[chains isEqualToString:@"BNB"] ? @"ETH":chains rememberCode:rememberCode];
            // 先判断助记词是不是正确的，再判断助记词是不是已经存在，如果没有则开始创建钱包和加入币种
            
            if (hdWallet == nil || [hdWallet isEqual:[NSNull null]])
            {
                // 助记词不正确
                dispatch_async(dispatch_get_main_queue(), ^{
                  
                });
                state = NO;
                break;
            }
            else
            {
                NSData *pubKey = [hdWallet newKeyPub:0 error:&error];

                NSString *address = [GoFunction createAddress:hdWallet coinType:coinStr platform:platStr andTreaty:treaty];
//                CGFloat balance = [GoFunction goGetBalance:coinStr platform:platStr address:address andTreaty:treaty];
                LocalCoin *coin = [[LocalCoin alloc] init];
                coin.coin_walletid = [[PWDataBaseManager shared] queryMaxWalletId];
                coin.coin_type = coinStr;
                coin.coin_address = address;
                coin.coin_balance = 0;
                coin.coin_pubkey = [pubKey hexString];
                coin.icon = dic[@"icon"];
                coin.coin_show = 1;
                coin.coin_platform = dic[@"platform"];
                coin.coin_coinid = [dic[@"id"] integerValue];
                coin.treaty = [dic[@"treaty"] integerValue];
                coin.coin_chain = dic[@"chain"];
                coin.coin_type_nft = [dic[@"coin_type_nft"] integerValue];
                [[PWDataBaseManager shared] addCoin:coin];
                
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (state) {
               
//               
//                NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
//                NSMutableArray *muArr = [[NSMutableArray alloc] init];
//                for (LocalCoin *coin in coinArray) {
//                    NSDictionary *dict = @{@"cointype":coin.coin_type,
//                                           @"address":coin.coin_address
//                    };
//                    
//                    [muArr addObject:dict];
//                }
                
//                [GoFunction muImpAddr:[NSArray arrayWithArray:muArr]];
//                [[PWAppsettings instance] deletecurrentCoinsName];
//                [[PWAppsettings instance] savecurrentCoinsName:@"2"];
//                [[PWAppsettings instance] deleteHomeCoinPrice];
//                [[PWAppsettings instance] deleteHomeLocalCoin];
//                [[PWAppsettings instance] deleteAddress];
//
            }
        });
    });
}

- (BOOL)haveRemWithPubKey:(NSString *)key
{
    NSArray *walletArray = [[PWDataBaseManager shared] queryAllWallets];
    for (LocalWallet *wallet in walletArray)
    {
        // 防止出现导入了私钥钱包而出现的助记词重复bug
        if (wallet.wallet_issmall == 2 || wallet.wallet_issmall == 3 || wallet.wallet_isEscrow == 1) {
            continue;
        }
        NSArray *localCoinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnWallet:wallet];
        for (LocalCoin *coin in localCoinArray) {
            if ([coin.coin_pubkey isEqualToString:key]) {
                return YES;
            }
        }

    }
    return NO;
}

@end
