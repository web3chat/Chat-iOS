//
//  GameGoFunction.h
//  PWallet
//
//  Created by 宋刚 on 2018/8/15.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface GameGoFunction : NSObject


+ (NSString *)querySelectedBtyAddress;
+ (NSString *)queryAddressByChain:(NSString *)chain;
+ (NSArray *)getPwalletSelectdAddress;
+ (CGFloat)querySelectedBtyBalance;


@end
