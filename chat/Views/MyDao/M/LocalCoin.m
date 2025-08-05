//
//  LocalCoin.m
//  PWallet
//
//  Created by 宋刚 on 2018/6/6.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "LocalCoin.h"
#import <YYModel/YYModel.h>
#import "CoinPrice.h"
#import "PWDataBaseManager.h"
@interface LocalCoin()
{
   NSString *optional_name;
}
@end
@implementation LocalCoin
- (id)copyWithZone:(NSZone *)zone
{
    LocalCoin * model = [[LocalCoin allocWithZone:zone] init];
    model.coin_id = self.coin_id;
    model.coin_walletid = self.coin_walletid;
    model.coin_type = self.coin_type;
    model.coin_balance = self.coin_balance;
    model.coin_pubkey = self.coin_pubkey;
    model.coin_address = self.coin_address;
    model.coin_show = self.coin_show;
    model.coin_sid = self.coin_sid;
    model.coin_platform = self.coin_platform;
    model.treaty = self.treaty;
    model.coin_chain = self.coin_chain;
    model.coin_coinid = self.coin_coinid;
    model.icon = self.icon;
    model.coinprice_price = self.coinprice_price;
    model.coin_type_nft = self.coin_type_nft;
    
    return model;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(self.coin_id) forKey:@"coin_id"];
    [aCoder encodeObject:@(self.coin_walletid) forKey:@"coin_walletid"];
    [aCoder encodeObject:self.coin_type forKey:@"coin_type"];
    [aCoder encodeObject:self.coin_platform forKey:@"coin_paltform"];
    [aCoder encodeObject:@(self.coin_balance) forKey:@"coin_balance"];
    [aCoder encodeObject:self.coin_pubkey forKey:@"coin_pubkey"];
    [aCoder encodeObject:self.coin_address forKey:@"coin_address"];
    [aCoder encodeObject:@(self.coin_show) forKey:@"coin_show"];
    [aCoder encodeObject:self.coin_sid forKey:@"coin_sid"];
    [aCoder encodeObject:@(self.coin_coinid) forKey:@"coin_coinid"];
    [aCoder encodeObject:@(self.treaty) forKey:@"treaty"];
    [aCoder encodeObject:self.icon forKey:@"icon"];
    [aCoder encodeObject:@(self.coinprice_price) forKey:@"coinprice_price"];
    [aCoder encodeObject:self.coin_chain forKey:@"coin_chain"];
    [aCoder encodeObject:@(self.coin_type_nft) forKey:@"coin_type_nft"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self)
    {
        self.coin_id = [[aDecoder decodeObjectForKey:@"coin_id"] integerValue];
        self.coin_walletid = [[aDecoder decodeObjectForKey:@"coin_walletid"] integerValue];
        self.coin_type = [aDecoder decodeObjectForKey:@"coin_type"];
        self.coin_platform = [aDecoder decodeObjectForKey:@"coin_paltform"];
        self.coin_balance = [[aDecoder decodeObjectForKey:@"coin_balance"] floatValue];
        self.coin_pubkey = [aDecoder decodeObjectForKey:@"coin_pubkey"];
        self.coin_address = [aDecoder decodeObjectForKey:@"coin_address"];
        self.coin_show = [[aDecoder decodeObjectForKey:@"coin_show"] integerValue];
        self.coin_sid = [aDecoder decodeObjectForKey:@"coin_sid"];
        self.coin_coinid = [[aDecoder decodeObjectForKey:@"coin_coinid"] integerValue];
        self.treaty = [[aDecoder decodeObjectForKey:@"treaty"] integerValue];
        self.icon = [aDecoder decodeObjectForKey:@"icon"];
        self.coinprice_price = [[aDecoder decodeObjectForKey:@"coinprice_price"] floatValue];
        self.coin_chain = [aDecoder decodeObjectForKey:@"coin_chain"];
        self.coin_type_nft = [[aDecoder decodeObjectForKey:@"coin_type_nft"] integerValue];
    }
    
    return self;
}
//- (NSString *)optional_name{
//    if (optional_name == nil) {
//        CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.coin_type platform:self.coin_platform andTreaty:self.treaty];
//        optional_name = IS_BLANK(coinPrice.coinprice_optional_name) ? self.coin_type : coinPrice.coinprice_optional_name;
//    }
//    return optional_name;
//}

- (NSString *)optional_name
{
    if (optional_name == nil) {
        CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.coin_type platform:self.coin_platform andTreaty:self.treaty];
        optional_name = (coinPrice.coinprice_optional_name == nil || [coinPrice.coinprice_optional_name isEqualToString:@""]) ? self.coin_type : coinPrice.coinprice_optional_name;
    }
    return optional_name;
}

- (BOOL)isBtyChild{
    return (![self.coin_platform isEqual:@"bty"]) && [self.coin_chain isEqual:@"BTY"] && (![self.coin_platform isEqual:@"guodun"]);
}

@end
