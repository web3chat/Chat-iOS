//
//  PWSingelCoinTransListViewController.m
//  PWallet
//
//  Created by 郑晨 on 2021/7/12.
//  Copyright © 2021 陈健. All rights reserved.
//

#import "PWSingelCoinTransListViewController.h"
#import "TradeCell.h"
#import <MJRefresh/MJRefresh.h>
#import "TradeDetailViewController.h"
#import "Depend.h"
#import "chat-Swift.h"
@interface PWSingelCoinTransListViewController ()
<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic,strong) NSMutableArray *transactionArray;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) NSInteger count;
@property (nonatomic) NSInteger index;
@property (nonatomic) NSInteger direction;
@property (nonatomic, copy) NSString *totalAmout;

@end

@implementation PWSingelCoinTransListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"转账记录";
    [self.view addSubview:self.tableView];
    self.transactionArray = [[NSMutableArray alloc] init];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.tableView addSubview:self.refreshControl];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.index = 0;
    [self getTransportData];
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


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *headview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 160)];
    headview.backgroundColor =  CMColorFromRGB(0xf8f8fa);
    UIImageView *backgroundImgView = [[UIImageView alloc] init];
    backgroundImgView.image = [UIImage imageNamed:@"record_background"];
    backgroundImgView.layer.cornerRadius = 4;
    [headview addSubview:backgroundImgView];
    
    UILabel *countLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:14]
                                      textColor:CMColorFromRGB(0xd4b171)
                                  textAlignment:NSTextAlignmentLeft
                                           text:[NSString stringWithFormat:@"已转%@(个)",_selectedCoin.coin_type]];
    [backgroundImgView addSubview:countLab];
    
    UILabel *counntDeatilLab = [UILabel getLabWithFont:[UIFont fontWithName:@"DINAlternate-Bold" size:36]
                                             textColor:CMColorFromRGB(0xd4b171)
                                         textAlignment:NSTextAlignmentLeft
                                                  text:@""];
    counntDeatilLab.text = self.totalAmout;
    [backgroundImgView addSubview:counntDeatilLab];
    
    [backgroundImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(headview).offset(17);
        make.right.equalTo(headview).offset(-17);
        make.top.equalTo(headview).offset(20);
        make.height.mas_equalTo(120);
    }];
    
    [countLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(backgroundImgView).offset(20);
        make.right.equalTo(backgroundImgView).offset(-17);
        make.top.equalTo(backgroundImgView).offset(27);
        make.height.mas_equalTo(20);
    }];
    
    [counntDeatilLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(backgroundImgView).offset(20);
        make.right.equalTo(backgroundImgView).offset(-17);
        make.top.equalTo(countLab.mas_bottom).offset(5);
        make.height.mas_equalTo(42);
    }];
    
    
    return headview;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 160.f;
}


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
    self.index = 0;
    self.transactionArray = [[NSMutableArray alloc] init];
    [self getTransportData];
}


/**
 * 加载更多
 */
- (void)loadMore
{
    self.index++;
    [self queryTransactions];
}

/**
 * 查询交易记录
 */
- (void)queryTransactions
{
    [self getTransportData];
}



- (void)getTransportData
{
    NSString *platformStr = self.selectedCoin.coin_platform;
    NSString *coinType = self.selectedCoin.coin_type;
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinType platform:platformStr andTreaty:self.selectedCoin.treaty];
    NSString *tokenSymbol = coinType;
    
    if (coinPrice.treaty == 2)
    {
        tokenSymbol = [NSString stringWithFormat:@"%@.coins",coinPrice.coinprice_platform];
    }
    else
    {
        if ([coinPrice.coinprice_chain isEqualToString:@"BTY"] && ![coinPrice.coinprice_platform isEqualToString:@"bty"]) {
            NSString *platformStr = coinPrice.coinprice_platform;
            tokenSymbol = [NSString stringWithFormat:@"%@.%@",platformStr,coinType];
        }
    }
    
    if ([coinPrice.coinprice_chain isEqualToString:coinType]) {
        tokenSymbol = @"";
    }
    NSDictionary *payload = @{@"cointype":self.selectedCoin.coin_chain,
                              @"tokensymbol":tokenSymbol,
                              @"from":self.selectedCoin.coin_address,
                              @"to":self.toAddr,
                              @"direction":@0,
                              @"count":@200,
                              @"index":@(self.index)
    };
    
    
    NSDictionary *rawdata = @{@"method":@"QueryTxHistoryDetail",
                              @"payload":payload};
    
    NSDictionary *infoParam = @{@"cointype":self.selectedCoin.coin_chain,
                                @"tokensymbol":tokenSymbol,
                                @"rawdata":rawdata
    };
    NSDictionary *param = @{@"id":@1,
                            @"method":@"Wallet.Transport",
                            @"params":@[infoParam]
    };
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:GoNodeUrl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        NSDictionary *responseObjects = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
        [self.tableView.mj_footer endRefreshing];
        NSLog(@"reply json %@",responseObjects);
        if (self.totalAmout == nil || self.totalAmout.length == 0) {
            self.totalAmout = [responseObjects[@"result"] objectForKey:@"totalamount"];
        }
        NSArray *arr = [responseObjects[@"result"] objectForKey:@"txs"];
//        if (arr.count == 20) {
//            self.tableView.mj_footer.hidden = false;
//        }else{
            self.tableView.mj_footer.hidden = true;
//        }
        [self.transactionArray addObjectsFromArray:arr];
        [self.tableView reloadData];
    } failure:^(NSString * _Nullable errorMessage) {
        
    }];
    
//    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:param options:0 error:nil];
//    
//    NSString *strJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//    // https://183.129.226.77:8083
//    NSString *url = GoNodeUrl;// @"https://go.biqianbao.net";
//    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
//    NSMutableURLRequest *req = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:url parameters:nil error:nil];
//    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
//    securityPolicy.allowInvalidCertificates = YES;
//    manager.securityPolicy = securityPolicy;
//    req.timeoutInterval= [[[NSUserDefaults standardUserDefaults] valueForKey:@"timeoutInterval"] longValue];
//    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
//    [req setHTTPBody:[strJson dataUsingEncoding:NSUTF8StringEncoding]];
//    
//   NSURLSessionDataTask *task = [manager dataTaskWithRequest:req uploadProgress:nil downloadProgress:nil
//               completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
//        if (!error) {
//            
//        }else{
//            NSLog(@"error is %@",error);
//        }
//    }];
//    [task resume];
}

#pragma mark - getter and setter

- (UITableView *)tableView
{
    if (!_tableView) {
        UITableView *tradeList = [[UITableView alloc] init];
        tradeList.delegate = self;
        tradeList.dataSource = self;
        tradeList.rowHeight = 70;
        tradeList.estimatedRowHeight = 0;
        tradeList.estimatedSectionFooterHeight = 0;
        tradeList.estimatedSectionHeaderHeight = 0;
        tradeList.separatorColor = SGColorRGBA(217, 220, 233, 1);
        tradeList.backgroundColor = CMColorFromRGB(0xf8f8fa);
        [self.view addSubview:tradeList];
        _tableView = tradeList;
        tradeList.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingTarget:self refreshingAction:@selector(loadMore)];
        tradeList.mj_footer.hidden = true;
        
        
       
    }
    
    return _tableView;
}

- (UIRefreshControl *)refreshControl
{
    if (!_refreshControl) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(refreshClick:) forControlEvents:UIControlEventValueChanged];
       
        self.refreshControl = refreshControl;
    }
    return _refreshControl;
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
