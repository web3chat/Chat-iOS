//
//  NSString+CommonUseTool.h
//  BBP
//
//  Created by zczhao on 16/11/16.
//  Copyright © 2016年 TangYunfei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSString (CommonUseTool)

/*是否是空串**/
+ (BOOL)isBlankString:(NSString*)string;

- (BOOL)isURL;
/*是否全是字母**/
- (BOOL)isLatter;
/*是否是合法密码 8到16位 数字、字母、符号,必须包含其中至少两种**/
- (BOOL)isRightPassword;

+ (NSString *)getSecurityPhoneNumber:(NSString *)phoneNum;
+ (BOOL)stringIsOnlyInNumberAndLetter:(NSString *)password;
- (instancetype)removedEmojiString;

//把字符串中的字母全变为大写字母
+(NSString *)getCapitalStringByLowercaseString:(NSString *)lowerStr;
//把字符串中的字母全变为小写字母
+(NSString *)getLowercaseStringByCapitalString:(NSString *)capitalStr;

//获取字符串各个中文开头字母
+ (NSString *)getEnglishFirstCharactor:(NSString *)str;
//获取中文首字母,如果空字符串返回#
+ (NSString *)firstCharactor:(NSString *)aString;
//汉字转英文字母 每个字空格分开
+ (NSString *)transformEnglishWithChinese:(NSString *)chinese;

//获取随机汉字
+ (NSString *)getRandomChineseCharacter;

//data转十六进制字符串
+ (NSString *)getHexStringFromData:(NSData *)data;

+ (NSAttributedString *)getAttrStrByAddress:(NSString *)address;

+ (NSAttributedString *)getAttrStrByAddress:(NSString *)address withColor:(UIColor *)color;

+ (NSString *)stringChangeMoneyWithStr:(NSString *)str numberStyle:(NSNumberFormatterStyle)numberStyle;

@end
