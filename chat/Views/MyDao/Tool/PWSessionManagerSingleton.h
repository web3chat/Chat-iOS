//
//  PWSessionManagerSingleton.h
//  PWallet
//
//  Created by 陈健 on 2018/5/16.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AFHTTPSessionManager;

@interface PWSessionManagerSingleton : NSObject
+ (AFHTTPSessionManager *) sharedSessionManager;
@end
