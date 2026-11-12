//
//  PWSearchCoinChildViewController.m
//  PWallet
//
//  Created by 郑晨 on 2020/1/7.
//  Copyright © 2020 fzm. All rights reserved.
//

#import "PWSearchCoinChildViewController.h"
#import "UIViewController+RTRootNavigationController.h"
#import "PWAlertController.h"
#import "LocalCoin.h"
#import "PWDataBaseManager.h"
#import "CoinTableViewCell.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]

@interface PWSearchCoinChildViewController ()
<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *coinTableView;
@property (nonatomic, strong) NSMutableArray *coinArray;
@property (nonatomic, strong) NSString *titleStr;
@property (nonatomic) BOOL isEditing;
@property (nonatomic, strong) UIButton *completeBtn;

@end

@implementation PWSearchCoinChildViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = UIColor.whiteColor;
    self.coinArray = [NSMutableArray array];
    // ⚠️ `_titleStr` 必须是「自己这一栏」的标题：以前写死成「首页币种」，所有 tab 都会按首页币种处理
    // （长按排序、数据源重建全错）。父页在 createView 里先 set title 再让 view 加载，所以这里拿得到。
    _titleStr = self.title.length > 0 ? self.title : L(@"首页币种");
    [self.view addSubview:self.coinTableView];
    [self.coinTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    // ⚠️ 这里**不查库**：CAPSPageMenu 会把每个 tab 的 childVC 都加载一遍，
    // 若每个 childVC 都在 viewDidLoad 里整表查库，建页面时会同时压上 N 条全表查询，
    // 首页币种的数据被挤在队列后面 ⇒ 页面看着更慢。
    // 数据改成由父页广播驱动（进页面时第一栏、切 tab 时对应那一栏），见 changeDatasource:。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(changeDatasource:)
                                                 name:SEARCHCOINNOTIFICATION
                                               object:nil];
    
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// 查「首页币种」（钱包里已添加的币）：整表查 + 逐行解析模型，放后台做，主线程只负责铺列表
- (void)reloadWalletCoins
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *coins = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
        dispatch_async(dispatch_get_main_queue(), ^{
            // 期间可能已经切到别的链的 tab（那边会自己铺数据），别把它冲掉
            if (![self->_titleStr isEqualToString:L(@"首页币种")]) { return; }
            self.coinArray = [NSMutableArray arrayWithArray:coins];
            [self.coinTableView reloadData];
        });
    });
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.view endEditing:YES];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: CMColorRGBA(51,51,51,1),NSFontAttributeName : [UIFont boldSystemFontOfSize:18]};
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self logoutSort];
}

- (void)changeDatasource:(NSNotification *)notification
{
    NSDictionary *dict = notification.object;
    // ⚠️ 通知是**广播**的：所有 tab 的 childVC 都会收到（旧 pageMenu 拆下来的 childVC 也还挂在那里）。
    // 只有通知里 index 指向的那一栏需要重建数据，否则每切一次 tab 就是
    // 「N 个 childVC × 每个币多次整表查库」—— 添加币种页卡住的主因。
    NSNumber *index = [dict objectForKey:@"index"];
    if (index && index.integerValue != self.tabIndex) { return; }
    
    // 注意：不要再把 `_titleStr` 覆写成通知里的 name（那是「当前选中栏」的名字，
    // 会把所有 childVC 都带成首页币种）；它必须一直是「自己这一栏」的标题。
    NSArray *coinArray = [dict objectForKey:@"coinArray"];
    self.completeBtn.hidden = YES;
    if ([_titleStr isEqualToString:L(@"首页币种")])
    {
        self.completeBtn.hidden = !self.coinTableView.isEditing;
        // 整表查放后台（见 reloadWalletCoins）
        [self reloadWalletCoins];
        return;
    }
    
    // 链路 tab：整表查一次，把 DB 往返挪出循环。
    // 原来每个币都查两遍整表（queryAddressBasedOnChain + queryCoinArrayBasedOnSelectedWalletID）
    // ⇒ O(N²) 次同步 DB 查询，币一多就明显卡。
    NSArray *localCoins = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    // ⚠️ `wallet_id` / `coin_walletid` 都是 NSInteger（不是字符串），别用 NSString * 接
    NSInteger walletId = [[PWDataBaseManager shared] queryWalletIsSelected].wallet_id;
    NSMutableDictionary<NSString *, NSString *> *addressCache = [NSMutableDictionary dictionary];
    self.coinArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < coinArray.count; i ++) {
        NSDictionary *dic = [coinArray objectAtIndex:i];
        LocalCoin *coin = [[LocalCoin alloc] init];
        
        coin.coin_walletid = walletId;
        coin.coin_type = dic[@"name"];
        NSString *chain = dic[@"chain"];
        NSString *address = addressCache[chain ?: @""];
        if (address == nil) {
            // 同一条主链只查一次
            address = [[PWDataBaseManager shared] queryAddressBasedOnChain:chain] ?: @"";
            addressCache[chain ?: @""] = address;
        }
        coin.coin_address = address;
        coin.coin_balance = 0;
        coin.coin_pubkey = @"";
        coin.coin_show = 0;
        coin.coin_platform = dic[@"platform"];
        coin.treaty = [dic[@"treaty"] integerValue];
        coin.coin_chain = dic[@"chain"];
        coin.coin_coinid = [dic[@"id"] integerValue];
        coin.icon = dic[@"icon"];
        coin.coin_type_nft = 2;
        // 继承本地已添加那枚币的状态：在内存里比，别再整表查库
        for (LocalCoin *localCoin in localCoins) {
            if ([localCoin.coin_type isEqualToString:dic[@"name"]] && localCoin.coin_coinid == [dic[@"id"] integerValue])
            {
                coin.coin_show = localCoin.coin_show;
                coin.coin_id = localCoin.coin_id;
                coin.coin_balance = localCoin.coin_balance;
            }
        }
        [self.coinArray addObject:coin];
    }
    [self.coinTableView reloadData];
}


#pragma mark - uitableviewdalegate datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _coinArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // ⚠️ 必须复用：原来每个 row 都 alloc 一个新的 CoinTableViewCell（内部建一整套子视图 + 装约束），
    // 币种一多、一滚动就卡
    static NSString *CellIdentifier = @"CoinTableViewCell";
    CoinTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[CoinTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = CMTextFont18;
    cell.textLabel.textColor = TextColor51;
    cell.detailTextLabel.font = CMTextFont14;
    cell.detailTextLabel.textColor = PlaceHolderColor;
    cell.separatorInset = UIEdgeInsetsMake(0, 66, 0, 0);
    __block typeof(cell) weakCell = cell;
    if (self.coinTableView.editing) {
        cell.switchBtn.hidden = YES;
    }
    else
    {
        cell.switchBtn.hidden = NO;
    }
    
    cell.addCoin = ^(LocalCoin *coin, BOOL isOn) {
        // 要弹框
        LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
        // 已开启面容/指纹时直接验证通过，否则弹密聊密码输入框
        [ChatPasswordGate requestVerifiedPasswordWithTitle:L(@"请输入密聊密码")
                                                cancelled:^{ weakCell.switchBtn.on = NO; }
                                                  success:^(NSString * _Nonnull text) {
            if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
                dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
                dispatch_async(queue, ^{
                    [GoFunction addChainCoinIntoWallet:coin password:text];
                });
                
            } else {
                weakCell.switchBtn.on = NO;
                [self showCustomMessage:L(@"密码错误") hideAfterDelay:1];
            }
        }];
    };
    return cell;

}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.coinArray.count < indexPath.row + 1)
    {
        return;
    }
    LocalCoin *coin = [self.coinArray objectAtIndex:indexPath.row];
    CoinTableViewCell *coinCell = (CoinTableViewCell *)cell;
    coinCell.coin = coin;
    
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80.f;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    if ([_titleStr isEqualToString:L(@"首页币种")]) {
        return YES;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    NSLog(@"old is %@",self.coinArray);
    LocalCoin *coin = self.coinArray[sourceIndexPath.row];
    [self.coinArray removeObjectAtIndex:sourceIndexPath.row];
    [self.coinArray insertObject:coin atIndex:destinationIndexPath.row];
    NSLog(@"new is %@",self.coinArray);
    LocalWallet *localWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
   if( [[PWDataBaseManager shared] deleteCoin:localWallet])
   {
       for (LocalCoin *localCoin in self.coinArray) {
           LocalCoin *newCoin = [[LocalCoin alloc] init];
           newCoin.coin_walletid = localWallet.wallet_id;
           newCoin.coin_type = localCoin.coin_type;
           newCoin.coin_address = localCoin.coin_address;
           newCoin.coin_balance = localCoin.coin_balance;
           newCoin.coin_pubkey = localCoin.coin_pubkey;
           
           newCoin.coin_show = localCoin.coin_show;
           newCoin.coin_platform = localCoin.coin_platform;
           newCoin.coin_coinid = localCoin.coin_coinid;
           newCoin.treaty = localCoin.treaty;
           newCoin.coin_chain = localCoin.coin_chain;
           newCoin.coin_type_nft = localCoin.coin_type_nft;
           [[PWDataBaseManager shared] addCoin:newCoin];
       }
   }
    self.coinArray = [NSMutableArray arrayWithArray:[[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID]];
    [self.coinTableView reloadData];
    
}


#pragma mark - 首页推荐
- (void)longPressGestureRecognized:(UIGestureRecognizer *)sender
{
    if (![_titleStr isEqualToString:L(@"首页币种")]) {
        return ;
    }
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        self.completeBtn.hidden = NO;
        [self.coinTableView setEditing:YES animated:YES];
        [self.coinTableView reloadData];
    }
    else
    {
        // do nothing
    }
    
}

- (void)logoutSort
{
    for (UIView *view in [UIApplication sharedApplication].keyWindow.subviews) {
        if ([view isKindOfClass:[UIButton class]] && view.tag == 1001) {
            view.hidden = YES;
        }
    }
    [self.coinTableView setEditing:NO animated:YES];
    [self.coinTableView reloadData];
}



#pragma mark - setter and getter
- (UITableView *)coinTableView
{
    if (!_coinTableView) {
        _isEditing = NO;
        UITableView *coinTableView = [[UITableView alloc] init];
        coinTableView.delegate = self;
        coinTableView.dataSource = self;
        coinTableView.rowHeight = 70;
        coinTableView.backgroundColor = self.view.backgroundColor;
        coinTableView.showsVerticalScrollIndicator = NO;
        coinTableView.separatorColor = LineColor;
        _coinTableView = coinTableView;
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognized:)];
        longPress.minimumPressDuration = 0.8;
        [_coinTableView addGestureRecognizer:longPress];
        
    }
    return _coinTableView;
}

- (UIButton *)completeBtn
{
    if (!_completeBtn) {
        _completeBtn = [[UIButton alloc] init];
        [_completeBtn setTitle:L(@"退出排序") forState:UIControlStateNormal];
        [_completeBtn setTitleColor:SGColorFromRGB(0xffffff) forState:UIControlStateNormal];
        [_completeBtn setBackgroundColor:SGColorFromRGB(0x7190ff)];
        [_completeBtn.layer setCornerRadius:(CGFloat)23.f];
        [_completeBtn.titleLabel setFont:[UIFont systemFontOfSize:16.f]];
        _completeBtn.layer.shadowOpacity = 1;
        _completeBtn.layer.shadowOffset = CGSizeMake(0, 0);
        _completeBtn.layer.shadowColor = CMColorFromRGB(0xebedf8).CGColor;
        [_completeBtn addTarget:self action:@selector(logoutSort) forControlEvents:UIControlEventTouchUpInside];
        _completeBtn.hidden = YES;
        _completeBtn.tag = 1001;
        UIWindow *keywindow = [UIApplication sharedApplication].keyWindow;
        [keywindow addSubview:_completeBtn];
        
        [_completeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(keywindow).offset(-100);
            make.centerX.equalTo(keywindow);
            make.height.mas_equalTo(46);
            make.width.mas_equalTo(122);
        }];
    }
    return _completeBtn;
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
