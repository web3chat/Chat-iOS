//
//  PWAlertController.m
//  PWAlert
//
//  Created by 陈健 on 2018/6/14.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "PWAlertController.h"
#import "SGNetwork.h"
#import "GameGoFunction.h"
#import "Depend.h"
#import "chat-Swift.h"
@interface PWAlertController ()<UITextFieldDelegate,UIGestureRecognizerDelegate>
/**title*/
@property (nonatomic,copy) NSString *topTitle;
/**leftButtonName*/
@property (nonatomic,copy) NSString *leftButtonName;
/**rightButtonName*/
@property (nonatomic,copy) NSString *rightButtonName;
/**textFiled中输入的字符串*/
@property (nonatomic,copy) NSString *text;
@property (nonatomic,weak) UITextField *textField;
/**handler*/
@property (nonatomic,copy) PWAlertControllerHandler handler;
@property (nonatomic, copy) PWAlertControllerExchangeHandler exchangeHandler;
@property (nonatomic,copy) NSString *defaultText;
/**灰色背景view*/
@property (nonatomic,weak) UIView *bgView;

/**白色背景view*/
@property (nonatomic,weak) UIView *whiteView;
// 去中心化交易所 手续费
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UILabel *moneyLab;
@property (nonatomic, strong) UILabel *realMoneyLab;
@property (nonatomic, strong) UILabel *speedLow;
@property (nonatomic, strong) UILabel *speedMid;
@property (nonatomic, strong) UILabel *speedHigh;
@property (nonatomic, strong) UIButton *showRound;
@property (nonatomic, strong) UIButton *showTipBtn;

@property (nonatomic, strong) SGSlider *slider;

@property (nonatomic,strong) UILabel *hLine;
@property (nonatomic, assign) double amount;
@property (nonatomic, assign) BOOL showSlider;
@property (nonatomic, strong) NSString *coinType;

@property (nonatomic, assign) double balance;
@end

@implementation PWAlertController

-(instancetype)initWithTitle:(NSString *)title withTextValue:(NSString *)text leftButtonName:(NSString *)leftButtonName rightButtonName:(NSString *)rightItemName handler:(PWAlertControllerHandler)handler {
    self = [super init];
    if (self) {
        _topTitle        = title;
        _leftButtonName  = leftButtonName;
        _rightButtonName = rightItemName;
        _handler         = handler;
        _defaultText     = text;
        [self initSubViews];
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title withTextValue:(NSString *)text rightButtonName:(NSString *)rightItemName coinType:(NSString *)coinType showSlider:(BOOL)showSlider amount:(double)amount handler:(PWAlertControllerExchangeHandler)exchaneHandler{
    
    self = [super init];
    if (self) {
        _topTitle        = title;
        _rightButtonName = rightItemName;
        _exchangeHandler = exchaneHandler;
        _defaultText     = text;
        _showSlider      = showSlider;
        _amount          = amount;
        _coinType        = coinType;
        if ([_coinType isEqualToString:@"ETH"]) {
            [self getBalanceWithType:_coinType];
        }
        [self initSubViews];
        [self requestFee];
        
    }
    
    return self;
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.modalPresentationStyle = UIModalPresentationCustom;
    [self initSubViews];

}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.whiteView.alpha = 1;
        self.whiteView.transform = CGAffineTransformMakeScale(1, 1);
    }];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![self.topTitle isEqualToString:@"手续费"]) {
        [self.textField becomeFirstResponder];
    }
}

- (void)getBalanceWithType:(NSString *)coinType
{
    WalletapiWalletBalance *walletbalance = [[WalletapiWalletBalance alloc] init];
    [walletbalance setCointype:coinType];
    [walletbalance setAddress:[GameGoFunction queryAddressByChain:coinType]];
    [walletbalance setTokenSymbol:@""];
    WalletapiUtil *util = [[WalletapiUtil alloc] init];
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    util.node = GoNodeUrl;
    [walletbalance setUtil:util];
    NSError *error;
    NSData *balanceData = WalletapiGetbalance(walletbalance, &error);
    
    if (balanceData == nil) {
        self.balance = 0.0;
    }
    
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:balanceData options:NSJSONReadingMutableLeaves error:nil];
  
    if ([jsonDict[@"result"] isEqual:[NSNull null]] || jsonDict[@"result"] == nil) {
        self.balance = 0.0;
    }
    NSDictionary *resultDict = jsonDict[@"result"];
   self.balance = [resultDict[@"balance"] doubleValue];
}

#pragma mark 网络请求
- (void)requestFee {
    
    NSDictionary *param = @{@"name":_coinType};
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodGET serverUrl:@"https://www.bitfeel.cn" apiPath:@"/goapi/interface/fees/recommended" parameters:param progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
         NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
         NSLog(@"%@",result[@"msg"]);
        NSInteger code = [result[@"code"] integerValue];
        if(code == 0) {
            NSDictionary *dict = (NSDictionary *)result[@"data"];
            Fee *feeModel = [Fee yy_modelWithJSON:dict];
            
            self.slider.minimumValue = feeModel.low;
            self.slider.maximumValue = feeModel.high;
            self.slider.value = feeModel.average;
            self.moneyLab.text = [NSString stringWithFormat:@"%.8f%@",self.slider.value,self.coinType];
            
        }else{
            
        }
    } failure:^(NSString * _Nullable errorMessage) {
        
    }];
}

#pragma mark - button点击
- (void)cancelBtnPress:(UIButton*)sender {
    [self.view endEditing:true];
    [self dismissViewControllerAnimated:false completion:^{
        if (self.closeVC) {
            self.closeVC();
        }
    }];
    
}

- (void)leftBtnPress:(UIButton*)sender {
    [self.view endEditing:true];
    if (self.handler) {
        [self dismissViewControllerAnimated:false completion:^{
            self.handler(ButtonTypeLeft, self.text);
        }];
    }
}
- (void)rightBtnPress:(UIButton*)sender {
    [self.view endEditing:true];
    if (self.handler) {
        [self dismissViewControllerAnimated:false completion:^{
            self.handler(ButtonTypeRight, self.text);
        }];
    }
    
    
    
    
    if (self.exchangeHandler) {
        if(self.showSlider)
        {
            double feeAndAm = self.amount + self.slider.value;
            if (self.balance < feeAndAm) {
                [self showCustomMessage:@"矿工费不足" hideAfterDelay:2.f];
                return;
            }
        }
        [self dismissViewControllerAnimated:false completion:^{
            self.exchangeHandler(ButtonTypeRight, self.text, self.slider.value);
        }];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    //收起键盘
    [self.view endEditing:true];
}

#pragma mark- textFaild 代理方法
- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.text = textField.text;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    
    if([self.topTitle isEqualToString:@"修改钱包名称"  ])
    {
        NSString *finalStr = [textField.text stringByAppendingString:string];
        if (finalStr.length > 8) {
            self.textField.text = [finalStr substringToIndex:8];
            return NO;
        }
    }
    
    if([self.topTitle isEqualToString:@"修改用户名"  ])
       {
           NSString *finalStr = [textField.text stringByAppendingString:string];
           if (finalStr.length > 12) {
               self.textField.text = [finalStr substringToIndex:12];
               return NO;
           }
       }
    
    
    if ([_coin.coin_chain isEqualToString:@"NEO"]) {
        NSMutableString *futureString = [NSMutableString stringWithString:textField.text];
        [futureString insertString:string atIndex:range.location];
        NSInteger flag = 0;
        const NSInteger limited = 0; // 限制小数位数
        for (int i =(int)(futureString.length -1); i>=0; i--) {
            if ([futureString characterAtIndex:i] == '.') {
                if (flag >limited) {
                    return NO;
                }
                break;
            }
            flag++;
        }
    }
    
    return YES;
}

- (void)setCoin:(LocalCoin *)coin
{
    _coin = coin;
}

#pragma mark - 初始化视图
- (void)initSubViews {
    
    for (UIView *view in _bgView.subviews) {
        [view removeFromSuperview];
    }
    //灰色view
    UIView *bgView = [[UIView alloc]initWithFrame:self.view.frame];
    bgView.backgroundColor = [[UIColor blackColor]colorWithAlphaComponent:0.6];
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(cancelBtnPress:)];
    recognizer.delegate = self;
    [bgView addGestureRecognizer:recognizer];
    [self.view addSubview:bgView];
    self.bgView = bgView;
   
    //白色Cover view
    UIView *whiteView = [[UIView alloc]init];
    [bgView addSubview:whiteView];
    self.whiteView = whiteView;
    whiteView.backgroundColor = [UIColor whiteColor];
    whiteView.layer.cornerRadius = 6;
    whiteView.layer.masksToBounds = true;
   
    
    UILabel *ftitleLab = [[UILabel alloc] init];
    ftitleLab.text = [NSString stringWithFormat:@"  %@",@"矿工费"  ];
    ftitleLab.textColor = CMColorFromRGB(0x333649);
    ftitleLab.font = [UIFont boldSystemFontOfSize:17];
    ftitleLab.textAlignment = NSTextAlignmentLeft;
    [whiteView addSubview:ftitleLab];
    
    
    UILabel *moneyLab = [[UILabel alloc] init];
    moneyLab.textAlignment = NSTextAlignmentRight;
    moneyLab.font = CMTextFont17;
    moneyLab.textColor = TextColor51;
    [whiteView addSubview:moneyLab];
    self.moneyLab = moneyLab;
    
    UILabel *realMoneyLab = [[UILabel alloc] init];
    realMoneyLab.textAlignment = NSTextAlignmentRight;
    realMoneyLab.font = CMTextFont12;
    realMoneyLab.text = [NSString stringWithFormat:@"0.00%@≈￥0.00",_coin.coin_type];
    realMoneyLab.textColor = SGColorFromRGB(0xda3866);
    [whiteView addSubview:realMoneyLab];
    self.realMoneyLab = realMoneyLab;
    self.realMoneyLab.hidden = YES;

    SGSlider *slider = [[SGSlider alloc] init];
    slider.minimumTrackTintColor = CMColorFromRGB(0x7190FF);
    slider.maximumTrackTintColor = CMColorFromRGB(0xC6D2FE);
    slider.thumbTintColor =[UIColor blackColor];
    [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateNormal];
    slider.continuous = NO;
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [whiteView addSubview:slider];
    self.slider = slider;
    if (isIPhoneXSeries) {
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateNormal];
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateHighlighted];
    }else{
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateNormal];
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateHighlighted];
    }
    
    UILabel *speedSlow = [[UILabel alloc] init];
    speedSlow.text = @"慢";
    speedSlow.font = CMTextFont13;
    speedSlow.textColor = CMColorFromRGB(0x8E92A3);
    speedSlow.textAlignment = NSTextAlignmentLeft;
    [whiteView addSubview:speedSlow];
    self.speedLow = speedSlow;
    
    UILabel *speedMid = [[UILabel alloc] init];
    speedMid.text = @"最佳";
    speedMid.font = CMTextFont13;
    speedMid.textColor = CMColorFromRGB(0x8E92A3);
    speedMid.textAlignment = NSTextAlignmentCenter;
    [whiteView addSubview:speedMid];
    self.speedMid = speedMid;
    
    UILabel *speedHigh = [[UILabel alloc] init];
    speedHigh.text = @"快";
    speedHigh.font = CMTextFont13;
    speedHigh.textColor = CMColorFromRGB(0x8E92A3);
    speedHigh.textAlignment = NSTextAlignmentRight;
    [whiteView addSubview:speedHigh];
    self.speedHigh = speedHigh;
    
    
    //title label
    UILabel *titleLab = [[UILabel alloc]init];
    [whiteView addSubview:titleLab];
    titleLab.text = self.topTitle;
    titleLab.font = [UIFont boldSystemFontOfSize:17];
    titleLab.textColor = SGColorRGBA(51, 54, 73, 1);
    
    //叉叉(取消)按钮
    UIButton *cancelBtn = [[UIButton alloc]init];
    [whiteView addSubview:cancelBtn];
    [cancelBtn setImage:[UIImage imageNamed:@"叉叉"] forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(cancelBtnPress:) forControlEvents:UIControlEventTouchUpInside];
   
    
    UIView *line = [[UIView alloc]init];
    line.backgroundColor = SGColorRGBA(113, 144, 255, 1);
    [whiteView addSubview:line];
    
    
    //输入框 textField
    UITextField *textField = [[UITextField alloc]init];
    [whiteView addSubview:textField];
    textField.delegate = self;
    textField.textColor = SGColorFromRGB(0x333649);
    textField.backgroundColor = SGColorRGBA(248, 248, 250, 1);
    textField.layer.borderWidth = 1;
    textField.layer.borderColor = [UIColor whiteColor].CGColor;
    textField.leftView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 8, 0)];
    textField.leftViewMode = UITextFieldViewModeAlways;
    textField.text = _defaultText;
  
    self.textField = textField;
    
    
    if ([_topTitle isEqualToString:@"请输入密聊密码"  ]) {
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.secureTextEntry = true;
        if (@available(iOS 11.0, *)) {
            textField.textContentType = UITextContentTypeName;
        }
    }
    else
    {
        if ([self.topTitle isEqualToString:@"请输入转币数量"  ])
        {
            textField.keyboardType = UIKeyboardTypeDecimalPad;
            textField.placeholder = @"请输入转币数量"  ;
        }
        else
        {
            textField.keyboardType = UIKeyboardTypeDefault;
        }
        
    }
    
    if (_showSlider) {
        ftitleLab.hidden = NO;
        self.moneyLab.hidden = NO;
        self.realMoneyLab.hidden = YES;
        self.slider.hidden = NO;
        self.speedLow.hidden = NO;
        self.speedHigh.hidden = NO;
        self.speedMid.hidden = NO;
        
        CGFloat whiteViewHeight = 306;
        [whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(whiteViewHeight);
            make.left.equalTo(bgView).offset(25);
            make.right.equalTo(bgView).offset(-25);
            make.centerY.equalTo(self.view).with.offset(-90);
        }];
        
        [ftitleLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(whiteView).with.offset(25);
            make.top.equalTo(whiteView).with.offset(15);
            make.height.mas_equalTo(13);
        }];
        
        [self.moneyLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(whiteView).with.offset(-60);
            make.centerY.equalTo(ftitleLab);
            make.left.equalTo(ftitleLab.mas_right);
            make.height.mas_equalTo(13);
        }];
        
        [self.realMoneyLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.moneyLab);
            make.top.equalTo(self.moneyLab.mas_bottom).offset(5);
            make.height.mas_equalTo(17);
        }];
        
        [self.slider mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(whiteView).with.offset(39);
            make.top.equalTo(whiteView).offset(60);
            make.right.equalTo(whiteView).with.offset(-39);
            make.height.mas_equalTo(16);
        }];
        
        [self.speedLow mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(17);
            make.top.equalTo(self.slider.mas_bottom).with.offset(15);
            make.left.equalTo(self.slider.mas_left).with.offset(0);
        }];
        
        [self.speedMid mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(17);
            make.top.equalTo(self.speedLow);
            make.centerX.equalTo(self.slider);
        }];
        
        [self.speedHigh mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(17);
            make.top.equalTo(self.speedLow);
            make.right.equalTo(self.slider.mas_right).with.offset(0);
        }];
        
        [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.speedLow.mas_bottom).offset(15);
            make.left.equalTo(whiteView).offset(25);
        }];
        
        [cancelBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.mas_equalTo(44);
            make.height.mas_equalTo(44);
            make.right.equalTo(whiteView).offset(-10);
            make.centerY.equalTo(ftitleLab);
        }];
        [line mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(titleLab);
            make.top.equalTo(titleLab.mas_bottom).offset(12);
            make.height.mas_equalTo(4);
            make.width.mas_equalTo(45);
        }];
        [textField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(line.mas_bottom).offset(20);
            make.left.equalTo(whiteView).offset(25);
            make.right.equalTo(whiteView).offset(-25);
            make.height.mas_equalTo(44);
        }];
    }else{
        ftitleLab.hidden = YES;
        self.moneyLab.hidden = YES;
        self.realMoneyLab.hidden = YES;
        self.slider.hidden = YES;
        self.speedLow.hidden = YES;
        self.speedHigh.hidden = YES;
        self.speedMid.hidden = YES;
        
        CGFloat whiteViewHeight = 196;
        [whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(whiteViewHeight);
            make.left.equalTo(bgView).offset(25);
            make.right.equalTo(bgView).offset(-25);
            make.centerY.equalTo(self.view).with.offset(-90);
        }];
        [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(whiteView).offset(15);
            make.left.equalTo(whiteView).offset(25);
        }];
        
        [cancelBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.mas_equalTo(44);
            make.height.mas_equalTo(44);
            make.right.equalTo(whiteView).offset(-10);
            make.centerY.equalTo(titleLab);
        }];
        [line mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(titleLab);
            make.top.equalTo(titleLab.mas_bottom).offset(12);
            make.height.mas_equalTo(4);
            make.width.mas_equalTo(45);
        }];
        [textField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(line.mas_bottom).offset(20);
            make.left.equalTo(whiteView).offset(25);
            make.right.equalTo(whiteView).offset(-25);
            make.height.mas_equalTo(44);
        }];
    }
    
    
    //left Button
    UIButton *leftBtn = [[UIButton alloc]init];
    [whiteView addSubview:leftBtn];
    [leftBtn setTitle:self.leftButtonName forState:UIControlStateNormal];
    leftBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    leftBtn.layer.cornerRadius = 6;
    leftBtn.layer.masksToBounds = true;
    leftBtn.layer.borderColor = SGColorRGBA(142, 146, 163, 1).CGColor;
    leftBtn.layer.borderWidth = 0.5;
    [leftBtn setBackgroundColor:[UIColor whiteColor]];
    [leftBtn setTitleColor:SGColorRGBA(142, 146, 163, 1) forState:UIControlStateNormal];
    [leftBtn addTarget:self action:@selector(leftBtnPress:) forControlEvents:UIControlEventTouchUpInside];
    [leftBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(120);
        make.height.mas_equalTo(40);
        make.bottom.equalTo(whiteView).offset(-18);
        make.left.equalTo(textField);
    }];

    //right Button
    UIButton *rightBtn = [[UIButton alloc]init];
    [whiteView addSubview:rightBtn];
    [rightBtn setTitle:self.rightButtonName forState:UIControlStateNormal];
    rightBtn.titleLabel.font = [UIFont systemFontOfSize:17];
    [rightBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [rightBtn setBackgroundColor:SGColorRGBA(113, 144, 255, 1)];
    rightBtn.layer.cornerRadius = 6;
    rightBtn.layer.masksToBounds = true;
    rightBtn.layer.borderColor = SGColorRGBA(113, 144, 255, 1).CGColor;
    rightBtn.layer.borderWidth = 0.5;
    [rightBtn addTarget:self action:@selector(rightBtnPress:) forControlEvents:UIControlEventTouchUpInside];
    [rightBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(leftBtn);
        make.height.equalTo(leftBtn);
        make.bottom.equalTo(leftBtn);
        make.right.equalTo(textField);
    }];
    
    
    
    if (IS_BLANK(self.rightButtonName)) {
        rightBtn.alpha = 0;
        [leftBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.mas_equalTo(120);
            make.height.mas_equalTo(40);
            make.bottom.equalTo(whiteView).offset(-18);
            make.centerX.equalTo(whiteView);
        }];
    }
    if (IS_BLANK(self.leftButtonName)) {
        leftBtn.alpha = 0;
        [rightBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(leftBtn);
            make.height.equalTo(leftBtn);
            make.bottom.equalTo(leftBtn);
            make.centerX.equalTo(whiteView);
        }];
    }
    
    
    self.whiteView.alpha = 0;
    self.whiteView.transform = CGAffineTransformMakeScale(0, 0);
    if ([self.topTitle isEqualToString:@"手续费"  ])
    {
        self.textField.hidden = YES;
        leftBtn.backgroundColor = SGColorRGBA(113, 144, 255, 1);
        [leftBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    }
    
}

- (void)sliderValueChanged:(UISlider *)sender
{
    NSString *sliderValue = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%.8f",sender.value]];
   self.moneyLab.text = [NSString stringWithFormat:@"%@%@",sliderValue,_coinType];
    
}

- (void)setFeeConfig:(FeeConfig *)feeConfig
{
    _feeConfig = feeConfig;
   
    NSString *coinName = self.defaultText;

    UILabel *textlab = [[UILabel alloc]init];
    [self.whiteView addSubview:textlab];
    textlab.font = [UIFont systemFontOfSize:15];
    textlab.numberOfLines = 0;
    textlab.textColor = SGColorRGBA(51, 54, 73, 1);
    textlab.textAlignment = NSTextAlignmentLeft;
    [textlab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.whiteView);
        make.left.equalTo(self.whiteView).offset(25);
        make.right.equalTo(self.whiteView).offset(-25);
    }];
    
    // 内部转账
    NSDecimalNumber *internalFee = [[NSDecimalNumber alloc] initWithDouble:self.feeConfig.internalFee];
    NSDecimalNumber *internalMinFee = [[NSDecimalNumber alloc] initWithDouble:self.feeConfig.internalMinFee];
    NSDecimalNumber *externalFee = [[NSDecimalNumber alloc] initWithDouble:self.feeConfig.externalFee];
    NSDecimalNumber *externalMinFee = [[NSDecimalNumber alloc] initWithDouble:self.feeConfig.externalMinFee];
    NSString *internalStr = [NSString stringWithFormat:@"内部转账:%@%@",internalFee,coinName];
    if (self.feeConfig.internalType == 2)
    {
        // 百分比
        
        NSString *coinMoneyStr = [NSString stringWithFormat:@"%.f%%",self.feeConfig.internalFee * 100];
        internalStr = [NSString stringWithFormat:@"内部转账:转账金额x%@,最低%@%@",coinMoneyStr,internalMinFee,coinName];
    }
    
    // 外部提币
    NSString *externalStr = [NSString stringWithFormat:@"外部提币:%@%@",externalFee,coinName];
    if (self.feeConfig.externalType == 2)
    {
        // 百分比
        NSString *coinMoneyStr = [NSString stringWithFormat:@"%.f%%",self.feeConfig.externalFee * 100];
        externalStr = [NSString stringWithFormat:@"外部提币:转账金额x%@,最低%@%@",coinMoneyStr,externalMinFee,coinName];
    }
    
    textlab.text = [NSString stringWithFormat:@"%@\n%@",internalStr,externalStr];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIGestureRecognizerDelegate
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    if (touch.view == self.bgView) {
        return YES;
    }
    return NO;
}
@end
