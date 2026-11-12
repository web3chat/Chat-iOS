//
//  PWSearchCoinChildViewController.h
//  PWallet
//
//  Created by 郑晨 on 2020/1/7.
//  Copyright © 2020 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Depend.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWSearchCoinChildViewController : CommonViewController
/** 自己对应第几栏（父页面的通知是广播的，child 靠它只处理自己那一栏） */
@property (nonatomic) NSInteger tabIndex;


@end

NS_ASSUME_NONNULL_END
