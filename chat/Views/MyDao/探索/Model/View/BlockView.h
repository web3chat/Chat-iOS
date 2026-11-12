//
//  BlockView.h
//  PWallet
//
//  Created by 宋刚 on 2019/3/20.
//  Copyright © 2019年 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ItemAction) (NSInteger index);
@interface BlockView : UIView
@property(nonatomic,copy)ItemAction itemAction;
- (instancetype)initTexts:(NSArray *)texts Title:(NSString *)title;
@end

NS_ASSUME_NONNULL_END
