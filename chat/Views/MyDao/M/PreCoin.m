//
//  PreCoin.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/7/18.
//  Copyright © 2023 fzm. All rights reserved.
//

#import "PreCoin.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]

static NSString * const kPreCoinImportWalletFinishedNotification = @"k_importwallet";

static void PreCoinPostImportWalletFinished(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kPreCoinImportWalletFinishedNotification object:nil];
    });
}

@implementation PreCoin

+ (NSArray*)getPreCoinArr
{

    NSMutableDictionary *edict = [NSMutableDictionary dictionary];
    [edict setValue:@"ETH" forKey:@"chain"];
    [edict setValue:@"http://bqbwallet.oss-cn-shanghai.aliyuncs.com/upload/application/dd069dfef3b7d7af31cf75d610b2a109.png" forKey:@"icon"];
    [edict setValue:@"90" forKey:@"id"];
    [edict setValue:@" "forKey:@"introduce"];
    [edict setValue:@"ETH" forKey:@"name"];
    [edict setValue:L(@"以太坊") forKey:@"nickname"];
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
    
    NSMutableDictionary *bty1xdict = [NSMutableDictionary dictionary];
    [bty1xdict setValue:@"BTY" forKey:@"chain"];
    [bty1xdict setValue:@"http://bqbwallet.oss-cn-shanghai.aliyuncs.com/upload/application/8568e340ae44fcd01bddf84a3eb2d7aa.png" forKey:@"icon"];
    [bty1xdict setValue:@"154" forKey:@"id"];
    [bty1xdict setValue:@"bty" forKey:@"introduce"];
    [bty1xdict setValue:@"BTY" forKey:@"name"];
    [bty1xdict setValue:@"Bityuan-1x" forKey:@"nickname"];
    [bty1xdict setValue:@"bty" forKey:@"platform"];
    [bty1xdict setValue:@"1" forKey:@"treaty"];
    [bty1xdict setValue:@"2" forKey:@"coin_type_nft"];
    
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
    
    NSMutableDictionary *pmmdict = [NSMutableDictionary dictionary];
    [pmmdict setValue:@"BTY" forKey:@"chain"];
    [pmmdict setValue:@"https://www.iconaves.com/token_icon_request/69cb4bef72df4b290e705fbc_1774930927.png" forKey:@"icon"];
    [pmmdict setValue:@"702" forKey:@"id"];
    [pmmdict setValue:@"pmm" forKey:@"introduce"];
    [pmmdict setValue:@"PMM" forKey:@"name"];
    [pmmdict setValue:@"PMM" forKey:@"nickname"];
    [pmmdict setValue:@"pmm" forKey:@"platform"];
    [pmmdict setValue:@"1" forKey:@"treaty"];
    [pmmdict setValue:@"10" forKey:@"coin_type_nft"];
    [pmmdict setValue:@"0x919B110C856D1d96E1850cDCA60de8637Bf18db6" forKey:@"coin_pubkey"];

    NSArray *array = @[edict,bityuan0xdict,bty1xdict,bnbdict,bnbudict];
    
    return array;
}

- (BOOL)addWalletIntoDB:(NSString *)rememberCode passwd:(NSString *)passwd
{
    LocalWallet *wallet = [[LocalWallet alloc] init];
    //下面使用kvc是为了不产生警告
    wallet.wallet_name = L(@"助记词钱包");
    wallet.wallet_password = [GoFunction passwordhash:passwd];
    wallet.wallet_remembercode = [GoFunction enckey:rememberCode password:passwd];
    wallet.wallet_totalassets = 0;
    wallet.wallet_issmall = 1;
    wallet.wallet_id = [[PWDataBaseManager shared] queryMaxWalletId] + 1;
    LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    if (selectedWallet != nil) {
        selectedWallet.wallet_isselected = 0;
        [[PWDataBaseManager shared] updateWallet:selectedWallet];
    }
    wallet.wallet_isbackup = 1;
    wallet.wallet_isselected = 1;
    wallet.wallet_issetpwd = 1;
    return [[PWDataBaseManager shared] addWallet:wallet];
}

/**
 * 用助记词推导账号的主链地址（口径与登录时的 `EncryptManager.publicKeyToAddress` 一致：BTY 地址）
 * 用于「同一助记词 → 同一个钱包」的去重，不依赖加密串。
 */
- (NSString *)accountMainAddressForSeed:(NSString *)seed
{
    if (seed.length == 0) {
        return nil;
    }
    WalletapiHDWallet *hdWallet = [GoFunction goCreateHDWallet:@"BTY" rememberCode:seed];
    if (hdWallet == nil || [hdWallet isEqual:[NSNull null]]) {
        return nil;
    }
    NSError *error;
    NSData *pubKey = [hdWallet newKeyPub:0 error:&error];
    if (pubKey == nil) {
        return nil;
    }
    NSString *address = WalletapiPubToAddress_v2(@"BTY", pubKey, &error);
    return address.length > 0 ? address : nil;
}

/**
 * 查当前助记词对应的既有钱包：
 *  1. 先按加密串（历史数据里可能有能命中的）
 *  2. 再按「主链地址」反查 coin 表 —— 助记词的加密是 AES-GCM，同一助记词每次密文都不同，
 *     只按加密串查会导致每次登录/切换账号都新建一个钱包（旧钱包的币还挂在旧 wallet_id 上，
 *     资产页就会显示成「钱包没切换」）。
 */
- (LocalWallet *)existingWalletForSeed:(NSString *)seed encryptedSeed:(NSString *)encCode
{
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletByRememberCode:encCode];
    if (wallet != nil) {
        return wallet;
    }
    NSString *accountAddress = [self accountMainAddressForSeed:seed];
    return [[PWDataBaseManager shared] queryWalletByCoinAddress:accountAddress];
}

/**
 * 添加币到钱包
 */
- (void)addCoinIntoW:(NSString *)rememberCode passwd:(NSString *)passwd
{
//    NSString *rememberCode = rememberdict[@"remeber"];
    // ⚠️ 不要打印助记词（明文会进系统日志）；加密与入库只用下面这条密文
    NSString *encCode = [GoFunction enckey:rememberCode password:passwd];
    LocalWallet *existing = [self existingWalletForSeed:rememberCode encryptedSeed:encCode];
    NSArray *array = [PreCoin getPreCoinArr];
    if (existing != nil) {
        existing.wallet_password = [GoFunction passwordhash:passwd];
        [[PWDataBaseManager shared] updateWallet:existing];
        [[PWDataBaseManager shared] selectWalletAsCurrent:existing];
        [self addCoinDetailOperation:array code:rememberCode walletId:existing.wallet_id onlyAddMissingCoins:YES];
        return;
    }
    if (![self addWalletIntoDB:rememberCode passwd:passwd]) {
        PreCoinPostImportWalletFinished();
        return;
    }
    // 新建钱包后以 MAX(wallet_id) 为准，避免依赖 isselected 查询在个别环境下为 0 导致币种挂到错误 id
    NSInteger newWalletId = [[PWDataBaseManager shared] queryMaxWalletId];
    if (newWalletId <= 0) {
        newWalletId = [[PWDataBaseManager shared] queryWalletId];
    }
    [self addCoinDetailOperation:array code:rememberCode walletId:newWalletId onlyAddMissingCoins:NO];
}

/**
 * 获取到推荐币种后的操作
 */
- (void)addCoinDetailOperation:(NSArray *)coinArray code:(NSString *)rememberCode walletId:(NSInteger)walletId onlyAddMissingCoins:(BOOL)onlyAddMissingCoins
{
    
    __block NSError *error;
    __block BOOL state = YES;
    if (coinArray.count == 0) {
        PreCoinPostImportWalletFinished();
        return;
    }
    if (walletId <= 0) {
        PreCoinPostImportWalletFinished();
        return;
    }
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        // 先拿第一个币种来创建一下钱包，然后导入其他的币
        NSDictionary *dict = coinArray[0];
        NSString *chain = dict[@"chain"];
        WalletapiHDWallet *hdWallets = [GoFunction goCreateHDWallet:chain rememberCode:rememberCode];
        if (hdWallets == nil || [hdWallets isEqual:[NSNull null]])
        {
            // 助记词不正确
            state = NO;
            PreCoinPostImportWalletFinished();
            return;
        }
        
        for (int i = 0; i < coinArray.count; i++) {
            
            NSDictionary *dic = [coinArray objectAtIndex:i];
            NSString *coinStr = dic[@"name"];
            NSString *chains = dic[@"chain"];
            NSString *platStr = dic[@"platform"];
            NSInteger treaty = [dic[@"treaty"] integerValue];
            NSInteger nft = [dic[@"coin_type_nft"] integerValue];
            NSString *coinaddr = dic[@"coin_pubkey"];
            if ([chains isEqualToString:@"POL"] ||[chains isEqualToString:@"BNB"]) {
                chains = @"ETH";
            }else if([chains isEqualToString:@"BTY"] && ![platStr isEqualToString:@"bty"]) {
                chains = @"ETH";
            }
            WalletapiHDWallet *hdWallet = [GoFunction goCreateHDWallet:chains rememberCode:rememberCode];

            // 先判断助记词是不是正确的，再判断助记词是不是已经存在，如果没有则开始创建钱包和加入币种
            
            if (hdWallet == nil || [hdWallet isEqual:[NSNull null]])
            {
                // 助记词不正确
                state = NO;
                break;
            }
            else
            {
                NSData *pubKey = [hdWallet newKeyPub:0 error:&error];

                NSString *address = [GoFunction createAddress:hdWallet coinType:coinStr platform:platStr andTreaty:treaty];
//                CGFloat balance = [GoFunction goGetBalance:coinStr platform:platStr address:address andTreaty:treaty];
                LocalCoin *coin = [[LocalCoin alloc] init];
                coin.coin_walletid = walletId;
                coin.coin_type = coinStr;
                coin.coin_address = address;
                coin.coin_balance = 0;
                coin.coin_pubkey = nft == 10 ? coinaddr : [pubKey hexString];
                coin.icon = dic[@"icon"];
                coin.coin_show = 1;
                coin.coin_platform = dic[@"platform"];
                coin.coin_coinid = [dic[@"id"] integerValue];
                coin.treaty = [dic[@"treaty"] integerValue];
                coin.coin_chain = dic[@"chain"];
                coin.coin_type_nft = [dic[@"coin_type_nft"] integerValue];
                if (onlyAddMissingCoins && [[PWDataBaseManager shared] existCoin:coin]) {
                    continue;
                }
                [[PWDataBaseManager shared] addCoin:coin];
                
            }
        }
        // 导入页 ImportSeedVC 依赖该通知结束 loading（此前工程内无任何地方发出）
        PreCoinPostImportWalletFinished();

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
