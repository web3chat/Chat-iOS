//
//  SGNetWork.m
//  PWallet
//
//  Created by 宋刚 on 2018/3/28.
//  Copyright © 2018年 宋刚. All rights reserved.
//

#import "SGNetWork.h"
#import "GoFunction.h"

@interface SGNetWork()
@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@end

@implementation SGNetWork
static SGNetWork *networkManager = nil;
/**
 *  单例
 *
 *  @return 网络请求类的实例，可在请求时直接调用方法，也是一个直接初始化的方式
 */
+ (instancetype)defaultManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!networkManager) {
            networkManager = [[SGNetWork alloc] init];
        }
    });
    return networkManager;
}

/**
 初始化，APP每次启动时会调用该方法，运行时不会调用
 
 @return 基本的请求设置
 */
- (instancetype)init {
    if (self = [super init]) {
        self.sessionManager = [AFHTTPSessionManager manager];
        // 设置请求以及相应的序列化器
        self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        self.sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        // 设置超时时间
        self.sessionManager.requestSerializer.timeoutInterval = 60.0;
        // 设置响应内容的类型
        self.sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",@"application/octet-stream", @"text/json", @"text/javascript",@"text/html",@"text/plain",nil];
        
    }
    return self;
}

#pragma mark 常用网络请求


/**
 常用网络请求方式
 
 @param requestMethod 请求方试
 @param serverUrl 服务器地址
 @param apiPath 方法的链接
 @param parameters 参数
 @param progress 进度
 @param success 成功
 @param failure 失败
 @return return value description
 */
- (nullable NSURLSessionDataTask *)sendRequestMethod:(HTTPMethod)requestMethod
                                           serverUrl:(nonnull NSString *)serverUrl
                                             apiPath:(nonnull NSString *)apiPath
                                          parameters:(nullable id)parameters
                                            progress:(nullable void (^)(NSProgress * _Nullable progress))progress
                                             success:(nullable void(^) (BOOL isSuccess, id _Nullable responseObject))success
                                             failure:(nullable void(^) (NSString * _Nullable errorMessage))failure {
    // 请求的地址
    NSString *requestPath = [serverUrl stringByAppendingPathComponent:apiPath];
    NSURLSessionDataTask * task = nil;
//    [self.sessionManager.requestSerializer setValue: [PWUtils getLang] forHTTPHeaderField:@"lang"];
    [self.sessionManager.requestSerializer setValue:@"1" forHTTPHeaderField:@"FZM-PLATFORM-ID"];
    //版本号 设备信息
    NSString *version = [NSString stringWithFormat:@"V%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];

    NSString *deviceiNFO = [UIDevice currentDevice].name;
    deviceiNFO = [deviceiNFO stringByAppendingString:[UIDevice currentDevice].model];
    deviceiNFO = [deviceiNFO stringByAppendingString:[UIDevice currentDevice].systemName];
    deviceiNFO = [deviceiNFO stringByAppendingString:[UIDevice currentDevice].systemVersion];

    [self.sessionManager.requestSerializer setValue:version forHTTPHeaderField:@"version"];
    [self.sessionManager.requestSerializer setValue:deviceiNFO forHTTPHeaderField:@"device"];

    
    switch (requestMethod) {
        case HTTPMethodGET:
        {
            
            task = [self.sessionManager GET:requestPath parameters:parameters headers:nil progress:progress success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                if (success) {
                    success(YES,responseObject);
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                if (failure) {
                    failure([self failHandleWithErrorResponse:error task:task]);
                }
            }];
            
        }
            break;
            
        case HTTPMethodPOST:
        {
            
            task = [self.sessionManager POST:requestPath parameters:parameters headers:nil progress:progress success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                if (success) {
                    success(YES,responseObject);
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                NSLog(@"%@",error);
                if (failure) {
                    failure([self failHandleWithErrorResponse:error task:task]);
                }
            }];
            
        }
            break;
            
        case HTTPMethodPUT:
        {
            
            task = [self.sessionManager PUT:requestPath parameters:parameters headers:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                if (success) {
                    success(YES,responseObject);
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                if (failure) {
                    failure([self failHandleWithErrorResponse:error task:task]);
                }
            }];
        }
            break;
            
        case HTTPMethodPATCH:
        {
            task = [self.sessionManager PATCH:requestPath parameters:parameters headers:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                if (success) {
                    success(YES,responseObject);
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                if (failure) {
                    failure([self failHandleWithErrorResponse:error task:task]);
                }
            }];
        }
            break;
            
        case HTTPMethodDELETE:
        {
            
            task = [self.sessionManager DELETE:requestPath parameters:parameters headers:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                if (success) {
                    success(YES,responseObject);
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                if (failure) {
                    failure([self failHandleWithErrorResponse:error task:task]);
                }
            }];
        }
            break;
    }
    return task;
}

#pragma mark POST 上传图片


#pragma mark 报错信息
/**
 处理报错信息
 
 @param error AFN返回的错误信息
 @param task 任务
 @return description
 */
- (NSString *)failHandleWithErrorResponse:( NSError * _Nullable )error task:( NSURLSessionDataTask * _Nullable )task {
    __block NSString *message = nil;
    // 这里可以直接设定错误反馈，也可以利用AFN 的error信息直接解析展示
    NSData * _Nullable afNetworking_errorMsg = [error.userInfo objectForKey:AFNetworkingOperationFailingURLResponseDataErrorKey];
    if (!afNetworking_errorMsg) {
        message = @"网络不给力，请稍后重试";
    }
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    NSInteger responseStatue = response.statusCode;
    if (responseStatue >= 500) {  // 网络错误
        message = @"服务器维护升级中,请耐心等待";
    } else if (responseStatue >= 400) {
        // 错误信息
        NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:afNetworking_errorMsg options:NSJSONReadingAllowFragments error:nil];
        message = responseObject[@"error"];
    }

    return message;
}
@end
