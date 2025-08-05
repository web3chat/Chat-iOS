//
//  ScanViewController.h
//  PWallet
//
//  Created by 宋刚 on 2018/3/21.
//  Copyright © 2018年 宋刚. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalWallet.h"
#import "CommonViewController.h"

typedef void (^ScanResult)(NSString *address);

@interface ScanViewController : CommonViewController
@property (nonatomic,copy)ScanResult scanResult;
@property (nonatomic, strong) LocalWallet *localWallet;
@property (nonatomic,assign)NSInteger fromType;//判断是否是从‘观察钱包->冷钱包导入’进入  ==1为yes
@end

