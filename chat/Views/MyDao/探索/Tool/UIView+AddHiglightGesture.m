//
//  UIView+AddHiglightGesture.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//  
//

#import "UIView+AddHiglightGesture.h"
#import <objc/runtime.h>
#import "Depend.h"
static NSString *translucenceViewKey = @"translucenceView";
@implementation UIView (AddHiglightGesture)

-(void)addTapAndLongPressWith:(GestureBlock)block{
    [self addLongPressWithBlock:block];
    [self addTapWithBlock:block];
}

-(void)addTapWithBlock:(GestureBlock)block{
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    
    @weakify(self)
    [[tap rac_gestureSignal] subscribeNext:^(__kindof UIGestureRecognizer * _Nullable x) {
        @strongify(self)
        block();
        self.translucenceView.alpha = 1;
        [UIView animateWithDuration:0.25 animations:^{
            self.translucenceView.alpha = 1;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.25 animations:^{
                self.translucenceView.alpha = 0;
            } completion:^(BOOL finished) {
                
            }];
        }];
    }];
    [self addGestureRecognizer:tap];
    
}
//长按的情况下仍然可以滑动
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]||[otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]){
        return YES;
    }
    return NO;
}

- (void)addLongPressWithBlock:(GestureBlock)block{
    //偏移大于10的情况下取消长按选中
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] init];
    __block CGPoint location;
    @weakify(self)
    [[longPress rac_gestureSignal] subscribeNext:^(__kindof UIGestureRecognizer * _Nullable x) {
        @strongify(self)
        
        UIWindow* window = [UIApplication sharedApplication].keyWindow;
        if (x.state == UIGestureRecognizerStateBegan) {
            location = [x locationInView:window];
            self.translucenceView.alpha = 1;
        }else if (x.state == UIGestureRecognizerStateEnded){
            if(fabs(location.y-[x locationInView:window].y)<=10 && fabs(location.x-[x locationInView:window].x)<=10 && self.translucenceView.alpha == 1){
                block();
            }
            self.translucenceView.alpha = 0;
            
        }else{
            if(fabs(location.y-[x locationInView:window].y)>10||fabs(location.x-[x locationInView:window].x)>10){
                self.translucenceView.alpha = 0;
            }
        }
    }];
    longPress.minimumPressDuration = 0.1;
    [self addGestureRecognizer:longPress];
}

- (void)setTranslucenceView:(UIView *)translucenceView{
   objc_setAssociatedObject(self, &translucenceViewKey, translucenceView, OBJC_ASSOCIATION_RETAIN);
}

- (UIView *)translucenceView{
    if (objc_getAssociatedObject(self, &translucenceViewKey) == nil) {
        UIView* translucenceView= [[UIView alloc] init];
        translucenceView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.6];
        [self addSubview:translucenceView];
        [translucenceView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.bottom.top.mas_equalTo(0);
        }];
         objc_setAssociatedObject(self, &translucenceViewKey, translucenceView, OBJC_ASSOCIATION_RETAIN);
    }
    
    return objc_getAssociatedObject(self, &translucenceViewKey);
}





@end
