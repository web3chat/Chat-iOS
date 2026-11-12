//
//  NSError+PWError.m
//  PWallet
//
//  Created by gg on 2018/5/16.
//  Copyright © 2018年 gg. All rights reserved.
//

#import "NSError+PWError.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@implementation NSError (PWError)
+ (NSError *) errorWithCode:(NSInteger) errorCode errorMessage:(NSString *) errorMessage {
    NSString *domain = @"PWiOSError";
    if (errorMessage == nil) {
        errorMessage = @"";
    }
    
//#ifdef DEBUG
//
//#else
    //包装Release模式下的错误展示
    if (errorCode == NSURLErrorNotConnectedToInternet) {
        // ⚠️ key 必须和 Localizable.strings 里一模一样（那里是全角逗号），
        // 写成半角逗号会命不中任何语言（连中文都是"原文直显"）
        errorMessage = L(@"无网络，请检查网络连接");
    } else if (errorCode == NSURLErrorTimedOut) {
        errorMessage = L(@"请求超时,请检查网络连接");
    } else if (errorCode == NSURLErrorDNSLookupFailed) {
        errorMessage = L(@"请求失败,请稍后再试");
    } else if (errorCode == NSURLErrorBadServerResponse) {
        errorMessage = L(@"未找到服务，请稍后再试");
    } else if (errorCode == NSURLErrorCannotConnectToHost) {
        errorMessage = L(@"连接错误,请稍后再试");
    } else if ([errorMessage isEqualToString:@""]) {
        //没有错误信息则展示 网络连接错误（key 用全角逗号，与语言文件一致）
         errorMessage = L(@"网络连接错误，请稍后再试");
    }
//#endif
    return [self errorWithDomain:domain code:errorCode userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
}

@end
