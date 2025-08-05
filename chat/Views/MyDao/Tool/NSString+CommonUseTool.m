//
//  NSString+CommonUseTool.m
//  BBP
//
//  Created by zczhao on 16/11/16.
//  Copyright © 2016年 TangYunfei. All rights reserved.
//

#import "NSString+CommonUseTool.h"

@implementation NSString (CommonUseTool)

+ (BOOL)isBlankString:(NSString*)string {
    if (!string) {
        return YES;
    }
    if ([self isKindOfClass:[NSNull class]]) {
        return YES;
    }
    if ([string isEqual:nil] || [string isEqual:Nil]){
        return YES;
    }
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimmedStr = [string stringByTrimmingCharactersInSet:set];
    if (!trimmedStr.length) {
        return YES;
    }
    if([string isEqualToString:@"(null)"]){
        return YES;
    }
    if ([string isEqualToString:@"nullnull"]) {
        return YES;
    }
    return NO;
}

- (BOOL)isURL {
    NSString *regex =@"[a-zA-z]+://[^\\s]*";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
    return [urlTest evaluateWithObject:self];
}

- (BOOL)isLatter {
    NSString *regex = @"[A-Za-z]+";
    NSPredicate*predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
    if ([predicate evaluateWithObject:self]) {
        return true;
    }
    return false;
}

- (BOOL)isRightPassword {
    NSString *passWordRegex = @"^(?=.*[a-zA-Z0-9].*)(?=.*[a-zA-Z\\W].*)(?=.*[0-9\\W].*).{8,16}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",passWordRegex];
    return [predicate evaluateWithObject:self];
}

+(NSString *)getSecurityPhoneNumber:(NSString *)phoneNum{
    if (!phoneNum) {
        return @"";
    }
    if (phoneNum.length == 13) {
        return [phoneNum stringByReplacingCharactersInRange:NSMakeRange(4, 4) withString:@"****"];
    }else if (phoneNum.length == 11) {
        return [phoneNum stringByReplacingCharactersInRange:NSMakeRange(3, 4) withString:@"****"];
    }else {
        return phoneNum;
    }
}

- (BOOL)isEmoji {
    const unichar high = [self characterAtIndex: 0];
    
    // Surrogate pair (U+1D000-1F77F)
    if (0xd800 <= high && high <= 0xdbff) {
        const unichar low = [self characterAtIndex: 1];
        const int codepoint = ((high - 0xd800) * 0x400) + (low - 0xdc00) + 0x10000;
        
        return (0x1d000 <= codepoint && codepoint <= 0x1f77f);
        
        // Not surrogate pair (U+2100-27BF)
    } else {
        return (0x2100 <= high && high <= 0x27bf);
    }
}

- (BOOL)isIncludingEmoji {
    BOOL __block result = NO;
    
    [self enumerateSubstringsInRange:NSMakeRange(0, [self length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock: ^(NSString* substring, NSRange substringRange, NSRange enclosingRange, BOOL* stop) {
                              if ([substring isEmoji]) {
                                  *stop = YES;
                                  result = YES;
                              }
                          }];
    
    return result;
}

- (instancetype)removedEmojiString {
    NSMutableString* __block buffer = [NSMutableString stringWithCapacity:[self length]];
    
    [self enumerateSubstringsInRange:NSMakeRange(0, [self length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock: ^(NSString* substring, NSRange substringRange, NSRange enclosingRange, BOOL* stop) {
                              [buffer appendString:([substring isEmoji])? @"": substring];
                          }];  
    
    return buffer;  
}

+ (BOOL)stringIsOnlyInNumberAndLetter:(NSString *)password {
    NSCharacterSet *disallowedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789QWERTYUIOPLKJHGFDSAZXCVBNMqwertyuioplkjhgfdsazxcvbnm"] invertedSet];
    NSCharacterSet *numberDisallowedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    NSCharacterSet *letterDisallowedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"QWERTYUIOPLKJHGFDSAZXCVBNMqwertyuioplkjhgfdsazxcvbnm"] invertedSet];
    NSRange foundRange = [password rangeOfCharacterFromSet:disallowedCharacters];
    NSRange numberFoundRange = [password rangeOfCharacterFromSet:numberDisallowedCharacters];
    NSRange letterFoundRange = [password rangeOfCharacterFromSet:letterDisallowedCharacters];
    
    if (foundRange.location == NSNotFound && numberFoundRange.location != NSNotFound && letterFoundRange.location != NSNotFound) {
        return YES;
    }
    return NO;
}


+(NSString *)getEnglishFirstCharactor:(NSString *)str{
    if (str.length == 0) {
        return @"";
    }
    NSMutableString *mutStr = [NSMutableString string];
    for (int i = 0; i < str.length; i++) {
        NSString *temp = [str substringWithRange:NSMakeRange(i, 1)];
        [mutStr appendString:[self firstCharactor:temp]];
    }
    return [mutStr copy];
}

+(NSString *)getCapitalStringByLowercaseString:(NSString *)lowerStr{
    for (NSInteger i=0; i<lowerStr.length; i++) {
        if ([lowerStr characterAtIndex:i]>='a'&[lowerStr characterAtIndex:i]<='z') {
            //A  65  a  97
            char  temp=[lowerStr characterAtIndex:i]-32;
            NSRange range=NSMakeRange(i, 1);
            lowerStr=[lowerStr stringByReplacingCharactersInRange:range withString:[NSString stringWithFormat:@"%c",temp]];
        }
    }
    return lowerStr;
}

+(NSString *)getLowercaseStringByCapitalString:(NSString *)capitalStr{
    for (NSInteger i=0; i<capitalStr.length; i++) {
        if ([capitalStr characterAtIndex:i]>='A'&[capitalStr characterAtIndex:i]<='Z') {
            //A  65  a  97
            char  temp=[capitalStr characterAtIndex:i]+32;
            NSRange range=NSMakeRange(i, 1);
            capitalStr=[capitalStr stringByReplacingCharactersInRange:range withString:[NSString stringWithFormat:@"%c",temp]];
        }
    }
    return capitalStr;
}

+ (NSString *)firstCharactor:(NSString *)aString

{
    if (aString.length == 0) {
        return @"#";
    }
    
    //转成了可变字符串
    
    NSMutableString *str = [NSMutableString stringWithString:aString];
    
    //先转换为带声调的拼音
    
    CFStringTransform((CFMutableStringRef)str,NULL, kCFStringTransformMandarinLatin,NO);
    
    //再转换为不带声调的拼音
    
    CFStringTransform((CFMutableStringRef)str,NULL, kCFStringTransformStripDiacritics,NO);
    
    //转化为大写拼音
    
    NSString *pinYin = [str capitalizedString];
    
    //获取并返回首字母
    NSString *returnPinYin = [pinYin substringToIndex:1];
    if ([@"ABCDEFGHIJKLMNOPQRSTUVWXYZ" containsString:returnPinYin]) {
        return returnPinYin;
    }
    
    return @"#";
    
}

+ (NSString *)transformEnglishWithChinese:(NSString *)chinese
{
    NSMutableString *pinyin = [chinese mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)pinyin, NULL, kCFStringTransformMandarinLatin, NO);
    CFStringTransform((__bridge CFMutableStringRef)pinyin, NULL, kCFStringTransformStripCombiningMarks, NO);
    return pinyin;
}


+(NSString *)getRandomChineseCharacter{
    NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
    NSInteger randomH = 0xA1+arc4random()%(0xFE - 0xA1+1);
    
    NSInteger randomL = 0xB0+arc4random()%(0xF7 - 0xB0+1);
    
    NSInteger number = (randomH<<8)+randomL;
    NSData *data = [NSData dataWithBytes:&number length:2];
    
    NSString *string = [[NSString alloc] initWithData:data encoding:gbkEncoding];
    
    return string;
}

+(NSString *)getHexStringFromData:(NSData *)data{
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    
    return [string copy];
}

+(NSAttributedString *)getAttrStrByAddress:(NSString *)address{
    return [self getAttrStrByAddress:address withColor:[UIColor greenColor]];
}

+(NSAttributedString *)getAttrStrByAddress:(NSString *)address withColor:(UIColor *)color{
    if (address && address.length > 4) {
        NSMutableAttributedString *attStr = [[NSMutableAttributedString alloc] initWithString:address];
        [attStr addAttributes:@{NSForegroundColorAttributeName:color} range:NSMakeRange(address.length-4, 4)];
        return attStr;
    }
    return [[NSAttributedString alloc] initWithString:@""];
}

/**
 * 金额的格式转化
 * str : 金额的字符串
 * numberStyle : 金额转换的格式
 * return  NSString : 转化后的金额格式字符串
 */
+ (NSString *)stringChangeMoneyWithStr:(NSString *)str numberStyle:(NSNumberFormatterStyle)numberStyle {
    
    // 判断是否null 若是赋值为0 防止崩溃
    if (([str isEqual:[NSNull null]] || str == nil)) {
        str = 0;
    }
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc]init];
    formatter.numberStyle = numberStyle;
    // 注意传入参数的数据长度，可用double
    NSString *money = [formatter stringFromNumber:[NSNumber numberWithDouble:[str doubleValue]]];
    
    return money;
}


@end
