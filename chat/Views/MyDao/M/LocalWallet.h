//
//  LocalWallet.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/31.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LocalWallet : NSObject<NSCopying>
@property(nonatomic,assign) NSInteger wallet_id;
@property(nonatomic,copy) NSString *wallet_name;
@property(nonatomic,copy) NSString *wallet_password; // 地址钱包因为没有密码，此参数作为地址钱包的主链以及地址使用  格式如下：主链:地址
@property(nonatomic,copy) NSString *wallet_remembercode;
//@property(nonatomic,copy) NSString *wallet_privatekey;
@property(nonatomic,assign) CGFloat wallet_totalassets;
#pragma mark ====此字段搜索未用到  暂时用作观察钱包--冷钱包导入   标识符
@property(nonatomic,assign) CGFloat wallet_totalassetsDollar;
@property(nonatomic,assign) NSInteger wallet_isselected;  //1:被选择 0:没被选择
@property(nonatomic,assign) NSInteger wallet_issmall;  //0:小钱包 1:正常钱包 2 导入私钥创建的钱包  3 导入地址创建的钱包 4、找回钱包
@property(nonatomic,assign) NSInteger wallet_isbackup;    //1:已备份 0:未备份
@property(nonatomic,assign) NSInteger wallet_issetpwd;    //1:已设置 0:未设置
@property(nonatomic,assign) NSInteger wallet_isEscrow;    //1:托管钱包

@property(nonatomic,assign)NSInteger isKJ;//是否是快捷转账 1:是  其他：否

@end
