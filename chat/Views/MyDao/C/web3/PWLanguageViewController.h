//
//  PWLanguageViewController.h
//  PWallet
//
//  Created by 郑晨 on 2019/6/3.
//  Copyright © 2019 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommonViewController.h"
NS_ASSUME_NONNULL_BEGIN
typedef enum : NSUInteger {
    ChangeLang, // 多语言
    ChangeMoney,
    ChangeIP,
    ChangeNet, // 切换链网络
} ChangeType;
@interface PWLanguageViewController :CommonViewController
- (instancetype)initWithChangeType:(ChangeType)type;

@end

NS_ASSUME_NONNULL_END
