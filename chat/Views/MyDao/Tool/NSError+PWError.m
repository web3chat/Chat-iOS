//
//  NSError+PWError.m
//  PWallet
//
//  Created by gg on 2018/5/16.
//  Copyright © 2018年 gg. All rights reserved.
//

#import "NSError+PWError.h"

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
        errorMessage = @"无网络,请检查网络连接";
    } else if (errorCode == NSURLErrorTimedOut) {
        errorMessage = @"请求超时,请检查网络连接";
    } else if (errorCode == NSURLErrorDNSLookupFailed) {
        errorMessage = @"请求失败,请稍后再试";
    } else if (errorCode == NSURLErrorBadServerResponse) {
        errorMessage = @"未找到服务，请稍后再试";
    } else if (errorCode == NSURLErrorCannotConnectToHost) {
        errorMessage = @"连接错误,请稍后再试";
    } else if ([errorMessage isEqualToString:@""]) {
        //没有错误信息则展示 网络连接错误
         errorMessage = @"网络连接错误,请稍后再试";
    }
//#endif
    return [self errorWithDomain:domain code:errorCode userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
}

@end
