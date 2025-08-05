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
        self.dataArr = @[@{@"name":@"最快",
                           @"value":@"0.000000",
                           @"detail":@""},
                         @{@"name":@"标准",
                           @"value":@"0.000000",
                           @"detail":@""},
                         @{@"name":@"经济",
                           @"value":@"0.000000",
                           @"detail":@""},
                         @{@"name":@"自定义",
                           @"value":@"",
                           @"detail":@""}];
    }
    return self;
}


- (void)initView
{
    [self addSubview:self.contentsView];
    [self.contentsView addSubview:self.tableView];
    [self.contentsView addSubview:self.titleLab];
    self.titleLab.text = @"矿工费";
    
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
        
        double customFee = (self.selectedGasPrice.doubleValue * self.selectedGas.doubleValue) / 1000000000.0;
        self.selectedFeeStr = [NSString stringWithFormat:@"%.6f",customFee];
    }
    NSDictionary *dict = @{@"value":self.selectedFeeStr,
                           @"gas":self.selectedGas,
                           @"gasPrice":self.selectedGasPrice,
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
        rpcurl = @"https://bsc.publicnode.com";
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
       
        double gasPrice = [self.gasPrice doubleValue] / 1000000000.0;
        double lowGasPrice = gasPrice * 1.5;
        double lowFee = lowGasPrice * 21000 / 1000000000.0;
        double norGasPrice = gasPrice * 2.0;
        double norFee = norGasPrice * 21000 / 1000000000.0;
        double fastGasPrice = gasPrice * 3.0;
        double fastFee = fastGasPrice * 21000 / 1000000000.0;
        NSString *chain = self.localCoin.coin_chain;
        if ([self.localCoin.coin_chain isEqualToString:@"ETH"] && [self.localCoin.coin_type isEqualToString:@"BTY"]) {
            chain = @"BTY";
        }
        self.dataArr = @[@{@"name":@"最快",
                           @"value":[NSString stringWithFormat:@"%.6f %@",fastFee,chain],
                           @"detail":[NSString stringWithFormat:@"%.6f %@ = Gas(21000)*GasPrice(%.2f GWEI)",fastFee,chain,fastGasPrice],
                           @"gas":@"21000",
                           @"gasPrice":[NSString stringWithFormat:@"%.2f",fastGasPrice]},
                         @{@"name":@"标准",
                           @"value":[NSString stringWithFormat:@"%.6f %@",norFee,chain],
                           @"detail":[NSString stringWithFormat:@"%.6f %@ = Gas(21000)*GasPrice(%.2f GWEI)",norFee,chain,norGasPrice],
                           @"gas":@"21000",
                           @"gasPrice":[NSString stringWithFormat:@"%.2f",norGasPrice]},
                         @{@"name":@"经济",
                           @"value":[NSString stringWithFormat:@"%.6f %@",lowFee,chain],
                           @"detail":[NSString stringWithFormat:@"%.6f %@ = Gas(21000)*GasPrice(%.2f GWEI)",lowFee,chain,lowGasPrice],
                           @"gas":@"21000",
                           @"gasPrice":[NSString stringWithFormat:@"%.2f",lowGasPrice]},
                         @{@"name":@"自定义",
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
        [btn setTitle:@"取消" forState:UIControlStateNormal];
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
        [btn setTitle:@"确认" forState:UIControlStateNormal];
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
