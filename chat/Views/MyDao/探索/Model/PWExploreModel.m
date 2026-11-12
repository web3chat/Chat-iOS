//
//  PWExploreModel.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "PWExploreModel.h"

@implementation PWExploreModel

+ (NSDictionary *)mj_objectClassInArray {
    
    return @{ @"apps":@"PWApplication" };
}

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    
    return @{ @"Id": @"id" };
}

@end

@implementation PWExploreAPPModel

@end
