//
//  TransferTopView.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"
#import "CoinPrice.h"
#import "PWDataBaseManager.h"


typedef void(^ChoiceNFTIDBlock)(UIButton *btn);


@interface TransferTopView : UIView
@property (nonatomic,copy)LocalCoin *coin;
/**  */
@property (nonatomic, copy) CoinPrice *coinPrice;
@property (nonatomic,strong) UITextField *moneyText;
@property (nonatomic,assign,getter=getInputMoney) double inputMoney;
/** 折合人民币 */
@property (nonatomic, assign) double inputCNY;
/** 输入数量 */
@property (nonatomic, copy) NSString *inputNumber;

@property (nonatomic, copy) NSString *scanMoney; // 扫专属二维码拿到的数据
@property (nonatomic,assign) CGFloat feeValue;

@property (nonatomic, assign) BOOL isPrecent;// 手续费是否是百分比

@property (nonatomic) ChoiceNFTIDBlock choiceNFTIDBlock; // 选择编号


- (void)setKeybordBtn:(UIButton *)keybordBtn action:(SEL) action;
- (double )getTokenInputMoney;
@end
