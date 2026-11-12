//
//  PWSwitchView.m
//  PWallet
//
//  Created by fzm on 2018/11/1.
//  Copyright © 2018 fzm. All rights reserved.
//

#import "PWSwitchView.h"
#import "Depend.h"

@interface PWSwitchView()
/**button*/
@property (nonatomic,strong) UIButton *btn;
@property (nonatomic,strong) id target;
@property (nonatomic,assign) SEL action;
@end
@implementation PWSwitchView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.btn];
    }
    return self;
}

- (void)layoutSubviews {
    [self.btn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
}

- (void)addTarget:(nullable id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {
    self.target = target;
    self.action = action;
    [self.btn addTarget:self action:@selector(btnPress:) forControlEvents:controlEvents];
}

- (BOOL)isOn {
    return self.btn.isSelected;
}

- (void)setOn:(BOOL)on {
    self.btn.selected = on;
}

- (void)btnPress:(UIButton*)sender {
    if (sender.isSelected) {
        [UIView animateWithDuration:0.2 animations:^{
            sender.transform = CGAffineTransformMakeRotation(M_PI_4);
        } completion:^(BOOL finished) {
            sender.transform = CGAffineTransformIdentity;
            sender.selected = false;
            [self.target performSelectorOnMainThread:self.action withObject:self waitUntilDone:false];
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            sender.transform = CGAffineTransformMakeRotation(-M_PI_4);
        } completion:^(BOOL finished) {
            sender.transform = CGAffineTransformIdentity;
            sender.selected = true;
            [self.target performSelectorOnMainThread:self.action withObject:self waitUntilDone:false];
        }];
    }
    
    
}

- (UIButton *)btn {
    if (!_btn) {
        _btn = [[UIButton alloc]init];
        [_btn setImage:[UIImage imageNamed:@"switchOn_new"] forState:UIControlStateSelected];
        [_btn setImage:[UIImage imageNamed:@"switchOff_new"] forState:UIControlStateNormal];
        [_btn setImage:[UIImage imageNamed:@"switchOff_new"] forState:UIControlStateHighlighted];

    }
    return _btn;
}


@end
