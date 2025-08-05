//
//  ChoiceCoinView.h
//  chat
//
//  Created by 郑晨 on 2025/3/5.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^ChoiceCoinViewBlock)(LocalCoin *coin);

@interface ChoiceCoinView : UIView

@property (nonatomic) ChoiceCoinViewBlock choiceCoinBlock;

- (void)showwithView:(UIView *)view;
@end

NS_ASSUME_NONNULL_END
