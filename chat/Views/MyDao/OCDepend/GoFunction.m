//
//  GoFunction.m
//  PWallet
//
//  Created by 宋刚 on 2018/6/19.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "GoFunction.h"
#import "PWDataBaseManager.h"
#import "CoinPrice.h"
#import <sys/utsname.h>
#import "Depend.h"
#import "chat-Swift.h"
#define YCC @"YCC"
#define BTY @"BTY"
#define ETH @"ETH"
#define BTC @"BTC"
#define BLANK @""


@implementation GoFunction


//
+ (NSString *)getSeesionIdWithAppSymbol:(NSString *)appSymbol AppKey:(NSString *)appKey
{
    WalletapiWalletSession *session = [[WalletapiWalletSession alloc] init];
    session.appSymbol = appSymbol;
    NSString *hardInfo = [NSString stringWithFormat:@"%@ %@ %@",[self getDeviceModelName],[UIDevice currentDevice].systemName,[UIDevice currentDevice].systemVersion];
    session.hardinfo = hardInfo;
    // 设置appkey
    WalletapiSetAppKey(appKey);
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [util setNode:GoNodeUrl];
    NSError *error;
    NSString *sessionId = WalletapiGetSessionId(session, util, &error);
    NSLog(@"sessionid->>>>>>>>>>> %@",sessionId);
    if (error) {
        return BLANK;
    }
    
    return sessionId;
    
}
+ (void)setSessionId
{
    NSString *sessionId = [GoFunction getSeesionIdWithAppSymbol:APPSYMBOL AppKey:APPKEY];
    if (sessionId.length == 0) {
        return;
    }
    WalletapiSetSessionID(sessionId);
}

/// 获取设备型号，该型号就是 设置->通用->关于手机->型号名称
+ (NSString *)getDeviceModelName {
    struct utsname systemInfo;
    
    if (uname(&systemInfo) < 0) {
        return BLANK;
    } else {
        // 获取设备标识Identifier
        NSString *deviceIdentifer = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        // 根据identifier去匹配到对应的型号名称
        NSString *modelName = [[self modelList] objectForKey:deviceIdentifer];
        return modelName?:BLANK;
    }
}

/// 只列出了iphone、ipad和simulator的型号，其他设备型号请到 https://www.theiphonewiki.com/wiki/Models 查看
+ (NSDictionary *)modelList {
    // @{identifier: name}
    return @{
        // iPhone
        @"iPhone1,1" : @"iPhone",
        @"iPhone1,2" : @"iPhone 3G",
        @"iPhone2,1" : @"iPhone 3GS",
        @"iPhone3,1" : @"iPhone 4",
        @"iPhone3,2" : @"iPhone 4",
        @"iPhone3,3" : @"iPhone 4",
        @"iPhone4,1" : @"iPhone 4S",
        @"iPhone5,1" : @"iPhone 5",
        @"iPhone5,2" : @"iPhone 5",
        @"iPhone5,3" : @"iPhone 5c",
        @"iPhone5,4" : @"iPhone 5c",
        @"iPhone6,1" : @"iPhone 5s",
        @"iPhone6,2" : @"iPhone 5s",
        @"iPhone7,2" : @"iPhone 6",
        @"iPhone7,1" : @"iPhone 6 Plus",
        @"iPhone8,1" : @"iPhone 6s",
        @"iPhone8,2" : @"iPhone 6s Plus",
        @"iPhone8,4" : @"iPhone SE (1st generation)",
        @"iPhone9,1" : @"iPhone 7",
        @"iPhone9,3" : @"iPhone 7",
        @"iPhone9,2" : @"iPhone 7 Plus",
        @"iPhone9,4" : @"iPhone 7 Plus",
        @"iPhone10,1" : @"iPhone 8",
        @"iPhone10,4" : @"iPhone 8",
        @"iPhone10,2" : @"iPhone 8 Plus",
        @"iPhone10,5" : @"iPhone 8 Plus",
        @"iPhone10,3" : @"iPhone X",
        @"iPhone10,6" : @"iPhone X",
        @"iPhone11,8" : @"iPhone XR",
        @"iPhone11,2" : @"iPhone XS",
        @"iPhone11,6" : @"iPhone XS Max",
        @"iPhone11,4" : @"iPhone XS Max",
        @"iPhone12,1" : @"iPhone 11",
        @"iPhone12,3" : @"iPhone 11 Pro",
        @"iPhone12,5" : @"iPhone 11 Pro Max",
        @"iPhone12,8" : @"iPhone SE (2nd generation)",
        @"iPhone13,1" : @"iPhone 12 mini",
        @"iPhone13,2" : @"iPhone 12",
        @"iPhone13,3" : @"iPhone 12 Pro",
        @"iPhone13,4" : @"iPhone 12 Pro Max",
        @"iPhone14,4" : @"iPhone 13 mini",
        @"iPhone14,5" : @"iPhone 13",
        @"iPhone14,2" : @"iPhone 13 Pro",
        @"iPhone14,3" : @"iPhone 13 Pro Max",
        @"iPhone14,6" : @"iPhone SE (3rd generation)",
        // iPad
        @"iPad1,1" : @"iPad",
        @"iPad2,1" : @"iPad 2",
        @"iPad2,2" : @"iPad 2",
        @"iPad2,3" : @"iPad 2",
        @"iPad2,4" : @"iPad 2",
        @"iPad3,1" : @"iPad (3rd generation)",
        @"iPad3,2" : @"iPad (3rd generation)",
        @"iPad3,3" : @"iPad (3rd generation)",
        @"iPad3,4" : @"iPad (4th generation)",
        @"iPad3,5" : @"iPad (4th generation)",
        @"iPad3,6" : @"iPad (4th generation)",
        @"iPad6,11" : @"iPad (5th generation)",
        @"iPad6,12" : @"iPad (5th generation)",
        @"iPad7,5" : @"iPad (6th generation)",
        @"iPad7,6" : @"iPad (6th generation)",
        @"iPad7,11" : @"iPad (7th generation)",
        @"iPad7,12" : @"iPad (7th generation)",
        @"iPad11,6" : @"iPad (8th generation)",
        @"iPad11,7" : @"iPad (8th generation)",
        @"iPad12,1" : @"iPad (9th generation)",
        @"iPad12,2" : @"iPad (9th generation)",
        @"iPad4,1" : @"iPad Air",
        @"iPad4,2" : @"iPad Air",
        @"iPad4,3" : @"iPad Air",
        @"iPad5,3" : @"iPad Air 2",
        @"iPad5,4" : @"iPad Air 2",
        @"iPad11,3" : @"iPad Air (3rd generation)",
        @"iPad11,4" : @"iPad Air (3rd generation)",
        @"iPad13,1" : @"iPad Air (4th generation)",
        @"iPad13,2" : @"iPad Air (4th generation)",
        @"iPad13,16" : @"iPad Air (5th generation)",
        @"iPad13,17" : @"iPad Air (5th generation)",
        @"iPad6,7" : @"iPad Pro (12.9-inch)",
        @"iPad6,8" : @"iPad Pro (12.9-inch)",
        @"iPad6,3" : @"iPad Pro (9.7-inch)",
        @"iPad6,4" : @"iPad Pro (9.7-inch)",
        @"iPad7,1" : @"iPad Pro (12.9-inch) (2nd generation)",
        @"iPad7,2" : @"iPad Pro (12.9-inch) (2nd generation)",
        @"iPad7,3" : @"iPad Pro (10.5-inch)",
        @"iPad7,4" : @"iPad Pro (10.5-inch)",
        @"iPad8,1" : @"iPad Pro (11-inch)",
        @"iPad8,2" : @"iPad Pro (11-inch)",
        @"iPad8,3" : @"iPad Pro (11-inch)",
        @"iPad8,4" : @"iPad Pro (11-inch)",
        @"iPad8,5" : @"iPad Pro (12.9-inch) (3rd generation)",
        @"iPad8,6" : @"iPad Pro (12.9-inch) (3rd generation)",
        @"iPad8,7" : @"iPad Pro (12.9-inch) (3rd generation)",
        @"iPad8,8" : @"iPad Pro (12.9-inch) (3rd generation)",
        @"iPad8,9" : @"iPad Pro (11-inch) (2nd generation)",
        @"iPad8,10" : @"iPad Pro (11-inch) (2nd generation)",
        @"iPad8,11" : @"iPad Pro (12.9-inch) (4th generation)",
        @"iPad8,12" : @"iPad Pro (12.9-inch) (4th generation)",
        @"iPad13,4" : @"iPad Pro (11-inch) (3rd generation)",
        @"iPad13,5" : @"iPad Pro (11-inch) (3rd generation)",
        @"iPad13,6" : @"iPad Pro (11-inch) (3rd generation)",
        @"iPad13,7" : @"iPad Pro (11-inch) (3rd generation)",
        @"iPad13,8" : @"iPad Pro (12.9-inch) (5th generation)",
        @"iPad13,9" : @"iPad Pro (12.9-inch) (5th generation)",
        @"iPad13,10" : @"iPad Pro (12.9-inch) (5th generation)",
        @"iPad13,11" : @"iPad Pro (12.9-inch) (5th generation)",
        @"iPad2,5" : @"iPad mini",
        @"iPad2,6" : @"iPad mini",
        @"iPad2,7" : @"iPad mini",
        @"iPad4,4" : @"iPad mini 2",
        @"iPad4,5" : @"iPad mini 2",
        @"iPad4,6" : @"iPad mini 2",
        @"iPad4,7" : @"iPad mini 3",
        @"iPad4,8" : @"iPad mini 3",
        @"iPad4,9" : @"iPad mini 3",
        @"iPad5,1" : @"iPad mini 4",
        @"iPad5,2" : @"iPad mini 4",
        @"iPad11,1" : @"iPad mini (5th generation)",
        @"iPad11,2" : @"iPad mini (5th generation)",
        @"iPad14,1" : @"iPad mini (6th generation)",
        @"iPad14,2" : @"iPad mini (6th generation)",
        // 其他
        @"i386" : @"iPhone Simulator",
        @"x86_64" : @"iPhone Simulator",
    };
}
/**
 * 创建WalletHDWallet
 */
+ (WalletapiHDWallet *)goCreateHDWallet:(NSString *)coinType rememberCode:(NSString *)mnemonic
{
    NSString *mainCoinType = coinType;
    
    NSError *error;
    WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2(mainCoinType,mnemonic, &error);
    return hdWallet;
}

/**
 * 创建地址
 */
+ (NSString *)createAddress:(WalletapiHDWallet *)hdWallet coinType:(NSString *)coinType platform:(NSString *)platStr andTreaty:(NSInteger)treaty
{
    NSError *error;
    NSString *address = [hdWallet newAddress_v2:0 error:&error];
   
    if (address != nil && ![address isEqual:[NSNull null]]) {
        
        return address;
    }else
    {
        return BLANK;
    }
}

/**
 * 根据交易ID查询交易详情
 */
+ (NSDictionary*)queryTransactionByTxid:(NSString *)coinType platform:(NSString *)platStr Txid:(NSString *)txid andTreaty:(NSInteger)treaty
{
    NSError *error;
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinType platform:platStr andTreaty:treaty];
    NSString *tokenSybmol = BLANK;
    WalletapiWalletQueryByTxid *querybytxid = [[WalletapiWalletQueryByTxid alloc] init];
    if ([coinPrice.coinprice_platform isEqualToString:@"wwchain"]) {
        tokenSybmol = [NSString stringWithFormat:@"ww.%@",coinPrice.coinprice_heyueAddress];
    }
    
    [querybytxid setCointype:coinType];
    [querybytxid setTxid:txid];
    [querybytxid setTokenSymbol:tokenSybmol];
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    [util setNode:GoNodeUrl];
    [querybytxid setUtil:util];
    
    NSData *data = WalletapiQueryTransactionByTxid(querybytxid, &error);
    if (data == nil) {
        return nil;
    }
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    if([jsonDict[@"result"] isEqual:[NSNull null]])
    {
        return nil;
    }else{
        
        return [NSDictionary dictionaryWithDictionary:jsonDict[@"result"]];
    }
}

/**
 * 查询交易记录
 */
+ (NSArray *)queryTransactionsByaddress:(NSString *)coinType platform:(NSString *)platStr address:(NSString *)coinAddress page:(NSInteger)page andTreaty:(NSInteger)treaty type:(NSInteger)type
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSError *error;
    NSString *tokenSymbol = coinType;
   
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinType platform:platStr andTreaty:treaty];
    NSString *realCoinType = coinPrice.coinprice_chain;
    if(coinPrice == nil || [coinPrice isEqual:[NSNull null]])
    {
        return array;
    }
    
    NSData *data;
    
    if (coinPrice.treaty == 2)
    {
        if ([coinType isEqualToString:@"WW"] &&( [coinPrice.coinprice_chain isEqualToString:ETH] || [coinPrice.coinprice_chain isEqualToString:BTY])) {
            tokenSymbol =  @"ww.coins";
            realCoinType = BTY;
        }else{
            tokenSymbol = [NSString stringWithFormat:@"%@.coins",coinPrice.coinprice_platform];
        }
       
    }
    else
    {
        if ([coinPrice.coinprice_chain isEqualToString:BTY] && ![coinPrice.coinprice_platform isEqualToString:BTY]) {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.%@",platformStr,coinType];
        }
        if ([coinPrice.coinprice_platform isEqualToString:@"wwchain"]){
            realCoinType = BTY;
            tokenSymbol = [NSString stringWithFormat:@"ww.%@",coinPrice.coinprice_heyueAddress];
        }
    }
    
    if ([coinPrice.coinprice_chain isEqualToString:coinType]) {
        tokenSymbol = BLANK;
    }

    // eth地址和BTC地址的YCC要特殊处理
    if (([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:ETH])
        ||([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:BTC])) {
        tokenSymbol = BLANK;
        realCoinType = YCC;
    }
    
    if ([coinType isEqualToString:BTY] && [coinPrice.coinprice_chain isEqualToString:ETH]) {
        tokenSymbol = BLANK;
        realCoinType = BTY;
    }
    // ybf的币特殊处理
    if([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"yhchain"]){
        if (coinPrice.treaty == 2)
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.coins",platformStr];
            realCoinType = BTY;
        }
        else
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.%@",platformStr,coinType];
            realCoinType = BTY;
        }
    }
    
    WalletapiQueryByPage *queryByPage = [[WalletapiQueryByPage alloc] init];
    [queryByPage setCointype:realCoinType];
    [queryByPage setAddress:coinAddress];
    [queryByPage setTokenSymbol:tokenSymbol];
    
    
    [queryByPage setIndex:page * 20];
    [queryByPage setCount:20];
    [queryByPage setDirection:0];
    // type=1，入账，，type=2，出账
    if (type == 1 || type == 2) {
        [queryByPage setType:type];
    }
    
    WalletapiWalletQueryByAddr *walletQueryByAddr = [[WalletapiWalletQueryByAddr alloc] init];
    [walletQueryByAddr setQueryByPage:queryByPage];
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [util setNode:GoNodeUrl];
//    [util setNode:@"https://112.74.59.221:8084"]; // 账单类型测试
    [walletQueryByAddr setUtil:util];
    
    data = WalletapiQueryTransactionsByaddress(walletQueryByAddr, &error);
    
    if (data == nil) {
        return array;
    }
    
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    if ([jsonDict[@"result"] isEqual:[NSNull null]]) {
        return array;
    }else{
        
        NSArray *result = jsonDict[@"result"];
        NSMutableArray *resultArray = [[NSMutableArray alloc] init];
        
        // USDT 去除转账金额小于1的账单，增加安全性
        if ([coinType isEqualToString:@"USDT"]) {
            for (int i = 0; i < result.count; i ++) {
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:[result objectAtIndex:i]];
                CGFloat value = [dic[@"value"] floatValue];
                if (value < 1) {
                    
                } else {
                    [resultArray addObject:dic];
                }
            }
        }
        
        if ((![coinPrice.coinprice_platform isEqual:BTY]) && [coinPrice.coinprice_chain isEqual:BTY] && (![coinPrice.coinprice_platform isEqual:@"guodun"])) {
            for (int i = 0; i < result.count; i ++) {
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:[result objectAtIndex:i]];
                NSString *type = dic[@"type"];
                //                CGFloat value = [dic[@"value"] doubleValue];
                NSString *note = dic[@"note"];
                if ([type isEqualToString:@"send"] && [note isEqualToString:@"token fee"])
                {
                }
                else
                {
                    [resultArray addObject:dic];
                }
            }
            
            return resultArray;
        }
        
        
        return result;
    }
}

/**
 * 查询余额
 */
+ (CGFloat )goGetBalance:(NSString *)coinType platform:(NSString *)platStr address:(NSString *)address  andTreaty:(NSInteger)treaty
{
    NSData *balanceData;
    NSError *error;
    CGFloat balance = 0;
    NSString *tokenSymbols = coinType;
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinType platform:platStr andTreaty:treaty];
    NSString *realCoinType = coinPrice.coinprice_chain;
    
    if (coinPrice.treaty == 2)
    {
        NSString *platformStr = coinPrice.coinprice_platform;
        if ([platformStr isEqualToString:@"wwchain"]) {
            tokenSymbols = [NSString stringWithFormat:@"%@.coins",[coinType lowercaseString]];
            realCoinType = BTY;
        }else{
            tokenSymbols = [NSString stringWithFormat:@"%@.coins",platformStr];
        }
    }
    else
    {
        if ([coinPrice.coinprice_chain isEqualToString:BTY] && ![coinPrice.coinprice_platform isEqualToString:BTY]) {
            
            NSString *platformStr = coinPrice.coinprice_platform;
            if ([platformStr isEqualToString:@"wwchain"]) {
                tokenSymbols = [NSString stringWithFormat:@"%@.coins",[coinType lowercaseString]];
                realCoinType = BTY;
            }else{
                tokenSymbols = [NSString stringWithFormat:@"%@.%@",platformStr,coinType];
            }
            
        }else if ([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"wwchain"]){
            realCoinType = BTY;
            tokenSymbols = [NSString stringWithFormat:@"%@.%@",@"WW",coinPrice.coinprice_heyueAddress];
        }
    }
    
    if ([coinPrice.coinprice_chain isEqualToString:coinType]) {
        tokenSymbols = BLANK;
    }
    if (([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:ETH])
        || ([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:BTC])) {
        tokenSymbols = BLANK;
        realCoinType = YCC;
    }
    
    if([coinType isEqualToString:BTY] && [coinPrice.coinprice_chain isEqualToString:ETH]){
        tokenSymbols = BLANK;
        realCoinType = BTY;
    }
    
    // ybf的币特殊处理
    if([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"yhchain"]){
        if (coinPrice.treaty == 2)
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbols = [NSString stringWithFormat:@"%@.coins",platformStr];
            realCoinType = BTY;
        }
        else
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbols = [NSString stringWithFormat:@"%@.%@",platformStr,coinType];
            realCoinType = BTY;
        }
    }
    
    
    WalletapiWalletBalance *walletbalance = [[WalletapiWalletBalance alloc] init];
    [walletbalance setCointype:realCoinType];
    [walletbalance setAddress:address];
    [walletbalance setTokenSymbol:tokenSymbols];
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    BlockchainTool *tool = [[BlockchainTool alloc] init];
//    NSString *chain = [tool getBlockChain];
    [util setNode:GoNodeUrl];
    [walletbalance setUtil:util];
    if (util.node.length == 0) {
        return -1;
    }
    balanceData = WalletapiGetbalance(walletbalance, &error);
    
    if (balanceData == nil) {
        return -1;
    }
    
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:balanceData options:NSJSONReadingMutableLeaves error:nil];
  
    if ([jsonDict[@"result"] isEqual:[NSNull null]] || jsonDict[@"result"] == nil) {
        return -1;
    }
    NSDictionary *resultDict = jsonDict[@"result"];
    balance = [resultDict[@"balance"] doubleValue];

    return balance;
}

/**
 * 转币 构造签名前数据
 */
+ (NSData *)goCreateRawTransaction:(NSString *)coinType
                          platForm:(NSString *)platStr
                       fromAddress:(NSString *)from
                         toAddress:(NSString *)to
                            amount:(double)amount
                               fee:(double)fee
                              note:(NSString *)note
                         andTreaty:(NSInteger)treaty
{
    NSData *result;
    NSError *error;
    NSString *tokenSymbol = coinType;
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinType platform:platStr andTreaty:treaty];
    NSString *realCointype = coinPrice.coinprice_chain;
    if([coinPrice.coinprice_platform isEqualToString:@"guodun"])
    {
        tokenSymbol = [NSString stringWithFormat:@"guodun.%@",coinType];
    }
    
    if ([coinPrice.coinprice_chain isEqualToString:coinType]) {
        tokenSymbol = BLANK;
    }
    
    if ([coinPrice.coinprice_platform isEqualToString:@"malltest"])
    {
        tokenSymbol = [NSString stringWithFormat:@"malltest.%@",coinType];
    }
    
    if (coinPrice.treaty == 2)
    {
        tokenSymbol = [NSString stringWithFormat:@"%@.coins",coinPrice.coinprice_platform];
    }
   
    if ([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:ETH]) {
        realCointype = YCC;
        tokenSymbol = BLANK;
       
    }
    if ([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:BTC]) {
        realCointype = YCC;
        tokenSymbol = BLANK;
        
    }
    
    if ([coinType isEqualToString:BTY] && [coinPrice.coinprice_chain isEqualToString:ETH]) {
        tokenSymbol = BLANK;
        realCointype = BTY;
    }
    
    // ybf的币特殊处理
    if([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"yhchain"]){
        if (coinPrice.treaty == 2)
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.coins",platformStr];
            realCointype = BTY;
        }
        else
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.%@",platformStr,coinType];
            realCointype = BTY;
        }
    }
    
    // 平行链2.0
    if ([coinPrice.coinprice_platform isEqualToString:@"wwchain"] && [coinPrice.coinprice_chain isEqualToString:@"ETH"]) {
        realCointype = @"WW";
        tokenSymbol = [NSString stringWithFormat:@"ww.%@",coinPrice.coinprice_heyueAddress];
    }
    
    WalletapiWalletTx *walletTx = [[WalletapiWalletTx alloc] init];
    [walletTx setCointype:realCointype];
    WalletapiTxdata *txData = [[WalletapiTxdata alloc] init];
    [txData setFrom:from];
    [txData setTo:to];
    [txData setAmount:amount];
    [txData setFee:fee];
    [txData setNote:note];
    [walletTx setTx:txData];
    if ([coinPrice.coinprice_chain containsString:@"-"] && coinPrice.treaty == 2) {
        // 联盟链下的coins币
        [walletTx setTokenSymbol:BLANK];
    }
    else
    {
        [walletTx setTokenSymbol:tokenSymbol];
    }
    
    
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    [util setNode:GoNodeUrl];
    [walletTx setUtil:util];
    
    result = WalletapiCreateRawTransaction(walletTx, &error);
    return result;
}

/**
 *转币 签名
 */
+ (NSString *)goWalletSignRawTransaction:(NSString *)coinType
                                platform:(NSString *)platStr
                          unSignedData:(NSData *)data
                               privKey:(NSString *)prive
                               andTreaty:(NSInteger)treaty
{
    NSString *signedData;
    NSError *error;
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinType platform:platStr andTreaty:treaty];
    NSString *realCointype = coinPrice.coinprice_chain == nil ? coinType:coinPrice.coinprice_chain;
    WalletapiSignData *signData = [[WalletapiSignData alloc] init];
    //addressID 2 为eth地址的ycc转账； addressID 0 为BTC地址的ycc转账
    if ([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:ETH]) {
        realCointype = YCC;
        signData.addressID = 2;
    }
    if ([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:BTC]) {
        realCointype = YCC;
        signData.addressID = 0;
    }
    
    if ([coinType isEqualToString:BTY] && [coinPrice.coinprice_chain isEqualToString:ETH]) {
        realCointype = BTY;
        signData.addressID = 2;
    }
    
    // ybf的币特殊处理
    if([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"yhchain"]){
        realCointype = BTY;
        signData.addressID = 2;
    }
    // 平行链2.0
    if([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"wwchain"]){
        realCointype = ETH;
        signData.addressID = 2;
        signData.chainID = 5188;// 5188;
    }
    
    
    signData.cointype = realCointype;
    signData.data = data;
    signData.privKey = prive;
    
    signedData =  WalletapiSignRawTransaction(signData, &error);
    
    return signedData;
}

/**
 * 发送签名数据
 */
+ (NSData *)goWalletSendRawTransaction:(NSString *)coinType //  合约币的情况下，cointype为含有“$”的字符串，需要解析
                              platform:(NSString *)platStr
                                signTx:(NSString *)signTx
                             andTreaty:(NSInteger)treaty
{
    NSError *error;
    NSData *resultData;
    NSString *tokenSymbol = coinType;
    
    if ([coinType containsString:@"$"]) {
        NSArray *arr = [coinType componentsSeparatedByString:@"$"];
        tokenSymbol = arr[1];
        coinType = arr[0];
    }
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinType platform:platStr andTreaty:treaty];
    NSString *realCointype = coinPrice.coinprice_chain == nil ? coinType : coinPrice.coinprice_chain;
    if ([coinPrice.coinprice_chain isEqualToString:coinType]) {
        tokenSymbol = BLANK;
    }
    
    if (([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:ETH])
        || ([coinType isEqualToString:YCC] && [coinPrice.coinprice_chain isEqualToString:BTC])) {
        realCointype = YCC;
        tokenSymbol = BLANK;
    }
    
    if ([coinType isEqualToString:BTY] && [coinPrice.coinprice_chain isEqualToString:ETH]) {
        realCointype = BTY;
        tokenSymbol = BLANK;
    }
    if ([coinType isEqualToString:@"WW"] && ([coinPrice.coinprice_chain isEqualToString:BTY] || [coinPrice.coinprice_chain isEqualToString:@"ETH"])) {
        realCointype = BTY;
        tokenSymbol = [NSString stringWithFormat:@"%@.coins",[coinType lowercaseString]];
    }
    
    // ybf的币特殊处理
    if([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"yhchain"]){
        if (coinPrice.treaty == 2)
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.coins",platformStr];
            realCointype = BTY;
        }
        else
        {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.%@",platformStr,coinType];
            realCointype = BTY;
        }
    }
    
    // ww的币特殊处理
    if([coinPrice.coinprice_chain isEqualToString:ETH] && [coinPrice.coinprice_platform isEqualToString:@"wwchain"]){
       
        tokenSymbol = [NSString stringWithFormat:@"ww.%@",coinPrice.coinprice_heyueAddress];
        realCointype = @"WW";
    }
    
    
    WalletapiWalletSendTx *sendTx = [[WalletapiWalletSendTx alloc] init];
    [sendTx setCointype:realCointype];
    [sendTx setSignedTx:signTx];
    [sendTx setTokenSymbol:tokenSymbol];
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    [util setNode:GoNodeUrl];
    [sendTx setUtil:util];
    
    resultData = WalletapiSendRawTransaction(sendTx, &error);
    return resultData;
}

/**
 * 查询主链下有余额的币种
 */
+ (NSArray *)goWalletapiQueryTokenListByAddr:(NSString *)chain address:(NSString *)address tokensymbol:(NSString *)tokenStr
{
    NSError *error;
    WalletapiWalletTokens *tokens = [[WalletapiWalletTokens alloc] init];
    [tokens setCointype:chain];
    [tokens setAddress:address];
    if (![tokenStr isEqualToString:BLANK]) {
        [tokens setTokenSymbol:tokenStr];
    }
    
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    [util setNode:GoNodeUrl];
    
    NSData *data = WalletapiQueryTokenListByAddr(tokens, util, &error);
    if ([data isEqual:[NSNull null]] || data == nil) {
        return [NSArray new];
    }
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    if ([jsonDict isEqual:[NSNull null]] || jsonDict == nil) {
        return [NSArray new];
    }
    
    NSArray *resultArray = jsonDict[@"result"];
    if ([resultArray isEqual:[NSNull null]] || resultArray == nil) {
        return [NSArray new];
    }
    return resultArray;
}

#pragma mark -- 豆子钱包
/**
 * 豆子钱包构造和签名 并发送
 */
+ (NSString *)goWalletSendRawTransaction_Douzi:(WalletapiGsendTx *)gtx platfrom:(NSString *)platStr coinName:(NSString *)name andTreaty:(NSInteger)treaty
{
    NSError *error;
    WalletapiGsendTxResp *resp = WalletapiCoinsTxGroup(gtx, &error);
    
    NSData *data = [self goWalletSendRawTransaction:[NSString stringWithFormat:@"%@$%@",name,gtx.tokenSymbol] platform:platStr signTx:resp.signedTx andTreaty:treaty];
    
    if (data == nil || [data isEqual:[NSNull null]]) {
        return false;
    }
    NSError *error2;
    NSDictionary *signDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error2];
    if ([signDic[@"result"] isEqual:[NSNull null]] || signDic[@"result"] == nil) {
        return BLANK;
    }else
    {
        return resp.txId;
    }
}

/**
 * 添加币到钱包
 */
+ (BOOL)addCoinIntoWallet:(CoinPrice *)coinprice
{
    NSString *coinStr = coinprice.coinprice_name;
    NSString *platStr = coinprice.coinprice_platform;
    
    NSString *coinChain = coinprice.coinprice_chain;
    NSString *address = BLANK;
    NSString *pubKey = BLANK;
    NSArray *localCoinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    for (LocalCoin *localCoin in localCoinArray) {
        if ([localCoin.coin_chain isEqualToString:coinChain]) {
            address = localCoin.coin_address;
            pubKey = localCoin.coin_pubkey;
            break;
        }
    }
    
    CGFloat balance = [GoFunction goGetBalance:coinStr platform:platStr address:address andTreaty:coinprice.treaty];
    
    LocalCoin *coin = [[LocalCoin alloc] init];
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    coin.coin_walletid = wallet.wallet_id;
    coin.coin_type = coinStr;
    coin.coin_address = address;
    coin.coin_balance = balance == -1 ? 0 : balance;
    coin.coin_pubkey = pubKey;
    coin.coin_show = 1;
    coin.coin_platform = coinprice.coinprice_platform;
    coin.coin_coinid = coinprice.coinprice_id;
    coin.treaty = coinprice.treaty;
    coin.coin_chain = coinprice.coinprice_chain;
    coin.coin_type_nft = 2; // 默认是非NFT币
    if ([[PWDataBaseManager shared] existCoin:coin]) {
       return [[PWDataBaseManager shared] updateCoin:coin];
    }
    return [[PWDataBaseManager shared] addCoin:coin];
}

/**
* 添加主链币到钱包
*/
+ (BOOL)addChainCoinIntoWallet:(CoinPrice *)coinprice passwd:(NSString *)passwd
{
    NSString *coinStr = coinprice.coinprice_name;
    NSString *platStr = coinprice.coinprice_platform;
    NSString *coinChain = coinprice.coinprice_chain;
    NSInteger treaty = coinprice.treaty;
    
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    NSString *remembercode = [GoFunction deckey:wallet.wallet_remembercode password:passwd];
    NSString *mainCoinType = coinStr;
    
    if (coinprice != nil)
    {
        mainCoinType = coinprice.coinprice_chain;
    }
    else
    {
        if ([coinStr isEqualToString:YCC]) {
            mainCoinType = ETH;
        }
        else
        {
            mainCoinType = [GoFunction getChainBasedOnToken:coinStr];
        }
    }
    NSError *error;
    WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2(mainCoinType,remembercode, &error);
    NSData *pubKey = [hdWallet newKeyPub:0 error:&error];
    NSString *address = [GoFunction createAddress:hdWallet coinType:coinStr platform:platStr andTreaty:treaty];
    CGFloat balance = [GoFunction goGetBalance:coinStr platform:platStr address:address andTreaty:treaty];
    LocalCoin *coin = [[LocalCoin alloc] init];
    coin.coin_walletid = wallet.wallet_id;
    coin.coin_type = coinStr;
    coin.coin_address = address;
    coin.coin_balance = balance == -1 ? 0 : balance;
    coin.coin_pubkey = [pubKey hexString];
    coin.coin_show = 1;
    coin.coin_platform = platStr;
    coin.coin_coinid = coinprice.coinprice_id;
    coin.treaty = treaty;
    coin.coin_chain = coinChain;
    coin.coin_type_nft = 2;
    return [[PWDataBaseManager shared] addCoin:coin];
}

/**
* addcoint页面添加主链币到钱包
*/
+ (BOOL)addChainCoinIntoWallet:(LocalCoin *)coin password:(NSString *)passwd
{
    NSString *coinStr = coin.coin_type;
    NSString *platStr = coin.coin_platform;
    NSString *coinChain = coin.coin_chain;
    NSInteger treaty = coin.treaty;
    
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    NSString *remembercode = [GoFunction deckey:wallet.wallet_remembercode password:passwd];
    WalletapiHDWallet *hdWallet = [GoFunction goCreateHDWallet:coinStr  rememberCode:remembercode];
    NSError *error;
    NSData *pubKey = [hdWallet newKeyPub:0 error:&error];
    NSString *address = [GoFunction createAddress:hdWallet coinType:coinStr platform:platStr andTreaty:treaty];
    CGFloat balance = [GoFunction goGetBalance:coinStr platform:platStr address:address andTreaty:treaty];
    LocalCoin *coins = [[LocalCoin alloc] init];
    coins.coin_walletid = wallet.wallet_id;
    coins.coin_type = coinStr;
    coins.coin_address = address;
    coins.coin_balance = balance == -1 ? 0 : balance;
    coins.coin_pubkey = [pubKey hexString];
    coins.coin_show = 1;
    coins.coin_platform = platStr;
    coins.coin_coinid = coin.coin_coinid;
    coins.treaty = treaty;
    coins.coin_chain = coinChain;
    coins.coin_type_nft = 2;

    return [[PWDataBaseManager shared] addCoin:coins];
}


/**
 * 密码一级加密
 */
+ (NSString *)encpassword:(NSString *)password
{
    NSData *data = WalletapiEncPasswd(password);
    return [data hexString];
}

/**
 * 密码二级加密
 */
+ (NSString *)passwordhash:(NSString *)password
{
    NSData *data = WalletapiEncPasswd(password);
    NSString *hashStr = WalletapiPasswdHash(data);
    
    return hashStr;
}

/**
 * 校验密码
 */
+ (BOOL)checkPassword:(NSString *)password hash:(NSString *)passwordHash
{
    BOOL result = WalletapiCheckPasswd(password, passwordHash);
    return result;
}

/**
 * 对助记词进行加密
 */
+ (NSString *)enckey:(NSString *)rememberCode password:(NSString *)password
{
    NSError *error;
    NSData *data = WalletapiEncPasswd(password);

    NSData *rememberCodedata =  WalletapiStringTobyte(rememberCode,&error);
    NSData *resultData = WalletapiSeedEncKey(data, rememberCodedata,&error);
    return [resultData hexString];
}

/**
 * 对助记词进行解密
 */
+ (NSString *)deckey:(NSString *)rememberCode password:(NSString *)password
{
    NSError *error;
    NSData *data = WalletapiEncPasswd(password);
    NSData *rememberCodedata =  WalletapiHexTobyte(rememberCode);
    NSData *resultData = WalletapiSeedDecKey(data, rememberCodedata, &error);
    NSString *resultStr = WalletapiByteTostring(resultData);
    return resultStr;
}

/**
 * BTY 购买 月饼币
 */
+ (BOOL)createTradetx:(NSDictionary *)tradeDic  password:(NSString *)password address:(NSString *)addressStr
{
    NSError *error;
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    NSString *remembercode = [GoFunction deckey:wallet.wallet_remembercode password:password];
    WalletapiHDWallet *hdWallet = [GoFunction goCreateHDWallet:BTY rememberCode:remembercode];
    NSString *priKey = [[hdWallet newKeyPriv:0 error:&error] hexString];
    
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [util setNode:GoNodeUrl];
    
    WalletapiWalletTrade *trade = [[WalletapiWalletTrade alloc] init];
    trade.amount = [tradeDic[@"amount"] doubleValue];
    trade.boardlotCnt = [tradeDic[@"boardlotcnt"] intValue];
    trade.sellId = tradeDic[@"sellId"];
    trade.privkey = priKey;
    trade.util = util;
    
    trade.tokenSymbol = tradeDic[@"tokensymbol"];
    trade.tokenNum = [tradeDic[@"tokenNum"] doubleValue];
    trade.address = addressStr;
    WalletapiGsendTxResp *resp = WalletapiCreateTradeTxGroup(trade, &error);
    NSData *data = [self goWalletSendRawTransaction:BTY platform:BTY signTx:resp.signedTx andTreaty:1];
    NSDictionary *resultDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    
    if (resultDic[@"result"] == nil || [resultDic[@"result"] isEqual:[NSNull null]] || [resultDic[@"result"] isEqualToString:BLANK]) {
        return false;
    }else{
        return true;
    }
}

/**
 * 通过地址获取公钥
 */
+ (NSString *)goGetPubFromAddr:(NSString *)addressStr
{
    NSError *error;
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    [util setNode:GoNodeUrl];
    
    NSString *resultStr = WalletapiGetPubFromAddr(addressStr,util, &error);
   
    return resultStr;
}

/**
 * 月饼提货备注加密
 */
+ (NSString *)goEncrypt:(NSString *)pubKey note:(NSString *)noteStr
{
    NSError *error;
    NSString *resultStr = WalletapiEncrypt(pubKey, noteStr, &error);
    return resultStr;
}

/**
 * 月饼提货备注解密
 */
+ (NSString *)goDecrypt:(NSString *)priKey note:(NSString *)noteStr
{
    NSError *error;
    NSString *resultStr = WalletapiDecrypt(priKey, noteStr, &error);
    return resultStr;
}

/**
 * 获取默认推荐币种
 */
+ (NSArray *)getDefaultRecommendCoin
{
    NSArray *coinArray;
    NSArray *platArray;
    coinArray = @[BTC,ETH,BTY,YCC,@"DCR"];
    platArray = @[BTC,@"ethereum",BTY,@"ethereum",@"dcr"];

    NSMutableArray *finalArray = [NSMutableArray new];
    for (int i = 0; i < coinArray.count; i ++) {
        NSString *coinStr = [coinArray objectAtIndex:i];
        NSString *platStr = [platArray objectAtIndex:i];
        NSDictionary *dic = @{@"name":coinStr,@"platform":platStr};
        [finalArray addObject:dic];
    }
    return finalArray;
}

/**
 * 平行链返回主链
 */
// 此处修改，tokenString增加BTY
+ (NSString *)getChainBasedOnToken:(NSString *)tokenStr
{
    NSString *tokenString = @"BCD,MGT,DDL,YYT,DQZY,FS,SCTC,HTXY,BTY";
    NSArray *tokens = [tokenString componentsSeparatedByString:@","];
    
    if ([tokens containsObject:tokenStr]) {
        return BTY;
    }
    return BLANK;
}

+ (BOOL)muImpAddr:(NSArray *)addArray
{
    return YES;
    WalletapiWalletMulAddr *muladdr = [[WalletapiWalletMulAddr alloc] init];
    muladdr.mulAddr = [self objArrayToJSON:addArray];
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSString *registrationID = [userDefault objectForKey:@"registrationID"];
    
    
    muladdr.appid = registrationID;
    muladdr.appSymbol = @"p";
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [util setNode:GoNodeUrl];//https://183.129.226.77:8083
    [muladdr setUtil:util];
    if (WalletapiImortMulAddress(muladdr)) {
        NSLog(@"success add");
    }else{
        NSLog(@"failure add");
    }
    return WalletapiImortMulAddress(muladdr);
    
   
}


+ (BOOL)muDelAddr:(NSArray *)addArray
{
    return YES;
    WalletapiWalletMulAddr *muladdr = [[WalletapiWalletMulAddr alloc] init];
    muladdr.mulAddr = [self objArrayToJSON:addArray];
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSString *registrationID = [userDefault objectForKey:@"registrationID"];
    
    muladdr.appid = registrationID;
    muladdr.appSymbol = @"p";
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [util setNode:GoNodeUrl];
    [muladdr setUtil:util];
    if (WalletapiDeleteMulAddress(muladdr)) {
        NSLog(@"success del");
    }else{
        NSLog(@"failure del");
    }
    return WalletapiDeleteMulAddress(muladdr);
}

+ (NSString *)objArrayToJSON:(NSArray *)array {

    NSString *jsonStr = @"[";
    for (NSInteger i = 0; i < array.count; ++i) {
        if (i != 0) {
            jsonStr = [jsonStr stringByAppendingString:@","];
        }
        NSDictionary *dict = array[i];
        jsonStr = [jsonStr stringByAppendingString:dict.yy_modelToJSONString];
    }
    jsonStr = [jsonStr stringByAppendingString:@"]"];

    return jsonStr;

}

@end
