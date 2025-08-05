//
//  NSError+PWError.h
//  PWallet
//
//  Created by fzm on 2018/5/16.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (PWError)
+ (NSError *) errorWithCode:(NSInteger) errorCode errorMessage:(NSString *) errorMessage;
@end
