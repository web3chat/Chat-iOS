//
//  UIViewController+AppClicked.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
// 


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class PWApplication;
@interface UIViewController (AppClicked)
- (void)appClicked:(PWApplication *)app;
@end

NS_ASSUME_NONNULL_END
