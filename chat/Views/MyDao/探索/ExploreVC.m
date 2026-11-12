//
//  ExploreVC.m
//  PWallet
//
//  Created by 郑晋源 on 2019/10/21.
//  Copyright © 2019 fzm. All rights reserved.
//

#import "ExploreVC.h"
#import "ExploreCell.h"
#import "HorizontalAPPCell.h"
#import "PWBannerView.h"
#import "PWBannerModel.h"
#import "chat-Swift.h"
#import "MJExtension.h"
#import "PWExploreModel.h"
#import "RecentlyUsedAppTool.h"
#import "AppsTableVC.h"
#import "CollectionViewCell.h"
#import "UIViewController+AppClicked.h"
#import "ExploreAlertTool.h"
#import "PWReloadView.h"
#import "WMZBannerView.h"
#import "PWHotTitleTableViewCell.h"
#import "ExploreNewCell.h"
#import "ExploreSearchViewController.h"
#import "PWLanguageViewController.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface ExploreVC ()<UITableViewDelegate, UITableViewDataSource,UITextFieldDelegate>
//@property (nonatomic, strong) PWBannerView *bannerView;
@property (nonatomic, strong) WMZBannerView *bannerView;
@property (nonatomic, strong) WMZBannerParam *bannerParam;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<PWExploreModel *> *dataArray;
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UIButton *choiceNetWorkBtn; // 选择网络
@property (nonatomic, copy) NSArray *appIdArr;
//如果切换了语言，把状态保存起来。进入界面的时候再刷新，防止切换就刷新
@property (nonatomic, strong) PWReloadView *reloadView;
/**搜索框背景View*/
@property (nonatomic,strong) UIView *searchView;
/**搜索框*/
@property (nonatomic,strong) UITextField *searchTextField;
@property (nonatomic) BOOL exitSearch; // 退出了搜索页面


@end
static NSString *const firstTimeOpenExplore = @"firstTimeOpenExplore";
static NSString *const cellIdentity = @"ExploreCell";
static NSString *const horizontalAPPCellIdentity = @"HorizontalAPPCell";
static NSString *const collectionViewCellIdentity = @"CollectionViewCell";
static NSString *const identity = @"newcell";
@implementation ExploreVC

#pragma mark - request
- (void)loadBanner {
    NSString* urlStr = [WalletURL stringByAppendingString:PWallet_Banners];
    NSDictionary *param = @{@"type":@(1)};
    [PWNetworkingTool getRequestWithUrl:urlStr parameters:param successBlock:^(id object) {
        
        NSMutableArray<PWBannerModel *> *bannerArray = [PWBannerModel mj_objectArrayWithKeyValuesArray:object];
        if (bannerArray.count > 0) {
            NSMutableArray *marray = [[NSMutableArray alloc] init];
            for (PWBannerModel *model in bannerArray) {
                [marray addObject:model.image_url];
            }
            
            NSArray *bannerData = [NSArray arrayWithArray:marray];
            
            self.bannerParam =  BannerParam()
            .wFrameSet(CGRectMake(0, 0, kScreenWidth - 40, kScreenWidth*150/375+20))
            .wDataSet(bannerData)
            .wRepeatSet(YES)
            .wAutoScrollSet(YES)
            .wImageFillSet(NO);
            
            self.bannerView = [[WMZBannerView alloc] initConfigureWithModel:self.bannerParam];
            self.bannerView.layer.cornerRadius = 8.f;
            self.bannerView.layer.masksToBounds = YES;
            WEAKSELF
            self.bannerParam.wEventClick = ^(id anyID, NSInteger index) {
                PWBannerModel *banner = bannerArray[index];
                if (![banner.banner_url isEqualToString:@"#"]) {
                    NSURL *openURL = [NSURL URLWithString:banner.banner_url ?: @""];
                    if (!openURL) { return; }
                    DAppBrowserViewController *vc = [[DAppBrowserViewController alloc] initWithDappURL:openURL];
                    vc.title = banner.title;
                    vc.hidesBottomBarWhenPushed = true;
                    [weakSelf.navigationController pushViewController:vc animated:YES];
                }
            };

            UIView* headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenWidth*150/375+20)];
            headView.backgroundColor = UIColor.whiteColor;
            [headView addSubview:weakSelf.bannerView];
            [weakSelf.bannerView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.mas_equalTo(0);
                make.bottom.mas_equalTo(0);
                make.left.mas_equalTo(20);
                make.right.mas_equalTo(-20);
            }];
           
            self.tableView.tableHeaderView = headView;
        }
        
    } failureBlock:^(NSError *error) {
        [self showError:error hideAfterDelay:2];
    }];
}

- (void)loadData {
    NSString* urlStr = [WalletURL stringByAppendingString:Explore_Apps];
    WEAKSELF
    [PWNetworkingTool getRequestWithUrl:urlStr parameters:nil successBlock:^(id object) {
        if ([object isKindOfClass:[NSNull class]]) {
            return ;
        }
        if (weakSelf.reloadView) {
            [self hideProgress];
            [weakSelf.reloadView removeFromSuperview];
        }
        self.dataArray = [PWExploreModel mj_objectArrayWithKeyValuesArray:object];
        //数据结构不一致，需单独取出style=4 数据存入model数组
        NSMutableArray *arr = [NSMutableArray array];
        NSMutableArray *newArr = [NSMutableArray array];
        if (self.dataArray.count > 0) {
            for (PWExploreModel *model in self.dataArray) {
                if (model.style == 4) {
                    [arr addObject:model];
                }else{
                    [newArr addObject:model];
                }
            }
        }
        [self.dataArray removeAllObjects];
        [self.dataArray addObjectsFromArray:newArr];
        if (arr.count > 0) {
            PWExploreModel *model1 = [[PWExploreModel alloc]init];
            model1.style = 4;
            model1.array = arr;
            model1.name = L(@"热门专题");
            [self.dataArray insertObject:model1 atIndex:0];
        }
        [self.tableView reloadData];
        [self loadLikeData];
//        [self loadRecentlyUsedData];
    } failureBlock:^(NSError *error) {
        if (!weakSelf.reloadView) {
             weakSelf.reloadView = [[PWReloadView alloc] initWithFrame:CGRectZero withError:error];
        }
        [self hideProgress];
        weakSelf.reloadView.reloadBlock = ^{
            [weakSelf reloadExploreData];
        };
        [self.view addSubview:weakSelf.reloadView];
        [weakSelf.reloadView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self.view);
            make.width.mas_equalTo(kScreenWidth - 30);
            make.height.mas_equalTo(250);
        }];
        
    }];
}

- (void)loadRecentlyUsedData {
    //先把旧数据清除
    if ([self.dataArray.firstObject.name isEqualToString:L(@"最近使用")] || [self.dataArray.firstObject.name isEqualToString:@"最近使用"]) {
        [self.dataArray removeObjectAtIndex:0];
    }
    //最近使用的应用的id数组
    self.appIdArr = [RecentlyUsedAppTool getAppIDArray];
    if (self.appIdArr.count == 0) {
        [UIView performWithoutAnimation:^{
           [self.tableView reloadData];
        }];
        return;
    }
    NSString* urlStr = [WalletURL stringByAppendingString:Explore_AppsByIDs];
    [PWNetworkingTool getRequestWithUrl:urlStr parameters:@{@"ids":[self.appIdArr componentsJoinedByString:@","]} successBlock:^(id object) {
        if([object isKindOfClass:[NSNull class]]){
            return;
        }
        NSArray <PWApplication*> *apps = [PWApplication mj_objectArrayWithKeyValuesArray:object];
        if (apps.count > 0) {
            
            PWExploreModel* model = [[PWExploreModel alloc] init];
            model.apps = apps;
            model.name = L(@"最近使用");
            model.style = 2;
            [self.dataArray insertObject:model atIndex:0];
        }
        [UIView performWithoutAnimation:^{
           [self.tableView reloadData];
        }];
    } failureBlock:^(NSError *error) {
        [self showError:error hideAfterDelay:2];
        [UIView performWithoutAnimation:^{
           [self.tableView reloadData];
        }];
    }];
}

- (void)loadLikeData
{
    //先把旧数据清除
    if ([self.dataArray.firstObject.name isEqualToString:L(@"收藏")] || [self.dataArray.firstObject.name isEqualToString:@"收藏"]) {
        [self.dataArray removeObjectAtIndex:0];
    }

    NSArray *likeArr = [RecentlyUsedAppTool getLikeAppArray];
    NSMutableArray <PWApplication *> *appliction = [[NSMutableArray alloc] initWithCapacity:likeArr.count];
    for (NSDictionary *app in likeArr) {
        PWApplication *apps = [[PWApplication alloc] init];
        apps.app_url = app[@"url"];
        apps.name = app[@"name"];
        apps.icon = app[@"icon"];
        apps.appID = app[@"appId"];
        [appliction addObject:apps];
    }
    if (likeArr.count > 0) {
        PWExploreModel* model = [[PWExploreModel alloc] init];
        model.apps = appliction;
        model.name = L(@"收藏");
        model.style = 2;
        [self.dataArray insertObject:model atIndex:0];
        [UIView performWithoutAnimation:^{
           [self.tableView reloadData];
        }];
        
    }else{
        [UIView performWithoutAnimation:^{
           [self.tableView reloadData];
        }];
        return;
    }
    
    
    
}

#pragma mark - reloadData
- (void)reloadExploreData
{
    [self showProgressWithMessage:@""];
    [self loadBanner];
    
    [self loadData];
}

#pragma mark - view

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self loadData];
    self.navigationItem.rightBarButtonItem = [self rightBarButtonItem];
    if (@available(iOS 13.0, *)) {
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
    } else {
        // Fallback on earlier versions
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    }
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateLan)
                                                name:LanguageManager.LanguageChangedNotification
                                              object:nil];
}

- (void)updateLan {
    self.titleLab.text = L(@"探索");
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

}

- (void)viewDidLoad {
    [super viewDidLoad];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadBanner];
        [self loadData];
    });
    [self createNavigationBar];
    
    //第一次进入探索弹框
    if (![[[NSUserDefaults standardUserDefaults] valueForKey:firstTimeOpenExplore] isEqualToString:@"no"]) {
        [[ExploreAlertTool defaultManager] showOneBtnViewWithTitle:L(@"探索精彩DApp") detailText:L(@"什么是DApp?DApp就是区块链上的应用，快和我一起来体验下吧") btnText:L(@"开始体验") andBlock:^{
            [[NSUserDefaults standardUserDefaults] setObject:@"no" forKey:firstTimeOpenExplore];
        }];
    }
}


-(void)createNavigationBar{
    self.showMaskLine = false;
    
    UIView* titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 64)];

//    [self.navigationController.navigationBar addSubview:titleView];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:titleView];
    self.titleLab = [[UILabel alloc]init];
    self.titleLab.text = L(@"探索");
    self.titleLab.textColor = CMColorFromRGB(0x333649);
    self.titleLab.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:18];
    [titleView addSubview:self.titleLab];
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(titleView).offset(12);
        make.top.mas_equalTo(-12);
    }];
    UILabel* blueLine = [[UILabel alloc]init];
    blueLine.backgroundColor = CMColorFromRGB(0x7190FF);
    blueLine.layer.cornerRadius = 2;
    blueLine.clipsToBounds = YES;
    [titleView addSubview:blueLine];
    [blueLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.titleLab);
        make.top.equalTo(self.titleLab.mas_bottom);
        make.width.mas_equalTo(20);
        make.height.mas_equalTo(4);
    }];
    
    UIView *searchView = [[UIView alloc]init];
    [self.view addSubview:searchView];
    self.searchView = searchView;
    
    UITextField *searchTextField = [[UITextField alloc]init];
    [searchView addSubview:searchTextField];
    self.searchTextField = searchTextField;
    
    searchTextField.textColor = SGColorFromRGB(0x333649);
    searchTextField.font = [UIFont systemFontOfSize:16];
    searchTextField.backgroundColor = SGColorFromRGB(0xF8F8FA);
    searchTextField.layer.cornerRadius = 3;
    searchTextField.leftView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 44, 39)];
    searchTextField.leftView.backgroundColor = SGColorFromRGB(0xF8F8FA);
    searchTextField.leftViewMode = UITextFieldViewModeAlways;
    searchTextField.returnKeyType = UIReturnKeyDone;
    searchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    searchTextField.delegate = self;
    searchTextField.placeholder = L(@"请输入网址");
    [searchTextField setValue:SGColorFromRGB(0x8a97a5) forKeyPath:@"placeholderLabel.textColor"];
    UIImageView *imageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"APP搜索"]];
    imageView.frame = CGRectMake(13, 9, 20, 20);
    [searchTextField.leftView addSubview:imageView];
    
    [self.searchView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(53);
    }];
    
    [self.searchTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.searchView).offset(10);
        make.left.equalTo(self.searchView).offset(23);
        make.right.equalTo(self.searchView).offset(-23);
        make.height.mas_equalTo(39);
    }];
    
}

- (CGSize)intrinsicContentSize {
    return UILayoutFittingExpandedSize;
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView {

    if (scrollView.contentOffset.y <= 0) {
        self.showMaskLine = false;
    } else {
        self.showMaskLine = true;
    }
}



- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if(!self.exitSearch){
        [self.view endEditing:YES];
        [self.searchTextField endEditing:YES];
        
        [self toSearchViewController];
    }else{
        self.exitSearch = NO;
    }
    
    
    return YES;
}

- (void)toSearchViewController
{
    ExploreSearchViewController *vc = [[ExploreSearchViewController alloc] init];
    vc.dismissBlock = ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    
            [self.view endEditing:YES];
            [self.searchTextField endEditing:YES];
        });
       
        self.exitSearch = NO;
    };
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Table view data source
//万一后台没有返回style按1处理
// style 1 竖直布局
// style 2 水平布局 可以多行 五个一行
// style 3 水平布局滑动
// style 4 热门专题
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
//    return 140;
    if (self.dataArray[indexPath.section].style == 3) {
        return 90*kScreenRatio;
    }else  if (self.dataArray[indexPath.section].style == 2) {
        return (90*kScreenRatio)*ceil(self.dataArray[indexPath.section].apps.count/5.0);

    }else  if (self.dataArray[indexPath.section].style == 1) {
        return 70*kScreenRatio;
    }else if (self.dataArray[indexPath.section].style == 4) {
        return 270 * kScreenRatio;
    }else{
        return 0;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.dataArray.count > 0) {
        return self.dataArray.count;
    }else{
        return 0;
    }
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//    return 1;
    if (self.dataArray[section].style == 0 || self.dataArray[section].style == 2 || self.dataArray[section].style == 3 || self.dataArray[section].style == 4) {
        return 1;
    }else{
        return self.dataArray[section].apps.count;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    UIView* headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 42)];
    headView.backgroundColor = UIColor.whiteColor;
    UILabel* headTitle = [[UILabel alloc] init];
#pragma mark ======bug=======
    NSString *name = @"";
    if (section < self.dataArray.count) {
        name = self.dataArray[section].name;
    }
    if (name.length > 24) {
        headTitle.text = [self.dataArray[section].name substringToIndex:24];
    }else{
        headTitle.text = self.dataArray[section].name;
    }

    headTitle.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:16];
    headTitle.textColor = SGColorFromRGB(0x333649);
    [headView addSubview:headTitle];
    [headTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(20);
        make.top.mas_equalTo(8);
        make.height.mas_equalTo(44);
    }];

    NSString *sectionName = self.dataArray[section].name;
    BOOL isRecentSection = [sectionName isEqualToString:@"最近使用"] || [sectionName isEqualToString:L(@"最近使用")];
    if (self.dataArray[section].style == 1
        || self.dataArray[section].style == 3
        || (self.dataArray[section].style == 2 && !isRecentSection)) {
        UIButton* allBtn = [[UIButton alloc] init];
        allBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [allBtn setTitle:L(@"全部") forState:normal];
        [allBtn setTitleColor:CMColorFromRGB(0x7190FF) forState:normal];
        [headView addSubview:allBtn];
        [allBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.mas_equalTo(-17);
            make.centerY.equalTo(headTitle);
        }];
        WEAKSELF
        [[allBtn rac_signalForControlEvents:UIControlEventTouchUpInside]
         subscribeNext:^(__kindof UIControl * _Nullable x) {
            AppsTableVC* vc = [[AppsTableVC alloc] initWitID:weakSelf.dataArray[section].Id];
            vc.hidesBottomBarWhenPushed = true;
            [weakSelf.navigationController pushViewController:vc animated:true];
        }
         ];
    }
    return headView;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
//    if(section == 0)
//    {
//        return .1f;
//    }
    return 52;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section{
    //11高度的灰色加12高度的白色，使得最后一行cell更宽
    UIView* footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 23)];
//    footerView.backgroundColor = CMColorFromRGB(0xF8F8FA);
    UIView* whiteView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 12)];
    whiteView.backgroundColor = UIColor.whiteColor;
//    [footerView addSubview:whiteView];
    
    return footerView;
    
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
    return 0.1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WEAKSELF;
   
    if (self.dataArray[indexPath.section].style == 3){
        HorizontalAPPCell *cell = [tableView dequeueReusableCellWithIdentifier:horizontalAPPCellIdentity forIndexPath:indexPath];
        cell.model = self.dataArray[indexPath.section];
        cell.block = ^(PWApplication* app){
            [weakSelf appClicked:app];
        };

        return cell;
    }
    else if (self.dataArray[indexPath.section].style == 2){
           CollectionViewCell *cell = [tableView dequeueReusableCellWithIdentifier:collectionViewCellIdentity forIndexPath:indexPath];
           cell.model = self.dataArray[indexPath.section];
           cell.block = ^(PWApplication* app){
               [weakSelf appClicked:app];
           };

           return cell;
       }
    else if (self.dataArray[indexPath.section].style == 1){
        ExploreCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentity forIndexPath:indexPath];
        [cell setValueWithApp:self.dataArray[indexPath.section].apps[indexPath.row]];
        cell.block = ^(){
            [weakSelf appClicked:weakSelf.dataArray[indexPath.section].apps[indexPath.row]];
        };

        return cell;
    }else{
        PWHotTitleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PWHotTitleTableViewCell" forIndexPath:indexPath];
        cell.model = self.dataArray[indexPath.section];
        cell.block = ^(PWApplication* app){
            [weakSelf appClicked:app];
        };
        cell.ClickTapCell = ^(NSInteger idStr) {
            [weakSelf goInfor:idStr];
        };
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AppsTableVC* vc = [[AppsTableVC alloc] initWitID:self.dataArray[indexPath.section].Id];
    vc.hidesBottomBarWhenPushed = true;
    [self.navigationController pushViewController:vc animated:true];
}

- (void)goInfor:(NSInteger )idStr{
    AppsTableVC* vc = [[AppsTableVC alloc] initWitID:idStr];
    vc.hidesBottomBarWhenPushed = true;
    [self.navigationController pushViewController:vc animated:true];
}

- (void)btnAction:(id)sender{
    PWLanguageViewController *vc = [[PWLanguageViewController alloc] initWithChangeType:ChangeNet];
    vc.title = L(@"选择网络");
    vc.hidesBottomBarWhenPushed = true;
    
    [self.navigationController pushViewController:vc animated:true];
}
#pragma mark - 懒加载
- (UIBarButtonItem *)rightBarButtonItem
{
    // 使用系统 UIBarButtonItem（自定义 view 在交互式转场里不会跟着淡出）
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"changenet"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(btnAction:)];
    item.tintColor = CMColorFromRGB(0x333649);
    return item;
}



- (UITableView *)tableView{
    if (_tableView == nil) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = NO;
        _tableView.backgroundColor = UIColor.whiteColor;
        _tableView.showsVerticalScrollIndicator = false;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        [self.view addSubview:_tableView];
        [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view).offset(58);
            make.bottom.equalTo(self.view);
            make.left.right.mas_equalTo(0);
        }];
        [_tableView registerClass:[ExploreCell class] forCellReuseIdentifier:cellIdentity];
        [_tableView registerClass:[HorizontalAPPCell class] forCellReuseIdentifier:horizontalAPPCellIdentity];
        [_tableView registerClass:[CollectionViewCell class] forCellReuseIdentifier:collectionViewCellIdentity];
        [_tableView registerClass:[PWHotTitleTableViewCell class] forCellReuseIdentifier:@"PWHotTitleTableViewCell"];
        [_tableView registerClass:[ExploreNewCell class] forCellReuseIdentifier:identity];
    }
    return _tableView;
}

- (NSMutableArray *)dataArray{
    if (_dataArray == nil) {
        _dataArray = [[NSMutableArray alloc]init];
    }
    return _dataArray;
}

@end
