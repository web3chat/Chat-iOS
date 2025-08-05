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

- (void)show;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
