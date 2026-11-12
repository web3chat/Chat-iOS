//
//  PWChoiceFeeSheetView.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/11/17.
//  Copyright © 2023 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Depend.h"
NS_ASSUME_NONNULL_BEGIN


typedef void(^ChoiceFeeBlock)(NSDictionary *dict);

@interface PWChoiceFeeSheetView : UIView

@property (nonatomic) ChoiceFeeBlock choiceFeeBlock;
- (instancetype)initWithFrame:(CGRect)frame withCoin:(LocalCoin *)localCoin withDict:(NSDictionary *)dict;

/// 使用外部给定的档位数据（不再内部请求 gasPrice）
/// @param dataArr 4 个元素：最快/标准/经济/自定义，元素字段 name/value/detail/gas/gasPrice
/// @param gasLimit 自定义手输时默认的 Gas
/// @param selectedIndex 默认选中档（0~3）
- (instancetype)initWithFrame:(CGRect)frame
                      dataArr:(NSArray<NSDictionary *> *)dataArr
                     gasLimit:(NSString *)gasLimit
                selectedIndex:(NSInteger)selectedIndex;

- (void)show;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
