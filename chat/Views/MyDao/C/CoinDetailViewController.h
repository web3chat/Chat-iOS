//
//  CoinDetailViewController.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CoinDetailView.h"
#import "TradeCell.h"
#import "TransferViewController.h"
#import "PWNesReceiptMoneyViewController.h"

#import "LocalCoin.h"
#import "CoinPrice.h"

#import <Walletapi/Walletapi.h>
#import "NoRecordView.h"

typedef void(^CoinTransferBlock)(NSString *coinType,NSString *txId,NSString *sessionId);

typedef enum : NSUInteger {
    CoinListTypeAll = 0, // 全部
    CoinListTypeOut = 1, // 转账
    CoinListTypeIn = 2,// 收款
} CoinListType;

@interface CoinDetailViewController : CommonViewController
@property (nonatomic,copy) LocalCoin *selectedCoin;
@property (nonatomic) CoinListType coinListType;
@property(nonatomic,assign)NSInteger fromType;//是否是从观察钱包点击转账  ==1是   否则为否

@property(nonatomic) CoinTransferBlock coinTransferBlock; // 转账传值


@end
