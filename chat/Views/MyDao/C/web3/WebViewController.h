//
//  WebViewController.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <WKWebViewJavascriptBridge.h>
#import "ScanViewController.h"
#import "PWAlertController.h"
#import "LocalWallet.h"
#import "PWDataBaseManager.h"
#import "GoFunction.h"

typedef enum : NSUInteger {
    FaceIDTypeImportSeed = 0, // 树莓派
    FaceIDTypeSignRawTransaction, // 签名
    FaceIDTypeCoinsWithoutTxGroup, // 组签名
} FaceIDType;

typedef void(^WebviewBackBlock)(void);

@interface WebViewController : CommonViewController
@property (nonatomic, copy) NSString * webUrl;
@property (nonatomic, copy) NSString *iconUrl;
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *fromType;
@property (nonatomic) WebviewBackBlock backBlock;
@property (nonatomic) FaceIDType faceIDType;

@end
