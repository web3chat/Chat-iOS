//
//  LoginUserInfo.m
//  chat
//
//  Created by Cursor on 2026/4/7.
//

#import "LoginUserInfo.h"
#import <YYModel/YYModel.h>

@implementation LoginUserInfo

+ (NSDictionary *)modelCustomPropertyMapper
{
    return @{@"address0x": @"0xaddress"};
}

- (id)copyWithZone:(NSZone *)zone
{
    LoginUserInfo *model = [[LoginUserInfo allocWithZone:zone] init];
    model.phone = self.phone;
    model.address = self.address;
    model.address0x = self.address0x;
    model.avatarurl = self.avatarurl;
    model.name = self.name;
    model.encryptedRemembercode = self.encryptedRemembercode;
    model.encryptedPassword = self.encryptedPassword;
    return model;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.phone forKey:@"phone"];
    [aCoder encodeObject:self.address forKey:@"address"];
    [aCoder encodeObject:self.address0x forKey:@"address0x"];
    [aCoder encodeObject:self.avatarurl forKey:@"avatarurl"];
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.encryptedRemembercode forKey:@"encryptedRemembercode"];
    [aCoder encodeObject:self.encryptedPassword forKey:@"encryptedPassword"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.phone = [aDecoder decodeObjectForKey:@"phone"];
        self.address = [aDecoder decodeObjectForKey:@"address"];
        self.address0x = [aDecoder decodeObjectForKey:@"address0x"];
        self.avatarurl = [aDecoder decodeObjectForKey:@"avatarurl"];
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.encryptedRemembercode = [aDecoder decodeObjectForKey:@"encryptedRemembercode"];
        self.encryptedPassword = [aDecoder decodeObjectForKey:@"encryptedPassword"];
    }
    return self;
}

@end
