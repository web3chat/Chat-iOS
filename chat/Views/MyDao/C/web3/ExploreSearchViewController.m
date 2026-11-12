//
//  ExploreSearchViewController.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/12/22.
//  Copyright © 2022 fzm. All rights reserved.
//

#import "ExploreSearchViewController.h"
// #import "WebViewController.h"  // 探索搜索已改推 DAppBrowser，若恢复 WebViewController 再打开
#import "chat-Swift.h"
#import "PWLanguageViewController.h"
#import "RecentlyUsedAppTool.h"
#import "ExploreAlertTool.h"
// sd_cancelCurrentImageLoad 声明在 UIView+WebCache.h（SDWebImage 4.0 的 UIImageView+WebCache.h 不会引它，必须显式引）
#import "UIView+WebCache.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]

/// 常用网站（App 端写死，不依赖网络/接口）
static NSString *const kCommonDAppName = @"BitYuan";
static NSString *const kCommonDAppURL  = @"https://bityuan.com";
/// BitYuan 联邦商城
static NSString *const kFedMallName = @"BitYuan联邦商城";
static NSString *const kFedMallURL  = @"https://fedmall.bityuan.com/";

static NSArray<NSDictionary *> *FZMCommonDAppList(void){
    // icon 留空 = 用站点自己的 favicon（https://<host>/favicon.ico），不写死项目里的本地图标
    return @[@{@"name": kCommonDAppName,
               @"url": kCommonDAppURL,
               @"icon": @""},
             @{@"name": kFedMallName,
               @"url": kFedMallURL,
               @"icon": @""}];
}

/// 历史项没有本地图标时用的占位图（地球）
static NSString *const kExploreDefaultIcon = @"changenet";

/// 取网址的域名（host）：统一小写、去掉 www. 前缀；解析不出返回 @""
static NSString *FZMHostFromURLString(NSString *urlString){
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    NSString *host = url.host.lowercaseString;
    if ([host hasPrefix:@"www."]) {
        host = [host substringFromIndex:4];
    }
    return host.length > 0 ? host : @"";
}

/// 列表行：图标 + 名称 / 网址（第二行，与名称左对齐）+ 缩小后的箭头
@interface FZMExploreAppCell : UITableViewCell
@property (nonatomic, strong) UIView *textContainerView;
@property (nonatomic, strong) UIImageView *appIconView;
@property (nonatomic, strong) UILabel *appNameLab;
@property (nonatomic, strong) UILabel *appUrlLab;
@property (nonatomic, strong) UIImageView *arrowView;
/// iconName 非空用本地图（不联网）；为空则按域名拉站点 favicon，失败回退占位图
- (void)configWithName:(NSString *)name url:(NSString *)urlString iconName:(NSString *)iconName;
@end

@implementation FZMExploreAppCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.whiteColor;
        // 先把子视图都加进去，再激活互相引用的约束
        [self.contentView addSubview:self.appIconView];
        [self.contentView addSubview:self.textContainerView];
        [self.contentView addSubview:self.arrowView];
        [self.textContainerView addSubview:self.appNameLab];
        [self.textContainerView addSubview:self.appUrlLab];
        [self.appIconView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView).offset(16);
            make.centerY.equalTo(self.contentView);
            // 站点 favicon 普遍只有 32px，图标位放小（@3x 只需 72px）才不至于明显放大发糊
            make.width.height.mas_equalTo(24);
        }];
        [self.arrowView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.contentView).offset(-16);
            make.centerY.equalTo(self.contentView);
            make.width.mas_equalTo(7);
            make.height.mas_equalTo(12);
        }];
        // 两行文字整体垂直居中，宽度由图标与箭头的位置决定
        [self.textContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.appIconView.mas_right).offset(12);
            make.right.equalTo(self.arrowView.mas_left).offset(-8);
            make.centerY.equalTo(self.contentView);
        }];
        [self.appNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.top.equalTo(self.textContainerView);
        }];
        // 网址另起一行，左边与名称对齐
        [self.appUrlLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.textContainerView);
            make.top.equalTo(self.appNameLab.mas_bottom).offset(3);
            make.bottom.equalTo(self.textContainerView);
        }];
    }
    return self;
}

- (void)configWithName:(NSString *)name url:(NSString *)urlString iconName:(NSString *)iconName{
    self.appNameLab.text = name;
    self.appUrlLab.text = urlString;
    UIImage *placeholderImage = [UIImage imageNamed:kExploreDefaultIcon];
    if (iconName.length > 0) {
        // 本地图标，不联网
        [self.appIconView sd_cancelCurrentImageLoad];
        self.appIconView.image = [UIImage imageNamed:iconName];
        return;
    }
    // 历史项没有本地图标：拉站点 favicon，无网/失败就显示占位图
    self.appIconView.image = placeholderImage;
    NSString *host = FZMHostFromURLString(urlString);
    if (host.length > 0) {
        NSURL *faviconURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/favicon.ico", host]];
        if (faviconURL != nil) {
            [self.appIconView sd_setImageWithURL:faviconURL placeholderImage:placeholderImage];
        }
    }
}

- (UIView *)textContainerView{
    if (_textContainerView == nil) {
        _textContainerView = [[UIView alloc] init];
    }
    return _textContainerView;
}

- (UIImageView *)appIconView{
    if (_appIconView == nil) {
        _appIconView = [[UIImageView alloc] init];
        _appIconView.layer.cornerRadius = 6;
        _appIconView.clipsToBounds = YES;
        _appIconView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _appIconView;
}

- (UILabel *)appNameLab{
    if (_appNameLab == nil) {
        _appNameLab = [[UILabel alloc] init];
        _appNameLab.font = [UIFont systemFontOfSize:15];
        _appNameLab.textColor = SGColorFromRGB(0x333649);
        _appNameLab.numberOfLines = 1;
    }
    return _appNameLab;
}

- (UILabel *)appUrlLab{
    if (_appUrlLab == nil) {
        _appUrlLab = [[UILabel alloc] init];
        _appUrlLab.font = [UIFont systemFontOfSize:12];
        _appUrlLab.textColor = SGColorFromRGB(0x8a97a5);
        _appUrlLab.numberOfLines = 1;
        // 网址太长时中间省略，保留域名与结尾
        _appUrlLab.lineBreakMode = NSLineBreakByTruncatingMiddle;
    }
    return _appUrlLab;
}

- (UIImageView *)arrowView{
    if (_arrowView == nil) {
        _arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"arrow_gray_right"]];
        _arrowView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _arrowView;
}

@end

@interface ExploreSearchViewController ()<UITextFieldDelegate,UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) NSArray *dataArray;
@property (nonatomic, strong) NSMutableArray *titleArray;
@property (nonatomic, strong) NSMutableArray *nameArrray;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic) BOOL exitSearch; // 退出了搜索页面

@property (nonatomic, strong) NSMutableArray *websiteMarray;
/// 搜索历史的自定义显示名称：key = 原始网址串，value = 自定义名称
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *websiteNameMap;
/// 本会话里由「dapp 页面标题」自动写入历史的名字（host → 名字）；
/// 用于后续收到更新的标题时允许覆盖（用户自己改过的名字不在此列）
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *autoNameByHost;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation ExploreSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = UIColor.whiteColor;
    self.rt_disableInteractivePop = true;
   
    [self initTitleView];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self.searchTextField endEditing:YES];
//    });
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    // 搜索框占位与右上角「搜索」按钮都在 viewDidLoad 只创建一次，切语言后需在这里同步
    self.searchTextField.placeholder = L(@"请输入网址");
    self.navigationItem.rightBarButtonItem.title = L(@"搜索");
    if (@available(iOS 13.0, *)) {
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
    } else {
           // Fallback on earlier versions
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    }
    self.websiteMarray = [[PWAppsettings instance] getEWebsite];
    if(self.websiteMarray == nil)
    {
        self.websiteMarray = [[NSMutableArray alloc] init];
    }
    self.websiteNameMap = [NSMutableDictionary dictionaryWithDictionary:[[PWAppsettings instance] getEWebsiteNames]];
    
    [self.tableView reloadData];

}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}


//重写返回方法
- (void)backAction{
    [self.view endEditing:YES];
    [self.searchTextField endEditing:YES];
    [self cancel];
}

- (void)initTitleView
{
    
//    self.view.addSubview(cancelBtn)
//    cancelBtn.snp.makeConstraints { (m) in
//        m.right.equalToSuperview()
//        m.width.equalTo(65)
//        m.height.equalTo(40)
//        m.top.equalToSuperview().offset(k_StatusBarHeight + 5)
//    }
//    self.view.addSubview(searchBlockView)
//    searchBlockView.snp.makeConstraints { (m) in
//        m.top.bottom.equalTo(cancelBtn)
//        m.right.equalTo(cancelBtn.snp.left)
//        m.left.equalToSuperview().offset(15)
//    }
//    self.view.addSubview(searchTableView)
//    searchTableView.snp.makeConstraints { (m) in
//        m.left.right.bottom.equalToSuperview()
//        m.top.equalTo(searchBlockView.snp.bottom).offset(5)
//    }
//
    
    _searchTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 257 * kScreenRatio, 36)];
    _searchTextField.placeholder = L(@"请输入网址");
    _searchTextField.backgroundColor = SGColorFromRGB(0xf8f8fa);
    _searchTextField.font = [UIFont systemFontOfSize:16.f];
    _searchTextField.textColor = SGColorFromRGB(0x333649);
    _searchTextField.leftViewMode = UITextFieldViewModeAlways;
    _searchTextField.returnKeyType = UIReturnKeySearch;
    _searchTextField.delegate = self;
    [_searchTextField setValue:SGColorFromRGB(0x8a97a5) forKeyPath:@"placeholderLabel.textColor"];
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(6, 9, 23, 23)];
    imageView.image = [UIImage imageNamed:@"tool_search"];

    [leftView addSubview:imageView];
    
    _searchTextField.leftView = leftView;


    self.navigationItem.titleView = _searchTextField;
    
    // 右侧「搜索」：用输入框里的网址直接打开 DApp（等同键盘回车）
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:L(@"搜索") style:UIBarButtonItemStylePlain target:self action:@selector(searchAction)];
    [rightItem setTintColor:SGColorFromRGB(0x32B2F7)];
    [rightItem setTitleTextAttributes:@{NSForegroundColorAttributeName:SGColorFromRGB(0x32B2F7)} forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    
    // 使用系统 UIBarButtonItem（自定义 view 在交互式转场里不会跟着淡出）
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"changenet"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(changeNet)];
    leftItem.tintColor = SGColorFromRGB(0x333649);
    self.navigationItem.leftBarButtonItem = leftItem;
    
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

- (void)cancel
{
    if(self.dismissBlock)
    {
        self.dismissBlock();
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)changeNet
{
    PWLanguageViewController *vc = [[PWLanguageViewController alloc] initWithChangeType:ChangeNet];
    vc.title = L(@"选择网络");
    vc.hidesBottomBarWhenPushed = true;
    
    [self.navigationController pushViewController:vc animated:true];
}

#pragma mark - uitableview
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // section 0：搜索历史；section 1：常用网站
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.websiteMarray.count;
    }
    NSArray *commonApps = FZMCommonDAppList();
    return commonApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const identity = @"exploreApp";
    FZMExploreAppCell *cell = [tableView dequeueReusableCellWithIdentifier:identity];
    if (!cell) {
        cell = [[FZMExploreAppCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identity];
    }
    NSDictionary *item = [self itemInfoAtIndexPath:indexPath];
    [cell configWithName:item[@"name"] url:item[@"url"] iconName:item[@"icon"]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 两行式列表行：图标 + 名称 / 网址
    return 64.f;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 1) {
        // 「常用网站」标题
        UIView *commonHeadView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 25)];
        commonHeadView.backgroundColor = UIColor.whiteColor;
        UILabel *commonLab = [[UILabel alloc] init];
        commonLab.text = L(@"常用网站");
        commonLab.font = [UIFont systemFontOfSize:12];
        commonLab.textColor = SGColorFromRGB(0x8a97a5);
        commonLab.textAlignment = NSTextAlignmentLeft;
        [commonHeadView addSubview:commonLab];
        [commonLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(commonHeadView).offset(16);
            make.height.top.equalTo(commonHeadView);
        }];
        return commonHeadView;
    }
    
    UIView *headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 25)];
    headView.backgroundColor = UIColor.whiteColor;
    UILabel *titLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:12]
                                    textColor:SGColorFromRGB(0x8a97a5)
                                textAlignment:NSTextAlignmentLeft
                                         text:L(@"搜索历史")];
    [headView addSubview:titLab];
    
    UIButton *clearBtn = [[UIButton alloc] init];
    [clearBtn setTitle:L(@"清空") forState:UIControlStateNormal];
    [clearBtn setTitleColor:SGColorFromRGB(0x8a97a5) forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearHis:) forControlEvents:UIControlEventTouchUpInside];
    [clearBtn.titleLabel setFont:[UIFont systemFontOfSize:12]];
    
    
    [headView addSubview:clearBtn];
    
    [titLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(headView).offset(16);
        make.height.top.equalTo(headView);
    }];
    
    [clearBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(headView).offset(-16);
        make.height.top.equalTo(headView);
    }];
    
    return self.websiteMarray.count == 0 ? nil : headView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 1) {
        return 25;
    }
    return self.websiteMarray.count == 0 ? 0.1f : 25;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self itemInfoAtIndexPath:indexPath];
    NSString *website = item[@"name"];
    NSString *complete = item[@"url"];
    if (complete.length == 0) {
        return;
    }
//    WebViewController *vc = [[WebViewController alloc] init];
//    vc.webUrl = complete;
//    vc.hidesBottomBarWhenPushed = true;
//    vc.title = website;
//    [self.navigationController pushViewController:vc animated:YES];

    NSURL *openURL = [NSURL URLWithString:complete];
    if (!openURL) { return; }
    [self openDAppWithURL:openURL title:website];
}

#pragma mark - 行数据 / 左滑删除
/// 列表行数据：name 显示名称，url 完整链接，icon 本地图标（空则用站点 favicon）
- (NSDictionary *)itemInfoAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        NSArray *commonApps = FZMCommonDAppList();
        NSDictionary *item = commonApps[indexPath.row];
        return @{@"name": item[@"name"], @"url": item[@"url"], @"icon": item[@"icon"]};
    }
    NSString *raw = [NSString stringWithFormat:@"%@", self.websiteMarray[indexPath.row]];
    NSString *complete = [self getCompleteWebSite:raw];
    if (complete.length == 0) {
        complete = raw;
    }
    // 第一行显示名：优先用用户自定义名称，没有才回退到域名
    NSString *displayName = self.websiteNameMap[raw];
    if (displayName.length == 0) {
        NSString *host = FZMHostFromURLString(complete);
        displayName = host.length > 0 ? host : raw;
    }
    return @{@"name": displayName, @"url": complete, @"icon": @""};
}

/// 只有搜索历史可以左滑删除；常用网站是写死的入口，不给删
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 0) {
        return nil;
    }
    __weak typeof(self) weakSelf = self;
    // trailing 左滑：数组中越靠前的 action 越贴近屏幕右边缘（这里「删除」靠边）
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                              title:L(@"删除")
                                                                            handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        // 先不动数据，等二次确认
        completionHandler(NO);
        [weakSelf confirmDeleteHistoryAtIndexPath:indexPath];
    }];
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:L(@"编辑")
                                                                          handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        // 先收回划开的行，再弹输入框
        completionHandler(NO);
        [weakSelf presentEditNameForIndexPath:indexPath];
    }];
    editAction.backgroundColor = SGColorFromRGB(0x8a97a5);
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (void)confirmDeleteHistoryAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.websiteMarray.count) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    UIAlertController *alertvc = [UIAlertController alertControllerWithTitle:@"" message:L(@"确定删除该条搜索历史？") preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *acYes = [UIAlertAction actionWithTitle:L(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf deleteHistoryAtIndexPath:indexPath];
    }];
    UIAlertAction *acNo = [UIAlertAction actionWithTitle:L(@"取消") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 取消时把划开的那一行收回去
        [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }];
    [alertvc addAction:acNo];
    [alertvc addAction:acYes];
    [self presentViewController:alertvc animated:YES completion:nil];
}

#pragma mark - 编辑自定义显示名称
/// 左滑「编辑」：输入框改这条历史的第一行显示名，留空 = 恢复默认域名
- (void)presentEditNameForIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.websiteMarray.count) {
        return;
    }
    NSString *raw = [NSString stringWithFormat:@"%@", self.websiteMarray[indexPath.row]];
    NSString *currentName = self.websiteNameMap[raw];

    __weak typeof(self) weakSelf = self;
    UIAlertController *alertvc = [UIAlertController alertControllerWithTitle:L(@"编辑")
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alertvc addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = L(@"请输入网站名称");
        textField.text = currentName;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alertvc addAction:[UIAlertAction actionWithTitle:L(@"取消") style:UIAlertActionStyleDefault handler:nil]];
    [alertvc addAction:[UIAlertAction actionWithTitle:L(@"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        NSString *input = [alertvc.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length == 0) {
            // 清空 = 恢复默认域名显示
            [strongSelf.websiteNameMap removeObjectForKey:raw];
        } else {
            strongSelf.websiteNameMap[raw] = input;
        }
        [[PWAppsettings instance] saveEWebsiteNames:strongSelf.websiteNameMap];
        [strongSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }]];
    [self presentViewController:alertvc animated:YES completion:nil];
}

- (void)deleteHistoryAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.websiteMarray.count) {
        return;
    }
    // 同步清掉这条的自定义名称
    NSString *raw = [NSString stringWithFormat:@"%@", self.websiteMarray[indexPath.row]];
    [self.websiteNameMap removeObjectForKey:raw];
    [[PWAppsettings instance] saveEWebsiteNames:self.websiteNameMap];

    [self.websiteMarray removeObjectAtIndex:indexPath.row];
    [[PWAppsettings instance] deleteEWebsite];
    [[PWAppsettings instance] saveEWebsite:self.websiteMarray];
    [self.tableView reloadData];
}

- (void)clearHis:(UIButton *)sender
{
    UIAlertController *alertvc = [UIAlertController alertControllerWithTitle:@"" message:L(@"是否清空搜索历史") preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *acYes = [UIAlertAction actionWithTitle:L(@"是") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.websiteMarray removeAllObjects];
        [self.websiteNameMap removeAllObjects];
        [[PWAppsettings instance] deleteEWebsite];
        [[PWAppsettings instance] saveEWebsite:self.websiteMarray];
        [[PWAppsettings instance] saveEWebsiteNames:self.websiteNameMap];
        [self.tableView reloadData];
    }];
    UIAlertAction *acNo = [UIAlertAction actionWithTitle:L(@"否") style:UIAlertActionStyleDestructive handler:nil];
    
    [alertvc addAction:acNo];
    [alertvc addAction:acYes];
    
    [self presentViewController:alertvc animated:YES completion:nil];
}

#pragma mark- textFieldDidChange

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self openDAppWithText:textField.text];
    return YES;
}

#pragma mark - 打开 DApp（统一入口）
/// 导航栏右侧「搜索」：与键盘回车等价
- (void)searchAction
{
    [self.searchTextField resignFirstResponder];
    [self openDAppWithText:self.searchTextField.text];
}

/// 用输入框里的文本打开 DApp：先记入搜索历史，再按域名判断是否需要免责弹窗
- (void)openDAppWithText:(NSString *)text
{
    NSString *input = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (input.length == 0) {
        return;
    }
    if (![self.websiteMarray containsObject:input]) {
        [self.websiteMarray addObject:input];
        [[PWAppsettings instance] deleteEWebsite];
        [[PWAppsettings instance] saveEWebsite:self.websiteMarray];
        [self.tableView reloadData];
    }
    NSString *complete = [self getCompleteWebSite:input];
    if (complete.length == 0) {
        return;
    }
    NSURL *openURL = [NSURL URLWithString:complete];
    if (openURL == nil) {
        return;
    }
    [self openDAppWithURL:openURL title:input];
}

/// 新的 dapp（同一域名只弹一次）先弹「责任声明」，确认后再进入
- (void)openDAppWithURL:(NSURL *)url title:(NSString *)title
{
    NSString *host = FZMHostFromURLString(url.absoluteString);
    if (host.length == 0) {
        // 拿不到域名（非法网址）时不做拦截
        [self pushDAppBrowserWithURL:url title:title];
        return;
    }
    if ([RecentlyUsedAppTool hasConfirmedDAppDisclaimerForHost:host]) {
        [self pushDAppBrowserWithURL:url title:title];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[ExploreAlertTool defaultManager] showTwoBtnViewWithQuestion:L(@"责任声明")
                                                     messageText:L(@"您即将使用第三方DApp,确认即同意第三方的用户协议和隐私政策，您在这一DApp中的所有行为和使用情况，均由该DApp的供应商负责。")
                                                     leftBtnText:L(@"取消")
                                                    rightBtnText:L(@"确认")
                                                        andBlock:^{
        [RecentlyUsedAppTool markDAppDisclaimerConfirmedForHost:host];
        [weakSelf pushDAppBrowserWithURL:url title:title];
    }];
}

- (void)pushDAppBrowserWithURL:(NSURL *)url title:(NSString *)title
{
    DAppBrowserViewController *dappVC = [[DAppBrowserViewController alloc] initWithDappURL:url];
    dappVC.title = title;
    dappVC.hidesBottomBarWhenPushed = YES;
    // 站点真实标题回传：给搜索历史里同域名的条目补默认显示名
    NSString *host = FZMHostFromURLString(url.absoluteString);
    if (host.length > 0) {
        __weak typeof(self) weakSelf = self;
        dappVC.onPageTitleChanged = ^(NSString *pageTitle) {
            [weakSelf applyDAppPageTitle:pageTitle forHost:host];
        };
    }
    [self.navigationController pushViewController:dappVC animated:YES];
}

#pragma mark - dapp 页面标题 → 搜索历史默认显示名
/// dapp 里拿到站点标题后，给搜索历史里**同一域名**的条目写默认名：
/// · 没有名字的 → 写入；
/// · 名字是本会话里由标题自动写的 → 允许用更新的标题覆盖（WKWebView 的 title 会多次变化）；
/// · 用户左滑「编辑」自己起过的名字 → 不动（「编辑」留空仍可恢复默认域名）。
- (void)applyDAppPageTitle:(NSString *)pageTitle forHost:(NSString *)host
{
    NSString *name = [pageTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0 || host.length == 0) {
        return;
    }
    NSString *autoName = self.autoNameByHost[host];
    BOOL changed = NO;
    for (NSString *item in [self.websiteMarray copy]) {
        NSString *key = [NSString stringWithFormat:@"%@", item];
        NSString *existing = self.websiteNameMap[key];
        if (existing.length > 0 && (autoName.length == 0 || ![existing isEqualToString:autoName])) {
            continue;
        }
        NSString *complete = [self getCompleteWebSite:key];
        if (complete.length == 0) {
            complete = key;
        }
        if (![FZMHostFromURLString(complete) isEqualToString:host]) {
            continue;
        }
        self.websiteNameMap[key] = name;
        changed = YES;
    }
    self.autoNameByHost[host] = name;
    if (!changed) {
        return;
    }
    [[PWAppsettings instance] saveEWebsiteNames:self.websiteNameMap];
    [self.tableView reloadData];
}

- (NSString *)getCompleteWebSite:(NSString *)urlStr
{
    NSString *returnUrlStr = nil;
    NSString *scheme = nil;
    assert(urlStr != nil);
    
    urlStr = [urlStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if(urlStr != nil && urlStr.length != 0){
        NSRange urlRange = [urlStr rangeOfString:@"://"];
        if(urlRange.location == NSNotFound){
            returnUrlStr = [NSString stringWithFormat:@"https://%@",urlStr];
        }else{
            scheme = [urlStr substringWithRange:NSMakeRange(0, urlRange.location)];
            assert(scheme != nil);
            
            if([scheme compare:@"http" options:NSCaseInsensitiveSearch] == NSOrderedSame
               || [scheme compare:@"https" options:NSCaseInsensitiveSearch] == NSOrderedSame){
                returnUrlStr = urlStr;
            }else{
                // 不支持的url
            }
        }
    }
    return returnUrlStr;
    
}

#pragma mark - getter and setter
- (NSMutableDictionary<NSString *, NSString *> *)autoNameByHost
{
    if (!_autoNameByHost) {
        _autoNameByHost = [NSMutableDictionary dictionary];
    }
    return _autoNameByHost;
}

- (UITableView *)tableView
{
    if(!_tableView){
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        _tableView.backgroundColor = UIColor.whiteColor;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
//        _tableView.separatorColor = LineColor;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.delegate = self;
        _tableView.dataSource = self;
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
