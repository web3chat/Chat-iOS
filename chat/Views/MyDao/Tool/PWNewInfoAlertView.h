//
//  PWNewInfoAlertView.h
//  PWallet
//
//  Created by 陈健 on 2018/11/15.
//  Copyright © 2018 陈健. All rights reserved.
//

#import "PWBaseAlertView.h"

/*
 
 使用方式
 PWNewInfoAlertView *view = [[PWNewInfoAlertView alloc]initWithTitle:@"提示" message:@"ZWGYBA剩余数量不足，请稍后购买！" buttonName:@"确定"];
 view.okBlock = ^(id obj) {
 NSLog(@"12312312312312312312");
 };
 [[UIApplication sharedApplication].keyWindow addSubview:view];
 
 */

NS_ASSUME_NONNULL_BEGIN

@interface PWNewInfoAlertView : PWBaseAlertView
/**
 初始化方法
 @param title title
 @param message message
 @param buttonName 确定按钮名字
 */
- (instancetype)initWithTitle:(NSString*)title message:(NSString*)message buttonName:(NSString*)buttonName;

@property(nonatomic,copy)NSString *wallet_name;
@property(nonatomic,copy)NSString *coinName;
@property(nonatomic,copy)NSString *message;
@end

NS_ASSUME_NONNULL_END
