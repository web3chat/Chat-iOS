//
//  PWAuthorizationTool.m
//  PWallet
//
//  Created by 陈健 on 2018/10/15.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "PWAuthorizationTool.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

@implementation PWAuthorizationTool
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
                    if (status == PHAuthorizationStatusAuthorized) { // 用户第一次同意了访问相册权限
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
        } else if (status == PHAuthorizationStatusAuthorized) { // 用户允许当前应用访问相册
            if (authorizedBlock) {
                authorizedBlock();
            }
        } else if (status == PHAuthorizationStatusDenied) { // 用户拒绝当前应用访问相册
            if (deniedBlock) {
                deniedBlock();
            }
        } else if (status == PHAuthorizationStatusRestricted) {//由于系统原因, 无法访问相册
            if (deniedBlock) {
                deniedBlock();
            }
        }
    }
}
@end
