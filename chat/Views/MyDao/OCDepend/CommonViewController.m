//
//  CommonViewController.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/21.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "CommonViewController.h"
#import "Depend.h"

@interface CommonViewController ()
@property (nonatomic, strong) UILabel *titleLabel;/**< 题目标题*/
@property (nonatomic, strong) UIImageView *maskLineImageView;
@end

@implementation CommonViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setNavigationBar];
    [self setMaskLine];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navBarHairlineImageView.hidden = YES;
    if (@available(iOS 13.0, *)) {
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
    } else {
        // Fallback on earlier versions
         [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    }
    if (self.navigationController.navigationBar.hidden) {
        self.showMaskLine = false;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
   
}


//@{NSFontAttributeName : [UIFont boldSystemFontOfSize:18],NSForegroundColorAttributeName:UIColor.whiteColor};
//重写setTitle方法
- (void)setTitle:(NSString *)title {
    self.navigationController.navigationBar.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18],NSForegroundColorAttributeName:SGColorRGBA(51, 54, 73, 1)};
    self.navigationItem.title = title;
}

- (void)setShowMaskLine:(BOOL)showMaskLine {
    _showMaskLine = showMaskLine;
    self.maskLineImageView.alpha = showMaskLine;
}

- (UIBarButtonItem *)rt_customBackItemWithTarget:(id)target
                                          action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:[UIImage imageNamed:@"backArrow"] forState:UIControlStateNormal];
    
    if (@available(iOS 11.0, *)) {
        
    }else{
        button.imageEdgeInsets = UIEdgeInsetsMake(0,10, 0, -10);
    }

    //添加空格字符串 增加点击面积
    [button setTitle:@"    " forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:44];
    [button sizeToFit];
    [button addTarget:self
               action:@selector(backAction)
     forControlEvents:UIControlEventTouchUpInside];
    
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)backAction{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setMaskLine {
    UIImageView *imageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, 7)];
    [self.view addSubview:imageView];
    imageView.image = [UIImage imageNamed:@"蒙板"];
    imageView.layer.zPosition = MAXFLOAT;
    self.maskLineImageView = imageView;
}

- (void)setNavigationBar
{
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationController.navigationBar setBarTintColor:[UIColor whiteColor]];
    //去掉分割线
    self.navBarHairlineImageView = [self findHairlineImageViewUnder:self.navigationController.navigationBar];
    self.navBarHairlineImageView.backgroundColor =  [UIColor whiteColor]; //CMColorFromRGB(0xD2D8E1);
    [self.navigationController.navigationBar setShadowImage:[[UIImage alloc] init]];
}

- (UIImageView *)findHairlineImageViewUnder:(UIView *)view {
    
    if ([view isKindOfClass:UIImageView.class] && view.bounds.size.height <= 1.0) {
        
        return (UIImageView *)view;
    }
    
    for (UIView *subview in view.subviews) {
        subview.backgroundColor = [UIColor whiteColor];
        UIImageView *imageView = [self findHairlineImageViewUnder:subview];
        
        if (imageView) {
            
            return imageView;
        }
    }
    return nil;
}

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle
{
    [UIApplication sharedApplication].statusBarStyle = statusBarStyle;
}

@end
