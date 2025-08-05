//
//  CommonFunction.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/23.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CommonFunction : NSObject
/** 颜色转换为图片 */
+ (UIImage*)createImageWithColor:(UIColor*)color;
/** 生成二维码 */
+ (UIImage *)createImgQRCodeWithString:(NSString *)codeStr centerImage:(UIImage *)centerImage;
/** 行情价格解析 ￥23,345  => 23345*/
+ (CGFloat)handlePrice:(NSString *)priceStr;
/** 将所有的值的后面的0去掉（小于四位的后面会有0） */
+ (NSString *)removeZeroFromMoney:(NSString *)moneyStr;
/** 将所有的值的后面的0去掉 */
+ (NSString *)removeZeroFromMoney:(CGFloat)money withMaxLength:(int)length;
/** 计算UIlabel最后一个字符的位置 */
//+ (CGPoint )caculteLastPoint:(YYLabel *)label;
/** 播放音频文件*/
+ (void)playAudioFile;
+ (BOOL)judgeTimeByStartAndEnd:(NSString *)startStr EndTime:(NSString *)endStr;
/** 对生成的中文助记词重新处理 */
+ (NSString *)rehandleChineseCode:(NSString *)chineseCode;
/** 判断是否是中文*/
+(BOOL)IsChinese:(NSString *)str;
/** 提取ImToken中的z地址 */
+ (NSString *)queryImTokenAddress:(NSString *)imTokenAddress;
/** 初步判断地址是否合格 */
+ (BOOL)judgeAddress:(NSString *)addressStr type:(NSString *)coin;
/* 设置渐变色*/
+ (CAGradientLayer *)setGradualChangingColor:(UIView *)view formColor:(UIColor *)fromHexColor toColor:(UIColor *)toHexColor andCornerRadius:(CGFloat)cornerRadius;
@end
