//
//  OrderModel.h
//  PWallet
//
//  Created by 宋刚 on 2018/6/20.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    TransferFromStatusFailure = 100,
    TransferFromStatusEnsureing = 0,
    TransferFromStatusSuccess = 1,
    TransferFromStatusSuccess2 = 2,
} TransferFromStatus;

@interface OrderModel : NSObject
@property (nonatomic,assign) TransferFromStatus state; //成功 失败 确认中
@property (nonatomic,copy) NSString *time;
@property (nonatomic,assign) CGFloat coinNum;
@property (nonatomic,assign) CGFloat fee;
@property (nonatomic,copy) NSString *fromAddress;
@property (nonatomic,copy) NSString *toAddress;
@property (nonatomic,copy) NSString *blockHeight;
@property (nonatomic,copy) NSString *blockHash;
@property (nonatomic,copy) NSString *note;
@property (nonatomic,copy) NSString *type; //是转出还是转入
@property (nonatomic,copy) NSString *category_name; // 托管账单类型

@property (nonatomic,copy) NSString *category;
- (instancetype)initWithDic:(NSDictionary *)dic;
@end
