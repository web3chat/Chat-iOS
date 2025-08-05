//
//  UIImage+Screenshot.h
//  PWallet
//
//  Created by 陈健 on 2018/11/20.
//  Copyright © 2018 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (Screenshot)
/*截图
 view: 需要截图的view
 */

+ (UIImage*)getImageFromView:(UIView *)view;

/*截图
 view: 需要截图的view
 rect: 需要截的rect
 */
+ (UIImage *)screenshotWithView:(UIView *)view rect:(CGRect)rect;

/*
 画水印
 originImage: 原图
 mask: 水印图
 rect: 水印在原图的位置
*/
+ (UIImage *)originImage:(UIImage *)originImage withWaterMask:(UIImage *)mask inRect:(CGRect)rect;


/*
合并图片（竖着合并，以第一张图片的宽度为主）
 */
+ (UIImage *)combine:(UIImage *)oneImage otherImage:(UIImage *)otherImage;
/*
   缩放图片
 */
- (UIImage *)scaleToSize:(CGSize)size;

/**
 *从图片中按指定的位置大小截取图片的一部分
 * CGRect rect 要截取的区域
 */
- (UIImage *)clipImageInRect:(CGRect)rect;
@end

NS_ASSUME_NONNULL_END
