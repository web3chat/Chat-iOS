//
//  CoinPrice.h
//  PWallet
//
//  Created by 宋刚 on 2018/6/11.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CoinPrice : NSObject<NSCopying>
@property (nonatomic,copy) NSString *coinprice_name;
@property (nonatomic,assign) CGFloat coinprice_price; // 余额
@property (nonatomic,assign) CGFloat coinprice_dollarPrice; // 美元单价
@property (nonatomic,copy) NSString *coinprice_icon;
@property (nonatomic,copy) NSString *coinprice_nickname;
@property (nonatomic,assign) NSInteger coinprice_id;
@property (nonatomic,copy) NSString *coinprice_sid;
@property (nonatomic,copy) NSString *coinprice_chain;
@property (nonatomic,copy) NSString *coinprice_platform;
@property (nonatomic,copy) NSString *coinprice_heyueAddress;
@property (nonatomic,assign) NSInteger coin_sort;
@property (nonatomic, assign) NSInteger treaty; // 1 token  2 coins
@property (nonatomic,copy) NSString *coinprice_optional_name;
@property (nonatomic, assign) CGFloat coinprice_chain_country_rate;// 计算手续费
@property (nonatomic, assign) CGFloat coinprice_country_rate;// 计算价格
@property (nonatomic, assign) CGFloat rmb_country_rate; // 人民币价格
@property (nonatomic, assign) NSInteger lock; // 0 表示正常 1 表示币种在维护中
@end
