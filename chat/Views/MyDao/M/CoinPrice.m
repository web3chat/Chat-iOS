//
//  CoinPrice.m
//  PWallet
//
//  Created by 宋刚 on 2018/6/11.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "CoinPrice.h"
#import "Depend.h"

@implementation CoinPrice
- (id)copyWithZone:(NSZone *)zone
{
    CoinPrice * model = [[CoinPrice allocWithZone:zone] init];
    model.coinprice_name = self.coinprice_name;
    model.coinprice_price = self.coinprice_price;
    model.coinprice_dollarPrice = self.coinprice_dollarPrice;
    model.coinprice_icon = self.coinprice_icon;
    model.coinprice_nickname = self.coinprice_nickname;
    model.coinprice_id = self.coinprice_id;
    model.coinprice_sid = self.coinprice_sid;
    model.coinprice_heyueAddress = self.coinprice_heyueAddress;
    model.treaty = self.treaty;
    model.coinprice_optional_name = self.coinprice_optional_name;
    model.coinprice_chain_country_rate = self.coinprice_chain_country_rate;
    model.coinprice_country_rate = self.coinprice_country_rate;
    model.rmb_country_rate = self.rmb_country_rate;
    model.lock = self.lock;
    
    return model;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.coinprice_name forKey:@"coinprice_name"];
    [aCoder encodeObject:@(self.coinprice_price) forKey:@"coinprice_price"];
    [aCoder encodeObject:@(self.coinprice_dollarPrice) forKey:@"coinprice_dollarPrice"];
    [aCoder encodeObject:self.coinprice_icon forKey:@"coinprice_icon"];
    [aCoder encodeObject:self.coinprice_nickname forKey:@"coinprice_nickname"];
    [aCoder encodeObject:@(self.coinprice_id) forKey:@"coinprice_id"];
    [aCoder encodeObject:self.coinprice_sid forKey:@"coinprice_sid"];
    [aCoder encodeObject:self.coinprice_chain forKey:@"coinprice_chain"];
    [aCoder encodeObject:self.coinprice_platform forKey:@"coinprice_platform"];
    [aCoder encodeObject:self.coinprice_heyueAddress forKey:@"coinprice_heyueAddress"];
    [aCoder encodeObject:@(self.coin_sort) forKey:@"coin_sort"];
    [aCoder encodeObject:@(self.treaty) forKey:@"treaty"];
    [aCoder encodeObject:self.coinprice_optional_name forKey:@"coinprice_optional_name"];
    [aCoder encodeObject:@(self.coinprice_chain_country_rate) forKey:@"chain_country_rate"];
    [aCoder encodeObject:@(self.coinprice_country_rate) forKey:@"country_rate"];
    [aCoder encodeObject:@(self.rmb_country_rate) forKey:@"rmb_country_rate"];
    [aCoder encodeObject:@(self.lock) forKey:@"lock"];
    
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self)
    {
        self.coinprice_name               = [aDecoder decodeObjectForKey:@"coinprice_name"];
        self.coinprice_price              = [[aDecoder decodeObjectForKey:@"coinprice_price"] floatValue];
        self.coinprice_dollarPrice        = [[aDecoder decodeObjectForKey:@"coinprice_dollarPrice"] floatValue];
        self.coinprice_icon               = [aDecoder decodeObjectForKey:@"coinprice_icon"];
        self.coinprice_nickname           = [aDecoder decodeObjectForKey:@"coinprice_nickname"];
        self.coinprice_id                 = [[aDecoder decodeObjectForKey:@"coinprice_id"] integerValue];
        self.coinprice_sid                = [aDecoder decodeObjectForKey:@"coinprice_sid"];
        self.coinprice_chain              = [aDecoder decodeObjectForKey:@"coinprice_chain"];
        self.coinprice_platform           = [aDecoder decodeObjectForKey:@"coinprice_platform"];
        self.coinprice_heyueAddress       = [aDecoder decodeObjectForKey:@"coinprice_heyueAddress"];
        self.coin_sort                    = [[aDecoder decodeObjectForKey:@"coin_sort"] integerValue];
        self.treaty                       = [[aDecoder decodeObjectForKey:@"treaty"] integerValue];
        self.coinprice_optional_name      = [aDecoder decodeObjectForKey:@"coinprice_optional_name"];
        self.coinprice_chain_country_rate = [[aDecoder decodeObjectForKey:@"chain_country_rate"] floatValue];
        self.coinprice_country_rate       = [[aDecoder decodeObjectForKey:@"country_rate"] floatValue];
        self.rmb_country_rate             = [[aDecoder decodeObjectForKey:@"rmb_country_rate"] floatValue];
        self.lock                         = [[aDecoder decodeObjectForKey:@"lock"] integerValue];
    }
    
    return self;
}

-(NSString *)coinprice_optional_name{
    return (_coinprice_optional_name == nil||[_coinprice_optional_name isEqualToString:@""]) ? _coinprice_name : _coinprice_optional_name;
}

@end
