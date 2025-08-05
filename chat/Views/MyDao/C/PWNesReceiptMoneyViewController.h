//
//  PWNesReceiptMoneyViewController.h
//  PWallet
//
//  Created by 郑晨 on 2019/12/3.
//  Copyright © 2019 陈健. All rights reserved.
//

#import "CommonViewController.h"
#import "LocalCoin.h"
#import "LocalWallet.h"
#import "PWDataBaseManager.h"
#import "OrderModel.h"
NS_ASSUME_NONNULL_BEGIN


typedef enum : NSUInteger {
    ReceiptQrcodeTypeUniseral = 0, // 通用
    ReceiptQrcodeTypeExclusive, // 专属
} ReceiptQrcodeType;

@interface PWNesReceiptMoneyViewController : CommonViewController
@property(nonatomic,copy)LocalCoin *coin;
@property (nonatomic) ReceiptQrcodeType receiptQrcodeType;
@end

NS_ASSUME_NONNULL_END
