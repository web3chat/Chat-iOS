//
//  UITextView+KeyBoard.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/16.
//  Copyright © 2018年 宋刚. All rights reserved.
//

#import "UITextView+KeyBoard.h"
#import "Depend.h"

@implementation UITextView (KeyBoard)
- (void)setKeyBoardInputView:(UIView *)inputView action:(SEL)operation
{
    if ([inputView isKindOfClass:[UIButton class]]) {
        UIView *bgView = [[UIView alloc] init];
        bgView.backgroundColor = SGColorRGBA(210,213, 219, 0.9);
        bgView.frame = CGRectMake(0, 0, kScreenWidth, 60);
        
        UIButton *inputBtn = (UIButton *)inputView;
        UIButton *button = [[UIButton alloc] init];
        button.frame = CGRectMake(15, 8, kScreenWidth - 30, 44);
        button.layer.cornerRadius = 6;
        [button setTitle:inputBtn.titleLabel.text forState:UIControlStateNormal];
        [button setTitleColor:inputBtn.titleLabel.textColor forState:UIControlStateNormal];
        button.titleLabel.font = inputBtn.titleLabel.font;
        button.backgroundColor = inputBtn.backgroundColor;
        id target =  [[inputBtn.allTargets allObjects] firstObject];
        UIControlEvents event = [inputBtn allControlEvents];
        [button addTarget:target action:operation forControlEvents:event];
        [bgView addSubview:button];
        self.inputAccessoryView = bgView;
    }
    
}
@end
