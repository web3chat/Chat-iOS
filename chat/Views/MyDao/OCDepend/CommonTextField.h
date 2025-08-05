//
//  CommonTextField.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/23.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CommonTextField : UITextField
- (void)setAttributedPlaceholderDefault;
/** color */
@property (nonatomic, strong) UIColor *lineColor;
@end
