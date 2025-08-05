//
//  Fee.h
//  PWallet
//
//  Created by 宋刚 on 2018/6/14.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface Fee : NSObject
@property (nonatomic,assign) NSInteger level;
@property (nonatomic,assign) double max;
@property (nonatomic,assign) double min;
@property (nonatomic,assign) double fee;
@property (nonatomic,assign) NSInteger Id;
@property (nonatomic,assign) NSInteger type;
@property (nonatomic,assign) NSInteger create_at;
@property (nonatomic,assign) NSInteger update_at;
@property (nonatomic, copy) NSString *platform;
@property (nonatomic, assign) double origin_fee;
@property (nonatomic, assign) double fee_reduction;
@property (nonatomic, assign) double min_fee;
@property (nonatomic, assign) double average; // 平均价
@property (nonatomic, assign) double high;
@property (nonatomic, assign) double low;
@property (nonatomic, copy)  NSString* name;

@end

@interface FeeConfig : NSObject

@property (nonatomic, assign) NSInteger externalType;
@property (nonatomic, assign) double externalFee;
@property (nonatomic, assign) double externalMinFee;
@property (nonatomic, assign) NSInteger internalType;
@property (nonatomic, assign) double internalFee;
@property (nonatomic, assign) double internalMinFee;

- (instancetype)initWithAttritubes:(NSDictionary *)dict;


@end
