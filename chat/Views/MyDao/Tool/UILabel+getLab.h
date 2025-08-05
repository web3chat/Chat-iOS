//
//  UILabel+getLab.h
//  zhaobi
//
//  Created by 吴文拼 on 2018/9/18.
//  Copyright © 2018年 33.cn 复杂美科技有限公司. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UILabel (getLab)

+(UILabel *_Nullable)getLabWithFont:(UIFont *_Nullable)font textColor:(UIColor *_Nullable)color textAlignment:(NSTextAlignment)alignment text:(NSString * _Nullable)text;

@end
