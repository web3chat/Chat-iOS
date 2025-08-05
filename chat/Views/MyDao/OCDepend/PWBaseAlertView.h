//
//  PWBaseAlertView.h
//  PWallet
//
//  Created by 陈健 on 2018/8/15.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Depend.h"

typedef void(^PWBaseAlertViewBlock)(id);
typedef void(^PWBaseAlertViewCancelBlock)(id);
@interface PWBaseAlertView : UIView
/**确认按钮 点击回调*/
@property (nonatomic,copy) PWBaseAlertViewBlock okBlock;
@property (nonatomic,copy) PWBaseAlertViewCancelBlock cancelBlock;
- (void)hide;
//禁止点击背景移除alert
- (void)disableHideGesture;
@end
