//
//  PWAuthorizationTool.h
//  PWallet
//  判断各类权限 相机 相册
//  Created by 陈健 on 2018/10/15.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void(^AuthorizedBlock)(void);
typedef void(^DeniedBlock)(void);

@interface PWAuthorizationTool : NSObject
/**
 *  判断相机权限
 *  @param authorizedBlock   有权限回调
 *  @param deniedBlock       无权限回调请求回调
 */
+ (void)detectionCameraAuthorized:(AuthorizedBlock)authorizedBlock Denied:(DeniedBlock)deniedBlock;

/**
 *  判断相册权限
 *  @param authorizedBlock   有权限回调
 *  @param deniedBlock       无权限回调请求回调
 */
+ (void)detectionPhotoAuthorized:(AuthorizedBlock)authorizedBlock Denied:(DeniedBlock)deniedBlock;
@end
