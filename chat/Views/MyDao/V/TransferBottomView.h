//
//  TransferBottomView.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/30.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Fee.h"
#import "LocalCoin.h"
#import "CoinPrice.h"
#import "PWDataBaseManager.h"
#import "SGSlider.h"

@protocol BottomViewDelegate <NSObject>

- (void)showTips:(UIButton *)sender;

@end

@interface TransferBottomView : UIView
@property (nonatomic,strong)LocalCoin *coin;
@property (nonatomic,strong)Fee *feeModel;
@property (nonatomic,strong)CoinPrice *coinPrice;
@property (nonatomic,strong)CoinPrice *chainCoinPrice;
@property (nonatomic,assign,getter=getFee)CGFloat feeValue;
@property (nonatomic,copy)NSString *coins_name;
@property (nonatomic, assign) BOOL hiddenSlider;

@property (nonatomic, strong) NSString *inputNum;


@property (nonatomic, strong) NSString *gasPrice;

@property (nonatomic) id  <BottomViewDelegate>delegate;



@end
