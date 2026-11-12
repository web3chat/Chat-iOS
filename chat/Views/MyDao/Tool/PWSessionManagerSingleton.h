//
//  PWSessionManagerSingleton.h
//  PWallet
//
//  Created by fzm on 2018/5/16.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AFHTTPSessionManager;

@interface PWSessionManagerSingleton : NSObject
+ (AFHTTPSessionManager *) sharedSessionManager;
@end
