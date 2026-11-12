//
//  DappAlertSheetView.h
//  PWallet
//
//  Created by 郑晨 on 2021/5/27.
//  Copyright © 2021 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"

NS_ASSUME_NONNULL_BEGIN
typedef enum : NSUInteger {
    DappAlertSheetTypeSign = 0, // typesign
    DappAlertSheetTypePersonalSign , // persionalsign
    DappAlertSheetTypePay, // 支付
    
} DappAlertSheetType;


typedef void(^DappAlertBlock)(NSString *passwdStr,NSString *gas,NSString *gasPrice);
@interface DappAlertSheetView : UIView

@property (nonatomic) DappAlertSheetType dappType;
@property (nonatomic) DappAlertBlock dappBlock;
- (instancetype)initWithFrame:(CGRect)frame withType:(DappAlertSheetType)dappType withData:(NSDictionary *)dict withCoin:(LocalCoin *)coin;

- (void)showWithView:(UIView *)view;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
