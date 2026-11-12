//
//  LoginUserInfo.h
//  chat
//
//  Created by Cursor on 2026/4/7.
//

#import <Foundation/Foundation.h>

@interface LoginUserInfo : NSObject<NSCopying, NSCoding>

@property (nonatomic, copy) NSString *phone;
@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *address0x; // 数据库字段: 0xaddress
@property (nonatomic, copy) NSString *avatarurl;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *encryptedRemembercode;
@property (nonatomic, copy) NSString *encryptedPassword;

@end
