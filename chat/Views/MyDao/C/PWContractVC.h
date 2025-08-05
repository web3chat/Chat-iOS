//
//  PWContractVC.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2025/4/9.
//  Copyright © 2025 fzm. All rights reserved.
//

#import "CommonViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^PWContractVCBlock)(void);

@interface PWContractVC : CommonViewController

@property (nonatomic) PWContractVCBlock contractBlock;
@end

NS_ASSUME_NONNULL_END
