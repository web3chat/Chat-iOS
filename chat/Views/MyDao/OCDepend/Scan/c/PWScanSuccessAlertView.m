//
//  PWScanSuccessAlertView.m
//  PWallet
//
//  Created by fzm on 2021/4/16.
//  Copyright © 2021 陈健. All rights reserved.
//

#import "PWScanSuccessAlertView.h"

@implementation PWScanSuccessAlertView

- (instancetype)initWithFrame:(CGRect)frame withToastStr:(NSString *)str{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
        [self createViewWithStr:str];
    }
    return self;
}

- (void)createViewWithStr:(NSString *)str{
    self.backView = [[UIView alloc]init];
    self.backView.frame = self.bounds;
    self.backView.layer.cornerRadius = 20;
    self.backView.backgroundColor = [UIColor whiteColor];
    [self addSubview:self.backView];
    
    UILabel * titleLabel = [[UILabel alloc]initWithFrame:self.backView.bounds];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.text = str;
    [self.backView addSubview:titleLabel];
}

@end
