//
//  CommonTextField.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/23.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "CommonTextField.h"
#import "Depend.h"

@implementation CommonTextField

- (void)drawRect:(CGRect)rect {
    
    if (_lineColor == nil) {
        _lineColor = SGColor(142, 146, 163);
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, _lineColor.CGColor);
    CGContextFillRect(context, CGRectMake(0, CGRectGetHeight(self.frame) - 0.5, CGRectGetWidth(self.frame), 0.5));
    
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)setAttributedPlaceholderDefault
{
    NSMutableAttributedString *placeholder = [[NSMutableAttributedString alloc] initWithString:self.placeholder];
    [placeholder addAttribute:NSForegroundColorAttributeName
                        value:SGColor(142, 146, 163)
                        range:NSMakeRange(0, self.placeholder.length)];
    [placeholder addAttribute:NSFontAttributeName
                        value:CMTextFont15
                        range:NSMakeRange(0, self.placeholder.length)];
    self.attributedPlaceholder = placeholder;
}
@end
