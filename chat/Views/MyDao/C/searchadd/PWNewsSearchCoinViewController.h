//
//  PWNewsSearchCoinViewController.h
//  PWallet
//
//  Created by 郑晨 on 2020/1/3.
//  Copyright © 2020 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalWallet.h"
#import "Depend.h"

NS_ASSUME_NONNULL_BEGIN
typedef void(^SearchDismissBlock)(void);
@interface PWNewsSearchCoinViewController : CommonViewController
@property (nonatomic, strong) LocalWallet *selectedWallet;
@property(nonatomic,copy)NSArray *localArray;
@property(nonatomic) SearchDismissBlock searchDismissBlock;

@end

NS_ASSUME_NONNULL_END
