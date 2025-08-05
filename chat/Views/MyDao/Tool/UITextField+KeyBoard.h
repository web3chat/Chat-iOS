//
//  UITextField+KeyBoard.h
//  Test_GO
//
//  Created by 宋刚 on 2018/5/14.
//  Copyright © 2018年 宋刚. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UITextField (KeyBoard)
@property(nonatomic,strong) UIButton * _Nullable inputButton;
- (void)setKeyBoardInputView:(UIView *_Nonnull)inputView action:(SEL _Nonnull )operation;
@end
