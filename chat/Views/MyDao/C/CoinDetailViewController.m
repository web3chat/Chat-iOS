//
//  CoinDetailViewController.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "CoinDetailViewController.h"
#import "TradeDetailViewController.h"
#import "PWDataBaseManager.h"
#import "CoinPrice.h"
#import "PWImageAlertView.h"
#import <pop/POP.h>
#import "UIImage+Screenshot.h"
#import "ScanViewController.h"
#import <YYWebImage/YYWebImage.h>
#import "Depend.h"
#import "chat-Swift.h"
#import "PWContractRequest.h"

#define BROWSER_ETH @"https://etherscan.io/tx/"
#define BROWSER_BNB @"https://bscscan.com/tx/"
#define BROWSER_TRX @"https://tronscan.org/#/transaction/"
#define BROWSER_BTY @"https://mainnet.bityuan.com/tx/"
#define BROWSER_YCC @"https://yuan.org/tradeHash?hash="

@interface CoinDetailViewController ()<UITableViewDelegate,UITableViewDataSource>
{

}
@property (nonatomic, strong) NSString *nftUrl;
@property (nonatomic, strong) NSString *nftTokenId;
@property (nonatomic,assign) NSInteger page;
@property (nonatomic,strong) UIView *blackView;
@property (nonatomic,strong) CoinDetailView *titleView;
@property (nonatomic,strong) UIButton *tradeTitle;
@property (nonatomic,strong) UITableView *tradeList;
@property (nonatomic,strong) UIView *btnBgView;
@property (nonatomic,strong) BlueButton *outBtn;
@property (nonatomic,strong) BlueButton *inBtn;
@property (nonatomic, strong) UIButton *scanBtn;

@property (nonatomic,strong) NSMutableArray *transactionArray;
@property (nonatomic,strong) NoRecordView  *noRecordView;
@property (nonatomic,strong) UILabel *line;
@property (nonatomic,strong) UIRefreshControl *refreshControl;
@property(nonatomic,strong)dispatch_source_t timer;

@property (nonatomic, strong) NSArray *coinTypeArray; // 交易类型
@property (nonatomic, strong) UIView *coinTypeView;// 交易类型view
@property (nonatomic, strong) UIButton *toBroswerBtn; // 跳转对应的区块链浏览器
// 缓存交易记录
@property (nonatomic, strong) NSMutableDictionary *transListMuDict;
@property (nonatomic, strong) NSDictionary *allInfoDict;
@property (nonatomic, strong) NSDictionary *inInfoDict;
@property (nonatomic, strong) NSDictionary *outInfoDict;
@property (nonatomic, strong) LocalWallet *localWallet;

//@property (nonatomic, strong) NSArray *contactInfoArray;

@property (nonatomic, strong) OrderModel *lastorderModel;
@end

@implementation CoinDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.showMaskLine = false;
    self.statusBarStyle = UIStatusBarStyleLightContent;
    self.view.backgroundColor = SGColorFromRGB(0xFCFCFF);
    self.page = 0;
    _transactionArray = [[NSMutableArray alloc] init];
    _coinTypeArray = @[@"全部"  ,@"转账"  ,@"收款"  ];
   
    
    _coinListType = CoinListTypeAll;
    
    [self createView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(changeLanguage)
                                                 name:kChangeLanguageNotification
                                               object:nil];
    
    
}

#pragma mark - 切换语言
- (void)changeLanguage
{
    [self.tradeList.mj_header prepare];
    [self.tradeList.mj_footer prepare];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (@available(iOS 15, *))
    {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        appearance.backgroundColor = SGColorFromRGB(0xEBAE44);
        appearance.backgroundEffect = nil;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    else
    {
        self.navigationController.navigationBar.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        [self.navigationController.navigationBar setBackgroundImage:[CommonFunction createImageWithColor:SGColorFromRGB(0xEBAE44)] forBarMetrics:UIBarMetricsDefault];

    }
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_back"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(back)];
    backItem.tintColor = SGColorFromRGB(0x333649);
    self.navigationItem.leftBarButtonItem = backItem;
    if (self.selectedCoin.coin_type_nft != 2) {
        CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform andTreaty:self.selectedCoin.treaty];
//        [self queryNFTUrlWithCoinPrice:coinPrice];
        [self queryTokenidListWithCoinPrice:coinPrice];
    }
    [self refreshClick:self.refreshControl];
    [self refreshData];
    [self openGCDBalance];
    
}

- (void)back {
    [self.navigationController popViewControllerAnimated:true];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self stopGCDBalance];
    if (@available(iOS 15, *))
    {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        appearance.backgroundColor = SGColorFromRGB(0xffffff);
        appearance.backgroundEffect = nil;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : [UIColor whiteColor]};
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    else
    {
        self.navigationController.navigationBar.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName : [UIColor whiteColor]};
        [self.navigationController.navigationBar setBackgroundImage:[CommonFunction createImageWithColor:SGColorFromRGB(0xffffff)] forBarMetrics:UIBarMetricsDefault];

    }
}

- (void)createView{

    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform andTreaty:self.selectedCoin.treaty];
    NSString * coinName = IS_BLANK(coinPrice.coinprice_optional_name) ? self.selectedCoin.coin_type : coinPrice.coinprice_optional_name;
    if (IS_BLANK(coinPrice.coinprice_nickname)) {
        self.navigationItem.title = coinName;
    } else {
        self.navigationItem.title = [NSString stringWithFormat:@"%@（%@）",coinName,coinPrice.coinprice_nickname] ;
    }

    UIImageView *blackView = [[UIImageView alloc]init];
    [self.view addSubview:blackView];
    self.blackView = blackView;
    blackView.backgroundColor = SGColorFromRGB(0xEBAE44);
    
    CoinDetailView *titleView = [[CoinDetailView alloc] init];
    [self.view addSubview:titleView];
    self.titleView = titleView;
    self.titleView.coin = self.selectedCoin;
    WEAKSELF
    self.titleView.copyAddressBlock = ^(NSString *address) {
        if (IS_BLANK(address)) {
            return ;
        }
        UIPasteboard *pboard = [UIPasteboard generalPasteboard];
        pboard.string = address;
        [weakSelf showCustomMessage:@"地址复制成功"   hideAfterDelay:1];
    };
    self.titleView.qrCodeBlock = ^(UIImageView *imageView) {
    
            [weakSelf imageZoomAction:imageView];
    };
    self.titleView.nfturlBlock = ^{
        if (weakSelf.nftUrl != nil) {
            [weakSelf openSafariWithuRL:weakSelf.nftUrl];
        }else{
            [weakSelf showCustomMessage:@"未获取到对应的NFT地址 请稍后再试"   hideAfterDelay:2.f];
        }
        
    };
    
    //顶部按钮
    UIView *btnBgView = [[UIView alloc] init];
    [self.view addSubview:btnBgView];
    self.btnBgView = btnBgView;
    
    //转账
    BlueButton *outBtn = [[BlueButton alloc] init];
    outBtn.backgroundColor = [UIColor clearColor];
    outBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [outBtn setTitle:@"转账"   forState:UIControlStateNormal];
    
    [outBtn setBackgroundImage:[UIImage imageNamed:@"转账"] forState:UIControlStateNormal];
    [btnBgView addSubview:outBtn];
    self.outBtn = outBtn;
    [outBtn addTarget:self action:@selector(moneyOutAction) forControlEvents:UIControlEventTouchUpInside];
    
    //收款
    BlueButton *inBtn = [[BlueButton alloc] init];
    inBtn.backgroundColor = [UIColor clearColor];
    inBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [inBtn setTitle:@"收款"   forState:UIControlStateNormal];
    [inBtn setBackgroundImage:[UIImage imageNamed:@"收款"] forState:UIControlStateNormal];
    [btnBgView addSubview:inBtn];
    self.inBtn = inBtn;
    [inBtn addTarget:self action:@selector(moneyInAction) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *scanBtn = [[UIButton alloc] init];
    [scanBtn setImage:[UIImage imageNamed:@"coindetail_scan"] forState:UIControlStateNormal];
    [scanBtn setImage:[UIImage imageNamed:@"coindetail_scan"] forState:UIControlStateHighlighted];
    [scanBtn setContentMode:UIViewContentModeScaleAspectFit];
    [scanBtn addTarget:self action:@selector(scanAction) forControlEvents:UIControlEventTouchUpInside];
    [btnBgView addSubview:scanBtn];
    self.scanBtn = scanBtn;
    
    
    //交易记录
    UIButton *tradeTitle = [[UIButton alloc] init];
    [tradeTitle setTitle:[NSString stringWithFormat:@"  %@",@"交易记录"  ] forState:UIControlStateNormal];
    [tradeTitle setTitleColor:TextColor51 forState:UIControlStateNormal];
    tradeTitle.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    tradeTitle.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [tradeTitle setImage:[UIImage imageNamed:@"交易记录"] forState:UIControlStateNormal];
    [tradeTitle setImage:[UIImage imageNamed:@"交易记录"] forState:UIControlStateHighlighted];
    [self.view addSubview:tradeTitle];
    tradeTitle.backgroundColor = [UIColor whiteColor];
    self.tradeTitle = tradeTitle;
    tradeTitle.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
    UIView *coinTypeView= [[UIView alloc] init];
    coinTypeView.backgroundColor = UIColor.whiteColor;
    coinTypeView.tag = 123;
    self.coinTypeView = coinTypeView;
    
    [self.view addSubview:coinTypeView];
    
    CGFloat x = 0;
    CGFloat y = 0;
    CGFloat w = 0;
    CGFloat height = 30;
    for (int i = 0; i < _coinTypeArray.count; i++)
    {
        UIButton *btn = [self coinListTypeBtnWithType:i];
        [btn addTarget:self action:@selector(changeTransType:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitle:_coinTypeArray[i] forState:UIControlStateNormal];
        CGRect rect = [btn.titleLabel.text boundingRectWithSize:CGSizeMake(200, MAXFLOAT)
                                                        options:NSStringDrawingUsesLineFragmentOrigin
                                                     attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:14.f]}
                                                        context:nil];
        x = x + w + 20;
        btn.frame = CGRectMake(x, y, rect.size.width + 20, height);
        w = rect.size.width + 20;
        [self.coinTypeView addSubview:btn];
        if (i == 0)
        {
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            [btn setBackgroundColor:SGColorFromRGB(0x8e92a3)];
        }
    }
    
    UIButton *toBroswerBtn = [[UIButton alloc] init];
    [toBroswerBtn setTitle:@"前往区块链浏览器"   forState:UIControlStateNormal];
    [toBroswerBtn setTitleColor:SGColorFromRGB(0x7190FF) forState:UIControlStateNormal];
    [toBroswerBtn.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [toBroswerBtn addTarget:self action:@selector(toBroswer:) forControlEvents:UIControlEventTouchUpInside];
    self.toBroswerBtn = toBroswerBtn;
    [self.view addSubview:self.toBroswerBtn];
    
    
    
    UILabel *bottomLine = [[UILabel alloc] init];
    [self.view addSubview:bottomLine];
    bottomLine.backgroundColor = SGColorRGBA(217, 220, 233, 1);
    self.line = bottomLine;
    
    UITableView *tradeList = [[UITableView alloc] init];
    tradeList.delegate = self;
    tradeList.dataSource = self;
    tradeList.backgroundColor = [UIColor whiteColor];
    tradeList.rowHeight = 70;
    tradeList.separatorColor = SGColorRGBA(217, 220, 233, 1);
    [self.view addSubview:tradeList];
    self.tradeList = tradeList;
    
    //防止刷新出现闪动
    tradeList.estimatedRowHeight = 0;
    tradeList.estimatedSectionFooterHeight = 0;
    tradeList.estimatedSectionHeaderHeight = 0;
    
    tradeList.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingTarget:self refreshingAction:@selector(loadMore)];
    tradeList.mj_footer.hidden = true;
    
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshClick:) forControlEvents:UIControlEventValueChanged];
    [self.tradeList addSubview:refreshControl];
    self.refreshControl = refreshControl;
    
    UIView *tableFootView = [[UIView alloc] init];
    tradeList.tableFooterView = tableFootView;
    
    
    //没有交易记录
    NoRecordView *noRecordView = [[NoRecordView alloc] initWithImage:[UIImage imageNamed:@"notraderecord"] title:@"暂无交易记录"  ];
    [self.tradeList addSubview:noRecordView];
    noRecordView.hidden = true;
    self.noRecordView = noRecordView;
    
    
    [self.view bringSubviewToFront:self.tradeList];
}

- (void)openSafariWithuRL:(NSString *)url
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]  options:@{}
                             completionHandler:^(BOOL success) {
        NSLog(@"Open %d",success);
        
    }];
}

- (void)toBroswer:(UIButton *)sender
{
    NSString *urlStr = @"";
    NSString *addre = self.selectedCoin.coin_address;
    if ([self.selectedCoin.coin_chain isEqualToString:@"BNB"]) {
        urlStr = [NSString stringWithFormat:@"%@",BROWSER_BNB];
        [self openSafariWithuRL:urlStr];
        return;
    }
    if ([self.selectedCoin.coin_type isEqualToString:@"BTY"]) {
        urlStr = [NSString stringWithFormat:@"%@",BROWSER_BTY];
        [self openSafariWithuRL:urlStr];
        return;
    }
    if ([self.selectedCoin.coin_type isEqualToString:@"YCC"]) {
        urlStr = [NSString stringWithFormat:@"%@",BROWSER_YCC];
        [self openSafariWithuRL:urlStr];
        return;
    }
    if ([self.selectedCoin.coin_chain isEqualToString:@"ETH"]) {
        urlStr = [NSString stringWithFormat:@"%@",BROWSER_ETH];
        [self openSafariWithuRL:urlStr];
        return;
    }
   
    if ([self.selectedCoin.coin_chain isEqualToString:@"TRX"]) {
        urlStr = [NSString stringWithFormat:@"%@",BROWSER_TRX];
        [self openSafariWithuRL:urlStr];
        return;
    }
    
    if (urlStr.length == 0) {
        [self showCustomMessage:@"暂未支持" hideAfterDelay:2.f];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self.blackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self.view);
        make.height.mas_equalTo(136);
    }];
    
    [self.titleView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).with.offset(5);
        make.right.equalTo(self.view).with.offset(-5);
        make.top.equalTo(self.view);
        make.height.mas_equalTo(140);
    }];
    
    [self.btnBgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(self.titleView.mas_bottom).offset(5);
        make.height.mas_equalTo(81);
    }];
    
    CGFloat width = (SCREENBOUNDS.size.width - 32 - 20)/2;
    
    [self.outBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.btnBgView);
        make.height.mas_equalTo(50);
        make.width.mas_equalTo(width);
        make.left.equalTo(self.view).with.offset(16);
    }];
    
    [self.inBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.outBtn);
        make.height.mas_equalTo(50);
        make.width.mas_equalTo(width);
        make.left.equalTo(self.outBtn.mas_right).with.offset(10);
    }];
    
    [self.tradeTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.btnBgView.mas_bottom);
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(40);
    }];
    [self.coinTypeView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view);
        make.top.equalTo(self.tradeTitle.mas_bottom);
        make.height.mas_equalTo(35);
        make.right.equalTo(self.view).offset(-200);
    }];
    
    [self.toBroswerBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view).offset(-20);
        make.top.height.equalTo(self.coinTypeView);
    }];
    
    [self.tradeList mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.coinTypeView.mas_bottom).with.offset(1);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view).with.offset(-kIphoneXBottomOffset);
    }];
    
    
    [self.noRecordView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.tradeList);
        make.top.equalTo(self.tradeList);
        make.width.equalTo(self.tradeList);
        make.height.equalTo(self.tradeList);
    }];
    
    [self.line mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(0.5);
        make.bottom.equalTo(self.coinTypeView);
    }];
}

#pragma mark - 切换交易类型
- (void)changeTransType:(UIButton *)sender
{
    [sender setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [sender setBackgroundColor:SGColorFromRGB(0x8e92a3)];
    
    for (UIView *subView in self.view.subviews)
    {
        if (subView.tag == 123)
        {
            // 找到交易类型view
            for (UIButton *subBtn in subView.subviews)
            {
                if (subBtn.tag != sender.tag)
                {
                    // 找到不是当前点击的btn，切换颜色
                    [subBtn setTitleColor:SGColorFromRGB(0x8e92a3) forState:UIControlStateNormal];
                    [subBtn setBackgroundColor:UIColor.whiteColor];
                }
            }
        }
    }
    
    _coinListType = sender.tag;
    
    [self refreshData];
    
}

#pragma mark-
#pragma mark UITableView代理和数据源
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return _transactionArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"FirstCell";
    TradeCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[TradeCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    TradeCell *tradeCell = (TradeCell *)cell;
    if(_transactionArray.count > 0)
    {
        NSDictionary *dict = [_transactionArray objectAtIndex:indexPath.row];
        OrderModel *orderModel = [[OrderModel alloc] initWithDic:dict];
        
        tradeCell.coin = self.selectedCoin;
        tradeCell.orderModel = orderModel;

        
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *dict = [_transactionArray objectAtIndex:indexPath.row];

    
    OrderModel *orderModel = [[OrderModel alloc] initWithDic:dict];
    
    TradeDetailViewController *vc = [[TradeDetailViewController alloc] init];
    vc.coin = _selectedCoin;
    vc.orderModel = orderModel;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark-
#pragma mark  类方法

/**
 * refreshClick
 */
- (void)refreshClick:(UIRefreshControl *)refreshControl {
    
    [self.refreshControl beginRefreshing];
    [self.refreshControl endRefreshing];
    [self refreshData];
}


/**
 * 下拉刷新 tableView 网络请求数据源
 */

- (void)refreshData {
    self.page = 0;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.selectedCoin.coin_type_nft == 1) {
            // nft查询交易记录
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform andTreaty:self.selectedCoin.treaty];
            [PWNFTRequest requestTxsByAddrWithCoinType:self.selectedCoin.coin_chain
                                               address:self.selectedCoin.coin_address
                                          contractAddr:coinPrice.coinprice_heyueAddress
                                                 index:self.page
                                                 count:20
                                             direction:0
                                                  type:self.coinListType
                                               success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"tx result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSArray *array = result[@"result"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.page = 1;
                        [self refreshTableView:array ];
                    });
                }
                
            } failure:^(NSString * _Nonnull errorMsg) {
                
            }];
        }else if (self.selectedCoin.coin_type_nft == 3 || self.selectedCoin.coin_type_nft == 4){
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform andTreaty:self.selectedCoin.treaty];
            [PWNFTRequest requstSLGTxsByCoinType:self.selectedCoin.coin_chain
                                         address:self.selectedCoin.coin_address
                                    contractAddr:coinPrice.coinprice_heyueAddress
                                           index:self.page
                                           count:20
                                       direction:0
                                            type:self.coinListType
                                         success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"tx result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSArray *array = result[@"result"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.page = 1;
                        [self refreshTableView:array ];
                    });
                }
            } failure:^(NSString * _Nonnull errorMsg) {
               
            }];
        }else if (self.selectedCoin.coin_type_nft == 10){
            [PWContractRequest queryTransactionByAddress:self.selectedCoin.coin_address
                                                coinType:self.selectedCoin.coin_chain
                                            contractAddr:self.selectedCoin.coin_pubkey
                                                   index:self.page
                                                   count:20
                                               direction:0
                                                    type:self.coinListType
                                                 success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"tx result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSArray *array = result[@"result"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.page = 1;
                        [self refreshTableView:array ];
                    });
                }
            } failure:^(NSString * _Nonnull errorMsg) {
                
            }];
        }
        else{
            NSArray *array = [GoFunction queryTransactionsByaddress:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform address:self.selectedCoin.coin_address page:0 andTreaty:self.selectedCoin.treaty type:self.coinListType];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.page = 1;
                [self refreshTableView:array ];
            });
        }
        
    });
}

/*
 *下拉刷新 tableView reloadData
 */
- (void)refreshTableView:(NSArray*)array {
    [self hideProgress];
    if (IS_BLANK(array)) {
        self.noRecordView.hidden = false;
    } else {
        self.noRecordView.hidden = true;
    }
    self.transactionArray = [NSMutableArray arrayWithArray:array];
    if (self.transactionArray.count != 0) {
        self.lastorderModel = [[OrderModel alloc] initWithDic:self.transactionArray.firstObject];
    }
    [self.tradeList reloadData];
    self.tradeList.mj_footer.hidden = false;
    
}



/**
 * 加载更多
 */
- (void)loadMore
{
    [self queryTransactions];
}

/**
 * 查询交易记录
 */
- (void)queryTransactions
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if (self.selectedCoin.coin_type_nft == 1) {
            // nft查询交易记录
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform andTreaty:self.selectedCoin.treaty];
            [PWNFTRequest requestTxsByAddrWithCoinType:self.selectedCoin.coin_chain
                                               address:self.selectedCoin.coin_address
                                          contractAddr:coinPrice.coinprice_heyueAddress
                                                 index:self.page
                                                 count:20
                                             direction:1
                                                  type:self.coinListType
                                               success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSArray *array = result[@"result"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self loadMoreRefreshTableView:array];
                    });
                }
                
            } failure:^(NSString * _Nonnull errorMsg) {
                
            }];
        }else if (self.selectedCoin.coin_type_nft == 3 || self.selectedCoin.coin_type_nft == 4){
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform andTreaty:self.selectedCoin.treaty];
            [PWNFTRequest requstSLGTxsByCoinType:self.selectedCoin.coin_chain
                                         address:self.selectedCoin.coin_address
                                    contractAddr:coinPrice.coinprice_heyueAddress
                                           index:self.page
                                           count:20
                                       direction:0
                                            type:self.coinListType
                                         success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"tx result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSArray *array = result[@"result"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self loadMoreRefreshTableView:array];
                    });
                }
            } failure:^(NSString * _Nonnull errorMsg) {
               
            }];
        }else if (self.selectedCoin.coin_type_nft == 10){
            [PWContractRequest queryTransactionByAddress:self.selectedCoin.coin_address
                                                coinType:self.selectedCoin.coin_chain
                                            contractAddr:self.selectedCoin.coin_pubkey
                                                   index:self.page
                                                   count:20
                                               direction:0
                                                    type:self.coinListType
                                                 success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"tx result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSArray *array = result[@"result"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self loadMoreRefreshTableView:array];
                    });
                }
            } failure:^(NSString * _Nonnull errorMsg) {
                
            }];
        }
        else{
            NSArray *array = [GoFunction queryTransactionsByaddress:self.selectedCoin.coin_type platform:self.selectedCoin.coin_platform address:self.selectedCoin.coin_address page:self.page andTreaty:self.selectedCoin.treaty type:self.coinListType];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loadMoreRefreshTableView:array];
            });
        }
        
        
    });
}

/*
 *loadMore 刷新tableView
 */
- (void)loadMoreRefreshTableView:(NSArray*)array{
    self.page++;
    [self hideProgress];
    [self.transactionArray addObjectsFromArray:array];
    [self.tradeList reloadData];
    [self.tradeList.mj_footer endRefreshing];

}

/// 获取nft地址url
///
- (void)queryNFTUrlWithCoinPrice:(CoinPrice *)coinPrice
{
  
    [PWNFTRequest requestNFTTokenURLWithCoinType:self.selectedCoin.coin_chain
                                         tokenId:self.nftTokenId
                                    contractAddr:coinPrice.coinprice_heyueAddress
                                         success:^(id  _Nonnull object) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"url_result is %@",result);
        if (![result[@"result"] isKindOfClass:[NSNull class]]) {
            self.nftUrl = result[@"result"];
            
            [self.titleView.animatedImageView yy_setImageWithURL:[NSURL URLWithString:self.nftUrl] options:YYWebImageOptionIgnoreFailedURL];
        }
    
    } failure:^(NSString * _Nonnull errorMsg) {
        
    }];
}

- (void)queryTokenidListWithCoinPrice:(CoinPrice *)coinPrice
{
    [PWNFTRequest requestNFTTokenIdListWithCoinType:self.selectedCoin.coin_chain
                                               from:self.selectedCoin.coin_address
                                       contractAddr:coinPrice.coinprice_heyueAddress
                                            success:^(id  _Nonnull object) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"url_result is %@",result);
        if (![result[@"result"] isKindOfClass:[NSNull class]]) {
            NSArray *tokenIdArray = result[@"result"];
            self.nftTokenId = [NSString stringWithFormat:@"%@",tokenIdArray.firstObject];
            [self queryNFTUrlWithCoinPrice:coinPrice];
        }
    } failure:^(NSString * _Nonnull errorMsg) {
        
    }];
}


/**
 * 转账按钮点击事件
 */
- (void)moneyOutAction{
    
//    FZMSelectContactController *vc = [[FZMSelectContactController alloc]init];
//    vc.coin = self.selectedCoin;
//    [self.navigationController pushViewController:vc animated:true];
    
    
//    vc.seletedBlock = ^(ContactViewModel * contactViewModel) {
//        
//    };
//    [self presentViewController:[[UINavigationController alloc]initWithRootViewController:vc] animated:true completion:nil];
    
//    [self showCustomMessage:@"暂不支持"   hideAfterDelay:2.f];
//    return;
//    CoinPrice *coinprice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:self.selectedCoin.coin_type
//                                                                    platform:self.selectedCoin.coin_platform
//                                                                   andTreaty:self.selectedCoin.treaty];
//    if (coinprice.lock == 1)
//    {
//        [self showCustomMessage:@"该币种维护中..."   hideAfterDelay:2.f];
//        return;
//    }
//    if(self.localWallet.wallet_issmall == 3){
//        [self showCustomMessage:@"暂不支持"   hideAfterDelay:2.f];
//        return;
//    }
    TransferViewController *vc = [[TransferViewController alloc] init];
    vc.walletId = self.selectedCoin.coin_walletid;
//    vc.fromTag = TransferFromCoinDetail;
    vc.transferBlock = ^(NSString *coinName, NSString *txHash, NSString *amount) {
        if (self.coinTransferBlock) {
            self.coinTransferBlock(coinName, txHash, amount); // 这种情况下 amount是sessionid
        }
    };
    vc.coin = self.selectedCoin;
    vc.orderModel = self.lastorderModel;
    vc.fromTag = FromTagCoin;
    [self.navigationController pushViewController:vc animated:YES];
}

/**
 * 收款按钮点击事件
 */
- (void)moneyInAction
{
     PWNesReceiptMoneyViewController *vc = [[PWNesReceiptMoneyViewController alloc] init];
    vc.coin = self.selectedCoin;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)setSelectedCoin:(LocalCoin *)selectedCoin
{
    _selectedCoin = selectedCoin;
    self.titleView.coin = selectedCoin;
    self.title = selectedCoin.coin_type;
}

#pragma mark - 扫描
- (void)scanAction
{
    WEAKSELF
    ScanViewController *vc = [[ScanViewController alloc] init];
    [self.navigationController pushViewController:vc animated:true];
    vc.scanResult = ^(NSString *address) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *addressStr = address;
            NSString *moneyStr = @"0";

            if ([address containsString:@","])
            {
                // 可能是从专属地址过来的
                NSArray *array = [address componentsSeparatedByString:@","];
                if (array.count == 3) {
                    //从专属地址过来的
                    moneyStr = array[1];
                    addressStr = array[2];
                }
                else if (array.count == 2)
                {
                   moneyStr = array[0];
                    addressStr = array[1];
                }
            }
            TransferViewController *vc = [[TransferViewController alloc] init];
            vc.coin = weakSelf.selectedCoin;
            vc.addressStr = addressStr;
            vc.moneyStr = moneyStr;
//            vc.fromTag = TransferFromCoinDetail;
            [weakSelf.navigationController pushViewController:vc animated:YES];
        });
    };
}

/**
 * 轮询
 */
- (void)openGCDBalance
{
    WEAKSELF
    NSTimeInterval period = 5.0; //设置时间间隔
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, 0);
    dispatch_source_set_timer(_timer, start, period * NSEC_PER_SEC, 0); //每秒执行
    
    dispatch_source_set_event_handler(_timer, ^{
        //刷新账单
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!(self.tradeList.contentOffset.y > 0.5 || self.tradeList.contentOffset.y < -0.5)) {
                //用户不在滑动 定时刷新交易记录
                [self refreshData];
            }
        });
        if (self.selectedCoin.coin_type_nft == 1) {
            // nft
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:weakSelf.selectedCoin.coin_type platform:weakSelf.selectedCoin.coin_platform andTreaty:weakSelf.selectedCoin.treaty];
            [PWNFTRequest requestNFTBalanceWithCoinType:weakSelf.selectedCoin.coin_chain
                                                   from:weakSelf.selectedCoin.coin_address
                                           contractAddr:coinPrice.coinprice_heyueAddress
                                                success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSInteger balance = [result[@"result"] integerValue];
                   
                    weakSelf.selectedCoin.coin_balance = balance;
                    [[PWDataBaseManager shared]updateCoin:weakSelf.selectedCoin];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakSelf.titleView.coin = weakSelf.selectedCoin;
                    });
                }
               
            
            } failure:^(NSString * _Nullable errorMsg) {
                
            }];
        }else if (self.selectedCoin.coin_type_nft == 3){
            //erc721
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:weakSelf.selectedCoin.coin_type platform:weakSelf.selectedCoin.coin_platform andTreaty:weakSelf.selectedCoin.treaty];
            
            [PWNFTRequest requestERC721NFTBalanceWith:self.selectedCoin.coin_chain
                                              nftType:@"ERC721"
                                         contractAddr:coinPrice.coinprice_heyueAddress
                                             fromAddr:self.selectedCoin.coin_address
                                              success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSInteger balance = [result[@"result"] integerValue];
                   
                    weakSelf.selectedCoin.coin_balance = balance;
                    [[PWDataBaseManager shared]updateCoin:weakSelf.selectedCoin];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakSelf.titleView.coin = weakSelf.selectedCoin;
                    });
                }
            } failure:^(NSString * _Nonnull errorMsg) {
                
            }];
        }else if (self.selectedCoin.coin_type_nft == 4){
            //erc1155
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:weakSelf.selectedCoin.coin_type platform:weakSelf.selectedCoin.coin_platform andTreaty:weakSelf.selectedCoin.treaty];
            [PWNFTRequest requestERC1155NFTBalanceWith:self.selectedCoin.coin_chain
                                               nftType:@"ERC1155"
                                               tokenId:@"2"
                                          contractAddr:coinPrice.coinprice_heyueAddress
                                              fromAddr:self.selectedCoin.coin_address
                                               success:^(id  _Nonnull object) {
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
                NSLog(@"result is %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    NSInteger balance = [result[@"result"] integerValue];
                   
                    weakSelf.selectedCoin.coin_balance = balance;
                    [[PWDataBaseManager shared]updateCoin:weakSelf.selectedCoin];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakSelf.titleView.coin = weakSelf.selectedCoin;
                    });
                }
            } failure:^(NSString * _Nonnull errorMsg) {
                
            }];
        }else if (self.selectedCoin.coin_type_nft == 10){
            [PWContractRequest getBalancewithCoinType:self.selectedCoin.coin_chain
                                              address:self.selectedCoin.coin_address
                                               execer:self.selectedCoin.coin_pubkey
                                              success:^(id  _Nonnull object) {
                NSError *error;
                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:&error];
                NSLog(@"result %@",result);
                if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                    CGFloat balance = [result[@"result"][@"balance"] doubleValue];
                    if (balance != -1)
                    {
                        // 有余额
                        weakSelf.selectedCoin.coin_balance = balance;
                        [[PWDataBaseManager shared] updateCoin:self.selectedCoin];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            weakSelf.titleView.coin = weakSelf.selectedCoin;
                        });
                    }
                }
            } failure:^(NSString * _Nonnull errorMsg) {
                
            }];
        }
        else{
            CGFloat balance = [GoFunction goGetBalance:weakSelf.selectedCoin.coin_type platform:weakSelf.selectedCoin.coin_platform address:weakSelf.selectedCoin.coin_address andTreaty:self.selectedCoin.treaty];
            if (balance != -1)
            {
                NSArray *waArray = [[PWDataBaseManager shared]queryAllWallets];
                NSMutableArray *coinArray = [NSMutableArray array];
                for (LocalWallet *wallet in waArray) {
                    if (wallet.wallet_isEscrow != 1) {
                        NSArray *coin = [[PWDataBaseManager shared]queryAllCoinArrayBasedOnWalletID:wallet.wallet_id];
                        [coinArray addObjectsFromArray:coin];
                    }
                }
                
                for (LocalCoin *coin in coinArray) {
                    if ([coin.coin_type isEqualToString:weakSelf.selectedCoin.coin_type] && [coin.coin_address isEqualToString:weakSelf.selectedCoin.coin_address]) {
                        coin.coin_balance = balance;
                        [[PWDataBaseManager shared]updateCoin:coin];
                    }
                }
                weakSelf.selectedCoin.coin_balance = balance;
                [[PWDataBaseManager shared]updateCoin:weakSelf.selectedCoin];
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.titleView.coin = weakSelf.selectedCoin;
                });
            }
        }
        
        
        
        
       
        
    });
    dispatch_resume(_timer);
}



/**
 * 停止轮询
 */
- (void)stopGCDBalance
{
    NSLog(@"停止查余额啦！！！");
    dispatch_source_cancel(_timer);
    _timer = nil;
}


/**
 * 图片点击放大
 */
- (void)imageZoomAction:(UIImageView *)imageView
{
    
    PWImageAlertView *imageAlerView = [[PWImageAlertView alloc]initWithTitle:@"收款地址"   image:imageView.image address:self.selectedCoin.coin_address];
    WEAKSELF
    typeof(imageAlerView) __weak weakImageAlertView = imageAlerView;
    imageAlerView.cancelBlock = ^(id obj) {
        [weakSelf animationHideImageAlertView:weakImageAlertView toView:imageView];
    };
    imageAlerView.okBlock = ^(id obj) {
        NSString *str = obj;
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = str;
        [self showCustomMessage:@"复制成功"   hideAfterDelay:2.0];
    };
    [self animationShowImageAlertView:imageAlerView fromView:imageView];
    
}

#pragma mark - 动画展示和隐藏
- (void)animationShowImageAlertView:(PWImageAlertView*)imageAlerView fromView:(UIView*)fromView {

    [imageAlerView layoutIfNeeded];
    UIView *whiteView = imageAlerView.subviews.firstObject;
    UIImage *imageFromView = [UIImage getImageFromView:whiteView];
    CGRect senderViewOriginalFrame = [fromView.superview convertRect:fromView.frame toView:nil];

    UIView *fadeView = [[UIView alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.bounds];
    fadeView.backgroundColor = [UIColor clearColor];
    [[UIApplication sharedApplication].keyWindow addSubview:fadeView];

    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = senderViewOriginalFrame;
    resizableImageView.clipsToBounds = YES;
    resizableImageView.contentMode = fromView.contentMode;
    resizableImageView.backgroundColor = [UIColor clearColor];
    [[UIApplication sharedApplication].keyWindow addSubview:resizableImageView];

    void (^completion)(void) = ^() {
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
        [[UIApplication sharedApplication].keyWindow addSubview:imageAlerView];
    };

    [UIView animateWithDuration:0.28 animations:^{
        fadeView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
    } completion:nil];
    CGRect finalImageViewFrame = CGRectMake((kScreenWidth - whiteView.frame.size.width) * 0.5, (kScreenHeight - whiteView.frame.size.height) * 0.5, whiteView.frame.size.width, whiteView.frame.size.height);
    [self animateView:resizableImageView
              toFrame:finalImageViewFrame
           completion:completion];

}

- (void)animationHideImageAlertView:(PWImageAlertView*)imageAlerView toView:(UIView*)toView{
   
    UIView *fadeView = [[UIView alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.bounds];
    fadeView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
    [[UIApplication sharedApplication].keyWindow addSubview:fadeView];

    UIView *whiteView = imageAlerView.subviews.firstObject;
    UIImage *imageFromView = [UIImage getImageFromView:whiteView];
    CGRect senderViewOriginalFrame = CGRectMake((kScreenWidth - whiteView.frame.size.width) * 0.5, (kScreenHeight - whiteView.frame.size.height) * 0.5, whiteView.frame.size.width, whiteView.frame.size.height);
    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = senderViewOriginalFrame;
    resizableImageView.clipsToBounds = YES;
    resizableImageView.contentMode =  toView.contentMode;
    resizableImageView.backgroundColor = [UIColor clearColor];
    [[UIApplication sharedApplication].keyWindow addSubview:resizableImageView];

    void (^completion)(void) = ^() {
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
        [imageAlerView removeFromSuperview];
    };
    imageAlerView.alpha = 0;
    [UIView animateWithDuration:0.28 animations:^{
        fadeView.backgroundColor = [UIColor clearColor];
    } completion:nil];
    CGRect finalImageViewFrame = [toView.superview convertRect:toView.frame toView:nil];
    [self animateView:resizableImageView
              toFrame:finalImageViewFrame
           completion:completion];
    [UIView animateWithDuration:0.4 animations:^{
        resizableImageView.alpha = 0;
    } completion:nil];
}

- (void)animateView:(UIView *)view toFrame:(CGRect)frame completion:(void (^)(void))completion
{
    POPSpringAnimation *animation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
    [animation setSpringBounciness:6];
    [animation setDynamicsMass:1];
    [animation setToValue:[NSValue valueWithCGRect:frame]];
    [view pop_addAnimation:animation forKey:nil];

    if (completion)
    {
        [animation setCompletionBlock:^(POPAnimation *animation, BOOL finished) {
            completion();
        }];
    }
}

#pragma mark - 重写父类方法
- (UIBarButtonItem *)rt_customBackItemWithTarget:(id)target
                                          action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:[UIImage imageNamed:@"返回箭头"] forState:UIControlStateNormal];
    
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


- (UIButton *)coinListTypeBtnWithType:(CoinListType)coinListsType
{
    UIButton *btn = [[UIButton alloc] init];
    
    [btn setTitleColor:SGColorFromRGB(0x8e92a3) forState:UIControlStateNormal];
    btn.tag = coinListsType;
    [btn.layer setCornerRadius:5.f];
    [btn.titleLabel setFont:[UIFont systemFontOfSize:14.f]];
    
    return btn;
}


@end

