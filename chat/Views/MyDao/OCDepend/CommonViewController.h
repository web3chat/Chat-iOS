//
//  CommonViewController.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/21.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CommonViewController : UIViewController
@property (nonatomic,strong)UIImageView *navBarHairlineImageView;
//设置当前控制器的statusBarStyle 只在当前控制器有效
@property (nonatomic,assign)UIStatusBarStyle statusBarStyle;
@property (nonatomic,assign,getter=isShowMaskLine)BOOL showMaskLine;
- (void)backAction;
@end
