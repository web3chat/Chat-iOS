//
//  PWImageAlertView.h
//  PWallet
//
//  Created by 陈健 on 2018/11/23.
//  Copyright © 2018 陈健. All rights reserved.
//

#import "PWBaseAlertView.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWImageAlertView : PWBaseAlertView
/**
 初始化方法
 @param title title
 @param image image
 */
- (instancetype)initWithTitle:(NSString*)title image:(UIImage*)image address:(NSString *)address;

@end

NS_ASSUME_NONNULL_END
