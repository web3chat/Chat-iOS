//
//  TransferViewController.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Walletapi/Walletapi.h>
#import "LocalCoin.h"
#import <Walletapi/Walletapi.h>
#import "ScanViewController.h"
#import "Fee.h"
#import "PWAlertController.h"
#import "OrderModel.h"
#import "Depend.h"


typedef enum : NSUInteger {
    FromTagNormal = 0, // 普通页面
    FromTagChat = 1, // 聊天页面进入
    FromTagCoin = 2, // 从币种详情页面进入
} FromTag;

typedef void(^TransferBlock)(NSString *coinName,NSString *txHash,NSString *amount);
@interface TransferViewController : CommonViewController
@property (nonatomic,strong)LocalCoin *coin;
@property (nonatomic,assign)NSInteger selectIndex;
//@property (nonatomic,assign)TransferFrom fromTag;
// 扫一扫进来 的
@property (nonatomic, strong) NSString *addressStr;
@property (nonatomic, strong) NSString *moneyStr;
@property (nonatomic, strong) OrderModel *orderModel;
@property(nonatomic,assign)NSInteger walletId;//快捷转账用到

@property (nonatomic, strong) NSDictionary *contactDict;



@property(nonatomic) TransferBlock transferBlock;
@property(nonatomic) FromTag fromTag;

//@property (nonatomic, strong) User *user;
@end
