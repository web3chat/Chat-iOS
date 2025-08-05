//
//  PWAlertController.h
//  PWAlert
//
//  Created by 陈健 on 2018/6/14.
//  Copyright © 2018年 陈健. All rights reserved.
//

/*
 使用方式
 PWAlertController *vc = [[PWAlertController alloc] initWithTitle:@"请输入密码" leftButtonName:@"忘记密码" rightButtonName:@"确定" handler:^(ButtonType type, NSString *text) {
 if (type == ButtonTypeLeft) {
 NSLog(@"忘记密码按钮---%@",text);
 }
 if (type == ButtonTypeRight) {
 NSLog(@"确定按钮----%@",text);
 }
 }];
 vc.view.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
 [self presentViewController:vc1 animated:false completion:nil];
 **/

#import <UIKit/UIKit.h>
#import "Fee.h"
#import "SGSlider.h"
#import "LocalCoin.h"

typedef NS_ENUM(NSUInteger, ButtonType) {
    ButtonTypeLeft   = 0,
    ButtonTypeRight  = 1,
};

typedef void(^PWAlertControllerHandler)(ButtonType,NSString*);
typedef void(^PWAlertControllerExchangeHandler)(ButtonType,NSString*,double);
typedef void(^PWAlertControllerClose)(void);

@interface PWAlertController : UIViewController
@property (nonatomic,copy)PWAlertControllerClose closeVC;
@property (nonatomic, strong) LocalCoin *coin;
@property (nonatomic) FeeConfig *feeConfig;
// 有一个输入框 两个按钮 两个按钮颜色不一样 若只需一个按钮 则另一个按钮传nil
- (instancetype)initWithTitle:(NSString *)title withTextValue:(NSString *)text leftButtonName:(NSString *)leftButtonName rightButtonName:(NSString *)rightItemName handler:(PWAlertControllerHandler)handler;
- (instancetype)initWithTitle:(NSString *)title withTextValue:(NSString *)text rightButtonName:(NSString *)rightItemName coinType:(NSString *)coinType showSlider:(BOOL)showSlider amount:(double)amount handler:(PWAlertControllerExchangeHandler)exchaneHandler;


@end
