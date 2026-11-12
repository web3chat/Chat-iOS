//
//  UILabel+Width.m
//  PWallet
//
//  Created by 郑晋源 on 2019/9/12.
//  Copyright © 2019 fzm. All rights reserved.
//

#import "UILabel+Width.h"

@implementation UILabel (Width)
- (CGFloat)textWidth{
    CGSize size = [self.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:self.font,NSFontAttributeName,nil]];
    return size.width;
}
@end
