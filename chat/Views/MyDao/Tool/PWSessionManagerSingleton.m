//
//  PWSessionManagerSingleton.m
//  PWallet
//
//  Created by 陈健 on 2018/5/16.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "PWSessionManagerSingleton.h"
#import "AFNetworking.h"
#import <IPToolManager.h>
#import "Depend.h"
static inline NSString * GetCurrentIp() {
    NSString * ipStr = [[IPToolManager sharedManager] currentIpAddressByType:NetTypeWifi];
    if ([ipStr isEqualToString:@"0.0.0.0"]) {
        ipStr = [[IPToolManager sharedManager] currentIpAddressByType:NetTypeCellular];
    }
    return ipStr;
}

@interface PWSessionManagerSingleton ()

@end

static AFHTTPSessionManager *shareManager = nil;
@implementation PWSessionManagerSingleton
+ (AFHTTPSessionManager *) sharedSessionManager{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManager = [AFHTTPSessionManager manager];
        //配置shareManager
        // 设置请求以及相应的序列化器
        shareManager.requestSerializer = [AFHTTPRequestSerializer serializer];
        shareManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        // 设置超时时间
        shareManager.requestSerializer.timeoutInterval = 30.0;
        // 设置响应内容的类型
        shareManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",@"application/octet-stream", @"text/json", @"text/javascript",@"text/html",@"text/plain",nil];
        

        NSString *UUID = [self getUUID];//使用找币模块里面设置的UUID 保持统一
        NSString *ipStr = GetCurrentIp();
        [shareManager.requestSerializer setValue:@"wallet" forHTTPHeaderField:@"Fzm-Request-Source"];
        [shareManager.requestSerializer setValue:@"ios" forHTTPHeaderField:@"FZM-REQUEST-OS"];
        [shareManager.requestSerializer setValue:UUID forHTTPHeaderField:@"FZM-REQUEST-UUID"];
        [shareManager.requestSerializer setValue:ipStr forHTTPHeaderField:@"FZM-USER-IP"];
        
    });
    
    NSString *version = [NSString stringWithFormat:@"V%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];

    NSString *deviceiNFO = [UIDevice currentDevice].name;
    deviceiNFO = [deviceiNFO stringByAppendingString:[UIDevice currentDevice].model];
    deviceiNFO = [deviceiNFO stringByAppendingString:[UIDevice currentDevice].systemName];
    deviceiNFO = [deviceiNFO stringByAppendingString:[UIDevice currentDevice].systemVersion];
    
    [shareManager.requestSerializer setValue:version forHTTPHeaderField:@"version"];
    [shareManager.requestSerializer setValue:deviceiNFO forHTTPHeaderField:@"device"];
    
    [shareManager.requestSerializer setValue:@"1" forHTTPHeaderField:@"FZM-PLATFORM-ID"];
    [shareManager.requestSerializer setValue:[GoFunction getSeesionIdWithAppSymbol:APPSYMBOL AppKey:APPKEY] forHTTPHeaderField:@"SessionId"];
   
    return shareManager;
}

// 获取设备UUID
+ (NSString *)getUUID {
    NSString *u = [SAMKeychain passwordForService:@"keychain" account:@"key_chain"];
    
    if (!u || u.length == 0) {
        CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
        NSString *strUUID = (NSString *)CFBridgingRelease(CFUUIDCreateString (kCFAllocatorDefault,uuidRef));
        [self saveUUID:strUUID];
        u = strUUID;
    }
    NSLog(@"device is %@",u);
    
    return u;
}

+ (void)saveUUID:(NSString *)uuid {
    
    [SAMKeychain setPassword:uuid forService:@"keychain" account:@"key_chain"];
    
}

@end
