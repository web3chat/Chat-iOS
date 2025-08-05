//
//  PWUtils.h
//  PWallet
//
//  Created by 郑晨 on 2019/5/23.
//  Copyright © 2019 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>
#import <UIKit/UIKit.h>
#import "Depend.h"
NS_ASSUME_NONNULL_BEGIN

@interface PWUtils : NSObject
// 移除空格
+ (NSString *)removeSpaceAndNewline:(NSString *)str;
// 获取对应的attritubeString
+ (NSMutableAttributedString *)getAttritubeStringWithString:(NSString *)string andChangeStr:(NSString *)changeStr andFont:(UIFont *)font andColor:(UIColor *)color;
// view只有上半部分设置圆角
+(void)setViewTopRightandLeftRaduisForView:(UIView *)view size:(CGSize)size;
// view只有下半部分设置圆角
+(void)setViewBottomRightandLeftRaduisForView:(UIView *)view;

// 获取不同语言下的请求头
+ (NSString *)getLang;

// 判断输入的文字是否是中文
+ (BOOL)isChineseWithstr:(NSString *)str;

// 获取计价货币对应的币种显示样式
+(NSString *)getUnitStr;

// 查询是否存在钱包
+ (BOOL)checkExistWallet;

// 判断输入的字符串是否为16进制字符串
+ (BOOL)isHex:(NSString *)str;
// 判断是否包含表情
+(BOOL)stringContainsEmoji:(NSString *)string;
// 判断是否a包含中文
+(BOOL)checkIsChinese:(NSString *)string;
/**
 * 字母、数字正则判断（不包括空格）
 */
+ (BOOL)isInputRuleNotBlank:(NSString *)str andType:(nonnull NSString *)type;

+ (NSString *)getEthBtyAddress;
+ (NSString *)getEthBtyAddressWithWallet:(LocalWallet *)wallet;
// 给View加阴影
+ (void)addShadow:(UIView *)view;

// 获取 keywindow
+ (UIWindow *)getKeyWindowWithView:(UIView *)view;

// 对密码进行简单的加密解密
+ (NSString *)encryptString:(NSString *)str;
+ (NSString *)decryptString:(NSString *)str;

@end

NS_ASSUME_NONNULL_END
