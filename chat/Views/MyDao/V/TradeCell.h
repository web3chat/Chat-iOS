//
//  TradeCell.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OrderModel.h"
#import "LocalCoin.h"

@interface TradeCell : UITableViewCell
@property (nonatomic,strong) OrderModel *orderModel;
@property (nonatomic,strong) LocalCoin *coin;

@property (nonatomic, strong) NSArray *contactInfoArray;
@end
