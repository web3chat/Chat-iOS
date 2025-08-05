//
//  UITextField+KeyBoard.m
//  Test_GO
//
//  Created by 宋刚 on 2018/5/14.
//  Copyright © 2018年 宋刚. All rights reserved.
//

#import "UITextField+KeyBoard.h"
#import "Depend.h"
#import <objc/runtime.h>
@implementation UITextField (KeyBoard)

- (void)setKeyBoardInputView:(UIView *)inputView action:(SEL)operation
{
    if ([inputView isKindOfClass:[UIButton class]]) {
        
        UIView *bgView = [[UIView alloc] init];
        bgView.backgroundColor = SGColorRGBA(210,213, 219, 0.9);
        bgView.frame = CGRectMake(0, 0, kScreenWidth, 60);
        
        UIButton *inputBtn = (UIButton *)inputView;
        if (inputView.tag == 10033)
        {
            // 渐变色
            self.inputButton = [[UIButton alloc] init];
            self.inputButton.frame = CGRectMake(15, 8, kScreenWidth - 30, 44);
            
            CAGradientLayer *gl = [CAGradientLayer layer];
            gl.frame = self.inputButton.bounds;
            gl.startPoint = CGPointMake(1, 0.5);
            gl.endPoint = CGPointMake(0, 0.5);
            gl.colors = @[(__bridge id)[UIColor colorWithRed:105/255.0 green:121/255.0 blue:251/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:89/255.0 green:105/255.0 blue:240/255.0 alpha:1.0].CGColor];
            gl.locations = @[@(0), @(1.0f)];
            self.inputButton.layer.cornerRadius = 2;
            self.inputButton.layer.shadowColor = [UIColor colorWithRed:102/255.0 green:118/255.0 blue:249/255.0 alpha:0.5].CGColor;
            self.inputButton.layer.shadowOffset = CGSizeMake(0,1);
            self.inputButton.layer.shadowOpacity = 1;
            self.inputButton.layer.shadowRadius = 5;
            self.inputButton.backgroundColor = UIColor.clearColor;
            [self.inputButton.layer insertSublayer:gl below:self.inputButton.titleLabel.layer];
            [self.inputButton bringSubviewToFront:self.inputButton.titleLabel];
            [self.inputButton setTitle:inputBtn.titleLabel.text forState:UIControlStateNormal];
            [self.inputButton setTitleColor:inputBtn.titleLabel.textColor forState:UIControlStateNormal];
            self.inputButton.titleLabel.font = inputBtn.titleLabel.font;
        }
        else
        {
            self.inputButton = [[UIButton alloc] init];
            self.inputButton.frame = CGRectMake(15, 8, kScreenWidth - 30, 44);
            self.inputButton.layer.cornerRadius = 6;
            [self.inputButton setTitle:inputBtn.titleLabel.text forState:UIControlStateNormal];
            [self.inputButton setTitleColor:inputBtn.titleLabel.textColor forState:UIControlStateNormal];
            self.inputButton.titleLabel.font = inputBtn.titleLabel.font;
            self.inputButton.backgroundColor = inputBtn.backgroundColor;
        }
        
        id target =  [[inputBtn.allTargets allObjects] firstObject];
        UIControlEvents event = [inputBtn allControlEvents];
        [self.inputButton setEnabled:inputBtn.enabled];
        [self.inputButton addTarget:target action:operation forControlEvents:event];
        
        [bgView addSubview:self.inputButton];
        self.inputAccessoryView = bgView;
    }
    
}

- (void)setInputButton:(UIButton *)inputButton{
    objc_setAssociatedObject(self, "inputButtonKey", inputButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIButton *)inputButton{
   return objc_getAssociatedObject(self, "inputButtonKey");
}


@end
