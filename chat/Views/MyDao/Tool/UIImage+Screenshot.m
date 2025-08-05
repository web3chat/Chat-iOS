//
//  UIImage+Screenshot.m
//  PWallet
//
//  Created by 陈健 on 2018/11/20.
//  Copyright © 2018 陈健. All rights reserved.
//

#import "UIImage+Screenshot.h"

@implementation UIImage (Screenshot)

+ (UIImage*)getImageFromView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)screenshotWithView:(UIView *)view rect:(CGRect)rect {
    UIGraphicsBeginImageContextWithOptions(view.frame.size, false, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    //把像 素rect 转化为 点rect（如无转化则按原图像素取部分图片）
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat x = rect.origin.x * scale;
    CGFloat y = rect.origin.y * scale;
    CGFloat w = rect.size.width * scale;
    CGFloat h = rect.size.height * scale;
    CGRect dianRect = CGRectMake(x, y, w, h);
    //截取部分图片并生成新图片
    CGImageRef sourceImageRef = [viewImage CGImage];
    CGImageRef newImageRef = CGImageCreateWithImageInRect(sourceImageRef, dianRect);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    UIGraphicsEndImageContext();
    return newImage;
}

+ (UIImage *)originImage:(UIImage *)originImage withWaterMask:(UIImage *)mask inRect:(CGRect)rect {
    UIGraphicsBeginImageContextWithOptions(originImage.size, NO, 0);
    //原图
    [originImage drawInRect:CGRectMake(0, 0, originImage.size.width, originImage.size.height)];
    //水印图
    [mask drawInRect:rect];
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newPic;
}

+ (UIImage *)combine:(UIImage *)oneImage otherImage:(UIImage *)otherImage {
    //计算画布大小
    CGFloat width = oneImage.size.width;
    CGFloat height = oneImage.size.height + otherImage.size.height;
    CGSize resultSize = CGSizeMake(width, height);
    UIGraphicsBeginImageContextWithOptions(resultSize, false, 0.0);
    
    //放第一个图片
    CGRect oneRect = CGRectMake(0, 0, resultSize.width, oneImage.size.height);
    [oneImage drawInRect:oneRect];
    
    //放第二个图片
    CGRect otherRect = CGRectMake(0, oneRect.size.height, resultSize.width, otherImage.size.height);
    [otherImage drawInRect:otherRect];
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultImage;
}

- (UIImage *)scaleToSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
    
}

/**
 *从图片中按指定的位置大小截取图片的一部分
 * UIImage image 原始的图片
 * CGRect rect 要截取的区域
 */
- (UIImage *)clipImageInRect:(CGRect)rect {
    //将UIImage转换成CGImageRef
    CGImageRef sourceImageRef = [self CGImage];
    //按照给定的矩形区域进行剪裁
    CGImageRef newImageRef = CGImageCreateWithImageInRect(sourceImageRef, rect);
    //将CGImageRef转换成UIImage
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    return newImage;
    
}

@end
