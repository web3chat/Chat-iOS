//
//  PWDataBaseManager.h
//  JTB
//
//  Created by 吴文拼 on 2018/1/2.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"
#import "LocalWallet.h"
#import "LocalCoin.h"
#import "CoinPrice.h"
#import <YYModel/YYModel.h>
@interface PWDataBaseManager : NSObject

+ (void)lauchDataBase;

+ (instancetype)shared;

//查询方法
- (NSArray *)executeQuery:(NSString *)sql withParameterDictionary:(NSDictionary *)params;
//修改方法
- (BOOL)excuteUpdate:(NSString *)sql withParameterDictionary:(NSDictionary *)params;

#pragma mark - 钱包Wallet
/**
 * 添加Wallet
 */
- (BOOL)addWallet:(LocalWallet *)wallet;


/**
 * 添加wallet之前 检查是否存在
 */
- (BOOL)checkWallectIsExistence:(LocalWallet *)wallet;

/**
 * 查找钱包名称是否存在
 */
- (BOOL)checkExistWalletName:(NSString *)name;
/**
 * 查找助记词是否存在
 */
- (BOOL)checkExistRememberCode:(NSString *)code;
/**
 * 更新Wallet
 */
- (BOOL)updateWallet:(LocalWallet *)wallet;
/**
 * 删除Wallet
 */
- (BOOL)deleteWallet:(LocalWallet *)wallet;
/**
 * 查询Wallet的数量
 */
- (int)queryWalletCount;
/**
 * 查询wallet 根据wallet_id
 */
- (LocalWallet *)queryWallet:(NSInteger)walletId;
/**
 * 查询Wallet_id 根据wallet isselected
 */
- (NSInteger )queryWalletId;
/**
 * 查询最大的Wallet_id
 */
- (NSInteger )queryMaxWalletId;
/**
 * 查询wallet 根据wallet isselected
 */
- (LocalWallet *)queryWalletIsSelected;
/**
 *  查询all Wallet
 */
- (NSArray *)queryAllWallets;
/**
 * 计算钱包总额：传入LocalWallet ,如果nil 则是被选择的钱包
 */
- (double)caculateTotalAssets:(LocalWallet *)wallet;
- (double)caculateTotalAssetsDollar:(LocalWallet *)wallet;
#pragma mark - 货币Coin
/**
 * 某个钱包下，币是否纯在
 */
- (BOOL)existCoin:(LocalCoin *)coin;
/**
 * 添加Coin
 */
- (BOOL)addCoin:(LocalCoin *)coin;
/**
 * 更新coin_platform , coin_coinid
 */
- (BOOL)upadateCoin:(NSInteger)coinId platform:(NSString *)platStr cointype:(NSString *)coinName;

/**
 * 只更新 coin_platform
 */
- (BOOL)upadateCoin:(NSInteger)coinId platform:(NSString *)platStr;

/**
 * 更新Coin
 */
- (BOOL)updateCoin:(LocalCoin *)coin;

/**
 * 根据钱包ID 删除对应的币
 */
- (BOOL) deleteCoin:(LocalWallet *)wallet;

/**
 * 根据coin的名字s和平台删除对应的coin
 */
- (BOOL)deleteCoinWithplatform:(NSString *)platform andCoinType:(NSString *)coinType;

/**
 * 根据钱包ID查询货币数组
 */
- (NSArray *)queryCoinArrayBasedOnSelectedWalletID;

/**
 * 根据传入的钱包ID查询货币数组
 */
- (NSArray *)queryAllCoinArrayBasedOnWalletID:(NSInteger )walletId;


/**
 * 根据钱包ID查询货币数组 coin_show = 1
 */
- (NSArray *)queryCoinArrayBasedOnWalletIDAndShow;
/**
 * 根据钱包ID查询nft数组 coin_show = 1
 */
- (NSArray *)queryNFTArrayBasedOnWalletIDAndShow;
/**
 * 根据被选择钱包查询货币数组
 */
- (NSArray *)queryCoinArrayBasedOnWallet:(LocalWallet *)wallet;
/**
 * 根据主链查询地址
 */
- (NSString *)queryAddressBasedOnChain:(NSString *)chainStr;
/**
 * 根据主链查询LocalCoin全部信息
 */
- (LocalCoin *)queryCoinBasedOnChain:(NSString *)chainStr;

/**
 * 根据coinid查询LocalCoin全部信息
 */
- (LocalCoin *)queryCoinBasedOnCoinId:(NSInteger)coinid;


#pragma mark - 货币CoinPrice
/**
 * 添加CoinPrice
 */
- (BOOL)addCoinPrice:(CoinPrice *)coinPrice;

/**
 *  根据coinid查询CoinPrice
 */
- (CoinPrice *)queryCoinPriceBaseOn:(NSInteger )coinId;

/**
 * 根据货币名字查询CoinPrice
 */
- (CoinPrice *)queryCoinPriceBasedOn:(NSString *)coinName platform:(NSString *)coinPlat andTreaty:(NSInteger)treaty;

#pragma mark - 游戏Game
/**
 * 添加GameInfo
 */
//- (BOOL)addGame:(GameCreatedInfo *)gameInfo;
/**
 * 根据game_id查询出拳信息
 */
//- (GameCreatedInfo *)queryGameInfoBasesOnGameId:(NSString *)gameId;
@end
