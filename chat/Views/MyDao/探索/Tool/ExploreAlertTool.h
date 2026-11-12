//
//  ExploreAlertTool.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//
//  探索页面的弹框
//  两种样式 单按钮 双按钮

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef void(^clicked)(void);
@interface ExploreAlertTool : NSObject
+ (instancetype)defaultManager;
-(void)showOneBtnViewWithTitle:(NSString*)title detailText:(NSString*)detail btnText:(NSString*)btnText andBlock:(clicked)block;
-(void)showTwoBtnViewWithQuestion:(NSString*)question messageText:(NSString*)message leftBtnText:(NSString*)leftBtnText rightBtnText:(NSString*)rightBtnText andBlock:(clicked)block;
@end

NS_ASSUME_NONNULL_END
