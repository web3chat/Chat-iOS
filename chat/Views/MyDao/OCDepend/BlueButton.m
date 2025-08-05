//
//  BlueButton.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/22.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "BlueButton.h"
#import "Depend.h"

@implementation BlueButton

-(instancetype)init
{
    self = [super init];
    if (self) {
        [self createView];
    }
    return self;
}

- (void)createView
{
    self.layer.cornerRadius = 4;
    self.layer.masksToBounds = YES;
    self.backgroundColor = MainColor;
    self.titleLabel.font = CMTextFont16;
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    if (enabled) {
        self.backgroundColor = MainColor;
    }else{
        self.backgroundColor = CMColor(210, 216, 225);
    }
}

- (void)setPressedEnabled:(BOOL)enabled
{
    self.enabled = enabled;
    if (enabled) {
        self.backgroundColor = MainColor;
    }else
    {
        self.backgroundColor = CMColorFromRGB(0xD2D8E1);
    }
}
@end
