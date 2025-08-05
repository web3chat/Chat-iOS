//
//  Fee.m
//  PWallet
//
//  Created by 宋刚 on 2018/6/14.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "Fee.h"

@implementation Fee

@end

@implementation FeeConfig

- (instancetype)initWithAttritubes:(NSDictionary *)dict
{
    self = [super init];
    
    if (self) {
        self.externalType = [[[dict objectForKey:@"external"] objectForKey:@"type"] integerValue];
        self.externalFee = [[[dict objectForKey:@"external"] objectForKey:@"fee"] doubleValue];
        self.externalMinFee = [[[dict objectForKey:@"external"] objectForKey:@"min_fee"] doubleValue];
        self.internalType =  [[[dict objectForKey:@"internal"] objectForKey:@"type"] integerValue];
        self.internalFee = [[[dict objectForKey:@"internal"] objectForKey:@"fee"] doubleValue];
        self.internalMinFee = [[[dict objectForKey:@"internal"] objectForKey:@"min_fee"] doubleValue];
    }
    
    return self;
}

@end
