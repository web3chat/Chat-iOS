//
//  UIViewController+ShowInfo.h
//  PWallet
//
//  Created by 陈健 on 2018/5/17.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (ShowInfo)
/* 展示错误信息**/
- (void)showError:(NSError *)error;
/* 展示错误信息* delay秒后自动隐藏*/
- (void)showError:(NSError *)error hideAfterDelay:(NSTimeInterval)delay;
/* 展示自定义信息**/
- (void)showCustomMessage:(NSString *)message;
/* 展示自定义信息 delay秒后自动隐藏**/
- (void)showCustomMessage:(NSString *)message hideAfterDelay:(NSTimeInterval)delay;
/**展示进度菊花信息 delay秒后自动隐藏**/
- (void)showProgressMessage:(NSString *)message hideAfterDelay:(NSTimeInterval)delay;
/* 展示进度菊花**/
- (void)showProgressWithMessage:(NSString *)message;
/* 展示进度菊花**/
- (void)showKeywindowProgressWithMessage:(NSString *)message;
/* 隐藏进度菊花**/
- (void)hideProgress;
/* 隐藏进度菊花**/
- (void)hideProgressWithkeyWindow;
@end
