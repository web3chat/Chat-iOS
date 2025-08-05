//
//  PWDataBaseManager.m
//  JTB
//
//  Created by 吴文拼 on 2018/1/2.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

#import "PWDataBaseManager.h"
#import "PWDataBaseSQLCollection.h"

//数据库存放路径
#define JTBDataBasePath [[(NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)) lastObject]stringByAppendingPathComponent:@"jtb_db"]

@interface PWDataBaseManager()

@property (nonatomic, retain) FMDatabaseQueue *dbQueue;


@end

@implementation PWDataBaseManager

+ (void)lauchDataBase
{
    [self shared];
}

+ (instancetype)shared
{
    static PWDataBaseManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PWDataBaseManager alloc] init];
        [instance createTable:SQL_CREATE_WALLET];  //创建钱包表
        [instance createTable:SQL_CREATE_COIN];    //创建货币表
        [instance createTable:SQL_CREATE_COINPRICE]; //创建货币行情表

        
    });
    
    return instance;
}

- (FMDatabaseQueue *)dbQueue{
    if (!_dbQueue) {
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:@"chatwallets.sqlite"];
   
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:filePath];
    }
    return _dbQueue;
}

/**
 * 创建表
 */
-(void)createTable:(NSString *)sqlStr{
    //SQL_CREATE_FRIEND_LIST  建表语句
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        BOOL friend_list = [db executeUpdate:sqlStr];
        if (!friend_list) {
            NSLog(@"error when creating db friend_list");
        } else {
            NSLog(@"succ to creating db friend_list");
        }
    }];
}

- (NSArray *)executeQuery:(NSString *)sql withParameterDictionary:(NSDictionary *)params
{
    NSMutableArray *queryResult = [NSMutableArray array];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *s = [db executeQuery:sql withParameterDictionary:params];
        //可以直接根据模型 封装为模型
        while ([s next]) {
            if ([s resultDictionary]) {
                [queryResult addObject:[s resultDictionary]];
            }
        }
    }];
    return queryResult;
}

-(BOOL)excuteUpdate:(NSString *)sql withParameterDictionary:(NSDictionary *)params
{
    __block BOOL updateSuccess = NO;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        updateSuccess = [db executeUpdate:sql withParameterDictionary:params];
        if (!updateSuccess) {
            
        } else {
            
        }
    }];
    return updateSuccess;
}

#pragma mark - 钱包Wallet
/**
 * 查找钱包名称是否存在
 */
- (BOOL)checkExistWalletName:(NSString *)name
{
    __block int count = 0;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT COUNT(*) AS count FROM wallet WHERE wallet_name = ?",name];
        
        while ([res next]) {
            count = [res intForColumn:@"count"];
        }
    }];
    if (count == 0) {
        return NO;
    }else{
        return YES;
    }
}

/**
 * 查找助记词是否存在
 */
- (BOOL)checkExistRememberCode:(NSString *)code
{
    __block int count = 0;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT COUNT(*) AS count FROM wallet WHERE wallet_remembercode = ?",code];
        
        while ([res next]) {
            count = [res intForColumn:@"count"];
        }
    }];
    if (count == 0) {
        return NO;
    }else{
        return YES;
    }
}

/**
 * 添加Wallet
 */
- (BOOL)addWallet:(LocalWallet *)wallet
{
    if(wallet == nil)
    {
        return NO;
    }
    __block BOOL insertSuccess = NO;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSNumber *maxID = @(0);
        
        FMResultSet *res = [db executeQuery:@"SELECT MAX(wallet_id) AS maxid FROM wallet"];
        //获取数据库中最大的ID
        while ([res next]) {
                maxID = @([[res stringForColumn:@"maxid"] integerValue] ) ;
        }
        maxID = @([maxID integerValue] + 1);
        
        insertSuccess = [db executeUpdate:@"INSERT INTO wallet(wallet_id,wallet_name,wallet_remembercode,wallet_password,wallet_totalassets,wallet_isselected,wallet_issmall,wallet_isbackup,wallet_issetpwd,wallet_isEscrow,wallet_totalassetsDollar)VALUES(?,?,?,?,?,?,?,?,?,?,?)",maxID,wallet.wallet_name,wallet.wallet_remembercode,wallet.wallet_password,@(wallet.wallet_totalassets),@(wallet.wallet_isselected),@(wallet.wallet_issmall),@(wallet.wallet_isbackup),@(wallet.wallet_issetpwd),@(wallet.wallet_isEscrow),@(wallet.wallet_totalassetsDollar)];
    }];
    return insertSuccess;
}

/**
 * 添加wallet之前 检查是否存在
 */
- (BOOL)checkWallectIsExistence:(LocalWallet *)wallet{
    __block int count = 0;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT COUNT(*) AS count FROM wallet WHERE wallet_remembercode = ?",wallet.wallet_remembercode];
        while ([res next]) {
            count = [res intForColumn:@"count"];
        }
    }];
    if (count == 0) {
        return NO;
    }else{
        return YES;
    }
}

/**
 * 更新Wallet
 */
- (BOOL)updateWallet:(LocalWallet *)wallet
{
    if(wallet == nil || [wallet.wallet_remembercode isEqualToString:@""])
    {
        return false;
    }
    
    __block BOOL updateSuccess = NO;
    
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            updateSuccess = [db executeUpdate:@"UPDATE 'wallet' SET wallet_name = ? , wallet_password = ? ,wallet_remembercode = ?,wallet_totalassets = ?,wallet_isselected = ?,wallet_isbackup = ? ,wallet_issetpwd = ? ,wallet_isEscrow = ?,wallet_totalassetsDollar = ? WHERE wallet_id = ?",wallet.wallet_name,wallet.wallet_password,wallet.wallet_remembercode,@(wallet.wallet_totalassets),@(wallet.wallet_isselected),@(wallet.wallet_isbackup),@(wallet.wallet_issetpwd),@(wallet.wallet_isEscrow),@(wallet.wallet_totalassetsDollar),@(wallet.wallet_id)];
            
            if (updateSuccess) {
            }else{
                NSLog(@"error");
            }
        }];
    return updateSuccess;
}

/**
 * 删除Wallet
 */
- (BOOL)deleteWallet:(LocalWallet *)wallet
{
    if(wallet == nil)
    {
        return NO;
    }
    
    __block BOOL updateSuccess = NO;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        updateSuccess = [db executeUpdate:@"DELETE  FROM wallet WHERE wallet_id = ? ",@(wallet.wallet_id)];

        if (updateSuccess) {
            NSLog(@"success");
        }else{
            NSLog(@"error");
        }
    }];
    return updateSuccess;
}

/**
 * 查询Wallet的数量
 */
- (int)queryWalletCount
{
    __block int count = 0;
    
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT COUNT(*) AS count FROM wallet"];
    
        while ([res next]) {
           count = [res intForColumn:@"count"];
        }
    }];
    
    return count;
}

/**
 * 查询Wallet_id 根据wallet isselected
 */
- (NSInteger )queryWalletId
{
    __block NSInteger walletId = 0;
    
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM wallet WHERE wallet_isselected = 1"];
        
        while ([res next]) {
            walletId = [res intForColumn:@"wallet_id"];
        }
    }];
    return walletId;
}

/**
 * 查询最大的Wallet_id
 */
- (NSInteger )queryMaxWalletId
{
    __block NSNumber *maxID = @(0);
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
    
        FMResultSet *res = [db executeQuery:@"SELECT MAX(wallet_id) AS maxid FROM wallet"];
        //获取数据库中最大的ID
        while ([res next]) {
            maxID = @([[res stringForColumn:@"maxid"] integerValue] ) ;
        }
    }];
    return [maxID integerValue];
}

/**
 * 查询wallet 根据wallet_id
 */
- (LocalWallet *)queryWallet:(NSInteger)walletId
{
    __block LocalWallet *wallet;
    
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM wallet WHERE wallet_id = ?",@(walletId)];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            wallet = [LocalWallet yy_modelWithDictionary:dic];
        }
    }];
    return wallet;
}

/**
 * 查询wallet 根据wallet isselected
 */
- (LocalWallet *)queryWalletIsSelected
{
    __block LocalWallet *wallet;
    
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM wallet WHERE wallet_isselected = 1"];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            wallet = [LocalWallet yy_modelWithDictionary:dic];
        }
    }];
    return wallet;
}

/**
 *  查询all Wallet
 */
- (NSArray *)queryAllWallets
{
    __block NSMutableArray *walletsArray = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM wallet where wallet_isselected > -1"];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            LocalWallet *wallet = [LocalWallet yy_modelWithDictionary:dic];
            [walletsArray addObject:wallet];
        }
    }];
    return walletsArray;
}

/**
 * 计算钱包总额：传入LocalWallet ,如果nil 则是被选择的钱包
 */
- (double)caculateTotalAssets:(LocalWallet *)wallet{
    double totalAssets = 0;
    NSArray *coinArray = [self queryCoinArrayBasedOnWallet:wallet];
    
    for (int i = 0; i < coinArray.count; i ++) {
        LocalCoin *coin = [coinArray objectAtIndex:i];
        double balance = 0.00;
        double price = 0.00;
        if (coin.coin_show != 0) {
            balance = coin.coin_balance;
            CoinPrice *coinPrice = [self queryCoinPriceBasedOn:coin.coin_type platform:coin.coin_platform andTreaty:coin.treaty];
            price =  coinPrice.coinprice_country_rate;
        }
        totalAssets = totalAssets + price * balance;
    }
    return totalAssets;
}
/**
 * 计算钱包总额(美元)：传入LocalWallet ,如果nil 则是被选择的钱包
 */
- (double)caculateTotalAssetsDollar:(LocalWallet *)wallet{
    double totalAssets = 0;
    NSArray *coinArray = [self queryCoinArrayBasedOnWallet:wallet];
    
    for (int i = 0; i < coinArray.count; i ++) {
        LocalCoin *coin = [coinArray objectAtIndex:i];
        double balance = coin.coin_balance;
        CoinPrice *coinPrice = [self queryCoinPriceBasedOn:coin.coin_type platform:coin.coin_platform andTreaty:coin.treaty];
        double price = coinPrice.coinprice_dollarPrice;
        totalAssets = totalAssets + balance * price;
    }

    return totalAssets;
}


#pragma mark - 货币Coin
/**
 * 查询是否存在Coin
 */
- (BOOL)existCoin:(LocalCoin *)coin
{
    __block BOOL result = NO;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res;
        res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ? and coin_type = ? and coin_platform = ? and treaty = ? and coin_type_nft = ?",@(coin.coin_walletid),coin.coin_type,coin.coin_platform,@(coin.treaty),@(coin.coin_type_nft)];
        
        while ([res next]) {
            result = YES;
        }
    }];
    return result;
}

- (BOOL)exsitContractCoin:(LocalCoin *)coin
{
    __block BOOL result = NO;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res;
        res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ? and coin_type = ? and coin_chain = ? and coin_pubkey = ? and coin_type_nft = ?",@(coin.coin_walletid),coin.coin_type,coin.coin_chain,coin.coin_pubkey,@(coin.coin_type_nft)];
        
        while ([res next]) {
            result = YES;
        }
    }];
    
    
    return result;
}

/**
 * 添加Coin
 */
- (BOOL)addCoin:(LocalCoin *)coin
{
    if(coin == nil)
    {
        return NO;
    }
    
    __block BOOL insertSuccess = NO;
    
//    if ([self existCoin:coin]) {
//        
//        return YES;
//    }
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            NSNumber *maxID = @(0);
            
            FMResultSet *res = [db executeQuery:@"SELECT * FROM coin"];
            //获取数据库中最大的ID
            while ([res next]) {
                if ([maxID integerValue] < [[res stringForColumn:@"coin_id"] integerValue]) {
                    maxID = @([[res stringForColumn:@"coin_id"] integerValue] ) ;
                }
            }
            maxID = @([maxID integerValue] + 1);
            
            insertSuccess = [db executeUpdate:@"INSERT INTO coin(coin_id,coin_walletid,coin_type,coin_balance,coin_pubkey,coin_show,coin_address,coin_platform,coin_coinid,treaty,coin_chain,icon,coin_type_nft)VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",maxID,@(coin.coin_walletid),coin.coin_type,@(coin.coin_balance),coin.coin_pubkey,@(coin.coin_show),coin.coin_address,coin.coin_platform,@(coin.coin_coinid),@(coin.treaty),coin.coin_chain,coin.icon,@(coin.coin_type_nft)];
            if(insertSuccess)
            {
                NSLog(@"添加币成功");
            }else
            {
                NSLog(@"添加币失败");
            }
        }];
    });
    
    return insertSuccess;
}

/**
 * 根据coin_platform 和cointype更新coin_coinid
 */
- (BOOL)upadateCoin:(NSInteger)coinId platform:(NSString *)platStr cointype:(NSString *)coinName
{
    __block BOOL updateSuccess = NO;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       
        updateSuccess = [db executeUpdate:@"UPDATE 'coin' SET coin_coinid = ? WHERE coin_type = ? and coin_platform = ?",@(coinId),coinName,platStr];
        
        if (updateSuccess) {
            NSLog(@"update success");
        }else{
            NSLog(@"update error");
        }
    }];
    return updateSuccess;
}

/**
 * 只更新 coin_platform
 *
 */
- (BOOL)upadateCoin:(NSInteger)coinId platform:(NSString *)platStr
{
    __block BOOL updateSuccess = NO;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        updateSuccess = [db executeUpdate:@"UPDATE 'coin' SET coin_platform = ? WHERE coin_id = ?",platStr,@(coinId)];
        if (updateSuccess) {
          
        }else{
     
        }
    }];
    return updateSuccess;
}

/**
 * 更新Coin
 */
- (BOOL)updateCoin:(LocalCoin *)coin
{
    if(coin == nil)
    {
        return NO;
    }
    
    __block BOOL updateSuccess = NO;
    
    if(![self existCoin:coin])
    {
        [self addCoin:coin];
        return YES;
        
    }else{
        
        [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            if (coin.coin_address)
            {
                if (coin.coin_id == 0)
                {
                    updateSuccess = [db executeUpdate:@"UPDATE 'coin' SET coin_balance = ?,coin_show = ? ,coin_platform = ?,treaty = ?,coin_address = ? WHERE coin_walletid = ? and coin_coinid = ?",@(coin.coin_balance),@(coin.coin_show),coin.coin_platform,@(coin.treaty),coin.coin_address,@(coin.coin_walletid),@(coin.coin_coinid)];
                }
                else
                {
                    updateSuccess = [db executeUpdate:@"UPDATE 'coin' SET coin_balance = ?,coin_show = ? ,coin_platform = ?,treaty = ?,coin_address = ? WHERE coin_id = ?",@(coin.coin_balance),@(coin.coin_show),coin.coin_platform,@(coin.treaty),coin.coin_address,@(coin.coin_id)];
                }
                
            }
            else
            {
                if (coin.coin_id == 0)
                {
                    updateSuccess = [db executeUpdate:@"UPDATE 'coin' SET coin_balance = ?,coin_show = ? ,coin_platform = ?,treaty = ? WHERE coin_walletid = ? and coin_coinid = ?",@(coin.coin_balance),@(coin.coin_show),coin.coin_platform,@(coin.treaty),@(coin.coin_walletid),@(coin.coin_coinid)];
                }
                else
                {
                    updateSuccess = [db executeUpdate:@"UPDATE 'coin' SET coin_balance = ?,coin_show = ? ,coin_platform = ?,treaty = ? WHERE coin_id = ?",@(coin.coin_balance),@(coin.coin_show),coin.coin_platform,@(coin.treaty),@(coin.coin_id)];
                }
                
            }
            
            if (updateSuccess)
            {
            }
            else{
            }
        }];
    }
    return updateSuccess;
}

/**
 * 根据钱包ID 删除对应的币
 */
- (BOOL)deleteCoin:(LocalWallet *)wallet
{
    if(wallet == nil)
    {
        return NO;
    }
    
    __block BOOL updateSuccess = NO;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        updateSuccess = [db executeUpdate:@"DELETE FROM coin WHERE coin_walletid = ? ",@(wallet.wallet_id)];
        
        if (updateSuccess) {
            NSLog(@"success");
        }else{
            NSLog(@"error");
        }
    }];
    return updateSuccess;
}

/**
 * 根据coin的名字和平台删除对应的币
 */
- (BOOL)deleteCoinWithplatform:(NSString *)platform andCoinType:(NSString *)coinType
{
    if ([platform isEqualToString:@""] || [coinType isEqualToString:@""])
    {
        return NO;
    }
    
    __block BOOL deleteSuccess = NO;
    
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        deleteSuccess = [db executeUpdate:@"DELETE FROM coin WHERE coin_platform = ? and coin_type = ?",platform,coinType];
        if (deleteSuccess)
        {
            NSLog(@"delete success");
        }
        else
        {
            NSLog(@"");
        }
    }];
    
    return deleteSuccess;
    
}

/**
 * 根据被选择钱包ID查询货币数组
 */
- (NSArray *)queryCoinArrayBasedOnWalletID
{
    NSInteger walletId = [self queryWalletId];
    __block NSMutableArray *coinArray = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ?",@(walletId)];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            LocalCoin *coin = [LocalCoin yy_modelWithDictionary:dic];
            [coinArray addObject:coin];
        }
    }];
    return [self coinArray:coinArray];
}

/**
 * 根据被选择钱包ID查询货币数组
 */
- (NSArray *)queryCoinArrayBasedOnSelectedWalletID
{
    NSInteger walletId = [self queryWalletId];
    __block NSMutableArray *coinArray = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ?",@(walletId)];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            LocalCoin *coin = [LocalCoin yy_modelWithDictionary:dic];
            if (coin.coin_type_nft == 2 || coin.coin_type_nft == 10) {
                [coinArray addObject:coin];
            }
          
        }
    }];
    return [self coinArray:coinArray];
}



/**
 * 根据传入的钱包ID查询货币数组
 */
- (NSArray *)queryAllCoinArrayBasedOnWalletID:(NSInteger)walletId{
    NSInteger walletId1 = walletId;
    __block NSMutableArray *coinArray = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ?",@(walletId1)];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            LocalCoin *coin = [LocalCoin yy_modelWithDictionary:dic];
           [coinArray addObject:coin];
        }
    }];
    return [self coinArray:coinArray];
}


/**
 * 根据被选择钱包查询货币数组
 */
- (NSArray *)queryCoinArrayBasedOnWallet:(LocalWallet *)wallet
{
    NSInteger walletId = wallet.wallet_id;
    __block NSMutableArray *coinArray = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ?",@(walletId)];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            LocalCoin *coin = [LocalCoin yy_modelWithDictionary:dic];
            [coinArray addObject:coin];
        }
    }];
    return [self coinArray:coinArray];
}

/**
 * 根据主链查询地址
 */
- (NSString *)queryAddressBasedOnChain:(NSString *)chainStr
{
    NSArray *coinArray = [self queryCoinArrayBasedOnSelectedWalletID];
    for (int i = 0; i < coinArray.count; i ++) {
        LocalCoin *coin = [coinArray objectAtIndex:i];
        if ([coin.coin_type isEqualToString:chainStr]) {
            return coin.coin_address;
        }
    }
    return @"";
}

/**
 * 根据主链查询LocalCoin全部信息
 */
- (LocalCoin *)queryCoinBasedOnChain:(NSString *)chainStr
{
    NSArray *coinArray = [self queryCoinArrayBasedOnSelectedWalletID];
    for (int i = 0; i < coinArray.count; i ++) {
        LocalCoin *coin = [coinArray objectAtIndex:i];
        if ([coin.coin_type isEqualToString:chainStr]) {
            return coin;
        }
    }
    return nil;
}

/**
 * 根据coinid查询LocalCoin全部信息
 */
- (LocalCoin *)queryCoinBasedOnCoinId:(NSInteger)coinid
{
   NSArray *coinArray = [self queryCoinArrayBasedOnSelectedWalletID];
    for (int i = 0; i < coinArray.count; i ++) {
        LocalCoin *coin = [coinArray objectAtIndex:i];
        if (coin.coin_coinid == coinid) {
            return coin;
        }
    }
    return nil;
}

/**
 * 根据钱包ID查询货币数组 coin_show = 1
 */
- (NSArray *)queryCoinArrayBasedOnWalletIDAndShow
{
    NSInteger walletId = [self queryWalletId];
    __block NSMutableArray *coinArray = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ? and coin_show = 1",@(walletId)];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            LocalCoin *coin = [LocalCoin yy_modelWithDictionary:dic];
            if (coin.coin_type_nft == 2 || coin.coin_type_nft == 10) {
                [coinArray addObject:coin];
            }
        }
    }];
    return [self coinArray:coinArray];
}

/**
 * 根据钱包ID查询NFT数组 coin_show = 1
 */
- (NSArray *)queryNFTArrayBasedOnWalletIDAndShow
{
    NSInteger walletId = [self queryWalletId];
    __block NSMutableArray *coinArray = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM coin WHERE coin_walletid = ? and coin_show = 1",@(walletId)];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            LocalCoin *coin = [LocalCoin yy_modelWithDictionary:dic];
            if (coin.coin_type_nft != 2) {
                [coinArray addObject:coin];
            }
        }
    }];
    return [self coinArray:coinArray];
}

- (NSArray *)coinArray:(NSArray *)coinArray
{
    NSMutableArray *localCoinMarray = [[NSMutableArray alloc] initWithArray:coinArray];
    NSMutableArray *nameArray = [[NSMutableArray alloc] init];
    for (LocalCoin *localCoin in coinArray)
    {
        NSString *name = [NSString stringWithFormat:@"%@%@",localCoin.coin_type,localCoin.coin_platform];
        if ([nameArray containsObject:name])
        {
            [localCoinMarray removeObject:localCoin];
        }
        else
        {
            [nameArray addObject:name];
        }
    }
    coinArray = [NSArray arrayWithArray:localCoinMarray];
    
    return coinArray;
}

#pragma mark - 货币CoinPrice
/**
 * 添加CoinPrice
 */
- (BOOL)addCoinPrice:(CoinPrice *)coinPrice
{
    if(coinPrice == nil)
    {
        return NO;
    }
    
    __block BOOL insertSuccess = NO;
    
    if ([self existCoinPrice:coinPrice]) {
        [self updateCoinPrice:coinPrice];
        return YES;
    }

    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            
        insertSuccess = [db executeUpdate:@"INSERT INTO coinprice(coinprice_id,coinprice_name,coinprice_nickname,coinprice_price,coinprice_sid,coinprice_icon,coinprice_chain,coinprice_platform,coinprice_heyueAddress,treaty,coinprice_dollarPrice,coinprice_optional_name,coinprice_chain_country_rate,coinprice_country_rate,lock,rmb_country_rate)VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",@(coinPrice.coinprice_id),coinPrice.coinprice_name,coinPrice.coinprice_nickname,@(coinPrice.coinprice_price),coinPrice.coinprice_sid,coinPrice.coinprice_icon,coinPrice.coinprice_chain,coinPrice.coinprice_platform,coinPrice.coinprice_heyueAddress,@(coinPrice.treaty),@(coinPrice.coinprice_dollarPrice),coinPrice.coinprice_optional_name,@(coinPrice.coinprice_chain_country_rate),@(coinPrice.coinprice_country_rate),@(coinPrice.lock),@(coinPrice.rmb_country_rate)];
        if(insertSuccess)
        {
            NSLog(@"添加币行情成功");
        }else
        {
            NSLog(@"添加币行情失败");
        }
    }];

    return insertSuccess;
}

/**
 * 更新CoinPrice
 */
- (BOOL)updateCoinPrice:(CoinPrice *)coinPrice
{
    if(coinPrice == nil)
    {
        return NO;
    }
    
    __block BOOL updateSuccess = NO;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            if (coinPrice.lock == 0)
            {
                updateSuccess = [db executeUpdate:@"UPDATE 'coinprice' SET coinprice_chain = ?,coinprice_name = ?, coinprice_price = ? , coinprice_icon = ?,coinprice_nickname = ?,coinprice_heyueAddress = ? ,coinprice_platform = ?,treaty = ?,coinprice_dollarPrice = ?,coinprice_optional_name = ?,coinprice_chain_country_rate = ?,coinprice_country_rate = ?,coinprice_sid = ?,rmb_country_rate = ? WHERE coinprice_id = ? ",coinPrice.coinprice_chain,coinPrice.coinprice_name,@(coinPrice.coinprice_price),coinPrice.coinprice_icon,coinPrice.coinprice_nickname,coinPrice.coinprice_heyueAddress,coinPrice.coinprice_platform,@(coinPrice.treaty),@(coinPrice.coinprice_dollarPrice),coinPrice.coinprice_optional_name,@(coinPrice.coinprice_chain_country_rate),@(coinPrice.coinprice_country_rate),coinPrice.coinprice_sid,@(coinPrice.rmb_country_rate),@(coinPrice.coinprice_id)];
            }
            else
            {
                updateSuccess = [db executeUpdate:@"UPDATE 'coinprice' SET coinprice_chain = ?,coinprice_name = ?, coinprice_price = ? , coinprice_icon = ?,coinprice_nickname = ?,coinprice_heyueAddress = ? ,coinprice_platform = ?,treaty = ?,coinprice_dollarPrice = ?,coinprice_optional_name = ?,coinprice_chain_country_rate = ?,coinprice_country_rate = ?,coinprice_sid = ?,lock = ?,rmb_country_rate = ? WHERE coinprice_id = ? ",coinPrice.coinprice_chain,coinPrice.coinprice_name,@(coinPrice.coinprice_price),coinPrice.coinprice_icon,coinPrice.coinprice_nickname,coinPrice.coinprice_heyueAddress,coinPrice.coinprice_platform,@(coinPrice.treaty),@(coinPrice.coinprice_dollarPrice),coinPrice.coinprice_optional_name,@(coinPrice.coinprice_chain_country_rate),@(coinPrice.coinprice_country_rate),coinPrice.coinprice_sid,@(coinPrice.lock),@(coinPrice.rmb_country_rate),@(coinPrice.coinprice_id)];
            }
            
           
            if (updateSuccess) {
                NSLog(@"success");
            }else{
                NSLog(@"error");
            }
        }];
    });
    
    return updateSuccess;
}

/**
 * 数据库查询是否存在CoinPrice
 */
- (BOOL)existCoinPrice:(CoinPrice *)coinPrice
{
     __block int count = 0;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        
        FMResultSet *res = [db executeQuery:@"SELECT COUNT(*) AS count FROM coinprice WHERE coinprice_id = ?",@(coinPrice.coinprice_id)];
        
        while ([res next]) {
            count = [res intForColumn:@"count"];
        }
    }];
    if (count == 0) {
        return NO;
    }else
    {
        return YES;
    }
}

/**
 *  根据coinid查询CoinPrice
 */
- (CoinPrice *)queryCoinPriceBaseOn:(NSInteger )coinId
{
    __block CoinPrice *coinPrice;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res = [db executeQuery:@"SELECT * FROM coinprice WHERE coinprice_id = ?",coinId];
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            coinPrice = [CoinPrice yy_modelWithDictionary:dic];
        }
    }];
    return coinPrice;
}

/**
 * 根据货币名字查询CoinPrice
 */
- (CoinPrice *)queryCoinPriceBasedOn:(NSString *)coinName platform:(NSString *)coinPlat andTreaty:(NSInteger)treaty
{
    __block CoinPrice *coinPrice;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *res;
        if (treaty == 0)
        {
            res = [db executeQuery:@"SELECT * FROM coinprice WHERE coinprice_name = ? and coinprice_platform = ?",coinName,coinPlat];
        }
        else
        {
            res = [db executeQuery:@"SELECT * FROM coinprice WHERE coinprice_name = ? and coinprice_platform = ? and treaty = ?",coinName,coinPlat,@(treaty)];
            if ([res next]) {
                NSDictionary *dic = [res resultDictionary];
                coinPrice = [CoinPrice yy_modelWithDictionary:dic];
            }else{
                res = [db executeQuery:@"SELECT * FROM coinprice WHERE coinprice_name = ? and coinprice_platform = ?",coinName,coinPlat];
            }
        }
        // 查找omni下的USDT的主链信息，即BTC的信息
        if ([coinPlat isEqualToString:@"omni"] && [coinName isEqualToString:@"BTC"]) {
            res = [db executeQuery:@"SELECT * FROM coinprice WHERE coinprice_name = ? and coinprice_platform = ?",coinName,@"btc"];
        }
        
        while ([res next]) {
            NSDictionary *dic = [res resultDictionary];
            coinPrice = [CoinPrice yy_modelWithDictionary:dic];
        }
    }];
    
    NSLog(@"%f",coinPrice.coinprice_dollarPrice);
    
    return coinPrice;
}


@end
