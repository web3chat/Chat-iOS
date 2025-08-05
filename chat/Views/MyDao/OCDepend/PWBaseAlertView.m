//
//  PWBaseAlertView.m
//  PWallet
//
//  Created by 陈健 on 2018/8/15.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "PWBaseAlertView.h"
@interface PWBaseAlertView()<UIGestureRecognizerDelegate>
/**单点手势*/
@property (nonatomic,strong) UITapGestureRecognizer *recognizer;

@end

@implementation PWBaseAlertView
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(hide)];
        recognizer.delegate = self;
        [self addGestureRecognizer:recognizer];
        self.recognizer = recognizer;
    }
    return self;
}

//取消按钮
- (void)hide {
    [self removeFromSuperview];
}

- (void)disableHideGesture {
    [self removeGestureRecognizer:self.recognizer];
}

#pragma mark - UIGestureRecognizerDelegate
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    if (touch.view == self) {
        return YES;
    }
    return NO;
}
@end
