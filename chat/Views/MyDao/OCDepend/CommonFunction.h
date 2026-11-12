//
//  CommonFunction.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/23.
//  Copyright © 2018年 fzm. All rights reserved.
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
/**
 币种没有图标时的占位图：圆形色底 + 币种名首字母（资产页 / 添加币种列表共用）
 颜色由币种名算出 —— 同一个币永远是同一个颜色，避免每次刷新/滚动都换色
 @param name 币种名称（取首个字符，英文会转大写）
 @param diameter 直径（pt），<=0 时按 32 处理
 */
+ (UIImage *)coinPlaceholderImageWithName:(NSString *)name diameter:(CGFloat)diameter;
/* 设置渐变色*/
+ (CAGradientLayer *)setGradualChangingColor:(UIView *)view formColor:(UIColor *)fromHexColor toColor:(UIColor *)toHexColor andCornerRadius:(CGFloat)cornerRadius;
@end
