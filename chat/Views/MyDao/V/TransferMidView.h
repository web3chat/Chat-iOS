//
//  TransferMidView.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"
#import "PWDataBaseManager.h"

typedef void(^MidViewBlock)(NSString * _Nullable  str);

@interface TransferMidView : UIView
@property (nonatomic,strong) UITextView * _Nullable  addressText;
@property (nonatomic,copy) LocalCoin * _Nullable coin;
@property (nonatomic,copy,getter=getFromAddress) NSString * _Nullable fromAddress;
@property (nonatomic,copy,getter=getToAddress) NSString * _Nullable toAddress;
/** 联系人去转账 两个YCC的情况 */
@property (nonatomic,assign)NSInteger index;
/** 隐藏联系人 */
@property (nonatomic, assign) BOOL contactIsHidden;

@property (nonatomic, strong) NSString * _Nullable coinAddress;

- (void)addContactTarget:(nullable id)target action:(SEL _Nullable )action forControlEvents:(UIControlEvents)controlEvents;
- (void)addScanTarget:(nullable id)target action:(SEL _Nullable )action forControlEvents:(UIControlEvents)controlEvents;

- (void)setDestinationAddress:(NSString *_Nullable)address;
- (void)setExclusiveAddress:(NSString *_Nullable)address; // 专属地址
- (void)setKeybordBtn:(UIButton *_Nullable)keybordBtn action:(SEL _Nonnull ) action;


@property (nonatomic) MidViewBlock _Nullable  midViewBlock;


@end
