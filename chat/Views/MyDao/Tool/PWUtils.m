//
//  PWUtils.m
//  PWallet
//
//  Created by 郑晨 on 2019/5/23.
//  Copyright © 2019 陈健. All rights reserved.
//

#import "PWUtils.h"
#import "PWDataBaseManager.h"
#import "chat-Swift.h"

//#import "GTMBase64.h"

NSString *const gkInitVectorForGame = @"33878402";
NSString *const gDESKeyForGame = @"008f80e79e6b8c6a500e54e216e38ac2";

const Byte giv[] = {3,3,8,7,8,4,0,2};
@implementation PWUtils
// 去除字符串换行符和空格
+ (NSString *)removeSpaceAndNewline:(NSString *)str
{
    NSString *temp = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *text = [temp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    text = [text stringByReplacingOccurrencesOfString:@" " withString:@""];
    return text;
    
}


+ (NSMutableAttributedString *)getAttritubeStringWithString:(NSString *)string andChangeStr:(NSString *)changeStr andFont:(UIFont *)font andColor:(UIColor *)color
{
    if (string.length == 0)
    {
        return [[NSMutableAttributedString alloc] initWithString:@""];
    }
    NSMutableAttributedString *mustr = [[NSMutableAttributedString alloc] initWithString:string];
    UIColor *changeColor = color;
    NSRange rang = NSMakeRange([[mustr string] rangeOfString:changeStr].location, [[mustr string] rangeOfString:changeStr].length);
    [mustr addAttributes:@{NSFontAttributeName : font,NSForegroundColorAttributeName : changeColor} range:rang];
    
    return mustr;
}




// view只有上半部分设置圆角
+ (void)setViewTopRightandLeftRaduisForView:(UIView *)view size:(CGSize)size
{
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:view.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:size];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = view.bounds;
    maskLayer.path = maskPath.CGPath;
    view.layer.mask = maskLayer;
    
}
// view只有下半部分设置圆角
+ (void)setViewBottomRightandLeftRaduisForView:(UIView *)view
{
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:view.bounds byRoundingCorners:UIRectCornerBottomLeft | UIRectCornerBottomRight cornerRadii:CGSizeMake(5, 5)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = view.bounds;
    maskLayer.path = maskPath.CGPath;
    view.layer.mask = maskLayer;
}



// 获取不同语言下的请求头
+ (NSString *)getLang
{
    NSString *lang = @"zh-CN";
    return lang;
}



// 判断输入的文字是否全是中文
+ (BOOL)isChineseWithstr:(NSString *)str
{
    NSInteger count = str.length;
    NSInteger result = 0;
    for (int i = 0; i < str.length; i ++)
    {
        int a = [str characterAtIndex:i];
        // 判断输入的是否是中文
        if (a > 0x4e00 && a< 0x9fff)
        {
            result++;
        }
    }
    if (count == result) // 当字符长度和中文字符长度相等的时候
    {
        return YES;
    }
    
    return NO;
}


// 获取计价货币对应的币种显示样式
+(NSString *)getUnitStr
{
    return @"CNY";
}

// 查询是否存在钱包
+ (BOOL)checkExistWallet
{
    int walletCount = [[PWDataBaseManager shared] queryWalletCount];
    if (walletCount == 0) {
        return false;
    }else{
        return true;
    }
}

// 判断输入的字符串是否为16进制字符串
+ (BOOL)isHex:(NSString *)str
{
    NSString *regex = @"^[A-Fa-f0-9]+$";
    
    NSPredicate *numberPre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    
    return [numberPre evaluateWithObject:str];
}

+(BOOL)stringContainsEmoji:(NSString *)string
{
    __block BOOL returnValue = NO;
    
    [string enumerateSubstringsInRange:NSMakeRange(0, [string length])
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        const unichar high = [substring characterAtIndex: 0];
        
        // Surrogate pair (U+1D000-1F9FF)
        if (0xD800 <= high && high <= 0xDBFF) {
            const unichar low = [substring characterAtIndex: 1];
            const int codepoint = ((high - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000;
            
            if (0x1D000 <= codepoint && codepoint <= 0x1F9FF){
                returnValue = YES;
            }
            
            // Not surrogate pair (U+2100-27BF)
        } else {
            if (0x2100 <= high && high <= 0x27BF){
                returnValue = YES;
            }
        }
    }];
    
    return returnValue;
}

+ (BOOL)checkIsChinese:(NSString *)string{
    for (int i=0; i<string.length; i++) {
        unichar ch = [string characterAtIndex:i];
        if (0x4E00 <= ch  && ch <= 0x9FA5) {
            return YES;
        }
    }
    return NO;
}

/**
 * 字母、数字正则判断（不包括空格）
 */
+ (BOOL)isInputRuleNotBlank:(NSString *)str andType:(nonnull NSString *)type
{
    NSString *pattern = @"^[a-fA-F\\d]*$";
    if ([type isEqualToString:@"address"])
    {
        pattern = @"^[a-zA-Z\\d]*$";
    }
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
    BOOL isMatch = [pred evaluateWithObject:str];
    return isMatch;
}

+ (NSString *)getEthBtyAddress
{
    NSArray *localArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    NSString *ethBtyAddr = @"";
    for (LocalCoin *coin in localArray) {
        if([coin.coin_chain isEqualToString:@"ETH"] && [coin.coin_type isEqualToString:@"BTY"]){
            ethBtyAddr = coin.coin_address;
            break;
        }
    }
    
    return ethBtyAddr;
}

+ (NSString *)getEthBtyAddressWithWallet:(LocalWallet *)wallet
{
    NSArray *localArray = [[PWDataBaseManager shared] queryAllCoinArrayBasedOnWalletID:wallet.wallet_id];
    NSString *ethBtyAddr = @"";
    for (LocalCoin *coin in localArray) {
        if([coin.coin_chain isEqualToString:@"ETH"] && [coin.coin_type isEqualToString:@"BTY"]){
            ethBtyAddr = coin.coin_address;
            break;
        }
    }
    return ethBtyAddr;
}


// 给View加阴影
+ (void)addShadow:(UIView *)view
{
    view.layer.cornerRadius = 10;
    
    view.layer.shadowOpacity = 1;
    view.layer.shadowOffset = CGSizeMake(0, 0);
    view.layer.shadowColor = CMColorFromRGB(0xebedf8).CGColor;
}

// 获取 keywindow
+ (UIWindow *)getKeyWindowWithView:(UIView *)view
{
    UIWindow *foundWindow  = view.window.windowScene.keyWindow;
    
    return foundWindow;
}


// 对密码进行简单的加密解密
+ (NSString *)encryptString:(NSString *)str
{
    if ([str isEqualToString:@""] || str == nil)
    {
        return @"";
    }
    NSArray *array = @[@"a",@"B",@"C",@"D",@"e",@"f",@"G",@"h",@"I",@"J",@"k",@"l",@"m",@"n",@"O",@"p",@"q",@"r",@"s",@"T",@"U",@"V",@"w",@"x",@"y",@"Z",
                       @"A",@"b",@"c",@"d",@"E",@"F",@"g",@"H",@"i",@"j",@"K",@"L",@"M",@"N",@"o",@"P",@"Q",@"R",@"S",@"t",@"u",@"v",@"W",@"X",@"Y",@"z",
                       @"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",
                       @"/",@"~",@"-",@"+",@"@",@"#"];
    NSMutableSet *randomSet = [[NSMutableSet alloc] init];
    while (randomSet.count < 8)
    {
        int r = arc4random() % array.count;
        [randomSet addObject:[array objectAtIndex:r]];
    }
    NSArray *randomArray = [randomSet allObjects];
    NSLog(@"%@",randomArray);
    for (NSString *randomStr in randomArray)
    {
        str = [str stringByAppendingString:randomStr];
    }
    
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    
    return [data base64EncodedStringWithOptions:0];
}
+ (NSString *)decryptString:(NSString *)str
{
    if ([str isEqualToString:@""] || str == nil)
    {
        return @"";
    }
    else if (str.length <= 8)
    {
        return str;
    }
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:0];
    NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSString *passwd = [dataStr substringWithRange:NSMakeRange(0, dataStr.length - 8)];
    
    
    return passwd;
}

@end
