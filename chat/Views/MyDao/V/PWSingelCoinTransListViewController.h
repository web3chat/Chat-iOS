//
//  PWSingelCoinTransListViewController.h
//  PWallet
//
//  Created by 郑晨 on 2021/7/12.
//  Copyright © 2021 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LocalCoin.h"
#import "CommonViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWSingelCoinTransListViewController : CommonViewController

@property (nonatomic, copy) LocalCoin *selectedCoin;
@property (nonatomic, copy) NSString *toAddr;

@end

NS_ASSUME_NONNULL_END
