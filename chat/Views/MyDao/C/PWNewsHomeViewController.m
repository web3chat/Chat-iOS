//
//  PWNewsHomeViewController.m
//  PWallet
//
//  Created by 郑晨 on 2019/11/29.
//  Copyright © 2019 fzm. All rights reserved.
//

#import "PWNewsHomeViewController.h"
#import "HomeCoinTableViewCell.h"
#import "LocalCoin.h"
#import "LocalWallet.h"
#import "PWDataBaseManager.h"
#import "CoinDetailViewController.h"
#import "CoinPrice.h"
#import <NSObject+YYModel.h>
#import "ScanViewController.h"
//#import "TransferViewController.h"
//#import "PWNesReceiptMoneyViewController.h"
//#import "PWLoginTool.h"
#import <Masonry/Masonry.h>
#import "Depend.h"
#import "GoFunction.h"
#import "SGNetWork.h"
#import "PWNoCoinViewCell.h"
#import "PreCoin.h"
#import "PWContractVC.h"
#import "PWContractRequest.h"
#import "PWNewsSearchCoinViewController.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]

static NSString *reuseID = @"tableview";

@interface PWNewsHomeViewController ()
<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property(nonatomic,strong)NSMutableArray *coinDatasource; // 币种信息
@property(nonatomic,strong)NSMutableArray *priceArray;
@property(nonatomic,strong)LocalWallet *homeWallet; // 当前钱包
/** 当前钱包的wallet_id */
@property(nonatomic,assign)NSInteger walletId;
/**
 * 行情请求的 task（只用于持有，未实际取消）。
 * ⚠️ 必须是 **atomic**：`requestQuationList` 会被多个后台队列/多次重入调用，
 *    nonatomic 的 strong 属性被多线程同时赋值 = ARC 对旧值过度 release（EXC_BAD_ACCESS）。
 */
@property(atomic,strong)NSURLSessionDataTask *sessionTask;
@property(nonatomic,strong)dispatch_source_t timer;

@property (nonatomic, strong) LocalCoin *localCoin;

@end

@implementation PWNewsHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

//    self.navigationItem.leftBarButtonItem = [self leftBarButtonItem];
    self.navigationItem.rightBarButtonItem = [self rightBarButtonItem];
    
    // 左上角授权按钮
    UIBarButtonItem *approveItem = [[UIBarButtonItem alloc] initWithTitle:L(@"授权") style:UIBarButtonItemStylePlain target:self action:@selector(gotoApprove)];
    [approveItem setTintColor:SGColorFromRGB(0x333649)];
    self.navigationItem.leftBarButtonItem = approveItem;
    
    self.view.backgroundColor = SGColorFromRGB(0xffffff);
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self initValue];

    
    [self downRefresh];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
    // ⚠️ 必须用 setNavigationBarHidden:：从「AI 客服 / 扫码」这类自隐藏导航栏的页面返回时，
    // 只把 hidden 置 NO 不会清掉 `isNavigationBarHidden` 这个内部状态，
    // 之后再 push 详情页就会没导航栏、也没返回键（用户 2026-10-23 反馈）。
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    self.navigationItem.title = L(@"我的资产");
    // 左上角「授权」按钮是 viewDidLoad 里创建的一次性 item，切语言后需在这里同步文案
    self.navigationItem.leftBarButtonItem.title = L(@"授权");
    self.showMaskLine = false;
//    if (@available(iOS 13.0, *)) {
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
//    } else {
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
//    }
    
    if (@available(iOS 15, *))
    {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        // iOS 26/27：不显式 configureWithOpaqueBackground，系统会按「液态玻璃」绘制，
        // backgroundColor 只作用于状态栏区域，导航栏本体变成白色玻璃。
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = ThemeBlueColor;
        // 双保险：部分 iOS 26 小版本只认 backgroundImage
        appearance.backgroundImage = [CommonFunction createImageWithColor:ThemeBlueColor];
        appearance.backgroundEffect = nil;
        appearance.shadowColor = UIColor.clearColor;
        // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊（否则「授权」「+」会变成白色药丸）
        appearance.buttonAppearance.normal.backgroundImage = [UIImage new];
        appearance.buttonAppearance.highlighted.backgroundImage = [UIImage new];
        appearance.doneButtonAppearance.normal.backgroundImage = [UIImage new];
        appearance.doneButtonAppearance.highlighted.backgroundImage = [UIImage new];
        appearance.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        UINavigationBar *bar = self.navigationController.navigationBar;
        bar.translucent = NO;
        // 再兜一层：iOS 26 某些版本会忽略 appearance.backgroundColor，但认 barTintColor / backgroundColor
        bar.barTintColor = ThemeBlueColor;
        bar.backgroundColor = ThemeBlueColor;
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
        bar.compactAppearance = appearance;
    }
    else
    {
        self.navigationController.navigationBar.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        [self.navigationController.navigationBar setBackgroundImage:[CommonFunction createImageWithColor:ThemeBlueColor] forBarMetrics:UIBarMetricsDefault];

    }
   
/// 无需额外 0.2s 延迟，尽快启动余额轮询
    dispatch_async(dispatch_get_main_queue(), ^{
        [self openGCDBalance];
    });
     
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self stopGCDBalance];
}


- (void)initValue{

    self.homeWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    self.priceArray = [[NSMutableArray alloc] init];
    self.coinDatasource = [NSMutableArray arrayWithArray:[[PWDataBaseManager shared] queryCoinArrayBasedOnWalletIDAndShow]];

    [self.tableView reloadData];
}//娘雾义  圈饰真  昂萧旺  质载薄  诉委士

/**
 * 轮询
 */
- (void)openGCDBalance
{
    /// 先清掉可能还在跑的旧定时器：viewWillAppear 会反复进来，
    /// 直接覆盖 `_timer` 会让旧的 dispatch source 失去引用（激活态未取消就释放 = 未定义行为，可能闪退），
    /// 同时旧定时器会继续 tick，造成多轮 downRefresh 并发改同一个数据源。
    [self stopGCDBalance];

    /// 适当拉长间隔，避免与异步余额请求叠压、减少无效刷新
    NSTimeInterval period = 6.0;
    WEAKSELF
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, 0);
    dispatch_source_set_timer(_timer, start, period * NSEC_PER_SEC, 0); //每秒执行

    dispatch_source_set_event_handler(_timer, ^{
        
        [weakSelf downRefresh];
    });
    dispatch_resume(_timer);
}

/**
 * 停止轮询
 */
- (void)stopGCDBalance
{
    NSLog(@"停止查余额啦！！！");
    if (_timer)
    {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (void)dealloc
{
    // 定时器是在后台队列里 tick 的，控制器销毁时必须取消，否则会继续回调已释放的页面
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

/**
 * 下拉刷新
 */
- (void)downRefresh
{
    // 定时器是在全局队列里 tick 的，而 `coinDatasource` / 表格的读写在主线程；
    // 统一回主线程取快照，避免与 reloadData / 数据源回调并发读写同一个可变数组（EXC_BAD_ACCESS 的典型来源）。
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self downRefresh];
        });
        return;
    }

    WEAKSELF
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [weakSelf requestQuationList];
    });

    // ⚠️ 普通币余额走的是 Go 的 C 桥（`GoFunction goGetBalance`），**全局只能一个接一个调**。
    //    以前这里是 `dispatch_queue_create` 每轮新建一个串行队列 ⇒ 上一轮还没跑完（网络慢时
    //    很容易超 6s）下一轮又开一轮，两个串行队列之间是并发的 ⇒ C 桥被并发进入（闪退）。
    //    改成全类共用一个串行队列，跨轮也串行化。
    static dispatch_queue_t balanceQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        balanceQueue = dispatch_queue_create("com.pwallet.coinRefresh", DISPATCH_QUEUE_SERIAL);
    });

    NSArray *coinArray = [self.coinDatasource copy];
    NSUInteger coinCount = coinArray.count;
    if (coinCount == 0) {
        return;
    }

    /// 等「当前这一轮」所有币种余额逻辑结束后，主线程只 reload 一次，避免 N 次无效刷新、体感卡顿
    dispatch_group_t balanceGroup = dispatch_group_create();

    for (NSInteger i = 0; i < (NSInteger)coinCount; i++) {
        LocalCoin *coin = coinArray[i];
        dispatch_group_enter(balanceGroup);

        dispatch_async(queue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            void (^markBalanceDone)(void) = ^{
                dispatch_group_leave(balanceGroup);
            };

            if (!strongSelf) {
                markBalanceDone();
                return;
            }

            // 防止出现币种没有地址的情况
            if (coin.coin_address == nil ||
                [coin.coin_address isEqualToString:@""] ||
                coin.coin_address.length <= 0) {
                for (LocalCoin *localCoin in coinArray) {
                    if ([localCoin.coin_chain isEqualToString:coin.coin_chain] &&
                        [localCoin.coin_chain isEqualToString:localCoin.coin_type]) {
                        coin.coin_address = localCoin.coin_address;
                        break;
                    }
                }
            }

            if (coin.coin_type_nft == 10) { // 合约币
                if ([coin.coin_chain isEqualToString:@"BTY"]) {
                    [PWContractRequest getBalanceWithChain:coin.coin_chain
                                                   address:coin.coin_address
                                               tokenSymbol:coin.coin_pubkey
                                                   success:^(id  _Nonnull object) {
                        __strong typeof(weakSelf) innerSelf = weakSelf;
                        if (!innerSelf) {
                            markBalanceDone();
                            return;
                        }
                        NSDictionary *result = nil;
                        if ([object isKindOfClass:[NSData class]]) {
                            NSError *error;
                            result = [NSJSONSerialization JSONObjectWithData:(NSData *)object options:NSJSONReadingAllowFragments error:&error];
                        }
                        NSLog(@"result %@", result);
                        if (result && ![result[@"result"] isKindOfClass:[NSNull class]]) {
                            CGFloat balance = [result[@"result"][@"balance"] doubleValue];
                            if (balance != -1) {
                                coin.coin_balance = balance;
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    NSUInteger index = [innerSelf.coinDatasource indexOfObject:coin];
                                    if (index != NSNotFound && index < innerSelf.coinDatasource.count) {
                                        [innerSelf.coinDatasource replaceObjectAtIndex:index withObject:coin];
                                        // 只在币还在列表里时才写回余额：
                                        // 币可能刚被左滑删除（列表已重建），此时再写库会把它重新插回去（「删了还在」）
                                        [[PWDataBaseManager shared] updateCoin:coin];
                                    }
                                    markBalanceDone();
                                });
                                return;
                            }
                        }
                        markBalanceDone();
                    } failure:^(NSString * _Nonnull errorMsg) {
                        markBalanceDone();
                    }];
                } else {
                    [PWContractRequest getBalancewithCoinType:coin.coin_chain
                                                      address:coin.coin_address
                                                       execer:coin.coin_pubkey
                                                      success:^(id  _Nonnull object) {
                        __strong typeof(weakSelf) innerSelf = weakSelf;
                        if (!innerSelf) {
                            markBalanceDone();
                            return;
                        }
                        NSDictionary *result = nil;
                        if ([object isKindOfClass:[NSData class]]) {
                            NSError *error;
                            result = [NSJSONSerialization JSONObjectWithData:(NSData *)object options:NSJSONReadingAllowFragments error:&error];
                        }
                        NSLog(@"result %@", result);
                        if (result && ![result[@"result"] isKindOfClass:[NSNull class]]) {
                            CGFloat balance = [result[@"result"][@"balance"] doubleValue];
                            if (balance != -1) {
                                coin.coin_balance = balance;
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    NSUInteger index = [innerSelf.coinDatasource indexOfObject:coin];
                                    if (index != NSNotFound && index < innerSelf.coinDatasource.count) {
                                        [innerSelf.coinDatasource replaceObjectAtIndex:index withObject:coin];
                                        // 同上：币已不在列表里（刚删掉）就不再写库，避免把它复活
                                        [[PWDataBaseManager shared] updateCoin:coin];
                                    }
                                    markBalanceDone();
                                });
                                return;
                            }
                        }
                        markBalanceDone();
                    } failure:^(NSString * _Nonnull errorMsg) {
                        NSLog(@"Error: %@", errorMsg);
                        markBalanceDone();
                    }];
                }

            } else {
                dispatch_async(balanceQueue, ^{
                    __strong typeof(weakSelf) innerSelf = weakSelf;
                    if (!innerSelf) {
                        markBalanceDone();
                        return;
                    }
                    CGFloat balance = [GoFunction goGetBalance:coin.coin_type platform:coin.coin_platform address:coin.coin_address andTreaty:coin.treaty];
                    if (balance != -1) {
                        coin.coin_balance = balance;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSUInteger index = [innerSelf.coinDatasource indexOfObject:coin];
                            if (index != NSNotFound && index < innerSelf.coinDatasource.count) {
                                [innerSelf.coinDatasource replaceObjectAtIndex:index withObject:coin];
                                // 同上：币已不在列表里（刚删掉）就不再写库，避免把它复活
                                [[PWDataBaseManager shared] updateCoin:coin];
                            }
                            markBalanceDone();
                        });
                        return;
                    }
                    markBalanceDone();
                });
            }
        });
    }

    dispatch_group_notify(balanceGroup, dispatch_get_main_queue(), ^{
        if (!weakSelf) { return; }
        [weakSelf.tableView reloadData];
    });
    
//    WEAKSELF
//    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
//    dispatch_async(queue, ^{
//        [self requestQuationList];
//    });
//
//    for (int i = 0; i < self.coinDatasource.count; i ++) {
//        dispatch_async(queue, ^{
//            if (weakSelf.coinDatasource.count != 0)
//            {
//
//                LocalCoin *coin = [weakSelf.coinDatasource objectAtIndex:i];
//                // 防止出现币种没有地址的情况
//                if (coin.coin_address == nil
//                    || [coin.coin_address isEqualToString:@""]
//                    || coin.coin_address.length <= 0)
//                {
//                    for (LocalCoin *localCoin in weakSelf.coinDatasource)
//                    {
//                        if ([localCoin.coin_chain isEqualToString:coin.coin_chain] && [localCoin.coin_chain isEqualToString:localCoin.coin_type]) {
//                            coin.coin_address = localCoin.coin_address;
//                        }
//                        
//                    }
//                }
//
//                if (coin.coin_type_nft == 10) { // 合约币
//                    [PWContractRequest getBalancewithCoinType:coin.coin_chain
//                                                      address:coin.coin_address
//                                                       execer:coin.coin_pubkey
//                                                      success:^(id  _Nonnull object) {
//                        NSError *error;
//                        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:&error];
//                        NSLog(@"result %@",result);
//                        if (![result[@"result"] isKindOfClass:[NSNull class]]) {
//                            CGFloat balance = [result[@"result"][@"balance"] doubleValue];
//                            if (balance != -1)
//                            {
//                                // 有余额
//                                coin.coin_balance = balance;
//
//                                if(i < weakSelf.coinDatasource.count)
//                                {
//                                    [weakSelf.coinDatasource replaceObjectAtIndex:i withObject:coin];
//                                }
//                                [[PWDataBaseManager shared] updateCoin:coin];
//                            }
//                        }
//                    } failure:^(NSString * _Nonnull errorMsg) {
//                        
//                    }];
//                    
//                }else{
//                    CGFloat balance = [GoFunction goGetBalance:coin.coin_type platform:coin.coin_platform address:coin.coin_address andTreaty:coin.treaty];
//                    if (balance != -1)
//                    {
//                        // 有余额
//                        coin.coin_balance = balance;
//
//                        if(i < weakSelf.coinDatasource.count)
//                        {
//                            [weakSelf.coinDatasource replaceObjectAtIndex:i withObject:coin];
//                        }
//                        [[PWDataBaseManager shared] updateCoin:coin];
//                    }
//                }
//                
//            }
//        });
//    }
}

#pragma mark 网络请求
- (void)requestQuationList
{
    
    NSMutableArray *nameArray = [[NSMutableArray alloc] init];
    NSArray *coinArray =  [NSArray arrayWithArray:[[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID]];
    for (LocalCoin *coin in coinArray) {
        // 币种 type / platform 可能为空（历史数据 / 服务端新币）——
        // 空串进 `names` 会让后端返回一堆异常条目，这里直接跳过
        if (coin.coin_type.length == 0) { continue; }
        NSString *name = [NSString stringWithFormat:@"%@,%@", coin.coin_type, coin.coin_platform ?: @""];

        if (![nameArray containsObject:name])
        {
            [nameArray addObject:name];
        }
    }
    __weak typeof(self)weakself = self;
    
    NSDictionary *param = @{@"names":nameArray};
    _sessionTask = [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST serverUrl:WalletURL apiPath:HOMECOININDEX parameters:param progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
        // ⚠️ 服务端返回体可能是 NSNull / 字典 / 字符串；以前直接当 NSData 解析再当数组用，
        // 一旦结构不对就是 `-[NSNull isEqualToString:]` / `objectAtIndex:` 直接崩。
        NSDictionary *result = nil;
        if ([responseObject isKindOfClass:[NSData class]]) {
            id json = [NSJSONSerialization JSONObjectWithData:(NSData *)responseObject options:NSJSONReadingAllowFragments error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) { result = (NSDictionary *)json; }
        } else if ([responseObject isKindOfClass:[NSDictionary class]]) {
            result = (NSDictionary *)responseObject;
        }
        NSLog(@"home result is %@",result);
        id dataObject = [result isKindOfClass:[NSDictionary class]] ? result[@"data"] : nil;
        NSArray *priceArray = [dataObject isKindOfClass:[NSArray class]] ? (NSArray *)dataObject : @[];
        // 先在局部数组里攒，最后回主线程一次性替换（避免后台线程边改数据源边被 UI 读）
        NSMutableArray *prices = [NSMutableArray array];

        for(int i = 0;i < priceArray.count; i++)
        {
            id item = [priceArray objectAtIndex:i];
            if (![item isKindOfClass:[NSDictionary class]]) { continue; }
            NSDictionary *dic = (NSDictionary *)item;
            // 字段可能是 NSNull（向 NSNull 发 isEqualToString: 必崩），统一转成 NSString 或 nil
            NSString *dicName = [dic[@"name"] isKindOfClass:[NSString class]] ? dic[@"name"] : nil;
            NSString *dicPlatform = [dic[@"platform"] isKindOfClass:[NSString class]] ? dic[@"platform"] : nil;

            if([dicPlatform isEqualToString:@"OTHER"])
            {
                continue;
            }

            if (dicName.length == 0 || dicPlatform.length == 0) {
                continue;
            }

            if (![dicName isEqualToString:@"TEST"]) {
                [[PWDataBaseManager shared] upadateCoin:[dic[@"id"] integerValue] platform:dicPlatform cointype:dicName];
            }

            for (LocalCoin *localCoin in coinArray) {
                if (localCoin.coin_type_nft == 10) {
                    if ([localCoin.coin_type isEqualToString:dicName]) {
//                        localCoin.coin_id = dic[@"id"] != nil? [dic[@"id"] integerValue] : 0 ;
                        localCoin.coin_platform = dicPlatform;
                        if ([dic[@"icon"] isKindOfClass:[NSString class]]) {
                            localCoin.icon = dic[@"icon"];
                        }
                        
                        [[PWDataBaseManager shared] updateCoin:localCoin];
                        
                    }
                }
            }
            if([dic isKindOfClass:[NSNull class]]){
                continue;
            }
            CoinPrice *coinPrice = [[CoinPrice alloc] init];
            coinPrice.coinprice_name = dic[@"name"];
            coinPrice.coinprice_price = [dic[@"rmb"] doubleValue]; //[CommonFunction handlePrice:priceStr];
            coinPrice.coinprice_dollarPrice = [dic[@"usd"] doubleValue];
            coinPrice.coinprice_icon = dic[@"icon"];
            coinPrice.coinprice_sid = dic[@"sid"];
            coinPrice.coinprice_nickname = dic[@"nickname"];
            coinPrice.coinprice_id = [dic[@"id"] integerValue];
            coinPrice.coinprice_chain = dic[@"chain"];
            coinPrice.coinprice_platform = dic[@"platform"];
            coinPrice.coinprice_heyueAddress = dic[@"contract_address"];
            coinPrice.treaty = [dic[@"treaty"] integerValue];
            coinPrice.coinprice_optional_name = dic[@"optional_name"];
            coinPrice.coinprice_chain_country_rate = [dic[@"chain_country_rate"] doubleValue];
            coinPrice.coinprice_country_rate = [dic[@"country_rate"] doubleValue];
            coinPrice.rmb_country_rate = [dic[@"rmb_country_rate"] doubleValue];
            coinPrice.lock = [dic[@"lock"] integerValue];
            [prices addObject:coinPrice];
            [[PWDataBaseManager shared] addCoinPrice:coinPrice];
            
        }
//        if (weakself.homeViewBlock) {
//            weakself.homeViewBlock();
//        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakself) strongSelf = weakself;
            if (!strongSelf) { return; }
            [strongSelf.priceArray removeAllObjects];
            [strongSelf.priceArray addObjectsFromArray:prices];
            [strongSelf.tableView reloadData];
        });
        
    } failure:^(NSString * _Nullable errorMessage) {
        NSLog(@"error %@",errorMessage);
        // 添加默认数据（局部数组 → 主线程一次性替换）
        NSMutableArray *fallbackPrices = [NSMutableArray array];
        for (LocalCoin *coin in coinArray) {
            CoinPrice *coinPrice = [[CoinPrice alloc] init];
            coinPrice.coinprice_name = coin.coin_type;
            coinPrice.coinprice_price = 0; //[CommonFunction handlePrice:priceStr];
            coinPrice.coinprice_dollarPrice = 0;
            coinPrice.coinprice_icon = coin.icon;
            coinPrice.coinprice_sid = 0;
            coinPrice.coinprice_nickname = coin.optional_name;
            coinPrice.coinprice_id = coin.coin_id;
            coinPrice.coinprice_chain = coin.coin_chain;
            coinPrice.coinprice_platform = coin.coin_platform;
            coinPrice.coinprice_heyueAddress = @"";
            coinPrice.treaty = coin.treaty;
            coinPrice.coinprice_optional_name = coin.optional_name;
            coinPrice.coinprice_chain_country_rate = 0;
            coinPrice.coinprice_country_rate = 0;
            coinPrice.rmb_country_rate = 0;
            coinPrice.lock = 0;
            [fallbackPrices addObject:coinPrice];
            [[PWDataBaseManager shared] addCoinPrice:coinPrice];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakself) strongSelf = weakself;
            if (!strongSelf) { return; }
            [strongSelf.priceArray removeAllObjects];
            [strongSelf.priceArray addObjectsFromArray:fallbackPrices];
            [strongSelf.tableView reloadData];
        });
        
    }];
}

#pragma mark - UITableViewDelegate UITableViewDatasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if(_coinDatasource.count==0){
        return 1;
    }else{
        return _coinDatasource.count;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // ⚠️ 不要在数据源回调里改状态：以前这里会往 `localArray` 里塞 coin_chain，
    // 而那个数组全文件没有任何读取方 ⇒ 纯副作用，还会在 reload 过程中触发可变数组写入。
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(_coinDatasource.count==0){
        static NSString *CellIdentifier = @"NoCoinCell";
        PWNoCoinViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[PWNoCoinViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }else{
        static NSString *CellIdentifier = @"Cell";
        HomeCoinTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[HomeCoinTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        return cell;
    }

}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{

    HomeCoinTableViewCell *homeCell = (HomeCoinTableViewCell *)cell;
    homeCell.backgroundColor = SGColorFromRGB(0xf8f8fa);
    if([cell isKindOfClass:[HomeCoinTableViewCell class]] && indexPath.section < _coinDatasource.count)
    {
        LocalCoin *coin = [_coinDatasource objectAtIndex:indexPath.section];
        homeCell.coin = coin;
        BOOL existState = NO;
        NSString *coinType = coin.coin_type;
        for (int j = 0; j < _priceArray.count; j ++) {
            CoinPrice *coinPrice = [self.priceArray objectAtIndex:j];
            if ([coinPrice.coinprice_name isEqualToString:coinType] && [coin.coin_platform isEqualToString:coinPrice.coinprice_platform]) {
                homeCell.coinPrice = coinPrice;
                existState = YES;
                break;
            }
        }
        if (!existState) {
            homeCell.coinPrice = nil;
        }
    }
}

//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
//{
//    if (section == 0) {
//        UIView *headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
//        
//        UIImageView *bgImgView = [[UIImageView alloc] init];
//        bgImgView.image = [UIImage imageNamed:@"home_hd_bg"];
//        [headView addSubview:bgImgView];
//
//        UILabel *titleLab = [[UILabel alloc]init];
//        titleLab.font = [UIFont systemFontOfSize:14.f];
//        titleLab.textColor = SGColorRGBA(255, 255, 255, .7f);
//        titleLab.textAlignment = NSTextAlignmentLeft;
//        [headView addSubview:titleLab];
//
//        UIButton *moreBtn = [[UIButton alloc] init];
//        [moreBtn setImage:[UIImage imageNamed:@"home_more"] forState:UIControlStateNormal];
//        [moreBtn setContentMode:UIViewContentModeScaleAspectFit];
////        [moreBtn addTarget:self action:@selector(showMore:) forControlEvents:UIControlEventTouchUpInside];
//
////        [headView addSubview:moreBtn];
//
//        UIImageView *iconImageView = [[UIImageView alloc] init];
//        iconImageView.contentMode = UIViewContentModeScaleAspectFit;
//        iconImageView.hidden = YES;
//        [headView addSubview:iconImageView];
//
//        UILabel *assetLab = [[UILabel alloc]init];
//        assetLab.font = [UIFont systemFontOfSize:30.f];
//        assetLab.textColor = SGColorFromRGB(0xffffff);
//        assetLab.textAlignment = NSTextAlignmentLeft;
//        [headView addSubview:titleLab];
//        [headView addSubview:assetLab];
//        
//        UIButton *addCoinBtn = [[UIButton alloc] init];
//        [addCoinBtn setImage:[UIImage imageNamed:@"home_addcoin"] forState:UIControlStateNormal];
////        [addCoinBtn addTarget:self action:@selector(toSearchVC:) forControlEvents:UIControlEventTouchUpInside];
//        [addCoinBtn setContentMode:UIViewContentModeScaleAspectFit];
//        
////        [headView addSubview:addCoinBtn];
//        
//        titleLab.text = [NSString stringWithFormat:@"%@",self.homeWallet.wallet_name];
//
//        switch (self.homeWallet.wallet_issmall) {
//            case 1:
//            {
//                // HD钱包
//                bgImgView.image = [UIImage imageNamed:@"home_hd_bg"];
//                assetLab.text = @"助记词钱包";
//            }
//                break;
//            case 2:
//            {
//                //  导入私钥创建的钱包
//                bgImgView.image = [UIImage imageNamed:@"home_hd_bg"];
//                assetLab.text = @"私钥钱包";
//                NSArray *array = [[PWDataBaseManager shared] queryCoinArrayBasedOnWallet:self.homeWallet];
//                NSString *mainStr = @"";
//                LocalCoin *coin = array[0];
//                mainStr = coin.coin_chain;
//                bgImgView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_bg",mainStr]];
//                iconImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_icon",coin.coin_type]];
//                if(iconImageView.image==nil){
//                    iconImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_icon",mainStr]];
//                }
//            }
//                break;
//            case 3:
//            {
//                iconImageView.hidden = NO;
//                assetLab.text = @"观察钱包";
//                NSArray *infoArray = [self.homeWallet.wallet_password componentsSeparatedByString:@":"];
//                bgImgView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_bg",infoArray[0]]];
//                if (bgImgView.image == nil) {
//                    bgImgView.image = [UIImage imageNamed:@"home_BTY_bg"];
//                }
//                iconImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_icon",infoArray[0]]];
//
//                if([infoArray[0] isEqualToString:@"BTY"]){
//                    iconImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_icon",@"BTY"]];
//                }
//                if(iconImageView.image==nil){
//                    iconImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_icon",infoArray[0]]];
//                }
//               
//            }
//                break;
//            case 4:
//            {
//                // 4 找回钱包
//                bgImgView.image = [UIImage imageNamed:@"home_hd_bg"];
//                NSArray *array = [[PWDataBaseManager shared] queryCoinArrayBasedOnWallet:self.homeWallet];
//                NSString *mainStr = @"";
//                LocalCoin *coin = array[0];
//                mainStr = coin.coin_chain;
//                bgImgView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_bg",mainStr]];
//                iconImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_icon",coin.coin_type]];
//                if(iconImageView.image==nil){
//                    iconImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"home_%@_icon",mainStr]];
//                }
//                
//            }
//                break;
//            default:
//            {
//                // HD钱包
//                bgImgView.image = [UIImage imageNamed:@"home_hd_bg"];
//                assetLab.text = @"助记词钱包";
//            }
//                break;
//        }
//        
//        [bgImgView mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.left.equalTo(headView).offset(16);
//            make.right.equalTo(headView).offset(-16);
//            make.top.equalTo(headView).offset(10);
//            make.height.mas_equalTo(130);
//        }];
//
//        [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.left.equalTo(headView).offset(36);
//            make.top.equalTo(headView).offset(20);
//            make.height.mas_equalTo(20);
//        }];
//
//
//        [moreBtn mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.right.equalTo(headView).offset(-36);
//            make.top.equalTo(headView).offset(10);
//            make.width.mas_equalTo(21);
//            make.height.mas_equalTo(25);
//        }];
//        
//        [assetLab mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.left.equalTo(headView).offset(36);
//            make.right.equalTo(moreBtn);
//            make.height.mas_equalTo(42);
//            make.top.equalTo(titleLab.mas_bottom).offset(28);
//        }];
//        
//        [addCoinBtn mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.right.equalTo(headView).offset(-30);
//            make.width.height.mas_equalTo(36 * kScreenRatio);
//            make.top.equalTo(headView).offset(78);
//        }];
//        
//        return headView;
//    }
//    return nil;
//}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
//    if (section == 0)
//    {
//        return 150.f;
//    }
    
    return 10.f;

}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return .0001f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_coinDatasource.count == 0) {
        return kScreenHeight;
    }
    return 70.f;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < _coinDatasource.count)
    {
        LocalCoin *coin = [_coinDatasource objectAtIndex:indexPath.section];
        CoinDetailViewController *vc = [[CoinDetailViewController alloc] init];
        vc.hidesBottomBarWhenPushed = YES;
        vc.selectedCoin = coin;
        vc.coinTransferBlock = ^(NSString *coinType, NSString *txId, NSString *sessionId) {
            if (self.homeTransferBlock) {
                self.homeTransferBlock(coinType, txId, sessionId);
            }
        };
        [self.navigationController pushViewController:vc animated:YES];
    }

}

#pragma mark -- 左滑删除
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (indexPath.section >= _coinDatasource.count) { return; }
        LocalCoin *coin = [_coinDatasource objectAtIndex:indexPath.section];
        
        UIAlertController *vc = [UIAlertController alertControllerWithTitle:L(@"提示") message:[NSString stringWithFormat:L(@"是否删除%@"), coin.coin_type] preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *dAction = [UIAlertAction actionWithTitle:L(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (coin.coin_type_nft == 10) {
                // 合约币  coin_pubkey是合约地址}
                // 按**主键**删：合约地址字符串只要有一处对不上（大小写/空格/后端改写），
                // DELETE 就会 0 行命中，而 FMDB 的 executeUpdate 依旧返回 YES ⇒ 静默失败（删了还在）。
                // coin_id 缺失时才回退到旧的按合约地址删。
                BOOL deleted = coin.coin_id > 0
                    ? [[PWDataBaseManager shared] deleteCoinWithId:coin.coin_id]
                    : [[PWDataBaseManager shared] deleteCoinWithContractAddr:coin.coin_pubkey];
                
                self.coinDatasource = [NSMutableArray arrayWithArray:[[PWDataBaseManager shared] queryCoinArrayBasedOnWalletIDAndShow]];
                [tableView reloadData];
                
                // 重新查库后币还在 ⇒ 确实没删掉，给用户明确反馈（不再静默）
                if (!deleted) {
                    for (LocalCoin *item in self.coinDatasource) {
                        BOOL sameCoin = coin.coin_id > 0
                            ? (item.coin_id == coin.coin_id)
                            : [item.coin_pubkey isEqualToString:coin.coin_pubkey];
                        if (sameCoin) {
                            [self showCustomMessage:L(@"删除失败，请稍后重试") hideAfterDelay:2.f];
                            break;
                        }
                    }
                }
            }else{
                [self showCustomMessage:L(@"暂不支持删除") hideAfterDelay:2.f];
            }
            
        }];
        UIAlertAction *cAction = [UIAlertAction actionWithTitle:L(@"取消") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        [vc addAction:cAction];
        [vc addAction:dAction];
        [self.navigationController presentViewController:vc animated:true completion:nil];
        
       
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return L(@"删除");
}


#pragma mark - 设置导航栏左右的按钮
- (UIBarButtonItem *)leftBarButtonItem
{
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [btn setImage:[UIImage imageNamed:@"home_scan"] forState:UIControlStateNormal];
    [btn setContentMode:UIViewContentModeScaleAspectFit];
    btn.tag = 1;
    [btn addTarget:self action:@selector(btnAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:btn];
    
    return item;

    
}

#pragma mark - 设置导航栏左右的按钮
- (UIBarButtonItem *)rightBarButtonItem
{
    // 改用系统 UIBarButtonItem：initWithCustomView 在 iOS 26/27 会被套上玻璃胶囊，
    // 导航按钮视觉不统一。
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_add"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(btnAction:)];
    item.tag = 2;
    item.tintColor = SGColorFromRGB(0x333649);
    return item;
}

- (void)gotoApprove
{
    NSString *address = [[RedPacketWalletDataSource shared] getCurrentWalletAddress] ?: @"";
    TokenApproveListVC *vc = [[TokenApproveListVC alloc] initWithWalletAddress:address rpcURL:BlockchainRPC.currentURL];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)btnAction:(id)sender
{
    // sender 可能是 UIButton（旧的自定义 view）或 UIBarButtonItem（导航栏改用系统按钮后）
    NSInteger tag = 0;
    if ([sender isKindOfClass:[UIBarItem class]]) {
        tag = ((UIBarItem *)sender).tag;
    } else if ([sender isKindOfClass:[UIView class]]) {
        tag = ((UIView *)sender).tag;
    }
    switch (tag) {
        case 1:
        {
            ScanViewController *vc = [[ScanViewController alloc] init];
            vc.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:vc animated:YES];
            vc.scanResult = ^(NSString *address) {
                
                
            };
        }
            break;
        case 2:
        {
            [self toSearchVC];
            
            return;
            
            PWContractVC *vc = [[PWContractVC alloc] init];
            vc.hidesBottomBarWhenPushed = true;
            vc.contractBlock = ^{
                [self initValue];
            };
            [self.navigationController pushViewController:vc animated:true];
        }
            break;
        default:
            break;
    }
    
}

#pragma mark - 去添加币种
- (void)toSearchVC
{
    PWNewsSearchCoinViewController *newsSearchVC = [[PWNewsSearchCoinViewController alloc] init];
    newsSearchVC.hidesBottomBarWhenPushed = YES;
    newsSearchVC.selectedWallet = self.homeWallet;
    newsSearchVC.searchDismissBlock = ^{
        [self initValue];
    };
//    newsSearchVC.localArray = self.localArray;
    [self.navigationController pushViewController:newsSearchVC animated:YES];
    
}

#pragma mark - setting and getting
- (UITableView *)tableView
{
    
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.backgroundColor = SGColorFromRGB(0xf8f8fa);
    }
    return _tableView;
}


@end
