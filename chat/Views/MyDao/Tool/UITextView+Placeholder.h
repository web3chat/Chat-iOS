//
//  UITextView+Placeholder.h
//  自定义带placeholder的UITextView
//
//  Created by 樊小聪 on 16/6/3.
//  Copyright © 2016年 樊小聪. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface UITextView (Placeholder)

/**  placeholder的文字  */
@property (copy, nonatomic)  NSString *placeholder;

/**  placeholder文字的颜色  */
@property (weak, nonatomic)  UIColor *placeholderColor;

@end
