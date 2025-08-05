//
//  UILabel+getLab.m
//  zhaobi
//
//  Created by 吴文拼 on 2018/9/18.
//  Copyright © 2018年 33.cn 复杂美科技有限公司. All rights reserved.
//

#import "UILabel+getLab.h"

@implementation UILabel (getLab)

+(UILabel *)getLabWithFont:(UIFont *)font textColor:(UIColor *)color textAlignment:(NSTextAlignment)alignment text:(NSString * _Nullable)text{
    UILabel *lab = [[UILabel alloc] init];
    lab.font = font;
    lab.textColor = color;
    lab.textAlignment = alignment;
    lab.text = text;
    return lab;
}

@end
