//
//  HomeCoinTableViewCell.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/22.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"
#import "CoinPrice.h"


@interface HomeCoinTableViewCell : UITableViewCell
@property (nonatomic,copy)LocalCoin *coin;
@property (nonatomic,copy)CoinPrice *coinPrice;
@property (nonatomic, strong) UIButton *leftBtn;
@property (nonatomic, strong) UIButton *rightBtn;


@end
