//
//  YYUnitTextField.h
//  test
//
//  Created by 于优 on 2018/11/19.
//  Copyright © 2018 EasyRent. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface YYUnitTextField : UIView

/** 输入内容 */
@property (nonatomic, strong) NSString *contentNumber;

@property (nonatomic, strong) UITextField *textField;

/** 监听输入 */
@property (nonatomic, copy) void(^didTextValueDidChangedHandle)(UITextField *textField);

@end
