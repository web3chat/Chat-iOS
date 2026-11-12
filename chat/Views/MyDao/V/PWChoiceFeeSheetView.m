//
//  PWChoiceFeeSheetView.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/11/17.
//  Copyright © 2023 fzm. All rights reserved.
//

#import "PWChoiceFeeSheetView.h"
#import "PWChoiceFeeSheetCell.h"
#import <JKBigInteger/JKBigInteger.h>
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface PWChoiceFeeSheetView()<UITableViewDelegate, UITableViewDataSource>
{
    BOOL _selected[10000];
}
@property (nonatomic, strong) UIView *contentsView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *confirmBtn;
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) NSString *gasPrice;
@property (nonatomic, strong) NSArray *dataArr;
@property (nonatomic, strong) NSString *selectedFeeStr;
@property (nonatomic, strong) UITextField *gasPriceTextField;
@property (nonatomic, strong) UITextField *gasTextField;
@property (nonatomic, strong) UILabel *gasTipLab;
@property (nonatomic, strong) UILabel *gasPriceTipLab;
@property (nonatomic, strong) LocalCoin *localCoin;
@property (nonatomic, strong) NSDictionary *selectedDict;
@property (nonatomic, assign) BOOL isCustom; // 是否是自定义
@property (nonatomic, assign) NSInteger selectedInx;
@property (nonatomic, strong) NSString *selectedGas;
@property (nonatomic, strong) NSString *selectedGasPrice;
/// 是否使用外部传入的档位数据（不再内部请求 gasPrice）
@property (nonatomic, assign) BOOL useExternalDataArr;
/// 自定义手输换算除数：GWEI 口径为 1e9（Gas × GasPrice(GWEI) ÷ 1e9）
@property (nonatomic, assign) double customFeeDivisor;


@end

@implementation PWChoiceFeeSheetView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (instancetype)initWithFrame:(CGRect)frame withCoin:(LocalCoin *)localCoin withDict:(nonnull NSDictionary *)dict{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = SGColorRGBA(0, 0, 0, .5f);
        self.useExternalDataArr = NO;
        // 旧逻辑：自定义按 wei 口径换算，保持原行为
        self.customFeeDivisor = 1000000000000000000.0;
        [self initView];
        
        for (int i = 0; i < 4; i++) {
            _selected[i] = NO;
        }
        self.localCoin = localCoin;
        [self getGasPrice];
        self.selectedDict = dict;
        if (self.selectedDict != nil) {
            // 默认选择
            NSInteger index = [self.selectedDict[@"index"] integerValue];
            _selected[index] = YES;
            self.isCustom = index == 3 ? YES : NO;
            self.selectedInx = index;
        }
        self.dataArr = @[@{@"name":L(@"最快"),
                           @"value":@"0.000000",
                           @"detail":@""},
                         @{@"name":L(@"标准"),
                           @"value":@"0.000000",
                           @"detail":@""},
                         @{@"name":L(@"经济"),
                           @"value":@"0.000000",
                           @"detail":@""},
                         @{@"name":L(@"自定义"),
                           @"value":@"",
                           @"detail":@""}];
    }
    return self;
}

/// 外部给定档位数据（TransferBottomView 用）：不请求链上 gasPrice
- (instancetype)initWithFrame:(CGRect)frame
                      dataArr:(NSArray<NSDictionary *> *)dataArr
                     gasLimit:(NSString *)gasLimit
                selectedIndex:(NSInteger)selectedIndex {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = SGColorRGBA(0, 0, 0, .5f);
        self.useExternalDataArr = YES;
        // 手输 GWEI：Gas × GasPrice(GWEI) ÷ 1e9
        self.customFeeDivisor = 1000000000.0;
        [self initView];

        for (int i = 0; i < 4; i++) {
            _selected[i] = NO;
        }
        self.dataArr = [dataArr copy];
        if (selectedIndex < 0 || selectedIndex > 3) {
            selectedIndex = 1;
        }
        _selected[selectedIndex] = YES;
        self.selectedInx = selectedIndex;
        self.isCustom = (selectedIndex == 3);

        NSDictionary *sel = (selectedIndex < self.dataArr.count) ? self.dataArr[selectedIndex] : nil;
        NSMutableDictionary *prefill = [NSMutableDictionary dictionary];
        if (sel != nil) {
            [prefill addEntriesFromDictionary:sel];
        }
        if (gasLimit.length > 0) {
            prefill[@"gas"] = gasLimit;
        }
        // 自定义的 GasPrice 默认不预填（用户手输 GWEI）；非自定义档预填该档 GasPrice
        prefill[@"gasPrice"] = (selectedIndex != 3 && sel[@"gasPrice"] != nil) ? sel[@"gasPrice"] : @"";
        self.selectedDict = prefill;

        if (!self.isCustom) {
            self.selectedFeeStr = sel[@"value"];
            self.selectedGas = gasLimit;
            self.selectedGasPrice = sel[@"gasPrice"];
        }
    }
    return self;
}


- (void)initView
{
    [self addSubview:self.contentsView];
    [self.contentsView addSubview:self.tableView];
    [self.contentsView addSubview:self.titleLab];
    self.titleLab.text = L(@"矿工费");
    
    [self.contentsView addSubview:self.closeBtn];
    [self.contentsView addSubview:self.confirmBtn];
    
    self.contentsView.frame = CGRectMake(0, kScreenHeight, kScreenWidth, 532);
    [PWUtils setViewTopRightandLeftRaduisForView:self.contentsView size:CGSizeMake(6,6)];
    
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.contentsView).offset(6);
        make.top.equalTo(self.contentsView);
        make.width.mas_equalTo(52);
        make.height.mas_equalTo(50);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(64);
        make.top.equalTo(self.contentsView);
        make.right.equalTo(self.contentsView).offset(-64);
        make.height.mas_equalTo(50);
    }];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.titleLab.mas_bottom).offset(22);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(370);
    }];
    
    [self.confirmBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.right.equalTo(self.contentsView).offset(-16);
        make.bottom.equalTo(self.contentsView).offset(-28);
        make.height.mas_equalTo(44);
    }];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark : UIKeyboardWillShowNotification/UIKeyboardWillHideNotification
- (void)keyboardWillShow:(NSNotification *)notification{
    
    NSDictionary *userInfo = [notification userInfo];
    NSValue* aValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];//获取弹出键盘的fame的value值
    CGRect keyboardRect = [aValue CGRectValue];
    keyboardRect = [self convertRect:keyboardRect fromView:self.window];//获取键盘相对于self.view的frame ，传window和传nil是一样的
    NSNumber * animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];//获取键盘弹出动画时间值
    NSTimeInterval animationDuration = [animationDurationValue doubleValue];
    [UIView animateWithDuration:animationDuration animations:^{
        self.frame = CGRectMake(0, -keyboardRect.size.height, kScreenWidth, kScreenHeight);
    }];
    
}
- (void)keyboardWillHide:(NSNotification *)notification{
    NSDictionary *userInfo = [notification userInfo];
    NSNumber * animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];//获取键盘隐藏动画时间值
    NSTimeInterval animationDuration = [animationDurationValue doubleValue];
    if (self.frame.origin.y < 0) {//如果有偏移，当影藏键盘的时候就复原
        [UIView animateWithDuration:animationDuration animations:^{
            self.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
        }];
    }
}

#pragma mark - show
- (void)show
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"showFeeAlert"];
   
    [[UIApplication sharedApplication].keyWindow addSubview:self];
    
    [UIView animateWithDuration:.3 animations:^{
        CGRect frame = self.contentsView.frame;
        frame.origin.y -= frame.size.height;
        self.contentsView.frame = frame;
    }];

}

#pragma mark - hide
- (void)dismiss
{
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"showFeeAlert"];
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.contentsView.frame;
        frame.origin.y += frame.size.height;
        self.contentsView.frame = frame;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeFromSuperview];
    });
}

#pragma mark - cancel
- (void)clickCancelBtn:(UIButton *)sender
{
    [self dismiss];
}

- (void)confirm:(UIButton *)sender
{
    if (self.isCustom) {
        // 需要判断输入值的大小
        // 自定义
        if (self.gasTextField.text.length == 0) {
            self.gasTipLab.hidden = NO;
            return;
        }else{
            self.gasTipLab.hidden = YES;
        }
        
        if (self.gasPriceTextField.text.length == 0) {
            self.gasPriceTipLab.hidden = NO;
            return;
        }else{
            self.gasPriceTipLab.hidden = YES;
        }
        self.selectedGas = self.gasTextField.text;
        self.selectedGasPrice = self.gasPriceTextField.text;
        
        double divisor = self.customFeeDivisor > 0 ? self.customFeeDivisor : 1000000000000000000.0;
        double customFee = (self.selectedGasPrice.doubleValue * self.selectedGas.doubleValue) / divisor;
        self.selectedFeeStr = [NSString stringWithFormat:@"%.8f",customFee];
    }
    NSDictionary *dict = @{@"value":self.selectedFeeStr == nil ? @"0" : self.selectedFeeStr,
                           @"gas":self.selectedGas == nil ? @"0" : self.selectedGas,
                           @"gasPrice":self.selectedGasPrice == nil ? @"0" : self.selectedGasPrice,
                           @"index":@(self.selectedInx)};
    
    if (self.choiceFeeBlock) {
        [self dismiss];
        self.choiceFeeBlock(dict);
    }
}

#pragma mark - uitableview delegate datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identity = @"choiceFeeSheetCell";
    PWChoiceFeeSheetCell *cell = [tableView dequeueReusableCellWithIdentifier:identity];
    if (!cell) {
        cell = [[PWChoiceFeeSheetCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identity];
    }
    cell.customView.hidden = YES;
    cell.gasTipLab.hidden = YES;
    cell.gasPriceTipLab.hidden = YES;
    cell.toBtn.hidden = indexPath.row == 3 ? NO:YES; // 自定义那行，显示按钮，其余不显示
   
    
    if (_selected[indexPath.row] == NO) {
        cell.contentsView.layer.borderColor = UIColor.blueColor.CGColor;
        cell.contentsView.layer.borderWidth = 0;
        if (indexPath.row == 3) {
            [cell.contentsView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.mas_equalTo(40);
            }];
        }else{
            [cell.contentsView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.mas_equalTo(70);
            }];
        }
       
    } else {
        cell.contentsView.layer.borderColor = UIColor.blueColor.CGColor;
        cell.contentsView.layer.borderWidth = 1;
        if (indexPath.row == 3) {
            cell.customView.hidden = NO;
            self.gasTextField = cell.customGasTextField;
            self.gasPriceTextField = cell.customGasPriceTextField;
            self.gasTipLab = cell.gasTipLab;
            self.gasPriceTipLab = cell.gasPriceTipLab;
            [cell.contentsView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.mas_equalTo(240);
            }];
            
            if (self.selectedDict.count != 0) {
                cell.customGasTextField.text = self.selectedDict[@"gas"];
                cell.customGasPriceTextField.text = self.selectedDict[@"gasPrice"];
            }
            
        }else{
            cell.customView.hidden = YES;
            [cell.contentsView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.mas_equalTo(70);
            }];
        }
    }

    if (self.dataArr.count != 0) {
        NSDictionary *dict = self.dataArr[indexPath.row];
        cell.titleLab.text = dict[@"name"];
        cell.subtitleLab.text = dict[@"value"];
        cell.detailLab.text = dict[@"detail"];
        
        if (indexPath.row == 3) {
            cell.subtitleLab.hidden = YES;
            cell.detailLab.hidden = YES;
        }else{
            cell.subtitleLab.hidden = NO;
            cell.detailLab.hidden = NO;
        }
    }
    
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 3) {
        if (_selected[3] == NO) {
            return 40;
        }else{
            return 250;
        }
    }
    return 80;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    for (int i = 0; i < 4; i++) {
        _selected[i] = NO;
    }
    _selected[indexPath.row] = YES;
    _isCustom = indexPath.row == 3 ? YES : NO; // 选择了自定义
    if (indexPath.row != 3) {
        NSDictionary *dict = self.dataArr[indexPath.row];
        self.selectedFeeStr = dict[@"value"];
        self.selectedGasPrice = dict[@"gasPrice"];
        self.selectedGas = dict[@"gas"];
    }else{
        self.selectedFeeStr = @"0";
    }
    _selectedInx = indexPath.row;
    
    [self.tableView reloadData];
}

#pragma mark - 获取gas
- (void)getGasPrice{
    
    NSString *rpcurl = @"https://mainnet.bityuan.com/eth";
    if ([self.localCoin.coin_chain isEqualToString:@"BTY"]) {
        rpcurl = @"https://mainnet.bityuan.com/eth";
    }else if ([self.localCoin.coin_chain isEqualToString:@"ETH"]){
        if ([self.localCoin.coin_type isEqualToString:@"BTY"]) {
            rpcurl = @"https://mainnet.bityuan.com/eth";
        }else{
            rpcurl = @"https://rpc.flashbots.net";
        }
        
    }else if ([self.localCoin.coin_chain isEqualToString:@"BNB"]){
        rpcurl = @"https://bsc-dataseed.bnbchain.org/";
    }
    
    NSDictionary *params = @{@"id":@1,
                             @"jsonrpc":@"2.0",
                             @"method":@"eth_gasPrice",
                             @"params":@[]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:rpcurl
                                          apiPath:@""
                                       parameters:params
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        
        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"eth_gasPrice is %@",jsonData);
        NSString *result = jsonData[@"result"];
        if(result != nil || result.length != 0){
            self.gasPrice = [self sixteenToTen:result];
        }
        NSString *gas = self.selectedDict[@"gas"];
        double gasPrice = [self.gasPrice doubleValue] / 1000000000.0;
        double lowGasPrice = gasPrice * 1.5;
        double lowFee = lowGasPrice * gas.doubleValue / 1000000000.0;
        double norGasPrice = gasPrice * 2.0;
        double norFee = norGasPrice * gas.doubleValue / 1000000000.0;
        double fastGasPrice = gasPrice * 3.0;
        double fastFee = fastGasPrice * gas.doubleValue / 1000000000.0;
        NSString *chain = self.localCoin.coin_chain;
        if ([self.localCoin.coin_chain isEqualToString:@"ETH"] && [self.localCoin.coin_type isEqualToString:@"BTY"]) {
            chain = @"BTY";
        }
        self.dataArr = @[@{@"name":L(@"最快"),
                           @"value":[NSString stringWithFormat:@"%.6f %@",fastFee,chain],
                           @"detail":[NSString stringWithFormat:@"%.6f %@ = Gas(%@)*GasPrice(%.2f GWEI)",fastFee,chain,gas,fastGasPrice],
                           @"gas":gas,
                           @"gasPrice":[NSString stringWithFormat:@"%.2f",fastGasPrice]},
                         @{@"name":L(@"标准"),
                           @"value":[NSString stringWithFormat:@"%.6f %@",norFee,chain],
                           @"detail":[NSString stringWithFormat:@"%.6f %@ = Gas(%@)*GasPrice(%.2f GWEI)",norFee,chain,gas,norGasPrice],
                           @"gas":gas,
                           @"gasPrice":[NSString stringWithFormat:@"%.2f",norGasPrice]},
                         @{@"name":L(@"经济"),
                           @"value":[NSString stringWithFormat:@"%.6f %@",lowFee,chain],
                           @"detail":[NSString stringWithFormat:@"%.6f %@ = Gas(%@)*GasPrice(%.2f GWEI)",lowFee,chain,gas,lowGasPrice],
                           @"gas":gas,
                           @"gasPrice":[NSString stringWithFormat:@"%.2f",lowGasPrice]},
                         @{@"name":L(@"自定义"),
                           @"value":@"",
                           @"detail":@"",
                           @"gas":@"",
                           @"gasPrice":@""}];
        [self.tableView reloadData];
        
    } failure:^(NSString * _Nullable errorMessage) {
        NSLog(@"error is %@",errorMessage);
        
    }];
}

- (NSString *)sixteenToTen:(NSString *)str{

    if(str == nil){
        return @"0";
    }
    
    if([str hasPrefix:@"0x"]){
        str = [str stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    }

    JKBigInteger *hexint = [[JKBigInteger alloc] initWithString:str andRadix:16];

    return [NSString stringWithFormat:@"%@",hexint];

}

#pragma mark - getter setter
- (UITableView *)tableView
{
    if (!_tableView) {
        UITableView *tab = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        tab.delegate = self;
        tab.dataSource = self;
        tab.estimatedRowHeight = 0;
        tab.separatorStyle = UITableViewCellSeparatorStyleNone;
        tab.estimatedSectionFooterHeight = 0;
        tab.estimatedSectionHeaderHeight = 0;
        tab.scrollEnabled = YES;
        tab.layer.cornerRadius = 5.f;
        tab.backgroundColor = SGColorFromRGB(0xf8f8f8);
        
        _tableView = tab;
        
    }
    return _tableView;
}

- (UIView *)contentsView
{
    if (!_contentsView) {
        UIView *contentView = [[UIView alloc] init];
        contentView.backgroundColor = SGColorFromRGB(0xf8f8fa);
        
        _contentsView = contentView;
    }
    return _contentsView;
}

- (UILabel *)titleLab
{
    if (!_titleLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont fontWithName:@"PingFangSC-Medium" size:17.f];
        lab.textAlignment = NSTextAlignmentCenter;
        
        _titleLab = lab;
    }
    return _titleLab;
}

- (UIButton *)closeBtn
{
    if (!_closeBtn) {
        UIButton *btn = [[UIButton alloc] init];
        [btn setTitle:L(@"取消") forState:UIControlStateNormal];
        [btn setTitleColor:SGColorFromRGB(0x8e92a3) forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(clickCancelBtn:) forControlEvents:UIControlEventTouchUpInside];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:16.f]];
        
        _closeBtn = btn;
    }
    
    return _closeBtn;
}

- (UIButton *)confirmBtn
{
    if (!_confirmBtn) {
        UIButton *btn = [[UIButton alloc] init];
        [btn setTitle:L(@"确认") forState:UIControlStateNormal];
        [btn setTitleColor:SGColorFromRGB(0xffffff) forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(confirm:) forControlEvents:UIControlEventTouchUpInside];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:17.f]];
        btn.backgroundColor = SGColorFromRGB(0x7190ff);
        btn.layer.cornerRadius = 5;
        
        _confirmBtn = btn;
    }
    
    return _confirmBtn;
}

@end
