//
//  PWNewsSearchCoinViewController.m
//  PWallet
//
//  Created by 郑晨 on 2020/1/3.
//  Copyright © 2020 fzm. All rights reserved.
//

#import "PWNewsSearchCoinViewController.h"
#import "PWSearchCoinChildViewController.h"
#import "CAPSPageMenu.h"
#import "SearchCoinViewController.h"
#import "Depend.h"
#import "PWContractVC.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]

@interface PWNewsSearchCoinViewController ()
<CAPSPageMenuDelegate,UITextFieldDelegate>

@property (nonatomic, strong) NSArray *dataArray;
@property (nonatomic, strong) NSMutableArray *titleArray;
@property (nonatomic, strong) NSMutableArray *nameArrray;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic, strong) CAPSPageMenu *pageMenu;
/** 已经在拉推荐币 / 建分栏（避免每次进页面都重建一遍 pageMenu） */
@property (nonatomic) BOOL isRequestingSupportChain;
/** 当前 pageMenu 里的 childVC（拆旧 pageMenu 时要按个摘掉通知监听，
    否则通知中心一直持有它们、旧 childVC 会跟着响应通知） */
@property (nonatomic, strong) NSMutableArray<PWSearchCoinChildViewController *> *childTabs;
/** 当前分栏的数据（**只在主线程读写**）：`postCoinDataForIndex:` 靠它取 payload。
    不能直接读 `nameArrray` —— `initData`（现在跑在后台线程）会重建它，主线程同时读会竞争。 */
@property (nonatomic, strong) NSArray *currentNames;

@end

@implementation PWNewsSearchCoinViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = UIColor.whiteColor;
    [self initTitleView];
    // ⚠️ 这里**不再同步建分栏**（原来在这里直接调 rebuildPageMenuWithTitles:）：
    //   `pushViewController:` 会在主线程同步跑完新页的 viewDidLoad/viewWillAppear 才开始转场动画，
    //   而建分栏要把每个 childVC 的 view 都 load 一遍（CAPSPageMenu）+ 首栏数据准备，
    //   构建慢的时候表现就是「点了右上角 +，卡在资产页很久才进搜索页」。
    //   改成转场结束后再建（见 viewDidAppear / buildInitialPageMenuIfNeeded）。
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // 转场已经结束，这里建分栏不会破坏 push 动画（内部有 `self.pageMenu` 幂等保护）
    [self buildInitialPageMenuIfNeeded];
}

/// 首次建分栏（幂等）：转场结束后调；`getWalletSupportChain` 失败分支也走这里
- (void)buildInitialPageMenuIfNeeded
{
    if (self.pageMenu) { return; }
    [self rebuildPageMenuWithTitles:@[L(@"首页币种")]
                              names:@[@{@"name": L(@"首页币种"), @"coinArray": @[]}]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.searchTextField endEditing:YES];
    });
    
//    if (@available(iOS 13.0, *)) {
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
//    } else {
//           // Fallback on earlier versions
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
//    }
    
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
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    else
    {
        self.navigationController.navigationBar.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        [self.navigationController.navigationBar setBackgroundImage:[CommonFunction createImageWithColor:ThemeBlueColor] forBarMetrics:UIBarMetricsDefault];

    }
    // ⚠️ 只在第一次进页面时拉推荐币（「首页币种」在 viewDidLoad 里已经先铺好了，不用等它）：
    // 原来每次 viewWillAppear 都走一遍 getWalletSupportChain → initData → createView：
    //   ① 会再叠一个 pageMenu + 一整套 childVC（通知被重复接收、重复整表查库）；
    //   ② initData 里每个币要做 4~6 次主线程同步 DB 往返，从搜索页返回都会卡住。
    if (!self.isRequestingSupportChain) {
        self.isRequestingSupportChain = YES;
        [self getWalletSupportChain];
    }

}

- (void)initTitleView
{
    _searchTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 257 * kScreenRatio, 36)];
    _searchTextField.placeholder = L(@"输入Token名称或合约地址");
    _searchTextField.backgroundColor = SGColorFromRGB(0xf8f8fa);
    _searchTextField.font = [UIFont systemFontOfSize:16.f];
    _searchTextField.textColor = SGColorFromRGB(0x333649);
    _searchTextField.leftViewMode = UITextFieldViewModeAlways;
    _searchTextField.delegate = self;
    [_searchTextField setValue:SGColorFromRGB(0x8a97a5) forKeyPath:@"placeholderLabel.textColor"];
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(6, 9, 23, 23)];
    imageView.image = [UIImage imageNamed:@"APP搜索"];
    [leftView addSubview:imageView];
    
    _searchTextField.leftView = leftView;


    self.navigationItem.titleView = _searchTextField;
    
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:L(@"取消") style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    [rightItem setTintColor:SGColorFromRGB(0x8e92a3)];
    [rightItem setTitleTextAttributes:@{NSForegroundColorAttributeName:SGColorFromRGB(0x8e92a3)} forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = [self rightBarButtonItem];
    self.navigationItem.leftBarButtonItem = [self leftBarButtonItem];
    
    
}

//重写返回方法
- (void)backAction{
    if (self.searchDismissBlock) {
        self.searchDismissBlock();
    }
    [self cancel];
}

//取消搜索
- (void)cancel {
    [self.view endEditing:true];
    [self.navigationController popViewControllerAnimated:false];
}

- (void)createView
{
    [self rebuildPageMenuWithTitles:self.titleArray names:self.nameArrray];
}

/// 重建分栏：先拆掉旧的 pageMenu（含 childVC 的通知监听），再按 titles 建新的
/// - Parameter titles: 每个 tab 的标题（= childVC.title）
/// - Parameter names: 与 titles 一一对应的数据字典（@{@"name":…, @"coinArray":…}）
- (void)rebuildPageMenuWithTitles:(NSArray *)titles names:(NSArray *)names
{
    if (titles.count == 0) { return; }
    [self teardownPageMenu];
    
    self.titleArray = [NSMutableArray arrayWithArray:titles];
    self.nameArrray = [NSMutableArray arrayWithArray:names];
    self.currentNames = self.nameArrray;
    
    NSMutableArray *childVC = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < (NSInteger)titles.count; i++) {
        PWSearchCoinChildViewController *coinChildVc = [[PWSearchCoinChildViewController alloc] init];
        coinChildVc.title = titles[i];
        // 通知是广播的，child 靠这个只处理自己那一栏
        coinChildVc.tabIndex = i;
        [childVC addObject:coinChildVc];
    }
    self.childTabs = childVC;
    
        
    NSDictionary *parameters = @{
        CAPSPageMenuOptionBottomMenuHairlineColor: SGColorFromRGB(0xececec),
        CAPSPageMenuOptionScrollMenuBackgroundColor: [UIColor whiteColor],
        CAPSPageMenuOptionSelectionIndicatorHeight: @(3),
        CAPSPageMenuOptionMenuHeight:@(40),
        CAPSPageMenuOptionMenuItemWidth:@(75),
        CAPSPageMenuOptionUnselectedMenuItemLabelColor: SGColorFromRGB(0x8e92a3),
        CAPSPageMenuOptionSelectedMenuItemLabelColor: SGColorFromRGB(0x333649),
        CAPSPageMenuOptionSelectionIndicatorColor: SGColorFromRGB(0x333649),
        CAPSPageMenuOptionMenuItemFont:[UIFont boldSystemFontOfSize:16],
        CAPSPageMenuOptionMenuSelectedItemFont:[UIFont boldSystemFontOfSize:16],
        CAPSPageMenuOptionAddBottomMenuHairline:@(YES),
        CAPSPageMenuOptionMenuMargin:@(20),
        CAPSPageMenuOptionMenuItemWidthBasedOnTitleTextWidth:@(YES),
        CAPSPageMenuOptionHideIndicator:@(YES)
    };
    
    // ⚠️ 分栏要铺满整页（只扣掉 Home 指示条的安全区）：
    // 原来写死 `kScreenHeight - kBottomOffset - 40`，而 `kBottomOffset` = iPhone X 系列 **83** / 其它 49
    // ⇒ 底部会空出 123pt/89pt 的白色块（父视图白底），列表被截在块上方 ——
    // 就是用户说的「底部有一块白色挡住了币种」。
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
    }
    CGRect menuFrame = CGRectMake(0, 0, self.view.bounds.size.width,
                                  self.view.bounds.size.height - bottomSafe);

    self.pageMenu = [[CAPSPageMenu alloc] initWithViewControllers:childVC frame:menuFrame options:parameters];
    self.pageMenu.delegate = self;
    [self addChildViewController:self.pageMenu];

    self.pageMenu.view.frame = menuFrame;
    // 只让宽度跟着父视图变（高度按上面算好的，别被拉成整屏而压到 Home 条下面）
    self.pageMenu.view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.pageMenu.view];
    self.pageMenu.currentPageIndex = 0;
    
    // CAPSPageMenu 初始化时不一定回调 didMoveToPage，这里主动让第一栏加载自己的数据
    [self postCoinDataForIndex:0];
}

/// 拆掉当前分栏（连同 childVC 的通知监听）
- (void)teardownPageMenu
{
    if (!self.pageMenu) { return; }
    for (PWSearchCoinChildViewController *child in self.childTabs) {
        [[NSNotificationCenter defaultCenter] removeObserver:child];
    }
    [self.childTabs removeAllObjects];
    self.childTabs = nil;
    [self.pageMenu.view removeFromSuperview];
    [self.pageMenu willMoveToParentViewController:nil];
    [self.pageMenu removeFromParentViewController];
    self.pageMenu = nil;
}

/// 广播「某一栏」的数据。child 靠 `index` 认领（不能用 name：非私钥钱包第一栏的 name 是 "1"，与 tab 标题不一致）
- (void)postCoinDataForIndex:(NSInteger)index
{
    NSArray *names = self.currentNames;   // 只在主线程读，见 currentNames 的注释
    if (index < 0 || index >= (NSInteger)names.count) { return; }
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:names[index]];
    dict[@"index"] = @(index);
    [[NSNotificationCenter defaultCenter] postNotificationName:SEARCHCOINNOTIFICATION object:dict];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // 搜索框只是入口：点它就进搜索页，本页自己不进编辑态。
    // ⚠️ 必须返回 NO：以前返回 YES，这个输入框会变成第一响应者，返回本页时系统重设第一响应者 /
    // 键盘收起都可能再触发一次 shouldBeginEditing，于是出现「刚返回又被推进搜索页」
    // 「点了返回像没反应」（一次性 exitSearch 标记也会被提前消费）。
    if (textField == self.searchTextField) {
        [self searchCoinAction];
    }
    return NO;
}

/**
 * 搜索币种
 */
- (void)searchCoinAction
{
    // 已经在搜索页时不要再推一个（点得快/时序抖动时可能重入）
    if (self.navigationController.topViewController != self) { return; }
    SearchCoinViewController *vc = [[SearchCoinViewController alloc] init];
    // 本页（以及它的上一页）都是整屏的，搜索页也必须藏掉 tabbar，
    // 否则 tabbar 会重新冒出来盖住底部结果（看着就是底下一块白条挡住了币种）
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc
                                         animated:false];
}

#pragma mark -- CAPSPageMenuDelegate
- (void)didMoveToPage:(UIViewController *)controller index:(NSInteger)index
{
    [self postCoinDataForIndex:index];
}

- (void)willMoveToPage:(UIViewController *)controller index:(NSInteger)index
{
    NSLog(@"will move index is %li",(long)index);

}

#pragma mark - 获取主链币种
- (void)getWalletSupportChain
{
    NSString *url = [NSString stringWithFormat:@"%@%@",WalletURL,RECOMMENDCOIN];
    WEAKSELF
    [PWNetworkingTool getRequestWithUrl:url
                             parameters:nil
                           successBlock:^(id object) {
        NSLog(@"objectis %@",object);
        if([object isKindOfClass:[NSNull class]])
        {
            return ;
        }
        NSArray *array = (NSArray*)object;
        // ⚠️ initData 是三段双重循环：每个币一次同步 DB 读（queryCoinPriceBasedOn:）+ 逐个建 CoinPrice 模型，
        // 上百个币全在主线程算 ⇒ 接口回来的那一刻明显卡一下。
        // 整体挪到后台算（里面最后只把 `createView` 丢回主线程），主线程不参与这段计算。
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self initData:array];
        });
        
    } failureBlock:^(NSError *error) {
        // 失败也不影响使用：转场结束后已经铺了「首页币种」那一栏（viewDidAppear → buildInitialPageMenuIfNeeded），
        // 这里幂等调一次兜底，不再重建整页
        [weakSelf buildInitialPageMenuIfNeeded];
    }];
}

/// ⚠️ 本方法只在**后台线程**调用（见 getWalletSupportChain 里的 dispatch）：
/// 里面每个币都有一次同步 DB 读 + 建模型（上百个币），放主线程必然要卡一下。
/// 只有最后的 createView（建分栏）会丢回主线程。
- (void)initData:(NSArray *)array
{
    self.dataArray = array;
    self.titleArray = [[NSMutableArray alloc] init];
    self.nameArrray = [[NSMutableArray alloc] init];
    // 币价写库很重（每个币 2~3 次同步 DB 往返），先收集起来，最后统一交给后台写
    NSMutableArray<CoinPrice *> *pendingPrices = [NSMutableArray array];
    // `isPriKeyWallet` 宏 = 一次 DB 查询（queryWalletIsSelected），原来在循环里每轮都用一次，
    // 先取一次就够了
    BOOL isPriKey = isPriKeyWallet;
    NSString *homeTitle = L(@"首页币种");
    [self.titleArray addObject:homeTitle];
    [self.nameArrray addObject:@{@"name":homeTitle,
                                 @"coinArray":@[]}];
    
    // 私钥钱包分支要拿「当前钱包的主链」做判重：整表查一次就够，
    // 原来每轮 i 都查一遍（N 次整表查询）
    NSString *currentMainChain = @"";
    if (isPriKey) {
        NSArray *walletCoins = [[PWDataBaseManager shared] queryCoinArrayBasedOnWallet:self.selectedWallet];
        if (walletCoins.count > 0) {
            currentMainChain = ((LocalCoin *)walletCoins[0]).coin_chain ?: @"";
        }
    }
    
    for (int i = 0; i < self.dataArray.count; i++) {
        // 导航栏
        NSString *nameStr = [NSString stringWithFormat:@"%@",[self.dataArray[i] objectForKey:@"name"]];
        if (IS_BLANK(nameStr)) {
            continue;
        }
        if (isPriKey )
        {
            NSString *titleStr = [NSString stringWithFormat:@"%@",[self.dataArray[i] objectForKey:@"name"]];
            NSString *mainStr = currentMainChain;
            if (i == 0)
            {
                [self.titleArray addObject:titleStr];
                NSArray *coinArray = [self.dataArray[i] objectForKey:@"items"];
                for(int i = 0;i < coinArray.count; i++)
                {

                    NSDictionary *dic = [coinArray objectAtIndex:i];
                    CoinPrice *localCoinprice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:dic[@"name"] platform:dic[@"platform"] andTreaty:[dic[@"treaty"] integerValue]];
                    CoinPrice *coinPrice = [[CoinPrice alloc] init];
                    coinPrice.coinprice_name = dic[@"name"];
                    coinPrice.coinprice_price = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_price; //[CommonFunction handlePrice:priceStr];
                    coinPrice.coinprice_dollarPrice = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_dollarPrice;
                    coinPrice.coinprice_icon = dic[@"icon"];
                    coinPrice.coinprice_sid = dic[@"sid"];
                    coinPrice.coinprice_nickname = dic[@"nickname"];
                    coinPrice.coinprice_id = [dic[@"id"] integerValue];
                    coinPrice.coinprice_chain = dic[@"chain"];
                    coinPrice.coinprice_platform = dic[@"platform"];
                    coinPrice.coin_sort = [dic[@"sort"] integerValue];
                    coinPrice.treaty = [dic[@"treaty"] integerValue];
                    coinPrice.coinprice_optional_name = dic[@"optional_name"];
                    coinPrice.coinprice_chain_country_rate = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_chain_country_rate;
                    coinPrice.coinprice_country_rate = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_country_rate;
                    coinPrice.lock = localCoinprice == nil ? 0 : localCoinprice.lock;
                    
                    [pendingPrices addObject:coinPrice];
                }

                NSMutableArray *nameArray = [NSMutableArray array];
                for (NSDictionary *coin in coinArray) {
                    NSString *chainStr = coin[@"chain"];
                    if (![coin[@"platform"] isEqualToString:@"other"])
                    {
                        for (NSString * name in self.localArray) {
                            if ([chainStr isEqualToString:name]) {
                                [nameArray addObject:coin];
                            }
                        }

                    }
                }

                NSDictionary *dict = @{@"name":nameStr,
                                       @"coinArray":nameArray};
                [self.nameArrray addObject:dict];
            }
           
            if ([nameStr containsString:mainStr])
            {
                [self.titleArray addObject:titleStr];
                NSArray *coinArray = [self.dataArray[i] objectForKey:@"items"];
                for(int i = 0;i < coinArray.count; i++)
                {
                    NSDictionary *dic = [coinArray objectAtIndex:i];
                    CoinPrice *localCoinprice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:dic[@"name"] platform:dic[@"platform"] andTreaty:[dic[@"treaty"] integerValue]];
                    CoinPrice *coinPrice = [[CoinPrice alloc] init];
                    coinPrice.coinprice_name = dic[@"name"];
                    coinPrice.coinprice_price = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_price; //[CommonFunction handlePrice:priceStr];
                    coinPrice.coinprice_dollarPrice = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_dollarPrice;
                    coinPrice.coinprice_icon = dic[@"icon"];
                    coinPrice.coinprice_sid = dic[@"sid"];
                    coinPrice.coinprice_nickname = dic[@"nickname"];
                    coinPrice.coinprice_id = [dic[@"id"] integerValue];
                    coinPrice.coinprice_chain = dic[@"chain"];
                    coinPrice.coinprice_platform = dic[@"platform"];
                    coinPrice.coin_sort = [dic[@"sort"] integerValue];
                    coinPrice.treaty = [dic[@"treaty"] integerValue];
                    coinPrice.coinprice_optional_name = dic[@"optional_name"];
                    coinPrice.coinprice_chain_country_rate = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_chain_country_rate;
                    coinPrice.coinprice_country_rate = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_country_rate;
                    coinPrice.lock = localCoinprice == nil ? 0 : localCoinprice.lock;
                    [pendingPrices addObject:coinPrice];
                }
                
                NSMutableArray *nameArray = [NSMutableArray array];
                for (NSDictionary *coin in coinArray) {
                    if (![coin[@"platform"] isEqualToString:@"other"])
                    {
                        
                        [nameArray addObject:coin];
                    }
                }
                NSDictionary *dict = @{@"name":nameStr,
                                       @"coinArray":nameArray};
                [self.nameArrray addObject:dict];
            }
            
#pragma mark =====以下代码放在if里面
        }
        else
        {
            NSString *titleStr = [NSString stringWithFormat:@"%@",[self.dataArray[i] objectForKey:@"name"]];
            [self.titleArray addObject:titleStr];
            if (i == 0) {
                nameStr = [NSString stringWithFormat:@"%i",i + 1];
            }
            
            NSArray *coinArray = [self.dataArray[i] objectForKey:@"items"];
            for(int i = 0;i < coinArray.count; i++)
            {
                NSDictionary *dic = [coinArray objectAtIndex:i];
                if ([dic[@"name"] isKindOfClass:[NSNull class]]) {
                    continue;
                }
                CoinPrice *localCoinprice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:dic[@"name"] platform:dic[@"platform"] andTreaty:[dic[@"treaty"] integerValue]];
                CoinPrice *coinPrice = [[CoinPrice alloc] init];
                coinPrice.coinprice_name = dic[@"name"];
                coinPrice.coinprice_price = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_price; //[CommonFunction handlePrice:priceStr];
                coinPrice.coinprice_dollarPrice = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_dollarPrice;
                coinPrice.coinprice_icon = dic[@"icon"];
                coinPrice.coinprice_sid = dic[@"sid"];
                coinPrice.coinprice_nickname = dic[@"nickname"];
                coinPrice.coinprice_id = [dic[@"id"] integerValue];
                coinPrice.coinprice_chain = dic[@"chain"];
                coinPrice.coinprice_platform = dic[@"platform"];
                coinPrice.coin_sort = [dic[@"sort"] integerValue];
                coinPrice.treaty = [dic[@"treaty"] integerValue];
                coinPrice.coinprice_optional_name = dic[@"optional_name"];
                coinPrice.coinprice_chain_country_rate = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_chain_country_rate;
                coinPrice.coinprice_country_rate = localCoinprice == nil ? 0.00 : localCoinprice.coinprice_country_rate;
                coinPrice.lock = localCoinprice == nil ? 0 : localCoinprice.lock;
                [pendingPrices addObject:coinPrice];
            }
            
            NSMutableArray *nameArray = [NSMutableArray array];
            for (NSDictionary *coin in coinArray) {
                if ([coin[@"platform"] isKindOfClass:[NSNull class]]) {
                    continue;
                }
                if (![coin[@"platform"] isEqualToString:@"other"])
                {
                    
                    [nameArray addObject:coin];
                }
            }
            
            NSDictionary *dict = @{@"name":nameStr,
                                   @"coinArray":nameArray};
            [self.nameArrray addObject:dict];
        }
    }
    
    // 币价写库单独排一个低优先级后台任务：它跟「建分栏」没有先后依赖，
    // 不能堵在下面那个 main 回调前面（否则 tab 要等上百次 DB 写完才能出来）
    if (pendingPrices.count > 0) {
        NSArray<CoinPrice *> *pricesToSave = [pendingPrices copy];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            for (CoinPrice *price in pricesToSave) {
                [[PWDataBaseManager shared] addCoinPrice:price];
            }
        });
    }
    
    // 上面这些循环都在后台线程跑（见 getWalletSupportChain 里的 dispatch），
    // 只有「建分栏」必须回主线程
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createView];
    });
}


#pragma mark - left right 

/// 右上角「添加代币」（导航栏改成系统 item 后的入口）
- (void)addCoinAction
{
    PWContractVC *vc = [[PWContractVC alloc] init];
    vc.hidesBottomBarWhenPushed = true;
    vc.contractBlock = ^{
    };
    [self.navigationController pushViewController:vc animated:true];
}

- (void)btnAction:(UIButton *)sender
{
    switch (sender.tag) {
        case 1:
        {
            [self backAction];
        }
            break;
        case 2:
        {
            PWContractVC *vc = [[PWContractVC alloc] init];
            vc.hidesBottomBarWhenPushed = true;
            vc.contractBlock = ^{
//                [self initValue];
            };
            [self.navigationController pushViewController:vc animated:true];
        }
            break;
        default:
            break;
    }
}


#pragma mark - 设置导航栏左右的按钮
- (UIBarButtonItem *)leftBarButtonItem
{
    // 使用系统 UIBarButtonItem（自定义 view 在交互式转场里不会跟着淡出）
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_back"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(backAction)];
    item.tintColor = SGColorFromRGB(0x333649);
    return item;
}

#pragma mark - 设置导航栏左右的按钮
- (UIBarButtonItem *)rightBarButtonItem
{
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_add"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(addCoinAction)];
    item.tintColor = SGColorFromRGB(0x333649);
    return item;
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
