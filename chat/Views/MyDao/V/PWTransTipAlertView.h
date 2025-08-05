//
//  PWTransTipAlertView.h
//  PWallet
//
//  Created by 郑晨 on 2021/7/13.
//  Copyright © 2021 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^TipBlock)(void);

@interface PWTransTipAlertView : UIView

@property (nonatomic) TipBlock tipBlock;

- (void)show;

- (instancetype)initWithTipStr:(NSString *)tipStr;

@end

NS_ASSUME_NONNULL_END
