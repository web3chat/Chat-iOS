//
//  UINavigationBar+Extend.h
//  PWallet
//
//  Created by 郑晨 on 2019/11/14.
//  Copyright © 2019 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UINavigationBar (Extend)

/**
 设置navigationbar背景色

 @param backgroundColor 背景颜色
 */
- (void)lt_setBackgroundColor:(UIColor *)backgroundColor;

/**
 设置透明度

 @param alpha 透明度 0-1
 */
- (void)lt_setElementsAlpha:(CGFloat)alpha;

- (void)lt_setBackgroundImageView:(NSString *)name;
/**
 设置坐标

 @param translationY Y坐标
 */
- (void)lt_setTranslationY:(CGFloat)translationY;

/**
 重置
 */
- (void)lt_reset;

@end

NS_ASSUME_NONNULL_END
