//
//  WebSheetView.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2024/1/10.
//  Copyright © 2024 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


/// 使用 `NS_ENUM` 以便 Swift 中可写为 `.refresh`、`.copyUrl` 等（`typedef enum` 会生成 `WebSheetTypeRefresh` 等长名称，易与简写 case 不一致）。
typedef NS_ENUM(NSUInteger, WebSheetType) {
    WebSheetTypeChangeAccount, // 切换账号
    WebSheetTypeRefresh, // 刷新
    WebSheetTypeCopyUrl, // 复制链接
    WebSheetTypeOpenUrl, // 在浏览器打开
    WebSheetTypeExit, // 退出
    WebSheetTypeLike, // 收藏
};

typedef void(^WebSheetBlock)(WebSheetType sheetType);

@interface WebSheetView : UIView

@property (nonatomic) WebSheetBlock sheetBlock;
@property (nonatomic) WebSheetType sheetType;

/// Swift：`presentSheet(on:)`，避免与 `UIView` 扩展里的 `show(_ error: Error)` 同名冲突。
- (void)showWithView:(UIView *)view NS_SWIFT_NAME(presentSheet(on:));
- (instancetype)initWithFrame:(CGRect)frame isLiked:(BOOL)isLiked;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
