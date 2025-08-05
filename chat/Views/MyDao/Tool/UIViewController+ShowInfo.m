//
//  UIViewController+ShowInfo.m
//  PWallet
//
//  Created by 陈健 on 2018/5/17.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "UIViewController+ShowInfo.h"
#import "MBProgressHUD.h"
@implementation UIViewController (ShowInfo)
/* 展示错误信息**/
- (void)showError:(NSError *)error {
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    //先去除可能存在的hud
    [MBProgressHUD hideHUDForView:keyWindow animated:true];
    [MBProgressHUD hideHUDForView:self.view animated:false];
    //再新增
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:keyWindow animated:true];
    hud.mode = MBProgressHUDModeText;
    hud.label.numberOfLines = 0;
//    if (error.code == 需要特殊处理的错误) {   }
    //取出错误信息
    NSString *errorStr = error.localizedDescription;
    NSArray *errorArray = [errorStr componentsSeparatedByString:@"\""];
    NSString *showErrorStr = errorStr;
    for (int i = 0; i < errorArray.count; i++) {
        NSString *errStr = errorArray[i];
        if (![errStr containsString:@"Error"] && ![errStr containsString:@"UserInfo="] && ![errStr containsString:@"NSLocalizedDescription"])
        {
            showErrorStr = errStr;
            break;
        }
    }
    
     NSString *text = [NSString stringWithFormat:@"%@",showErrorStr];
     hud.label.text = text;
}
/* 展示错误信息* delay秒后自动隐藏*/
- (void)showError:(NSError *)error hideAfterDelay:(NSTimeInterval)delay {
    [self showError:error];
    [self hideMBProgressAfterDelay:delay];
}
/* 展示自定义信息**/
- (void)showCustomMessage:(NSString *)message {
     UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    //先去除可能存在的hud
    [MBProgressHUD hideHUDForView:keyWindow animated:true];
    [MBProgressHUD hideHUDForView:self.view animated:false];
    //再新增
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:keyWindow animated:true];
    hud.mode = MBProgressHUDModeText;
    hud.label.text = message;
    hud.label.numberOfLines = 0;
    [keyWindow addSubview:hud];
}
/* 展示自定义信息 delay秒后自动隐藏**/
- (void)showCustomMessage:(NSString *)message hideAfterDelay:(NSTimeInterval)delay {
    [self showCustomMessage:message];
    [self hideMBProgressAfterDelay:delay];
}
/**展示进度菊花信息 delay秒后自动隐藏**/
- (void)showProgressMessage:(NSString *)message hideAfterDelay:(NSTimeInterval)delay{
    [self showProgressWithMessage:message];
    [self hideMBProgressAfterDelay2:delay];
}

/* 展示进度菊花**/
- (void)showProgressWithMessage:(NSString *)message {
    //先去除可能存在的hud
    [MBProgressHUD hideHUDForView:self.view animated:false];
    
    //默认0.2秒后才展示菊花
    //先将hud添加到self.view上
    //保证使用 [MBProgressHUD hideHUDForView:animated:]方法是可以移除0.2秒后才会显示的hud
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:hud];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.label.text = message;
    hud.label.numberOfLines = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud showAnimated:true];
    });
}
- (void)showKeywindowProgressWithMessage:(NSString *)message
{
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    [MBProgressHUD hideHUDForView:keyWindow animated:false];
    
    //默认0.2秒后才展示菊花
    //先将hud添加到self.view上
    //保证使用 [MBProgressHUD hideHUDForView:animated:]方法是可以移除0.2秒后才会显示的hud
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:keyWindow];
    [keyWindow addSubview:hud];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.label.text = message;
    hud.label.numberOfLines = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud showAnimated:true];
    });
}
/* 隐藏进度菊花**/
- (void)hideProgress {
    [self hideMBProgressAfterDelay2:0];
}

- (void)hideProgressWithkeyWindow
{
    [self hideMBProgressAfterDelay:0];
}

- (void)hideMBProgressAfterDelay:(NSTimeInterval)delay {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:keyWindow animated:true];
    });
}

- (void)hideMBProgressAfterDelay2:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:self.view animated:true];
    });
}
@end
