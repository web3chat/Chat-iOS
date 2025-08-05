//
//  PWNewsHomeViewController.h
//  PWallet
//
//  Created by 郑晨 on 2019/11/29.
//  Copyright © 2019 陈健. All rights reserved.
//

#import "CommonViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^HomeViewBlock)(void);

typedef void(^HomeTransferBlock)(NSString *coinType,NSString *txId,NSString *sessionId);

@interface PWNewsHomeViewController : CommonViewController

@property (nonatomic) HomeViewBlock homeViewBlock;
@property (nonatomic) HomeTransferBlock homeTransferBlock;
@end

NS_ASSUME_NONNULL_END
