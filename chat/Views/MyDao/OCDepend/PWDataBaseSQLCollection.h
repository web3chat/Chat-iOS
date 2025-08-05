//
//  PWDataBaseSQLCollection.h
//  JTB
//
//  Created by 吴文拼 on 2018/1/17.
//  Copyright © 2018年 吴文拼. All rights reserved.
//

#ifndef PWDataBaseSQLCollection_h
#define PWDataBaseSQLCollection_h


#pragma mark 表-钱包 wallet_isselected  1:被选择 0:没被选择
#define SQL_CREATE_WALLET @"CREATE TABLE IF NOT EXISTS 'wallet'(\
'wallet_id'  INTEGER, \
'wallet_name' VARCHAR(1000), \
'wallet_password' VARCHAR(1000), \
'wallet_remembercode' VARCHAR(1000), \
'wallet_totalassets' FLOAT, \
'wallet_isselected' INTEGER,\
'wallet_issmall' INTEGER,\
'wallet_isbackup' INTEGER,\
'wallet_issetpwd' INTEGER,\
'wallet_isEscrow' INTEGER,\
'wallet_totalassetsDollar' FLOAT,\
PRIMARY KEY (wallet_id) \
)"

#pragma mark  表-货币 coin_walletid => wallet_id  coin_show 1:show 0:noshow
#define SQL_CREATE_COIN @"CREATE TABLE IF NOT EXISTS 'coin'(\
'coin_id'  INTEGER, \
'coin_walletid'  INTEGER, \
'coin_type' VARCHAR(1000), \
'coin_pubkey' VARCHAR(1000), \
'coin_address' VARCHAR(1000), \
'coin_balance' FLOAT, \
'coin_show' INTEGER,  \
'icon' VARCHAR(1000), \
'coin_platform' VARCHAR(1000),\
'coin_coinid' INTEGER,\
'treaty' INTEGER,\
'coin_type_nft' INTEGER,\
'coin_chain' VARCHAR(1000),\
PRIMARY KEY (coin_id) \
)"

#pragma mark  表-货币行情
#define SQL_CREATE_COINPRICE @"CREATE TABLE IF NOT EXISTS 'coinprice'(\
'coinprice_id'  INTEGER, \
'coinprice_name'  VARCHAR(1000), \
'coinprice_nickname' VARCHAR(1000), \
'coinprice_price' FLOAT, \
'coinprice_sid' VARCHAR(1000), \
'coinprice_icon' VARCHAR(1000), \
'coinprice_chain' VARCHAR(1000), \
'coinprice_platform' VARCHAR(1000), \
'coinprice_heyueAddress' VARCHAR(1000),\
'treaty' INTEGER,\
'coinprice_dollarPrice' FLOAT,\
'coinprice_optional_name' VARCHAR(1000),\
'coinprice_chain_country_rate' FLOAT,\
'coinprice_country_rate' FLOAT,\
'rmb_country_rate' FLOAT,\
'lock' INTEGER,\
PRIMARY KEY (coinprice_id) \
)"



#endif /* PWDataBaseSQLCollection_h */
