//
//  SearchCoinViewController.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/28.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "SearchCoinViewController.h"
#import "UIViewController+RTRootNavigationController.h"
#import "PWAlertController.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface SearchCoinViewController ()<UITableViewDelegate,UITableViewDataSource,UISearchBarDelegate>
/**搜索框背景View*/
@property (nonatomic,strong) UIView *searchView;
/**搜索框*/
@property (nonatomic,strong) UITextField *searchTextField;
/**未搜索时显示请输入Token名称....的view*/
@property (nonatomic,strong) YYLabel *beginLabel;
@property (nonatomic,assign) NSInteger page;
@property (nonatomic,strong) UITableView *coinTableView;
@property (nonatomic,strong) UIView *titleLine;
@property (nonatomic,strong) NSMutableArray *nameArray; //存放搜索内容
@property (nonatomic,strong) NSMutableArray *datasourceArray;
@property (nonatomic,copy) NSArray *walletCoinArray;
@property (nonatomic,strong) UIView *noRecordView;
@property (nonatomic,strong) UIView *searchBarView;
@property (nonatomic,strong) UIButton *backBtn;
@property (nonatomic,strong) NSMutableArray *temporarilyArray;
@property (nonatomic,strong) UILabel *label;
@property (nonatomic,strong) UIButton *feedbackBtn;
/** 约束只装一次（见 viewDidLayoutSubviews） */
@property (nonatomic, assign) BOOL didInstallConstraints;
@end

static const NSInteger limit = 10;

@implementation SearchCoinViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.rt_disableInteractivePop = true;
    
    self.title = L(@"添加币种");
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _temporarilyArray = [[NSMutableArray alloc] init];
    self.nameArray = [[NSMutableArray alloc] init];
    self.datasourceArray = [[NSMutableArray alloc] init];
    self.walletCoinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    _page = 1;
    [self createView];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // ⚠️ 本页原来完全不动导航栏外观，会继承「上一个页面」遗留的 appearance / tintColor：
    // 比如先进过「添加代币」（PWContractVC）再进来，返回键与「取消」会落回系统默认的**黑色**；
    // 这里跟分栏页（PWNewsSearchCoinViewController）保持一致：蓝底 + #333649 深色标题/返回。
    UINavigationBar *bar = self.navigationController.navigationBar;
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
        appearance.backgroundColor = ThemeBlueColor;
        appearance.backgroundEffect = nil;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
    }
    else
    {
        bar.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        [bar setBackgroundImage:[CommonFunction createImageWithColor:ThemeBlueColor] forBarMetrics:UIBarMetricsDefault];
    }
    // 返回键 / 取消：用「当前导航栏 tint」而不是继承来的黑。
    // （取消保持原设计的次要灰 0x8e92a3，item 自己的 tintColor 优先级高于导航栏 tint）
    bar.tintColor = SGColorFromRGB(0x333649);
    self.navigationItem.rightBarButtonItem.tintColor = SGColorFromRGB(0x8e92a3);
    
    [self.searchTextField becomeFirstResponder];
}

//重写返回方法
- (void)backAction{
    [self.view endEditing:YES];
    [self.searchTextField endEditing:YES];
    [self cancel];
}

//取消搜索
- (void)cancel {
    if (self.dismissBlock) {
        self.dismissBlock();
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)createView
{
    
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:L(@"取消") style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = rightItem;
    [rightItem setTitleTextAttributes:@{NSForegroundColorAttributeName:SGColorFromRGB(0x8e92a3)} forState:UIControlStateNormal];
    
    
    
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
    [searchTextField setValue:SGColorFromRGB(0x8a97a5) forKeyPath:@"placeholderLabel.textColor"];
    [searchTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    UIImageView *imageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"APP搜索"]];
    imageView.frame = CGRectMake(13, 9, 20, 20);
    [searchTextField.leftView addSubview:imageView];
    
    UITableView *coinTableView = [[UITableView alloc] init];
    coinTableView.delegate = self;
    coinTableView.dataSource = self;
    coinTableView.rowHeight = 70;
    coinTableView.backgroundColor = self.view.backgroundColor;
    coinTableView.showsVerticalScrollIndicator = true;
    coinTableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    coinTableView.separatorColor = LineColor;
    [self.view addSubview:coinTableView];
    self.coinTableView = coinTableView;
    
    coinTableView.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingTarget:self refreshingAction:@selector(loadMore)];
    coinTableView.mj_footer.hidden = true;
    
    UIView *titleLine = [[UIView alloc] init];
    titleLine.backgroundColor = LineColor;
    [self.view addSubview:titleLine];
    self.titleLine = titleLine;
    
    //没有交易记录
    UIView *noRecordView = [[UIView alloc]init];
    [self.view addSubview:noRecordView];
    self.noRecordView = noRecordView;
    
    UILabel *label = [[UILabel alloc]init];
    [self.noRecordView addSubview:label];
    label.text = L(@"抱歉，未能找到相关币种");
    label.textColor = SGColorFromRGB(0x8E92A3);
    label.font = [UIFont systemFontOfSize:16];
    self.label = label;
    
  
    UIView *bottomView = [[UIView alloc] init];
    coinTableView.tableFooterView = bottomView;
    
    //未搜索
    YYLabel *beginLabel = [[YYLabel alloc]init];
    [self.view addSubview:beginLabel];

    beginLabel.text = L(@"上传Token搜索提示");
   
    beginLabel.numberOfLines = 0;
    beginLabel.textContainerInset = UIEdgeInsetsMake(0, 40, 300, 40);
    beginLabel.backgroundColor = self.view.backgroundColor;
    beginLabel.textColor = SGColorFromRGB(0x8E92A3);
    beginLabel.font = [UIFont systemFontOfSize:14];
    self.beginLabel = beginLabel;
    
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // ⚠️ 约束只装一次：mas_makeConstraints 不会清理旧约束，而本回调每次布局都会跑
    // （弹/收键盘、旋转、列表刷新都会触发），每次都新增一整套 ⇒ 约束越堆越多、页面越来越卡。
    if (self.didInstallConstraints) { return; }
    self.didInstallConstraints = YES;
    
    
    [self.titleLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(0);
        make.height.mas_equalTo(0.5);
    }];
    
    [self.searchView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleLine.mas_bottom);
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(68);
    }];
    
    [self.searchTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.searchView).offset(10);
        make.left.equalTo(self.searchView).offset(23);
        make.right.equalTo(self.searchView).offset(-23);
        make.height.mas_equalTo(39);
    }];
    
    [self.coinTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(self.searchView.mas_bottom);
        // ⚠️ 原来是 `+49`（正数）⇒ 表格比页面还高 49pt，最底部那段内容在屏幕外、滚不到；
        // 现在本页也藏了 tabbar，直接铺到底即可（底部安全区由 table 自动 contentInset 处理）
        make.bottom.equalTo(self.view);
    }];
    
    [self.noRecordView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.coinTableView);
    }];
    
    [self.label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.noRecordView);
        make.top.equalTo(self.noRecordView).offset(126);
    }];

    [self.feedbackBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.noRecordView);
        make.width.mas_equalTo(107);
        make.height.mas_equalTo(44);
        make.top.equalTo(self.label.mas_bottom).offset(27);
    }];

    [self.beginLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.noRecordView);
    }];
    
}

#pragma mark-
#pragma mark 类方法
- (void)completeBtnAction
{
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    [self showProgressWithMessage:@""];
    for (int i = 0; i < _temporarilyArray.count; i++) {
        NSInteger count = 0;
        NSDictionary *dic = [_temporarilyArray objectAtIndex:i];
        CoinPrice *coinPrice = dic[@"COINPRICE"];
        BOOL isON = [dic[@"STATE"] boolValue];
        for (int j = 0; j < _walletCoinArray.count; j++) {
            LocalCoin *coin = [_walletCoinArray objectAtIndex:j];
            count ++;
            if ([coin.coin_type isEqualToString:coinPrice.coinprice_name]) {
                if (isON) {
                    coin.coin_show = 1;
                }else{
                    coin.coin_show = 0;
                }
                dispatch_group_enter(group);
                dispatch_async(queue, ^{
                    [[PWDataBaseManager shared] updateCoin:coin];
                    dispatch_group_leave(group);
                });
                continue;
            }
        }
        
        if (count == _walletCoinArray.count) {
            if (isON) {
                dispatch_group_enter(group);
                dispatch_async(queue, ^{
                    [[PWDataBaseManager shared] addCoinPrice:coinPrice];
                    [GoFunction addCoinIntoWallet:coinPrice];
                    dispatch_group_leave(group);
                });
            }
        }
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(0, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgress];
            [self.navigationController popViewControllerAnimated:YES];
        });
    });
}

#pragma mark-
#pragma mark UITableViewDelegate & UITableViewDatasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return _datasourceArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    static NSString *CellIdentifier = @"Cell";
    CoinTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[CoinTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    cell.coin = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = CMTextFont18;
    cell.textLabel.textColor = TextColor51;
    cell.detailTextLabel.font = CMTextFont14;
    cell.detailTextLabel.textColor = PlaceHolderColor;
    cell.imageView.backgroundColor = [UIColor grayColor];
    cell.separatorInset = UIEdgeInsetsMake(0, 56, 0, 0);
    __block typeof(cell) weakCell = cell;
    cell.selectTemCoin = ^(CoinPrice *coinPrice,BOOL isON) {
        NSArray *localCoinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
        // 获取钱包里面币种的所有主链币，放在数组里，如果点击的币种的主链在主链币数组里，那按照之前的逻辑。如果点击的币种不在主链币数组里，那么就弹框提示要输入密码加入主链币
        NSMutableArray *coinChainMarray = [[NSMutableArray alloc] init];
        for (LocalCoin *coin in localCoinArray) {
            
            [coinChainMarray addObject:coin.coin_chain == nil ? coin.coin_type : coin.coin_chain];
        }
        if ([coinChainMarray containsObject:coinPrice.coinprice_chain])
        {
            dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
            dispatch_async(queue, ^{
                [[PWDataBaseManager shared] addCoinPrice:coinPrice];
                [GoFunction addCoinIntoWallet:coinPrice];
            });
        }
        else
        {
            LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
            // 已开启面容/指纹时直接验证通过，否则弹密聊密码输入框
            [ChatPasswordGate requestVerifiedPasswordWithTitle:L(@"请输入密聊密码")
                                                    cancelled:^{ weakCell.switchBtn.on = NO; }
                                                      success:^(NSString * _Nonnull text) {
                if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
                    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
                    dispatch_async(queue, ^{
                        [[PWDataBaseManager shared] addCoinPrice:coinPrice];
                        [GoFunction addChainCoinIntoWallet:coinPrice passwd:text];
                    });
                    
                } else {
                    weakCell.switchBtn.on = NO;
                    [self showCustomMessage:L(@"密码错误") hideAfterDelay:1];
                }
            }];
        }
    };
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *dic = [self.datasourceArray objectAtIndex:indexPath.row];
    CoinTableViewCell *coinCell = (CoinTableViewCell *)cell;
    coinCell.coinArray = self.walletCoinArray;
    coinCell.temporarilyArray = self.temporarilyArray;
    coinCell.searchDic = dic;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   
}

#pragma mark- textFieldDidChange

- (void)textFieldDidChange:(UITextField*)textField {
    if (IS_BLANK(textField.text)) {
        [self.view bringSubviewToFront:self.beginLabel];
    } else {
        [self.view bringSubviewToFront:self.coinTableView];
        if (isPriKeyWallet)
        {
            LocalCoin *coin = self.walletCoinArray[0];
            
            [self requestCoinWithChain:coin.coin_chain platform:coin.coin_platform];
        }
        else
        {
            [self requestQuationList];
        }
       
    }
}

#pragma mark-
#pragma mark 网络请求
- (void)requestQuationList
{
    [self showProgressWithMessage:@""];
    
    NSString *nameStr = self.searchTextField.text;
    __weak typeof(self)weakself = self;
    _page = 1;
    NSString *platformId = @"1";
    
    NSDictionary *param = @{@"keyword":nameStr,@"page":@(_page),@"limit":@(limit),@"platform_id":platformId};
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST serverUrl:WalletURL apiPath:SEARCHCOINBYCHAINANDPLATFORM parameters:param progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
        
        [self hideProgress];
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        [weakself.datasourceArray removeAllObjects];
        NSArray *dataArray = result[@"data"];
        if (dataArray.count != 0) {
            weakself.page ++;
            [weakself.datasourceArray addObjectsFromArray:dataArray];
            [self.view bringSubviewToFront:self.coinTableView];
            self.coinTableView.mj_footer.hidden = false;
            
            if (dataArray.count < limit) {
                self.coinTableView.mj_footer.hidden = true;
            } else {
                [self.coinTableView.mj_footer resetNoMoreData];
            }
        }else{
            [self.view bringSubviewToFront:self.noRecordView];
            self.coinTableView.mj_footer.hidden = true;
        }
        [self.coinTableView reloadData];
    } failure:^(NSString * _Nullable errorMessage) {
        [self hideProgress];
    }];
}

/**
 * 加载更多
 */
- (void)loadMore
{
    if (isPriKeyWallet ) {
        LocalCoin *coin = self.walletCoinArray[0];
        [self loadMoreWithChain:coin.coin_chain platform:coin.coin_platform];
        return;
    }
   
    __weak typeof(self)weakself = self;
    NSString *nameStr = self.searchTextField.text;
    
    NSString *platformId = @"1";

    NSDictionary *param = @{@"name":nameStr,@"page":@(_page),@"limit":@(limit),@"platform_id":platformId};
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST serverUrl:WalletURL apiPath:SEARCHCOINBYNAME parameters:param progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
        [self hideProgress];
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        NSArray *dataArray = result[@"data"];
        if (dataArray.count != 0) {
            weakself.page ++;
            [weakself.datasourceArray addObjectsFromArray:dataArray];
            [self.coinTableView reloadData];
            [self.coinTableView.mj_footer endRefreshing];
        } else {
            [self.coinTableView.mj_footer endRefreshingWithNoMoreData];
        }
        
        
    } failure:^(NSString * _Nullable errorMessage) {
        
    }];
}

#pragma mark - 私钥钱包搜索币种
- (void)requestCoinWithChain:(NSString *)chain platform:(NSString *)platform
{
    NSString *keyword = self.searchTextField.text;
    NSString *platformId = @"1";
    _page = 1;
    NSDictionary *param = @{@"page":@(_page),
                            @"limit":@(limit),
                            @"platform_id":platformId,
                            @"keyword":keyword,
                            @"chain":chain,
                            @"platform":platform
    };
    WEAKSELF
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:WalletURL
                                          apiPath:SEARCHCOINBYCHAINANDPLATFORM
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        [self hideProgress];
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        [weakSelf.datasourceArray removeAllObjects];
        NSArray *dataArray = result[@"data"];
        if (dataArray.count != 0) {
            weakSelf.page ++;
            [weakSelf.datasourceArray addObjectsFromArray:dataArray];
            [self.view bringSubviewToFront:self.coinTableView];
            self.coinTableView.mj_footer.hidden = false;
            if (dataArray.count < limit) {
                self.coinTableView.mj_footer.hidden = true;
            } else {
                [self.coinTableView.mj_footer resetNoMoreData];
            }
        }else{
            [self.view bringSubviewToFront:self.noRecordView];
            self.coinTableView.mj_footer.hidden = true;
        }
        [self.coinTableView reloadData];
    } failure:^(NSString * _Nullable errorMessage) {
        [self hideProgress];
    }];
}

/**
 * 加载更多
 */
- (void)loadMoreWithChain:(NSString *)chain platform:(NSString *)platform
{
    WEAKSELF
   NSString *keyword = self.searchTextField.text;
    NSString *platformId = @"1";
    NSDictionary *param = @{@"page":@(_page),
                            @"limit":@(limit),
                            @"platform_id":platformId,
                            @"keyword":keyword,
                            @"chain":chain,
                            @"platform":platform
    };
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST serverUrl:WalletURL apiPath:SEARCHCOINBYCHAINANDPLATFORM parameters:param progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
        [self hideProgress];
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        NSArray *dataArray = result[@"data"];
        if (dataArray.count != 0) {
            weakSelf.page ++;
            [weakSelf.datasourceArray addObjectsFromArray:dataArray];
            [self.coinTableView reloadData];
            [self.coinTableView.mj_footer endRefreshing];
        } else {
            [self.coinTableView.mj_footer endRefreshingWithNoMoreData];
        }
        
        
    } failure:^(NSString * _Nullable errorMessage) {
        
    }];
}

@end
