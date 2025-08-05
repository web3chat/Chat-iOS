//
//  PWContractVC.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2025/4/9.
//  Copyright © 2025 fzm. All rights reserved.
//

#import "PWContractVC.h"
#import "CommonTextField.h"
#import "Depend.h"
#import "PWActionSheetView.h"
#import "PWContractRequest.h"

@interface PWContractVC ()
<UITextFieldDelegate>

@property (nonatomic, strong) UILabel *chainLab;
@property (nonatomic, strong) UIButton *selectedChainBtn;
@property (nonatomic, strong) UILabel *contractLab;
@property (nonatomic, strong) CommonTextField *contractAddTextField;
@property (nonatomic, strong) UILabel *nameLab;
@property (nonatomic, strong) CommonTextField *nameTextField;
@property (nonatomic, strong) UILabel *accuracyLab;
@property (nonatomic, strong) CommonTextField *accuracyTextField;
@property (nonatomic, strong) UIButton *confirBtn;
@property (nonatomic, strong) UIButton *scanBtn;

@property (nonatomic, strong) NSString *chainStr;

@end

@implementation PWContractVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"添加代币";
    self.view.backgroundColor = UIColor.whiteColor;
    [self initView];
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
    
}
- (void)back {
    [self.navigationController popViewControllerAnimated:true];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
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
- (void)initView
{
    _selectedChainBtn = [[UIButton alloc] init];
    [_selectedChainBtn setTitle:@"选择主链" forState:UIControlStateNormal];
    [_selectedChainBtn setTitleColor:SGColorFromRGB(0x7190ff) forState:UIControlStateNormal];
    [_selectedChainBtn.layer setCornerRadius:6.f];
    [_selectedChainBtn.layer setBorderColor:SGColorFromRGB(0x7190ff).CGColor];
    [_selectedChainBtn.layer setBorderWidth:1.f];
    [_selectedChainBtn.titleLabel setFont:[UIFont systemFontOfSize:16.f]];
    [_selectedChainBtn addTarget:self action:@selector(choiceChain:) forControlEvents:UIControlEventTouchUpInside];
    [_selectedChainBtn setImage:[UIImage imageNamed:@"choiceChain"] forState:UIControlStateNormal];
   
    
    [self.view addSubview:_selectedChainBtn];
    
    _contractLab = [[UILabel alloc] init];
    _contractLab.text = @"代币合约";
    _contractLab.textColor = SGColorFromRGB(0x8e92a3);
    _contractLab.textAlignment = NSTextAlignmentLeft;
    _contractLab.font = [UIFont systemFontOfSize:14.f];

    [self.view addSubview:_contractLab];
      //设置钱包名称
 
    CommonTextField *contractAddTextField = [[CommonTextField alloc] init];
    contractAddTextField.textColor = CMColorFromRGB(0x333649);
    contractAddTextField.placeholder = @"请输入合约地址";
    [contractAddTextField setValue:CMColorFromRGB(0x8E92A3) forKeyPath:@"placeholderLabel.textColor"];
    contractAddTextField.delegate = self;
    contractAddTextField.tag = 101;
    [self.view addSubview:contractAddTextField];
    self.contractAddTextField = contractAddTextField;
    [contractAddTextField setAttributedPlaceholderDefault];
    
    [contractAddTextField addTarget:self action:@selector(textFieldViewChanged:) forControlEvents:UIControlEventEditingChanged];
    
    _nameLab = [[UILabel alloc] init];
    _nameLab.text = @"代币符号";
    _nameLab.textColor = SGColorFromRGB(0x8e92a3);
    _nameLab.textAlignment = NSTextAlignmentLeft;
    _nameLab.font = [UIFont systemFontOfSize:14.f];

    [self.view addSubview:_nameLab];
      //设置钱包名称
    CommonTextField *nameTextField = [[CommonTextField alloc] init];
    nameTextField.textColor = CMColorFromRGB(0x333649);
    nameTextField.placeholder = @"请输入代币符号";
    [nameTextField setValue:CMColorFromRGB(0x8E92A3) forKeyPath:@"placeholderLabel.textColor"];
    nameTextField.delegate = self;
    [self.view addSubview:nameTextField];
    self.nameTextField = nameTextField;
    [nameTextField setAttributedPlaceholderDefault];
    
    _accuracyLab = [[UILabel alloc] init];
    _accuracyLab.text = @"代币精度";
    _accuracyLab.textColor = SGColorFromRGB(0x8e92a3);
    _accuracyLab.textAlignment = NSTextAlignmentLeft;
    _accuracyLab.font = [UIFont systemFontOfSize:14.f];

    [self.view addSubview:_accuracyLab];
      //设置钱包名称
    CommonTextField *accuracyTextField = [[CommonTextField alloc] init];
    accuracyTextField.textColor = CMColorFromRGB(0x333649);
    accuracyTextField.placeholder = @"18";
    [accuracyTextField setValue:CMColorFromRGB(0x8E92A3) forKeyPath:@"placeholderLabel.textColor"];
    accuracyTextField.delegate = self;
    [self.view addSubview:accuracyTextField];
    self.accuracyTextField = accuracyTextField;
    [accuracyTextField setAttributedPlaceholderDefault];
    
    UIButton *confirBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [confirBtn setTitle:@"确定" forState:UIControlStateNormal];
    confirBtn.backgroundColor = CMColorFromRGB(0x7190FF);
    [confirBtn setTitleColor:CMColorFromRGB(0xFFFFFF) forState:UIControlStateNormal];
    confirBtn.titleLabel.font = [UIFont systemFontOfSize:17];
    confirBtn.layer.cornerRadius = 6.f;
    confirBtn.clipsToBounds = YES;
    [self.view addSubview:confirBtn];
    self.confirBtn = confirBtn;
    [confirBtn addTarget:self action:@selector(confirWalletAction:) forControlEvents:UIControlEventTouchUpInside];


    [_contractAddTextField setKeyBoardInputView:confirBtn action:@selector(confirWalletAction:)];
    [_nameTextField setKeyBoardInputView:confirBtn action:@selector(confirWalletAction:)];
    [_accuracyTextField setKeyBoardInputView:confirBtn action:@selector(confirWalletAction:)];
}


- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self.selectedChainBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(20);
        make.left.equalTo(self.view).offset(18);
        make.width.mas_equalTo(kScreenWidth - 34);
        make.height.mas_equalTo(44);
    }];
    
    
    [self.contractLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(18);
        make.height.mas_equalTo(20);
        make.top.equalTo(self.selectedChainBtn.mas_bottom).offset(21);
    }];

    [self.contractAddTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contractLab);
        make.right.equalTo(self.view).offset(-18);
        make.height.mas_equalTo(50);
        make.top.equalTo(self.contractLab.mas_bottom);
    }];
    
    [self.nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(18);
        make.height.mas_equalTo(20);
        make.top.equalTo(self.contractAddTextField.mas_bottom).offset(21);
    }];

    [self.nameTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contractAddTextField);
        make.height.mas_equalTo(50);
        make.top.equalTo(self.nameLab.mas_bottom);
    }];
    
    [self.accuracyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(18);
        make.height.mas_equalTo(20);
        make.top.equalTo(self.nameTextField.mas_bottom).offset(21);
    }];

    [self.accuracyTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contractAddTextField);
        make.height.mas_equalTo(50);
        make.top.equalTo(self.accuracyLab.mas_bottom);
    }];
    
   
    [self.confirBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.contractAddTextField);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(self.view).with.offset(- 31 - kIphoneXBottomOffset);
    }];
    
}


- (void)choiceChain:(id)sender
{
    
    NSArray *array = [[PWDataBaseManager shared]queryCoinArrayBasedOnSelectedWalletID];
    NSMutableArray *coinArr = [[NSMutableArray alloc] init];
    for (LocalCoin *coin in array) {
        if ([coin.coin_type isEqualToString:coin.coin_chain]) {
            [coinArr addObject:coin];
        }
    }
   PWActionSheetView *actionSheetView = [[PWActionSheetView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)
                                                                      Title:@"请选择主链"
                                                                       dataArray:coinArr
                                                                       type:ActionViewTypePrikey];
    actionSheetView.actionSheetViewBlock = ^(LocalCoin * _Nonnull coin, CoinPrice * _Nonnull coinprice) {
        self.chainStr = coin.coin_chain;
        [self.selectedChainBtn setTitle:[NSString stringWithFormat:@"主链:%@",coin.coin_chain] forState:UIControlStateNormal];
        
    };
    
    [actionSheetView show];
//    UIAlertController *vc = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
//    
//    UIAlertAction *
//    
//    
//    [self presentViewController:vc animated:true completion:nil];
    
    
}

- (void)confirWalletAction:(id)sender
{
    if (self.chainStr == nil || self.chainStr.length == 0) {
        [self showCustomMessage:@"请先选择主链" hideAfterDelay:2.f];
        return;
    }
    
    if (self.nameTextField.text == nil || self.nameTextField.text.length == 0) {
        [self showCustomMessage:@"请输入代币符号" hideAfterDelay:2.f];
        return;
    }
    [self showProgressWithMessage:@""];
    if ([self existCoin]) {
        [self showCustomMessage:@"该币种已添加" hideAfterDelay:2.f];
        return;
    }else{
        [self addcoinToWallet];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self hideProgress];
            if (self.contractBlock) {
                self.contractBlock();
            }
            [self showCustomMessage:@"添加成功" hideAfterDelay:1.f];
            [self.navigationController popViewControllerAnimated:true];
        });
    }
   
       
    
    
}

- (BOOL)existCoin{
    
    BOOL exist = NO;
    NSString *coinStr = self.nameTextField.text;
    NSString *chains = self.chainStr;
    NSString *contractAddr = self.contractAddTextField.text;
    
    NSArray *array = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    for (LocalCoin *coin in array) {
        // 存在了
        if ([coinStr isEqualToString:coin.coin_type] && [chains isEqualToString:coin.coin_chain] && [contractAddr isEqualToString:coin.coin_pubkey]) {
            exist = YES;
        }
    }
    
    
    return exist;
}

- (BOOL)addcoinToWallet
{
    NSString *coinStr = self.nameTextField.text;
    NSString *chains = self.chainStr;
    NSString *platStr = self.nameTextField.text;
    
    NSInteger treaty = 1;
    NSString *address = @"";
    NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    for (LocalCoin *coin in coinArray) {
        if ([coin.coin_chain isEqualToString:self.chainStr]) {
            address = coin.coin_address;
        }
    }
    //                CGFloat balance = [GoFunction goGetBalance:coinStr platform:platStr address:address andTreaty:treaty];
    LocalCoin *coin = [[LocalCoin alloc] init];
    LocalWallet *localWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    coin.coin_walletid = localWallet.wallet_id;
    coin.coin_type = coinStr;
    coin.coin_address = address;
    coin.coin_balance = 0;
    coin.coin_pubkey = self.contractAddTextField.text;// 合约地址
    coin.icon = @"";
    coin.coin_show = 1;
    coin.coin_platform = platStr;
    coin.coin_coinid = 0;
    coin.treaty = treaty;
    coin.coin_chain = chains;
    coin.coin_type_nft = 10;
    
    
    return [[PWDataBaseManager shared] addCoin:coin];
}

#pragma mark - UITextField Delegate
- (void)textFieldDidBeginEditing:(UITextField *)textField {

    CommonTextField *textF = (CommonTextField *)textField;
    textF.lineColor = CMColorFromRGB(0x7190FF);
    
    [textF setNeedsDisplay];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
    CommonTextField *textF = (CommonTextField *)textField;
    textF.lineColor = CMColorFromRGB(0x8E92A3);
    [textF setNeedsDisplay];
}



- (void)textFieldViewChanged:(UITextField *)textField
{
    CommonTextField *textF = (CommonTextField *)textField;
    NSLog(@"textf %@",textF.text);
    if (textF.tag == 101) {
        NSString *tokenAddr = self.contractAddTextField.text;
        NSString *chain = self.chainStr;
        if ([chain isEqualToString:@""] || chain == nil) {
            [self showCustomMessage:@"请先选择主链" hideAfterDelay:2.f];
            return;
        }
        
        [self getContractorInfoWithChain:chain tokenAddr:tokenAddr];
    }
    
}

- (void)getContractorInfoWithChain:(NSString *)coinType tokenAddr:(NSString *)tokenAddr
{
    
    [PWContractRequest getContractorInfowithCoinType:coinType
                                             address:@""
                                              execer:tokenAddr
                                             success:^(id  _Nonnull object) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"result %@",result);
        if (![result[@"result"] isKindOfClass:[NSNull class]]) {
            NSString *symbol = result[@"result"][@"symbol"];
            self.nameTextField.text = symbol;
            self.nameTextField.enabled = (symbol == nil || symbol.length == 0) ? YES : NO;
            NSString *decimals = [result[@"result"][@"decimals"] stringValue];
            self.accuracyTextField.text = decimals;
            self.accuracyTextField.enabled = (decimals == nil || decimals.length == 0) ? YES : NO;
        }else{
//            [self showCustomMessage:result[@"error"] hideAfterDelay:2.f];
        }
        
    } failure:^(NSString * _Nonnull errorMsg) {
        [self showCustomMessage:errorMsg hideAfterDelay:2.f];
    }];
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
