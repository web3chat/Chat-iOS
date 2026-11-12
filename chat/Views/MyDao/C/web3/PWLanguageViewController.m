//
//  PWLanguageViewController.m
//  PWallet
//
//  Created by 郑晨 on 2019/6/3.
//  Copyright © 2019 fzm. All rights reserved.
//

#import "PWLanguageViewController.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface PWLanguageViewController ()
<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) NSArray *showArray; // 显示的多语言组
@property (nonatomic, strong) UITableView *tableView;
@property(nonatomic,assign)ChangeType changeType;
@property (nonatomic, strong) NSArray *modelArray;
@end

@implementation PWLanguageViewController

- (instancetype)initWithChangeType:(ChangeType)type
{
    self = [super init];
    if (self) {
        self.changeType = type;
    }
    return self;
}

-(instancetype)init{
    self = [super init];
       if (self) {
           self.changeType = ChangeNet;
       }
       return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setNav];
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.bottom.equalTo(self.view);
    }];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
//    [self.navigationController.navigationBar lt_setBackgroundColor:UIColor.whiteColor];

    if (@available(iOS 13.0, *)) {
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
    } else {
           // Fallback on earlier versions
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    }
    
    if (@available(iOS 15, *))
    {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        // iOS 26/27：不显式 opaque 会被画成「液态玻璃」，backgroundColor 只作用于状态栏区域
        [appearance configureWithOpaqueBackground];
        // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
        appearance.buttonAppearance.normal.backgroundImage = [UIImage new];
        appearance.buttonAppearance.highlighted.backgroundImage = [UIImage new];
        appearance.doneButtonAppearance.normal.backgroundImage = [UIImage new];
        appearance.doneButtonAppearance.highlighted.backgroundImage = [UIImage new];
        appearance.backButtonAppearance.normal.backgroundImage = [UIImage new];
        appearance.backButtonAppearance.highlighted.backgroundImage = [UIImage new];

        appearance.backgroundColor = SGColorFromRGB(0xffffff);
        appearance.backgroundEffect = nil;
        appearance.shadowColor = UIColor.clearColor;
         appearance.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:16], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    else
    {
        [self.navigationController.navigationBar setBackgroundImage:[CommonFunction createImageWithColor:SGColorFromRGB(0xffffff)] forBarMetrics:UIBarMetricsDefault];
    }
    
    switch (self.changeType) {
        case ChangeMoney:
        {
        }
            break;
        case ChangeLang:
        {
            // 顺序与显示名统一由 LanguageManager 提供：
            // 简体中文置顶，其余按中文名拼音排序，显示为「本地名(中文名)」，括号内不翻译
            _showArray = [LanguageManager languageOptions];
        }

            break;
        case ChangeIP:
        {
           
        }
            break;
        case ChangeNet:
        {
            _showArray = @[@{@"name":@"BitYuan Mainnet",@"type":@(NetBTY)},
                           @{@"name":@"Ethereum Mainnet",@"type":@(NetETH)},
                           @{@"name":@"BNB Smart Chain",@"type":@(NetBNB)}];
        }
            break;
            
        default:
            break;
    }
    
    
    [self.tableView reloadData];
    
}

- (void)setNav{
    // 与设置页（SettingVC，走 ViewControllerIntercepter 里的全局返回按钮）保持完全一致：
    // 45×44 容器 + nav_back 模板图（左对齐、垂直居中）+ tint 0x24374E。
    //
    // ⚠️ 原来用 setBackgroundImage: 把 10×17pt 的 nav_back 当背景图铺满 44×44 的按钮，
    // 图片被拉伸成又大又粗的箭头，所以改成 setImage: + 模板渲染。
    // 使用系统 UIBarButtonItem（自定义 view 在交互式转场里不会跟着淡出，会一直挂在导航栏上）
    UIImage *backIcon = [[UIImage imageNamed:@"nav_back"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:backIcon
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(backAction)];
    backItem.tintColor = SGColorFromRGB(0x24374E);
    self.navigationItem.leftBarButtonItem = backItem;

    // 语言页标题（网络页标题由调用方设置，保持原样）
    if (self.changeType == ChangeLang) {
        self.title = L(@"语言");
    }

    // 网络模式：右上角「编辑」进 RPC 地址设置页（语言模式不加）
    if (self.changeType == ChangeNet) {
        UIBarButtonItem *editItem = [[UIBarButtonItem alloc] initWithTitle:L(@"编辑")
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(editRPCAction)];
        editItem.tintColor = SGColorFromRGB(0x24374E);
        [editItem setTitleTextAttributes:@{NSFontAttributeName : [UIFont systemFontOfSize:15]} forState:UIControlStateNormal];
        self.navigationItem.rightBarButtonItem = editItem;
    }
}

- (void)backAction{
    [self.navigationController popViewControllerAnimated:YES];
}

/// 编辑 RPC 地址：与「选择网络」同一套网络列表，按网络分别配置节点地址
- (void)editRPCAction{
    DAppRPCEditorVC *vc = [[DAppRPCEditorVC alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - tableview delegate datasoruce

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    NSLog(@"=========");
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _showArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identity = @"languagecell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identity];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identity];
    }
    
    cell.textLabel.text = [_showArray[indexPath.row] objectForKey:@"name"];
    cell.textLabel.textColor = SGColorFromRGB(0x333649);
    cell.backgroundColor = UIColor.whiteColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    switch (self.changeType) {
        case ChangeMoney:{
           
        }
            break;
        case ChangeLang:{
            NSString *lan = [_showArray[indexPath.row] objectForKey:@"code"];
            NSString *selectedLanStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppSelectedLanguage"];
            if (selectedLanStr == nil) {
                selectedLanStr = @"zh-Hans";
            }
            if ([lan isEqualToString:selectedLanStr]) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }else{
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
            break;
        case ChangeIP:{

        }
            break;
        case ChangeNet:{
            NetType net = [[_showArray[indexPath.row] objectForKey:@"type"] intValue];
            if (net == [[PWAppsettings instance] getAPPNetType])
            {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
            break;
        default:
            break;
    }
    
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.f;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (self.changeType) {
        case ChangeMoney:{
//            MoneyType type = [[_showArray[indexPath.row] objectForKey:@"type"] intValue];
//            [LocalizableService setAPPMoneyType:type];
        }
            break;
        case ChangeLang:
        {
            NSString *lan = [_showArray[indexPath.row] objectForKey:@"code"];
            if (lan.length > 0) {
                [[LanguageManager shared] setLanguageWithCode:lan];
            }
        }
            break;
        case ChangeIP:
        {
           
        }
            break;
        case ChangeNet:
        {
            NetType net = [[_showArray[indexPath.row] objectForKey:@"type"] intValue];
            [[PWAppsettings instance] setAPPNetType:net];
        }
            break;
            
            
        default:
            break;
    }

    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - getter and setter
- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        _tableView.showsVerticalScrollIndicator = false;
        _tableView.backgroundColor = SGColorFromRGB(0xFCFCFF);
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.showsVerticalScrollIndicator = false;
        
    }
    
    return _tableView;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
