//
//  TradeDetailViewController.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/31.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OrderModel.h"
#import "LocalCoin.h"
#import "CommonViewController.h"

@interface TradeDetailViewController : CommonViewController
@property (nonatomic,strong) LocalCoin *coin;
@property (nonatomic,strong) OrderModel *orderModel;
/**标记此控制器是不是从通知中push进来的*/
@property (nonatomic,assign,getter=isPushedByNotification) BOOL pushedByNotification;
/**币种类型*/
@property (nonatomic,copy) NSString *coinType;
@property (nonatomic,copy) NSString *platStr;
@property (nonatomic) NSInteger treaty;
/**交易哈希*/
@property (nonatomic,copy) NSString *tradeHash;
@end
