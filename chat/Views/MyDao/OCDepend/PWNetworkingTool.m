//
//  PWNetworkingTool.m
//  PWallet
//
//  Created by fzm on 2018/5/16.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "PWNetworkingTool.h"
#import "AFNetworking.h"
#import "PWSessionManagerSingleton.h"
#import "NSError+PWError.h"
#import "PWDataBaseManager.h"

// 只在 Debug 打印请求/响应；Release 不再把 URL、参数、响应体写进系统日志。
#if DEBUG
#define PWNetLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#define PWNetLog(fmt, ...) do {} while (0)
#endif


@implementation PWNetworkingTool

+ (void)getRequestWithUrl:(NSString *)url
                 parameters:(NSDictionary *)parameters
             successBlock:(requestSuccessBlock)successBlock
              failureBlock:(requestFailureBlock)failureBlock {
    AFHTTPSessionManager *manager = [PWSessionManagerSingleton sharedSessionManager];
    PWNetLog(@"PWNetworkingTool请求URL:%@",url);
    PWNetLog(@"PWNetworkingTool请求参数:%@",parameters);
    
    [manager GET:url parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self requestResponseObject:responseObject successBlock:successBlock failureBlock:failureBlock];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (failureBlock) {
            failureBlock([NSError errorWithCode:error.code errorMessage:error.description]);
        }
    }];
    
}

+ (void)postRequestWithUrl:(NSString *)url
                  parameters:(id)parameters
              successBlock:(requestSuccessBlock)successBlock
               failureBlock:(requestFailureBlock)failureBlock {
    PWNetLog(@"PWNetworkingTool请求URL:%@",url);
    PWNetLog(@"PWNetworkingTool请求参数:%@",parameters);
    AFHTTPSessionManager *manager = [PWSessionManagerSingleton sharedSessionManager];
   
    [manager POST:url parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self requestResponseObject:responseObject successBlock:successBlock failureBlock:failureBlock];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (failureBlock) {
            failureBlock([NSError errorWithCode:error.code errorMessage:error.description]);
        }
    }];
}

+ (void)postRequestWithUrl:(NSString *)url parameters:(NSDictionary *)parameters data:(NSData *)fileData FieldName:(NSString *)fieldName FileName:(NSString *)fileName MimeType:(NSString *)mimeType successBlock:(requestSuccessBlock)successBlock failureBlock:(requestFailureBlock)failureBlock
{
    PWNetLog(@"PWNetworkingTool请求URL:%@",url);
    PWNetLog(@"PWNetworkingTool请求参数:%@",parameters);
    AFHTTPSessionManager *manager = [PWSessionManagerSingleton sharedSessionManager];
    [manager.requestSerializer setValue:@"coin_wallet" forHTTPHeaderField:@"FZM-Ca-AppKey"];
    
    [manager POST:url parameters:parameters headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:fileData
                                    name:fieldName
                                fileName:fileName
                                mimeType:mimeType];
        } progress:^(NSProgress * _Nonnull uploadProgress) {
            
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [self requestResponseObject:responseObject successBlock:successBlock failureBlock:failureBlock];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            if (failureBlock) {
                failureBlock([NSError errorWithCode:error.code errorMessage:error.description]);
            }
        }];
    
    
}

/**
 *  对http请求后响应的处理
 *
 *  @param responseObject    请求返回的响应对象
 *  @param successBlock      处理响应数据后的成功回调
 *  @param failureBlock      处理响应数据后的失败回调
 */
+ (void)requestResponseObject:(id)responseObject successBlock:(requestSuccessBlock)successBlock
                  failureBlock:(requestFailureBlock)failureBlock {
    
     responseObject = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
    PWNetLog(@"PWNetworkingTool请求返回信息%@",responseObject);
    if (responseObject[@"code"] != nil) {
        if ([responseObject[@"code"] integerValue] == 0 || [responseObject[@"code"] integerValue] == 200) {
            if (successBlock) {
                successBlock(responseObject[@"data"]);
            }
        } else {
            if ([responseObject[@"code"] integerValue] == 401) {
               
                
                NSString *errorMessage = responseObject[@"msg"];
                if (errorMessage == nil) {
                    errorMessage = responseObject[@"message"];
                }
                if (errorMessage == nil) {
                    errorMessage = responseObject[@"error"];
                }
                failureBlock([NSError errorWithCode:[responseObject[@"code"] integerValue] errorMessage:errorMessage]);
                
                
            }else if (failureBlock) {
                NSString *errorMessage = responseObject[@"msg"];
                if (errorMessage == nil) {
                    errorMessage = responseObject[@"message"];
                }
                if (errorMessage == nil) {
                    errorMessage = responseObject[@"error"];
                }
                failureBlock([NSError errorWithCode:[responseObject[@"code"] integerValue] errorMessage:errorMessage]);
            }
        }
    }
}
@end
