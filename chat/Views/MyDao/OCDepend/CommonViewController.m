//
//  CommonViewController.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/21.
//  Copyright © 2018年 fzm. All rights reserved.
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
    [self notifyFloatingAIVisibilityShouldUpdate];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self notifyFloatingAIVisibilityShouldUpdate];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self notifyFloatingAIVisibilityShouldUpdate];
}

/// 「资产」「发现」这两个 Tab 里的页面都是本类（或其子类），它们的 push/pop **不会**走 Swift 侧的
/// `ViewControllerIntercepter`（那不是它们的导航代理）⇒ 在这里补一次通知，
/// 让 TabBar 上的 AI 客服悬浮球在进出二级页面时重新判断显隐。
/// ⚠️ 通知名必须与 Swift 侧 `FZM_Notify_FloatingAIVisibilityShouldUpdate`（chat/BusinessTool/Common/CommonTools.swift）**完全一致**。
- (void)notifyFloatingAIVisibilityShouldUpdate {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FZM_Notify_FloatingAIVisibilityShouldUpdate" object:nil];
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
    // 使用系统 UIBarButtonItem，左内边距由系统给。
    // ⚠️ 旧写法是 initWithCustomView:（按钮里塞 4 个空格把图标顶到最左边），
    //    在 iOS 26/27 上还会被套上「液态玻璃」胶囊，并且整体偏左。
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_back"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:target
                                                            action:action];
    item.tintColor = SGColorFromRGB(0x333649);
    return item;
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
    // ⚠️ 这里**不要**再写死白色 barTintColor：iOS 26/27 上它会把 appearance.backgroundColor 盖掉，
    //    表现为「状态栏一条是页面要的颜色，导航栏本体却是白色」。背景色统一交给各页面的
    //    UINavigationBarAppearance 控制。
    [self.navigationController.navigationBar setBarTintColor:nil];
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
        // 只找高度 <= 1 的分割线，**不要**像老代码那样把每个子视图都刷成白色
        // （那会把导航栏背景视图涂白，iOS 26 上就出现「上边一条颜色 + 整条白底」）。
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
