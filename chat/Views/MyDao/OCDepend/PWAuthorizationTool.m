//
//  PWAuthorizationTool.m
//  PWallet
//
//  Created by fzm on 2018/10/15.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "PWAuthorizationTool.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

@implementation PWAuthorizationTool

/// 「部分照片」（iOS 14+ 的 limited）也算可用：只能读到已授权的那几张，但不是拒绝
+ (BOOL)fzm_photoAccessGranted:(PHAuthorizationStatus)status {
    if (status == PHAuthorizationStatusAuthorized) {
        return YES;
    }
    if (@available(iOS 14, *)) {
        return status == PHAuthorizationStatusLimited;
    }
    return NO;
}

+ (void)detectionCameraAuthorized:(AuthorizedBlock)authorizedBlock Denied:(DeniedBlock)deniedBlock {
    
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        NSString * mediaType = AVMediaTypeVideo;
        AVAuthorizationStatus  authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
        if (authorizationStatus == AVAuthorizationStatusNotDetermined) {
            //还未请求过权限
            [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        // 用户第一次同意了访问相机权限
                        if (authorizedBlock) {
                            authorizedBlock();
                        }
                    } else {
                        if (deniedBlock) {
                            deniedBlock();
                        }
                    }
                });
            }];
        }else if (authorizationStatus == AVAuthorizationStatusRestricted || authorizationStatus == AVAuthorizationStatusDenied) {
            // 无相机权限
            if (deniedBlock) {
                deniedBlock();
            }
        }else if (authorizationStatus == AVAuthorizationStatusAuthorized) {
            //相机可用
            if (authorizedBlock) {
                authorizedBlock();
            }
        }
    } else {
        //硬件问题
        if (deniedBlock) {
            deniedBlock();
        }
    }
}

+ (void)detectionPhotoAuthorized:(AuthorizedBlock)authorizedBlock Denied:(DeniedBlock)deniedBlock {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device) {
        // 判断授权状态
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusNotDetermined) { // 用户还没有做出选择
            // 弹框请求用户授权
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self fzm_photoAccessGranted:status]) { // 用户第一次同意了访问相册权限
                        if (authorizedBlock) {
                            authorizedBlock();
                        }
                    } else { // 用户第一次拒绝了访问相机权限
                        if (deniedBlock) {
                            deniedBlock();
                        }
                    }
                });
            }];
        } else if ([self fzm_photoAccessGranted:status]) { // 用户允许当前应用访问相册（含「部分照片」）
            if (authorizedBlock) {
                authorizedBlock();
            }
        } else { // 拒绝 / 系统限制
            if (deniedBlock) {
                deniedBlock();
            }
        }
    }
}
@end
