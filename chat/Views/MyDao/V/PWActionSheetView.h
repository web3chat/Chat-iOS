//
//  PWActionSheetView.h
//  PWallet
//
//  Created by 郑晨 on 2019/12/10.
//  Copyright © 2019 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"
#import "CoinPrice.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^ActionSheetViewBlock)(LocalCoin *coin, CoinPrice *coinprice);

typedef enum : NSUInteger {
    ActionViewTypeHome,
    ActionViewTypePrikey,
} ActionViewType;

@interface PWActionSheetView : UIView

@property (nonatomic) ActionSheetViewBlock actionSheetViewBlock;
@property (nonatomic) ActionViewType actionViewType;
- (instancetype)initWithFrame:(CGRect)frame Title:(NSString *)title dataArray:(NSArray *)dataArray type:(ActionViewType)actionViewType;
- (void)show;


@end

NS_ASSUME_NONNULL_END
