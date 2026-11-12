//
//  TransferBottomView.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/30.
//  Copyright © 2018年 fzm. All rights reserved.
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

/// 链上 gas 模式：gasPriceWei 为十进制 wei 字符串；gasLimit 为 Gas 数量；unit 为显示单位（BNB/ETH/BTY）
- (void)applyChainGasFeeWithGasPriceWei:(NSString *)gasPriceWei
                               gasLimit:(double)gasLimit
                                   unit:(NSString *)unit;

/// 固定档位模式：tiers 顺序为 最快/标准/经济（金额字符串）；defaultIndex 为默认选中档
- (void)applyFixedFeeTiers:(NSArray<NSString *> *)tiers
              defaultIndex:(NSInteger)defaultIndex
                      unit:(NSString *)unit;

/// 复位为原有逻辑（切换币种时用）
- (void)resetFeeMode;

@end
