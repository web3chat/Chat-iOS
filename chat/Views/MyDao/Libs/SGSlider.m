//
//  SGSlider.m
//  PWallet
//
//  Created by 宋刚 on 2018/6/25.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "SGSlider.h"

@implementation SGSlider

- (CGRect)trackRectForBounds:(CGRect)bounds
{
    return CGRectMake(0, 0, CGRectGetWidth(self.frame),10);
}

- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value
{
    bounds = [super thumbRectForBounds:bounds trackRect:rect value:value];

    return CGRectMake(bounds.origin.x, bounds.origin.y, 20, 20);

}

@end
