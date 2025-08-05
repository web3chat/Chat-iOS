//
//  PWNetworkingTool.h
//  PWallet
//
//  Created by 陈健 on 2018/5/16.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>

//网络请求成功回调block
typedef void (^requestSuccessBlock)(id object);
//网络请求失败回调block
typedef void (^requestFailureBlock)(NSError *error);

@interface PWNetworkingTool : NSObject
/**
 *  get请求
 *
 *  @param url          url
 *  @param parameters   请求头
 *  @param successBlock success
 *  @param failureBlock failed
 */
+ (void)getRequestWithUrl:(NSString *)url
                 parameters:(NSDictionary *)parameters
             successBlock:(requestSuccessBlock)successBlock
              failureBlock:(requestFailureBlock)failureBlock;
/**
 *  post请求
 *
 *  @param url          url
 *  @param parameters   请求头
 *  @param successBlock success
 *  @param failureBlock failed
 */
+ (void)postRequestWithUrl:(NSString *)url
                  parameters:(id)parameters
              successBlock:(requestSuccessBlock)successBlock
               failureBlock:(requestFailureBlock)failureBlock;


/**
 向服务器上传文件

 *  @param url       要上传的文件接口
 *  @param parameters 上传的参数
 *  @param fileData  上传的文件\数据
 *  @param fieldName 服务对应的字段
 *  @param fileName  上传到时服务器的文件名
 *  @param mimeType  上传的文件类型
 *  @param successBlock success
 *  @param failureBlock failed
 */
+ (void)postRequestWithUrl:(NSString *)url
                parameters:(NSDictionary *)parameters
                      data:(NSData *)fileData
                 FieldName:(NSString *)fieldName
                  FileName:(NSString *)fileName
                  MimeType:(NSString *)mimeType
              successBlock:(requestSuccessBlock)successBlock
              failureBlock:(requestFailureBlock)failureBlock;



@end
