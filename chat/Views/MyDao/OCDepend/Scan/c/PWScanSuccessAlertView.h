//
//  PWScanSuccessAlertView.h
//  PWallet
//
//  Created by fzm on 2021/4/16.
//  Copyright © 2021 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWScanSuccessAlertView : UIView

@property (nonatomic,strong)UIView * backView;
- (instancetype)initWithFrame:(CGRect)frame withToastStr:(NSString *)str;


@end

NS_ASSUME_NONNULL_END
