//
//  CommonFunction.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/23.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "CommonFunction.h"
#import <AVFoundation/AVFoundation.h>
#import "YYLabel.h"
#import <YYText/YYText.h>

#import "Depend.h"

@implementation CommonFunction

/**
 * 颜色转换为图片
 */
+ (UIImage*)createImageWithColor:(UIColor*)color{
    
    CGRect rect = CGRectMake(0.0f,0.0f,1.0f,1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}


+ (UIImage *)createImgQRCodeWithString:(NSString *)codeStr centerImage:(UIImage *)centerImage{
    //1.生成coreImage框架中的滤镜来生产二维码
    if (codeStr.length == 0) {
        return nil;
    }
    CIFilter *filter=[CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setDefaults];
    
    [filter setValue:[codeStr dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    //4.获取生成的图片
    CIImage *ciImg=filter.outputImage;
    //放大ciImg,默认生产的图片很小
    
    //5.设置二维码的前景色和背景颜色
    CIFilter *colorFilter=[CIFilter filterWithName:@"CIFalseColor"];
    //5.1设置默认值
    [colorFilter setDefaults];
    [colorFilter setValue:ciImg forKey:@"inputImage"];
    [colorFilter setValue:[CIColor colorWithRed:0 green:0 blue:0] forKey:@"inputColor0"];
    [colorFilter setValue:[CIColor colorWithRed:1 green:1 blue:1] forKey:@"inputColor1"];
    //5.3获取生存的图片
    ciImg=colorFilter.outputImage;
    
    CGAffineTransform scale=CGAffineTransformMakeScale(10, 10);
    ciImg=[ciImg imageByApplyingTransform:scale];
    
    //    self.imgView.image=[UIImage imageWithCIImage:ciImg];
    
    //6.在中心增加一张图片
    UIImage *img=[UIImage imageWithCIImage:ciImg];
    //7.生存图片
    //7.1开启图形上下文
    UIGraphicsBeginImageContext(img.size);
    //7.2将二维码的图片画入
    //BSXPCMessage received error for message: Connection interrupted   why??
    //    [img drawInRect:CGRectMake(10, 10, img.size.width-20, img.size.height-20)];
    [img drawInRect:CGRectMake(0, 0, img.size.width, img.size.height)];
    //7.3在中心划入其他图片
    UIImage *backgroundImage = [self createImageWithColor:[UIColor whiteColor]];
    
    CGFloat centerW=40;
    CGFloat centerH=40;
    CGFloat centerX=(img.size.width-40)*0.5;
    CGFloat centerY=(img.size.height -40)*0.5;
    
   
    if(centerImage != nil)
    {
        [backgroundImage drawInRect:CGRectMake(centerX, centerY, centerW, centerH)];
        [centerImage drawInRect:CGRectMake(centerX, centerY, centerW, centerH)];
    }
    
    //7.4获取绘制好的图片
    UIImage *finalImg=UIGraphicsGetImageFromCurrentImageContext();
    
    //7.5关闭图像上下文
    UIGraphicsEndImageContext();
    
    return finalImg;
}

/**
 * 行情价格解析 ￥23,345  => 23345
 */
+ (CGFloat)handlePrice:(NSString *)priceStr
{
    if (priceStr.length == 1) {
        return 0;
    }
    if ([priceStr isEqualToString:@""]) {
        return 0;
    }
    NSMutableString *finalStr = [@"" mutableCopy];
    NSString *numStr = [priceStr substringFromIndex:1];
    NSArray *strArray = [numStr componentsSeparatedByString:@","];
    for (int i = 0; i < strArray.count; i ++) {
        [finalStr appendString:[strArray objectAtIndex:i]];
    }
    
    return [finalStr doubleValue];
}

/**
 * 将所有的值的后面的0去掉
 */
+ (NSString *)removeZeroFromMoney:(NSString *)moneyStr
{
    if ([moneyStr doubleValue] == 0) {
        return @"0";
    }
    NSArray *moneyArray = [moneyStr componentsSeparatedByString:@"."];
    NSString *lastStr = [moneyArray lastObject];
    NSInteger lastMoney = [lastStr integerValue];
    if(lastMoney == 0)
    {
        return [moneyArray firstObject];
    }
    
    NSString *newStr = moneyStr;
    if ([moneyStr containsString:@"."]) {
        NSRange range;
        range = [moneyStr rangeOfString:@"."];
        if (range.location != NSNotFound) {
            if (moneyStr.length - range.location >3) {
                for (NSInteger i = moneyStr.length - 1; i > range.location ; i --) {
                    char c = [moneyStr characterAtIndex:i];
                    NSString *itemStr = [NSString stringWithFormat:@"%c",c];
                    if ([itemStr isEqualToString:@"0"]){
                        newStr = [moneyStr substringToIndex:i];
                    }else{
                        break;
                    }
                }
                return newStr;
            }else
            {
                return newStr;
            }
        }else{
            return newStr;
        }
    }else
    {
        return newStr;
    }
}

+ (NSString *)removeZeroFromMoney:(CGFloat)money withMaxLength:(int)length{
    NSString* moneyStr;
    // 提高精度
    
    NSString *doubleStr = [NSString stringWithFormat:@"%.8f",money];
    NSDecimalNumber *decNumber = [NSDecimalNumber decimalNumberWithString:doubleStr];
    
    if(length==0) {
        moneyStr = [NSString stringWithFormat:@"%f",floor(decNumber.doubleValue)];
    }else if (length==1) {
        NSDecimalNumber *s = [NSDecimalNumber decimalNumberWithString:@"10"];
        moneyStr = [NSString stringWithFormat:@"%.4f",floor([[decNumber decimalNumberByMultiplyingBy:s] doubleValue])/10];
    }else if (length==2) {
        NSDecimalNumber *s = [NSDecimalNumber decimalNumberWithString:@"100"];
        moneyStr = [NSString stringWithFormat:@"%.4f",floor([[decNumber decimalNumberByMultiplyingBy:s] doubleValue])/100];
    }else if (length==3) {
        NSDecimalNumber *s = [NSDecimalNumber decimalNumberWithString:@"1000"];
        moneyStr = [NSString stringWithFormat:@"%.4f",floor([[decNumber decimalNumberByMultiplyingBy:s] doubleValue])/1000];
    }else if (length==4) {
        NSDecimalNumber *s = [NSDecimalNumber decimalNumberWithString:@"10000"];
        moneyStr = [NSString stringWithFormat:@"%.4f",floor([[decNumber decimalNumberByMultiplyingBy:s] doubleValue])/10000];
    }else if (length==5) {
        NSDecimalNumber *s = [NSDecimalNumber decimalNumberWithString:@"100000"];
        moneyStr = [NSString stringWithFormat:@"%.8f",floor([[decNumber decimalNumberByMultiplyingBy:s] doubleValue])/100000];
    }else if (length==6) {
        NSDecimalNumber *s = [NSDecimalNumber decimalNumberWithString:@"1000000"];
        moneyStr = [NSString stringWithFormat:@"%.8f",floor([[decNumber decimalNumberByMultiplyingBy:s] doubleValue])/1000000];
    }else{
        [NSException raise:@"位数切割出错" format:@"目前只支持0-6位"];
    }

    if (money < 1) {
        return moneyStr;
    }
    if ([moneyStr doubleValue] == 0) {
        return @"0";
    }
    
    NSArray *moneyArray = [moneyStr componentsSeparatedByString:@"."];
    NSString *lastStr = [moneyArray lastObject];
    NSInteger lastMoney = [lastStr integerValue];
    if(lastMoney == 0)
    {
        return [moneyArray firstObject];
    }
    
    NSString *newStr = moneyStr;
    if ([moneyStr containsString:@"."]) {
        NSRange range;
        range = [moneyStr rangeOfString:@"."];
        if (range.location != NSNotFound) {
            if (moneyStr.length - range.location >1) {
                for (NSInteger i = moneyStr.length - 1; i > range.location ; i --) {
                    char c = [moneyStr characterAtIndex:i];
                    NSString *itemStr = [NSString stringWithFormat:@"%c",c];
                    if ([itemStr isEqualToString:@"0"]){
                        newStr = [moneyStr substringToIndex:i];
                    }else{
                        break;
                    }
                }
                return newStr;
            }else
            {
                return newStr;
            }
        }else{
            return newStr;
        }
    }else
    {
        return newStr;
    }
}

// 提高精度计算方法


/**
 * 计算UIlabel最后一个字符的位置
 */
+ (CGPoint )caculteLastPoint:(YYLabel *)label
{
    if (label == nil) {
        return CGPointZero;
    }
    CGPoint lastPoint;
    CGFloat midViewWidth = SCREENBOUNDS.size.width - 97 - 30;
    CGSize sz = [label.text sizeWithAttributes:@{NSFontAttributeName:label.font}];
    YYTextLayout *layout = [YYTextLayout layoutWithContainerSize:CGSizeMake(midViewWidth, CGFLOAT_MAX) text:label.attributedText];
    CGSize linesz = layout.textBoundingSize;
    if(sz.width <= linesz.width) //判断是否折行
    {
        lastPoint = CGPointMake(sz.width,0);
    }
    else
    {
        NSLog(@"%f",label.frame.origin.x);
        lastPoint = CGPointMake((int)sz.width % (int)linesz.width,linesz.height - sz.height);
    }
    
    return lastPoint;
}


/**
 * 播放音频文件
 */
+ (void)playAudioFile
{
    NSURL * url = [[NSBundle mainBundle] URLForResource:@"7586.wav" withExtension:nil];
    //2、设置系统的音效文件
    SystemSoundID soundID;
    
    //3、创建音效文件
    AudioServicesCreateSystemSoundID((__bridge CFURLRef _Nonnull)(url), &soundID);
    
    //4、播放音效文件，带振动的播放
    AudioServicesPlayAlertSound(soundID);
    
    
    //如果是不带振动的话那就是
//    AudioServicesPlaySystemSound(soundID);
    
    //5、不需要播放了，就去释放音效所占用的内存
    //AudioServicesDisposeSystemSoundID(soundID);
}

/**
 * 当前时间是否在时间段内 (完整时间)
 */
+ (BOOL)judgeTimeByStartAndEnd:(NSString *)startStr EndTime:(NSString *)endStr
{
    //获取当前时间
    NSDate *today = [NSDate date];
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    // 时间格式,建议大写    HH 使用 24 小时制；hh 12小时制
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString * todayStr=[dateFormat stringFromDate:today];//将日期转换成字符串
    today=[ dateFormat dateFromString:todayStr];//转换成NSDate类型。日期置为方法默认日期
    //start end 格式 "2016-05-18 9:00:00"
    NSDate *start = [dateFormat dateFromString:startStr];
    NSDate *expire = [dateFormat dateFromString:endStr];
    
    if ([today compare:start] == NSOrderedDescending && [today compare:expire] == NSOrderedAscending) {
        return YES;
    }
    return NO;
}

/**
 * 对生成的中文助记词重新处理
 */
+ (NSString *)rehandleChineseCode:(NSString *)chineseCode
{
    if (![self IsChinese:chineseCode]) {
        return chineseCode;
    }
    
    NSMutableString *str = [@"" mutableCopy];
    for (int i = 0; i < chineseCode.length; i ++) {
        NSString *indexStr = [chineseCode substringWithRange:NSMakeRange(i, 1)];
        if (![indexStr isEqualToString:@" "]) {
            [str appendString:indexStr];
        }
    }

    [str insertString:@" " atIndex:12];
    [str insertString:@" " atIndex:9];
    [str insertString:@" " atIndex:6];
    [str insertString:@" " atIndex:3];
    
    return str;
}

/**
 * 判断是否是中文
 */
+(BOOL)IsChinese:(NSString *)str
{
    for(int i=0; i< [str length];i++)
    {
        int a = [str characterAtIndex:i];
        if( a > 0x4e00 && a < 0x9fff)
        {
            return YES;
        }
    }
    return NO;
}

/**
 * 提取ImToken中的地址
 */
+ (NSString *)queryImTokenAddress:(NSString *)imTokenAddress
{
    NSString *regularStr = @"(?<=:).*(?=\\?)";
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:regularStr options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *result = [regular firstMatchInString:imTokenAddress options:NSMatchingReportCompletion range:NSMakeRange(0, imTokenAddress.length - 1)];
    NSRange range = result.range;
    return [imTokenAddress substringWithRange:range];
}

/**
 * 初步判断地址是否合格
 */
+ (BOOL)judgeAddress:(NSString *)addressStr type:(NSString *)coin
{
    if (addressStr == nil || [addressStr isEqualToString:@""]) {
        return false;
    }
    
    if ([coin isEqualToString:@"DCR"])
    {
        if (addressStr.length < 2) {
            return false;
        }
        NSString *subStr = [addressStr substringToIndex:2];
        if ([subStr isEqualToString:@"Ds"]) {
            return true;
        }
    }
    else if ([coin isEqualToString:@"ETH"] || [coin isEqualToString:@"ETC"])
    {
        if (addressStr.length < 2) {
            return false;
        }
        NSString *subStr = [addressStr substringToIndex:2];
        if ([subStr isEqualToString:@"0x"]) {
            return true;
        }
    }
    else if ([coin isEqualToString:@"LTC"])
    {
        if (addressStr.length < 1) {
            return false;
        }
        NSString *subStr = [addressStr substringToIndex:1];
        if ([subStr isEqualToString:@"L"]) {
            return true;
        }
    }
    else if ([coin isEqualToString:@"ZEC"])
    {
        if (addressStr.length < 1) {
            return false;
        }
        NSString *subStr = [addressStr substringToIndex:1];
        if ([subStr isEqualToString:@"t"]) {
            return true;
        }
    }
    else if ([coin isEqualToString:@"ATOM"])
    {
        if (addressStr.length < 1) {
            return false;
        }
        NSString *subStr = [addressStr substringToIndex:6];
        if ([subStr isEqualToString:@"cosmos"]) {
            return true;
        }
    }
    else if ([coin isEqualToString:@"NEO"])
    {
        if (addressStr.length < 1) {
            return false;
        }
        return true;
    }
    else
    {
        if (addressStr.length < 2) {
            return false;
        }
        NSString *subStr = [addressStr substringToIndex:2];
        if (![subStr isEqualToString:@"Ds"] && ![subStr isEqualToString:@"0x"]) {
            return true;
        }
        
    }
    return false;
}

+ (CAGradientLayer *)setGradualChangingColor:(UIView *)view formColor:(UIColor *)fromHexColor toColor:(UIColor *)toHexColor andCornerRadius:(CGFloat)cornerRadius
{
    //CAGradientLayer类对其绘制渐变色背景色、填充层的形状包括圆角
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    
    gradientLayer.frame = view.bounds;
    // 创建渐变色数组，需要转换为CGColor颜色
    gradientLayer.colors = @[(__bridge id)fromHexColor.CGColor,(__bridge id)toHexColor.CGColor];
    // z设置渐变色颜色方向，左上点为（0，0），右下点为（1，1）
    gradientLayer.startPoint = CGPointMake(0, 0);
    gradientLayer.endPoint   = CGPointMake(1, 0);
    gradientLayer.cornerRadius = cornerRadius;
    // 设置颜色变化点，取值范围 0.0~1.0
    gradientLayer.locations = @[@0.4,@1.0];
    
    return gradientLayer;
}
@end
