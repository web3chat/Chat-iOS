//
//  LocalCoin.h
//  PWallet
//
//  Created by 宋刚 on 2018/6/6.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LocalCoin : NSObject<NSCopying>
@property (nonatomic,assign) NSInteger coin_id;
@property (nonatomic,assign) NSInteger coin_walletid;
@property (nonatomic,copy) NSString *coin_type;
@property (nonatomic,copy) NSString *coin_platform;
@property (nonatomic) CGFloat coin_balance;
@property (nonatomic,copy) NSString *coin_pubkey; // 合约币的情况下 这一项是合约地址
@property (nonatomic,copy) NSString *coin_address;
@property (nonatomic,assign) NSInteger coin_show;
@property (nonatomic,copy) NSString *coin_sid;
@property (nonatomic, assign) NSInteger treaty;
@property (nonatomic,assign)  NSInteger coin_coinid;
@property (nonatomic,copy) NSString *icon;//托管账户使用
@property (nonatomic, assign) CGFloat coinprice_price;//托管账户使用
@property (nonatomic, copy) NSString *coin_chain; // 主链
@property (nonatomic, assign) CGFloat coin_type_nft; // 1 是nft  2是普通币 3是ERC721 4是ERC1155 10是合约币

//是不是bty平行链
@property (nonatomic,assign,readonly) BOOL isBtyChild;

//重名币的去掉后面编号的名字，比如AT
@property (nonatomic,copy,readonly) NSString *optional_name;
//-(NSString*)optional_name;
@end
