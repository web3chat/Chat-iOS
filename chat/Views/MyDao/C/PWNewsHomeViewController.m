//
//  PWNewsHomeViewController.m
//  PWallet
//
//  Created by 郑晨 on 2019/11/29.
//  Copyright © 2019 陈健. All rights reserved.
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

static NSString *reuseID = @"tableview";

@interface PWNewsHomeViewController ()
<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property(nonatomic,strong)NSMutableArray *coinDatasource; // 币种信息
@property(nonatomic,strong)NSMutableArray *priceArray;
@property(nonatomic,strong)LocalWallet *homeWallet; // 当前钱包
/** 当前钱包的wallet_id */
@property(nonatomic,assign)NSInteger walletId;
/** */
@property(nonatomic,strong)NSURLSessionDataTask *sessionTask;
@property(nonatomic,strong)dispatch_source_t timer;

@property (nonatomic, strong) LocalCoin *localCoin;
@property(nonatomic,strong)NSMutableArray *localArray;

@end

@implementation PWNewsHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

//    self.navigationItem.leftBarButtonItem = [self leftBarButtonItem];
    self.navigationItem.rightBarButtonItem = [self rightBarButtonItem];
    self.view.backgroundColor = SGColorFromRGB(0xffffff);
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self initValue];

    
    self.localArray = [NSMutableArray array];
    [self downRefresh];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationItem.title = @"我的资产";
    self.showMaskLine = false;
//    if (@available(iOS 13.0, *)) {
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
//    } else {
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
//    }
    
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
   
    [self.localArray removeAllObjects];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    NSTimeInterval period = 8.0; //设置时间间隔
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

/**
 * 下拉刷新
 */
- (void)downRefresh
{
    WEAKSELF
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    dispatch_async(queue, ^{
        [self requestQuationList];
    });

    for (int i = 0; i < self.coinDatasource.count; i ++) {
        dispatch_async(queue, ^{
            if (weakSelf.coinDatasource.count != 0)
            {

                LocalCoin *coin = [weakSelf.coinDatasource objectAtIndex:i];
                // 防止出现币种没有地址的情况
                if (coin.coin_address == nil
                    || [coin.coin_address isEqualToString:@""]
                    || coin.coin_address.length <= 0)
                {
                    for (LocalCoin *localCoin in weakSelf.coinDatasource)
                    {
                        if ([localCoin.coin_chain isEqualToString:coin.coin_chain] && [localCoin.coin_chain isEqualToString:localCoin.coin_type]) {
                            coin.coin_address = localCoin.coin_address;
                        }
                        
                    }
                }

                if (coin.coin_type_nft == 10) { // 合约币
                    [PWContractRequest getBalancewithCoinType:coin.coin_chain
                                                      address:coin.coin_address
                                                       execer:coin.coin_pubkey
                                                      success:^(id  _Nonnull object) {
                        NSError *error;
                        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:&error];
                        NSLog(@"result %@",result);
                        if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                            CGFloat balance = [result[@"result"][@"balance"] doubleValue];
                            if (balance != -1)
                            {
                                // 有余额
                                coin.coin_balance = balance;

                                if(i < weakSelf.coinDatasource.count)
                                {
                                    [weakSelf.coinDatasource replaceObjectAtIndex:i withObject:coin];
                                }
                                [[PWDataBaseManager shared] updateCoin:coin];
                            }
                        }
                    } failure:^(NSString * _Nonnull errorMsg) {
                        
                    }];
                    
                }else{
                    CGFloat balance = [GoFunction goGetBalance:coin.coin_type platform:coin.coin_platform address:coin.coin_address andTreaty:coin.treaty];
                    if (balance != -1)
                    {
                        // 有余额
                        coin.coin_balance = balance;

                        if(i < weakSelf.coinDatasource.count)
                        {
                            [weakSelf.coinDatasource replaceObjectAtIndex:i withObject:coin];
                        }
                        [[PWDataBaseManager shared] updateCoin:coin];
                    }
                }
                
            }
        });
    }
}

#pragma mark 网络请求
- (void)requestQuationList
{
    
    NSMutableArray *nameArray = [[NSMutableArray alloc] init];
    NSArray *coinArray =  [NSArray arrayWithArray:[[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID]];
    for (int i = 0; i < coinArray.count; i ++) {
        LocalCoin *coin = [coinArray objectAtIndex:i];
        NSString *name = [NSString stringWithFormat:@"%@,%@",coin.coin_type,coin.coin_platform];

        if (![nameArray containsObject:name])
        {
            [nameArray addObject:name];
        }
    }
    __weak typeof(self)weakself = self;
    
    NSDictionary *param = @{@"names":nameArray};
    _sessionTask = [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST serverUrl:WalletURL apiPath:HOMECOININDEX parameters:param progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"home result is %@",result);
        [weakself.priceArray removeAllObjects];
        if ([result[@"data"] isEqual:[NSNull null]]) {
            return ;
        }
        NSArray *priceArray = result[@"data"];
        
        for(int i = 0;i < priceArray.count; i++)
        {
            NSDictionary *dic = [priceArray objectAtIndex:i];
            
            if([dic[@"platform"] isEqualToString:@"OTHER"])
            {
                continue;
            }
            
            if (![dic[@"name"] isEqualToString:@"TEST"]) {
                [[PWDataBaseManager shared] upadateCoin:[dic[@"id"] integerValue] platform:dic[@"platform"] cointype:dic[@"name"]];
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
            [weakself.priceArray addObject:coinPrice];
            [[PWDataBaseManager shared] addCoinPrice:coinPrice];
            
        }
//        if (weakself.homeViewBlock) {
//            weakself.homeViewBlock();
//        }
        [self.tableView reloadData];
        
    } failure:^(NSString * _Nullable errorMessage) {
       
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
    if (self.coinDatasource.count > 0) {
        LocalCoin *coin = [_coinDatasource objectAtIndex:section];
        if (![self.localArray containsObject:coin.coin_chain] && coin.coin_chain != nil) {
            [self.localArray addObject:coin.coin_chain];
        }
    }
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
    if(indexPath.row < _coinDatasource.count)
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
    if (indexPath.row < _coinDatasource.count)
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
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [btn setImage:[UIImage imageNamed:@"icon_add"] forState:UIControlStateNormal];
    [btn setContentMode:UIViewContentModeScaleAspectFit];
    btn.tag = 2;
    [btn addTarget:self action:@selector(btnAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:btn];
    
    return item;

    
}

- (void)btnAction:(UIButton *)sender
{
    switch (sender.tag) {
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
