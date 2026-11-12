//
//  WKWebViewConfiguration+Extension.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/9/5.
//  Copyright © 2023 fzm. All rights reserved.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKWebViewConfiguration (Extension)
+ (WKWebViewConfiguration *)initBroswerAddr:(NSString *)addr rpcUrl:(NSString *)rpcUrl chainId:(NSInteger)chainID;
@end

NS_ASSUME_NONNULL_END
