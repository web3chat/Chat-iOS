//
//  PWDataBaseManager.h
//  JTB
//
//  Created by fzm on 2018/1/2.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"
#import "LocalWallet.h"
#import "LocalCoin.h"
#import "CoinPrice.h"
#import "LoginUserInfo.h"
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
 * 根据加密后的助记词查询钱包（与 wallet 表 wallet_remembercode 一致）
 * ⚠️ 助记词加密是 AES-GCM（每次密文都不同），同一助记词重新加密后**查不到**旧钱包，
 *    需要按地址去重时请用 queryWalletByCoinAddress:
 */
- (LocalWallet *)queryWalletByRememberCode:(NSString *)encryptedRememberCode;
/**
 * 根据币地址反查所属钱包（取 coin 表里第一行匹配的 coin_walletid）
 * ETH/BNB 这类 0x 地址按不区分大小写匹配，BTY 等 Base58 地址按原样精确匹配。
 */
- (LocalWallet *)queryWalletByCoinAddress:(NSString *)address;
/**
 * 取消其他钱包选中，将指定钱包设为当前选中
 */
- (BOOL)selectWalletAsCurrent:(LocalWallet *)wallet;
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
 * 根据coin的合约地址删除对应的币
 */
- (BOOL)deleteCoinWithContractAddr:(NSString *)addr;

/**
 * 根据主键 coin_id 精确删除一条币记录
 * @return YES = 确实删掉了（受影响行数 > 0）；NO = 没有删到任何行（币已不存在 / id 无效）
 * ⚠️ 与 `deleteCoinWithContractAddr:` 不同：这里用主键匹配，且**返回值是真实的**
 *   （旧的按合约地址删，地址字符串一旦对不上就是「0 行删除但返回成功」⇒ 表现为删了还在）
 */
- (BOOL)deleteCoinWithId:(NSInteger)coinId;

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

#pragma mark - 用户信息UserInfo
/**
 * 检查用户信息是否存在
 */
- (BOOL)checkuserinfo:(LoginUserInfo *)userInfo;

/**
 * 添加用户信息
 */
- (BOOL)addUserInfo:(LoginUserInfo *)userInfo;

/**
 * Swift调用的新增用户信息方法
 */
- (BOOL)addUserInfoWithPhone:(NSString *)phone
                     address:(NSString *)address
                   address0x:(NSString *)address0x
                   avatarurl:(NSString *)avatarurl
                        name:(NSString *)name
       encryptedRemembercode:(NSString *)encryptedRemembercode
           encryptedPassword:(NSString *)encryptedPassword;

/**
 * 更新用户信息
 */
- (BOOL)updateUserInfo:(LoginUserInfo *)userInfo;

/**
 * 更新用户密聊密码
 */
- (BOOL)updateUserInfoPasswordWithAddress:(NSString *)address
                        encryptedPassword:(NSString *)encryptedPassword;

/**
 * 更新用户头像
 */
- (BOOL)updateUserInfoAvatarWithAddress:(NSString *)address
                              avatarurl:(NSString *)avatarurl;

/**
 * 更新用户名
 */
- (BOOL)updateUserInfoNameWithAddress:(NSString *)address
                                 name:(NSString *)name;

/**
 * 根据address查询用户信息
 */
- (LoginUserInfo *)queryUserInfoWithAddress:(NSString *)address;

/**
 * 查询全部用户信息
 */
- (NSArray<LoginUserInfo *> *)queryAllUserInfo;

/**
 * Swift调用的用户信息列表查询方法（字典数组）
 */
- (NSArray<NSDictionary *> *)queryAllUserInfoData;

/**
 * 删除用户信息
 */
- (BOOL)deleteUserInfoWithAddress:(NSString *)address;

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
