//
//  PreCoin.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/7/18.
//  Copyright © 2023 fzm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
//网络请求成功回调block
typedef void (^successBlock)();
@interface PreCoin : NSObject

+ (NSArray*)getPreCoinArr;

/**
 * 添加币到钱包
 */
- (void)addCoinIntoW:(NSString *)rememberCode passwd:(NSString *)passwd;
@end

NS_ASSUME_NONNULL_END
