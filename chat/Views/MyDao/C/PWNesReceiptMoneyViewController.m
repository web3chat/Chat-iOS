//
//  PWNesReceiptMoneyViewController.m
//  PWallet
//
//  Created by 郑晨 on 2019/12/3.
//  Copyright © 2019 陈健. All rights reserved.
//

#import "PWNesReceiptMoneyViewController.h"
#import "PWAlertController.h"
#import "Depend.h"
#import "chat-Swift.h"

@interface PWNesReceiptMoneyViewController ()

@property (nonatomic,strong)UIImageView *bottomBgImg;
@property (nonatomic,strong)UIImageView *backgroundImg;
@property (nonatomic,strong)UILabel *walletNameLab;
@property (nonatomic,strong)UILabel *balanceLab;
@property (nonatomic,strong)UIImageView *qrcodeImg;
@property (nonatomic,strong)UIView *addressView;
@property (nonatomic,strong)UILabel *addressLab;
@property (nonatomic,strong)UIButton *eyeBtn;
@property (nonatomic,strong)dispatch_source_t timer;
@property (nonatomic, strong) UIButton *universalBtn; // 通用
@property (nonatomic, strong) UIButton *exclusiveBtn; // 专属
@property (nonatomic, strong) UILabel *tipLab; //提示语
@property (nonatomic, strong) UILabel *moneyLab; // 转入金额
@property (nonatomic, strong) UIButton *moneyBtn; // 指定金额
@property (nonatomic, strong) NSString *moneyStr;// 金额
@property (nonatomic, strong) NSString *shareURL;
@property (nonatomic, strong) NSString *qrAddressStr;


@end

@implementation PWNesReceiptMoneyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _moneyStr = @"0";
    _receiptQrcodeType = ReceiptQrcodeTypeUniseral;
    [self createView];

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = true;
    self.showMaskLine= NO;
//    [self openGCDBalance];
//    if (@available(iOS 13.0, *)) {
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
//    } else {
//        // Fallback on earlier versions
//        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
//    }

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
   
     self.navigationController.navigationBar.hidden = false;
//     [self stopGCDBalance];
}


- (void)createView{
    
    //背景
    UIImageView *bgView = [[UIImageView alloc]initWithImage:[CommonFunction createImageWithColor:SGColorFromRGB(0xEBAE44)]];
    [self.view addSubview:bgView];
    [bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    
    //返回箭头
    UIButton* backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:backBtn];
    [backBtn setImage:[UIImage imageNamed:@"backArrow"] forState:UIControlStateNormal];
    [backBtn setTitle:@"    " forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    [backBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(kTopOffset);
        make.left.equalTo(self.view).offset(16);
    }];
    
    //titleLabel
    UILabel *titleLabel = [[UILabel alloc]init];
    [self.view addSubview:titleLabel];
    titleLabel.textColor = SGColorFromRGB(0x333649);
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = @"二维码收款";
    
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(backBtn);
        make.centerX.equalTo(self.view);
        make.height.mas_equalTo(backBtn);
    }];

    //背景
    UIImageView *backgroundImg = [[UIImageView alloc] init];
    [backgroundImg setImage:[UIImage imageNamed:@"new_grcode_bg"]];
    backgroundImg.contentMode = UIViewContentModeScaleAspectFit;

    [self.view addSubview:backgroundImg];
    self.backgroundImg = backgroundImg;
    
    
    UILabel *moneyLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:22]
                                      textColor:SGColorFromRGB(0x333649)
                                  textAlignment:NSTextAlignmentCenter
                                           text:@"扫二维码向我转账"];
    [self.view addSubview:moneyLab];
    self.moneyLab = moneyLab;
    
    UIButton *moneyBtn = [[UIButton alloc] init];
    [moneyBtn setTitle:@"指定金额" forState:UIControlStateNormal];
    [moneyBtn addTarget:self action:@selector(inputMoney:) forControlEvents:UIControlEventTouchUpInside];
    [moneyBtn setTitleColor:SGColorFromRGB(0x7190ff) forState:UIControlStateNormal];
    [moneyBtn.titleLabel setFont:[UIFont systemFontOfSize:12.f]];
    [moneyBtn.layer setBorderColor:SGColorFromRGB(0x7190ff).CGColor];
    [moneyBtn.layer setCornerRadius:12.f];
    [moneyBtn.layer setBorderWidth:.5f];
    [self.view addSubview:moneyBtn];
    self.moneyBtn = moneyBtn;
    self.moneyBtn.hidden = true;
    

    LocalWallet *wallet = [[PWDataBaseManager shared] queryWallet:_coin.coin_walletid];
    UILabel *walletNameLab = [[UILabel alloc] init];
    walletNameLab.textColor = SGColorFromRGB(0x333649);
    walletNameLab.font = CMTextFont14;
    walletNameLab.textAlignment = NSTextAlignmentCenter;
    walletNameLab.text = wallet.wallet_name;
    [self.view addSubview:walletNameLab];
    self.walletNameLab = walletNameLab;
    self.walletNameLab.hidden = YES;
    
    NSString *balanceStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%f",_coin.coin_balance]];
    UILabel *balanceLab = [[UILabel alloc] init];
    balanceLab.text = [NSString stringWithFormat:@"%@：%@%@",@"余额",balanceStr,_coin.optional_name];
    balanceLab.textColor = SGColorRGBA(142, 146, 163, 1);
    balanceLab.font = CMTextFont14;
    balanceLab.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:balanceLab];
    self.balanceLab = balanceLab;
    self.balanceLab.hidden = YES;

    UIButton *eyeBtn = [[UIButton alloc] init];
    [eyeBtn setImage:[UIImage imageNamed:@"显示"] forState:UIControlStateNormal];
    [eyeBtn setImage:[UIImage imageNamed:@"隐藏"] forState:UIControlStateSelected];
    [self.view addSubview:eyeBtn];
    self.eyeBtn = eyeBtn;
    self.eyeBtn.hidden = YES;
    [eyeBtn addTarget:self action:@selector(eyeBtnClickAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIImageView *qrcodeImg = [[UIImageView alloc] init];
    qrcodeImg.backgroundColor = [UIColor grayColor];
    [self.view addSubview:qrcodeImg];
    self.qrcodeImg = qrcodeImg;
    qrcodeImg.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyAddressAction)];
    UIImageView *tempImageView = [[UIImageView alloc]init];

    [tempImageView sd_setImageWithURL:[NSURL URLWithString:_coin.icon]];

    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *targetStr = [tool getSessionId];
    NSString *platform = _coin.coin_platform;
    NSString *coinType = _coin.coin_type;
    if ([coinType isEqualToString:@"BTY"]) {
        platform = @"bty";
    }
    
    NSString *qrcodeStr = [NSString stringWithFormat:@"%@?transfer_target=%@&address=%@&chain=%@&platform=%@",@"https://3syxin.com/",targetStr,_coin.coin_address,coinType,platform];

    [qrcodeImg setImage:[CommonFunction createImgQRCodeWithString:qrcodeStr centerImage:[UIImage imageNamed:@"avatar_persion"]]];
    
    [qrcodeImg addGestureRecognizer:singleTap];
    

    UIView *addressView = [[UIView alloc] init];
    addressView.backgroundColor = CMColor(246, 248, 250);
    [self.view addSubview:addressView];
    self.addressView = addressView;
    
    UILabel *addressLab = [[UILabel alloc] init];
    addressLab.text = IS_BLANK(_coin.coin_address) ? @"" : [NSString stringWithFormat:@"%@   ",_coin.coin_address];
    _qrAddressStr = _coin.coin_address;
    addressLab.numberOfLines = 0;
    addressLab.font = CMTextFont16;
    addressLab.textColor = CMColor(102,102, 102);
    addressLab.textAlignment = NSTextAlignmentLeft;
    if (addressLab.text.length != 0) {
        NSMutableAttributedString *resultAttr1 = [[NSMutableAttributedString alloc] initWithString:addressLab.text];
        //    resultAttr1.yy_lineSpacing = 3;
        if (addressLab.text.length > 4) {
            [resultAttr1 addAttributes:@{NSForegroundColorAttributeName:SGColorFromRGB(0x7190ff)} range:NSMakeRange(addressLab.text.length - 7, 4)];
        }
        
        UIImage *img = [UIImage imageNamed:@"copy_add"];
        NSTextAttachment *attach = [[NSTextAttachment alloc] init];
        attach.image = img;
        attach.bounds = CGRectMake(0, 0, 12, 14);
        NSAttributedString *imageStr = [NSAttributedString attributedStringWithAttachment:attach];
        [resultAttr1 appendAttributedString:imageStr];
        addressLab.attributedText = resultAttr1;
    }
   
    addressLab.userInteractionEnabled = YES;
    [self.view addSubview:addressLab];
    
    self.addressLab = addressLab;
    
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(copyAddressAction)];
    [addressLab addGestureRecognizer:gesture];

    [self.bottomBgImg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(0);
    }];
    
    CGFloat topSpace = kTopOffset + 120;
    if (isIPhone5) {
        topSpace = kTopOffset + 90;
    }
    self.universalBtn.hidden = NO;
    self.exclusiveBtn.hidden = NO;
    self.tipLab.hidden = NO;

    [self.backgroundImg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).with.offset(22);
        make.right.equalTo(self.view).with.offset(-21);
        make.top.equalTo(self.view).offset(topSpace);
        make.height.mas_equalTo(440 * kScreenRatio);
    }];
    
    [self.moneyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.backgroundImg).offset(12);
        make.right.equalTo(self.backgroundImg).offset(-12);
        make.top.equalTo(self.backgroundImg).offset(25);
        make.height.mas_equalTo(30);
    }];
    
    [self.moneyBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.backgroundImg);
        make.height.mas_equalTo(24);
        make.width.mas_equalTo(60);
        
        make.top.equalTo(self.moneyLab.mas_bottom).offset(3);
    }];
    
    CGFloat imgWidth = 200 * kScreenRatio;
    [self.qrcodeImg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.backgroundImg);
        make.top.equalTo(self.moneyBtn.mas_bottom).with.offset(17);
        make.width.height.mas_equalTo(imgWidth);
    }];
    
    [self.walletNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.backgroundImg);
        make.top.equalTo(self.qrcodeImg.mas_bottom).offset(13);
        make.height.mas_equalTo(20);
    }];
    
    [self.balanceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.height.mas_equalTo(20);
        make.top.equalTo(self.walletNameLab.mas_bottom).with.offset(6);
    }];
    [self.eyeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.balanceLab.mas_centerY);
        make.left.equalTo(self.balanceLab.mas_right).with.offset(8);
        make.width.height.mas_equalTo(40);
    }];
    
    [self.addressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(50);
        make.left.equalTo(self.backgroundImg).offset(12);
        make.top.equalTo(self.balanceLab.mas_bottom).with.offset(6);
        make.right.equalTo(self.backgroundImg).offset(-12);
    }];
    
    [self.addressLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(250 * kScreenRatio);
        make.height.mas_equalTo(50 * kScreenRatio);
        make.centerX.equalTo(self.addressView.mas_centerX);
        make.centerY.equalTo(self.addressView.mas_centerY);
    }];
    switch (_receiptQrcodeType) {
        case ReceiptQrcodeTypeUniseral:
        {
           
            [self.universalBtn setBackgroundColor:SGColorFromRGB(0xffffff)];
            [self.universalBtn setTitleColor:SGColorFromRGB(0x333649) forState:UIControlStateNormal];
            [self.exclusiveBtn setBackgroundColor:UIColor.clearColor];
            [self.exclusiveBtn setTitleColor:SGColorFromRGB(0xffffff) forState:UIControlStateNormal];
            
        }
            break;
        case ReceiptQrcodeTypeExclusive:
        {
            
            [self.exclusiveBtn setBackgroundColor:SGColorFromRGB(0xffffff)];
            [self.exclusiveBtn setTitleColor:SGColorFromRGB(0x333649) forState:UIControlStateNormal];
            [self.universalBtn setBackgroundColor:UIColor.clearColor];
            [self.universalBtn setTitleColor:SGColorFromRGB(0xffffff) forState:UIControlStateNormal];
        }
            break;
        default:
            break;
    }
    
}//轧槽任  啥扑阻  既驻晒  见沈牛  然债章

#pragma mark - 通用和专属切换
- (void)changeType:(UIButton *)sender
{
    switch (sender.tag) {
        case 100:
        {
            _receiptQrcodeType = ReceiptQrcodeTypeUniseral;
            self.tipLab.text = @"适用于所有钱包收款";
            [self.tipLab mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view).offset(87);
                make.width.mas_equalTo(115);
                
                make.top.equalTo(self.universalBtn.mas_bottom).offset(5);
                make.height.mas_equalTo(17);
            }];
        
        
            
            UIImageView *tempImageView = [[UIImageView alloc]init];
            [tempImageView sd_setImageWithURL:[NSURL URLWithString:_coin.icon]];

            _qrAddressStr = _coin.coin_address;
            [self.qrcodeImg setImage:[CommonFunction createImgQRCodeWithString:_coin.coin_address centerImage:tempImageView.image]];
            
        }
            break;
        case 200:
        {
             _receiptQrcodeType = ReceiptQrcodeTypeExclusive;
            CGSize size = [[NSString stringWithFormat:@"仅适用于%@收款",@""] sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:12.f],NSFontAttributeName,nil]];
            self.tipLab.text = [NSString stringWithFormat:@"仅适用于%@收款",@""];
            [self.tipLab mas_remakeConstraints:^(MASConstraintMaker *make) {

                make.width.mas_equalTo(size.width+15);
                make.centerX.equalTo(self.exclusiveBtn.mas_centerX).offset(7);
                make.top.equalTo(self.exclusiveBtn.mas_bottom).offset(5);
                make.height.mas_equalTo(17);
            }];
           
            UIImageView *tempImageView = [[UIImageView alloc]init];
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:_coin.coin_type platform:_coin.coin_platform andTreaty:_coin.treaty];
            [tempImageView sd_setImageWithURL:[NSURL URLWithString:_coin.icon]];

            NSString *qrStr = [NSString stringWithFormat:@"%li,%@,%@",coinPrice.coinprice_id,_moneyStr,_coin.coin_address];
            _qrAddressStr = qrStr;
            [self.qrcodeImg setImage:[CommonFunction createImgQRCodeWithString:qrStr centerImage:tempImageView.image]];
        }
            break;
        default:
            break;
    }
}
#pragma mark - 输入指定金额
- (void)inputMoney:(UIButton *)sender
{
    WEAKSELF
    PWAlertController *alertVC = [[PWAlertController alloc] initWithTitle:@"请输入转币数量" withTextValue:@""  leftButtonName:nil rightButtonName:@"确定"   handler:^(ButtonType type, NSString *text) {
        if (type == ButtonTypeRight) {
            weakSelf.moneyStr = text;
            if ([weakSelf.coin.coin_chain isEqualToString:@"NEO"]) {
                weakSelf.moneyStr = [text stringByReplacingOccurrencesOfString:@"." withString:@""];
            }
            
            weakSelf.moneyLab.text = [NSString stringWithFormat:@"%@ %@ %@",@"指定收款",weakSelf.moneyStr,weakSelf.coin.optional_name];

            CGRect moneyLabRect = [weakSelf.moneyLab.text boundingRectWithSize:CGSizeMake(kScreenWidth - 45 - 24, MAXFLOAT)
                                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                                    attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:22]}
                                                                       context:nil];
            if (moneyLabRect.size.height > 30) {
                self.moneyLab.numberOfLines = 0;
                [self.moneyLab mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.equalTo(self.backgroundImg).offset(5);
                    make.height.mas_equalTo(60);
                }];
            }
            
            
            [weakSelf.moneyBtn setTitle:@"修改金额"   forState:UIControlStateNormal];
            
            CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:weakSelf.coin.coin_type platform:weakSelf.coin.coin_platform andTreaty:weakSelf.coin.treaty];
            UIImageView *tempImageView = [[UIImageView alloc]init];
            [tempImageView sd_setImageWithURL:[NSURL URLWithString:weakSelf.coin.icon]];
            NSString *qrStr = nil;
            switch (weakSelf.receiptQrcodeType) {
                case ReceiptQrcodeTypeUniseral:
                {
                    if (weakSelf.moneyStr.floatValue == 0)
                    {
                        qrStr = [NSString stringWithFormat:@"%@",weakSelf.coin.coin_address];
                    }
                    else
                    {
                        qrStr = [NSString stringWithFormat:@"%@,%@",weakSelf.moneyStr,weakSelf.coin.coin_address];
                    }
                    
                }
                    
                    break;
                case ReceiptQrcodeTypeExclusive:
                {
                    qrStr = [NSString stringWithFormat:@"%li,%@,%@",(long)coinPrice.coinprice_id,weakSelf.moneyStr,weakSelf.coin.coin_address];
                }
                    break;
                default:
                    break;
            }
            weakSelf.qrAddressStr = qrStr;
            [self.qrcodeImg setImage:[CommonFunction createImgQRCodeWithString:qrStr centerImage:tempImageView.image]];
        }
        
    }];
    alertVC.coin = self.coin;
    alertVC.view.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    [self presentViewController:alertVC animated:false completion:nil];
}

/**
 * 复制地址
 */
- (void)copyAddressAction
{
    if (IS_BLANK(self.addressLab.text)) {
        return;
    }
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = _coin.coin_address;
    [self showCustomMessage:@"复制成功"   hideAfterDelay:2.0];
}

- (void)backAction
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)eyeBtnClickAction:(UIButton *)sender
{
    if([sender isSelected])
    {
        NSString *balanceStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%f",_coin.coin_balance]];
        [sender setSelected:NO];
        self.balanceLab.text = [NSString stringWithFormat:@"%@：%@%@",@"余额"  ,balanceStr,_coin.optional_name];
    }else{
        [sender setSelected:YES];
        self.balanceLab.text = [NSString stringWithFormat:@"%@：****%@",@"余额"  ,_coin.optional_name];
        self.balanceLab.text = [NSString stringWithFormat:@"%@：****%@",@"余额"  ,_coin.optional_name];
        
    }
    CGSize size = [self.balanceLab.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:self.balanceLab.font,NSFontAttributeName,nil]];
    [self.balanceLab mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(size.width + 10);
    }];
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
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (![weakSelf.eyeBtn isSelected]) {
                CGFloat balance = [GoFunction goGetBalance:weakSelf.coin.coin_type platform:weakSelf.coin.coin_platform address:weakSelf.coin.coin_address andTreaty:weakSelf.coin.treaty];
                if (balance != -1)
                {
                    NSString *balanceStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%f",balance]];
                    weakSelf.balanceLab.text = [NSString stringWithFormat:@"%@：%@%@",@"余额"  ,balanceStr,weakSelf.coin.optional_name];
                }
            }
            
        });
       

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


@end
