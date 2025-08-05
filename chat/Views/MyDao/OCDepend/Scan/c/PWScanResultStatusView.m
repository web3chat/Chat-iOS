//
//  PWScanResultStatusView.m
//  PWallet
//
//  Created by fzm on 2021/4/16.
//  Copyright © 2021 陈健. All rights reserved.
//

#import "PWScanResultStatusView.h"
#import "PWScanSuccessAlertView.h"
#import "Depend.h"

@implementation PWScanResultStatusView

+ (void)showAlertWithStr:(NSString *)str
{
    PWScanSuccessAlertView *view = [[PWScanSuccessAlertView alloc]initWithFrame:CGRectMake(50, kScreenHeight + 20, kScreenWidth - 100, 40) withToastStr:str];
    UIWindow * window = [UIApplication sharedApplication].delegate.window;
    [window addSubview:view];
    [UIView animateWithDuration:0.5 animations:^{
        view.frame = CGRectMake(50, kScreenHeight - 120, kScreenWidth - 100, 40);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5 delay:2 options:UIViewAnimationOptionTransitionNone animations:^{
            view.frame = CGRectMake(50, kScreenHeight + 20, kScreenWidth - 100, 40);
        } completion:^(BOOL finished) {
            [view removeFromSuperview];
        }];
    }];
}




@end
