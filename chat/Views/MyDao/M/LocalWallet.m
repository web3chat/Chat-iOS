//
//  LocalWallet.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/31.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "LocalWallet.h"

@implementation LocalWallet
- (id)copyWithZone:(NSZone *)zone
{
    LocalWallet * model = [[LocalWallet allocWithZone:zone] init];
    model.wallet_id = self.wallet_id;
    model.wallet_name = self.wallet_name;
    model.wallet_password = self.wallet_password;
    model.wallet_remembercode = self.wallet_remembercode;
    model.wallet_totalassets = self.wallet_totalassets;
    model.wallet_totalassetsDollar = self.wallet_totalassetsDollar;
    model.wallet_isselected = self.wallet_isselected;
    model.wallet_issmall = self.wallet_issmall;
    model.wallet_isbackup = self.wallet_isbackup;
    model.wallet_issetpwd = self.wallet_issetpwd;
    return model;
}
@end
