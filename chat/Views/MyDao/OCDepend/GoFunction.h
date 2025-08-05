//
//  GoFunction.h
//  PWallet
//
//  Created by 宋刚 on 2018/6/19.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Walletapi/Walletapi.h>
#import "CoinPrice.h"
#import "LocalCoin.h"
@interface GoFunction : NSObject


/***
 获取go包session
 */
+ (NSString *)getSeesionIdWithAppSymbol:(NSString *)appSymbol AppKey:(NSString *)appKey;

/**
 设置session
 */
+ (void)setSessionId;

/**
 * 创建WalletHDWallet
 */
+ (WalletapiHDWallet *)goCreateHDWallet:(NSString *)coinType rememberCode:(NSString *)mnemonic;
/**
 * 创建地址
 */
+ (NSString *)createAddress:(WalletapiHDWallet *)hdWallet coinType:(NSString *)coinType platform:(NSString *)platStr andTreaty:(NSInteger)treaty;
/**
 * 根据交易ID查询交易详情
 */
+ (NSDictionary*)queryTransactionByTxid:(NSString *)coinType platform:(NSString *)platStr Txid:(NSString *)txid andTreaty:(NSInteger)treaty;
/**
 * 查询交易记录
 */
+ (NSArray *)queryTransactionsByaddress:(NSString *)coinType platform:(NSString *)platStr address:(NSString *)coinAddress page:(NSInteger)page andTreaty:(NSInteger)treaty type:(NSInteger)type;
/**
 * 查询余额
 */
+ (CGFloat )goGetBalance:(NSString *)coinType platform:(NSString *)platStr address:(NSString *)address andTreaty:(NSInteger)treaty;
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
                         andTreaty:(NSInteger)treaty;
/**
 *转币 签名
 */
+ (NSString *)goWalletSignRawTransaction:(NSString *)coinType
                                platform:(NSString *)platStr
                            unSignedData:(NSData *)data
                                 privKey:(NSString *)prive
                               andTreaty:(NSInteger)treaty;;
/**
 * 发送签名数据
 */
+ (NSData *)goWalletSendRawTransaction:(NSString *)coinType
                              platform:(NSString *)platStr
                                signTx:(NSString *)signTx
                             andTreaty:(NSInteger)treaty;;

/**
 * 豆子钱包构造和签名 并发送
 */
+ (NSString *)goWalletSendRawTransaction_Douzi:(WalletapiGsendTx *)gtx platfrom:(NSString *)platStr coinName:(NSString *)name andTreaty:(NSInteger)treaty;

/**
 * 添加币到钱包
 */
+ (BOOL)addCoinIntoWallet:(CoinPrice *)coinprice;
/**
* 搜索页面添加主链币到钱包
*/
+ (BOOL)addChainCoinIntoWallet:(CoinPrice *)coinprice passwd:(NSString *)passwd;
/**
* addcoin页面添加主链币到钱包
*/
+ (BOOL)addChainCoinIntoWallet:(LocalCoin *)coin password:(NSString *)passwd;
/**
 * 密码一级加密
 */
+ (NSString *)encpassword:(NSString *)password;
/**
 * 密码二级加密
 */
+ (NSString *)passwordhash:(NSString *)password;
/**
 * 校验密码
 */
+ (BOOL)checkPassword:(NSString *)password hash:(NSString *)passwordHash;
/**
 * 对助记词进行加密
 */
+ (NSString *)enckey:(NSString *)rememberCode password:(NSString *)password;
/**
 * 对助记词进行解密
 */
+ (NSString *)deckey:(NSString *)rememberCode password:(NSString *)password;
/**
 * BTY 购买 月饼币
 */
+ (BOOL)createTradetx:(NSDictionary *)tradeDic  password:(NSString *)password address:(NSString *)addressStr;
/**
 * 月饼提货备注加密
 */
+ (NSString *)goEncrypt:(NSString *)pubKey note:(NSString *)noteStr;
/**
 * 通过地址获取公钥
 */
+ (NSString *)goGetPubFromAddr:(NSString *)addressStr;
/**
 * 月饼提货备注解密
 */
+ (NSString *)goDecrypt:(NSString *)priKey note:(NSString *)noteStr;
/**
 * 获取默认推荐币种
 */
+ (NSArray *)getDefaultRecommendCoin;
/**
 * 查询主链下有余额的币种
 */
+ (NSArray *)goWalletapiQueryTokenListByAddr:(NSString *)chain address:(NSString *)address tokensymbol:(NSString *)tokenStr;
/**
 * 平行链返回主链
 */
+ (NSString *)getChainBasedOnToken:(NSString *)tokenStr;

/**
 *  批量导入地址
 */
+ (BOOL)muImpAddr:(NSArray *)addArray;
/**
 *  批量删除地址
 */
+ (BOOL)muDelAddr:(NSArray *)addArray;

@end
