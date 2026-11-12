//
//  PWApplication.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "PWApplication.h"

@implementation PWApplication
+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper{
    
    return @{@"appID":@"id",
             @"h5URL":@"h5_url",
             @"advertise":@"slogan",
             @"platformType":@"platform_type"
    };
}

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    
    return @{@"appID":@"id",
             @"h5URL":@"h5_url",
             @"advertise":@"slogan",
             @"platformType":@"platform_type"
    };
}
@end
