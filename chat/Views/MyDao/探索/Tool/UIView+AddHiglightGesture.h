//
//  UIView+AddHiglightGesture.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//  
//  长按和单击特效



#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^GestureBlock)(void);
@interface UIView (AddHiglightGesture)
@property(nonatomic,strong) UIView* translucenceView;
-(void)addTapWithBlock:(GestureBlock)block;
-(void)addLongPressWithBlock:(GestureBlock)block;
-(void)addTapAndLongPressWith:(GestureBlock)block;
@end

NS_ASSUME_NONNULL_END
