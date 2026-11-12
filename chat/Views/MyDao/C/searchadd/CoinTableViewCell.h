//
//  CoinTableViewCell.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/28.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"
#import "PWDataBaseManager.h"
#import <Walletapi/Walletapi.h>
#import "PWSwitchView.h"


typedef void (^SelectTemCoin)(CoinPrice *,BOOL);
typedef void (^AddCoin)(LocalCoin *,BOOL);

@interface CoinTableViewCell : UITableViewCell
@property (nonatomic,copy)LocalCoin *coin;
@property (nonatomic,copy)NSDictionary *searchDic;
@property (nonatomic,copy)NSArray *coinArray;
@property (nonatomic,copy)SelectTemCoin selectTemCoin;
@property (nonatomic,copy)AddCoin addCoin;
@property (nonatomic,copy)NSArray *temporarilyArray;
@property (nonatomic,strong) PWSwitchView *switchBtn;

- (void)setDataStr:(NSString *)title;


@end
