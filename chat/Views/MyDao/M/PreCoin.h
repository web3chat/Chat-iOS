//
//  PreCoin.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/7/18.
//  Copyright © 2023 fzm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreCoin : NSObject

+ (NSArray*)getPreCoinArr;

/**
 * 添加币到钱包
 */
- (void)addCoinIntoW:(NSString *)rememberCode;

@end

NS_ASSUME_NONNULL_END
