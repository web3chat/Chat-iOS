//
//  TradeDetailViewController.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/31.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "TradeDetailViewController.h"
#import "GoFunction.h"
#import "UIImage+Screenshot.h"
#import "NSString+CommonUseTool.h"
#import "PWAlertController.h"
#import "PWNewInfoAlertView.h"
#import "Depend.h"
#import "PWContractRequest.h"
@interface TradeDetailViewController ()
@property (nonatomic,strong) UIScrollView *scrollView;
@property (nonatomic,strong) UIView *midView;
@property (nonatomic,strong) UIImageView *stateImg;
@property (nonatomic,strong) UILabel *stateLab;
@property (nonatomic,strong) UILabel *timeValueLab;
@property (nonatomic,strong) UIView *line;
@property (nonatomic,strong) UIView *line2;
@property (nonatomic,strong) UILabel *timeLab;
@property (nonatomic,strong) UILabel *numValueLab;
@property (nonatomic,strong) UILabel *feeLab;
@property (nonatomic,strong) UILabel *feeValueLab;
@property (nonatomic,strong) UILabel *fromLab;
@property (nonatomic,strong) UILabel *fromValueLab;
@property (nonatomic,strong) UILabel *toLab;
@property (nonatomic,strong) UILabel *toValueLab;
@property (nonatomic,strong) UILabel *blockInfoLab;
@property (nonatomic,strong) UILabel *blockInfoValueLab;
@property (nonatomic,strong) UILabel *hashLab;
@property (nonatomic,strong) UILabel *hashValueLab;
@property (nonatomic,strong) UILabel *remarksLab;
@property (nonatomic,strong) UILabel  *remarksValueLab ;
@property (nonatomic,strong) UILabel *localRemarksLab;
@property (nonatomic,strong) UIButton *editLocalRemarksBtn;
@property (nonatomic,strong) UILabel *localRemarksValueLab ;
@property (nonatomic,strong) UIButton *addContactBtn;
@property (nonatomic, strong) UIImageView *cancelTradeImageView;
@property (nonatomic, strong) UIButton *cancelTradeBtn; // 撤销交易
@property (nonatomic, strong) UIImageView *quickenTradeImageView;
@property (nonatomic, strong) UIButton *qucikenTradeBtn; // 加速交易
@property (nonatomic,strong) UIButton *btnCopy1;
@property (nonatomic,strong) UIButton *btnCopy2;


/**区块链浏览器地址*/
@property (nonatomic,copy) NSString *brower;

@end

@implementation TradeDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    self.brower = @"";
    if (self.isPushedByNotification) {
        [self loadData];
    } else {
        [self createView];
        [self setViewValue];
    }
    
   

}


- (void)loadData {
    [self showProgressWithMessage:nil];
    WEAKSELF
    
    if (weakSelf.coin.coin_type_nft == 10) { // 合约币查交易详情

        [PWContractRequest queryTranscationByTxid:self.tradeHash
                                         coinType:self.coin.coin_chain
                                      tokenSymbol:[NSString stringWithFormat:@"%@.%@",[self.coin.coin_chain lowercaseString],self.coin.coin_pubkey]
                                          success:^(id  _Nonnull object) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:nil];
            NSLog(@"tx result is %@",result);
            if (![result[@"result"] isKindOfClass:[NSNull class]]) {
                self.orderModel = [[OrderModel alloc] initWithDic:result];
                dispatch_async(dispatch_get_main_queue(), ^{
                        [self createView];
                        [self setViewValue];
                        [self hideProgress];
                });
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showCustomMessage:@"网络请求失败"   hideAfterDelay:1];
                    [self.navigationController popViewControllerAnimated:true];
                });
            }
            
            
        } failure:^(NSString * _Nonnull errorMsg) {
            
        }];
        
    }else{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSDictionary *dic = [GoFunction queryTransactionByTxid:weakSelf.coin.coin_type
                                                          platform:weakSelf.coin.coin_platform
                                                              Txid:self.tradeHash
                                                         andTreaty:weakSelf.coin.treaty];
            self.orderModel = [[OrderModel alloc]initWithDic:dic];
    //        LocalCoin *coin = [[LocalCoin alloc]init];
    //        coin.coin_type = self.coinType;
    //        self.coin = coin;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (dic == nil) {
                    [self showCustomMessage:@"网络请求失败"   hideAfterDelay:1];
                } else {
                    [self createView];
                    [self setViewValue];
                    [self hideProgress];
                }
            });
        });
    }
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



- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateScrollViewContentSize];

}

- (void)createView
{
    UIScrollView *scrollView = [[UIScrollView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight - kTopOffset)];
    [self.view addSubview:scrollView];
    scrollView.backgroundColor = [UIColor whiteColor];
    self.scrollView = scrollView;
    
    UIView *midView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight - kTopOffset)];
    midView.backgroundColor = [UIColor whiteColor];
    [scrollView addSubview:midView];
    self.midView = midView;
    
    UIImageView *stateImg = [[UIImageView alloc] init];
    stateImg.layer.cornerRadius = 22;
    stateImg.layer.masksToBounds = YES;
    stateImg.backgroundColor = [UIColor whiteColor];
    [midView addSubview:stateImg];
    self.stateImg = stateImg;
    
    UILabel *numValueLab = [[UILabel alloc] init];
    numValueLab.textAlignment = NSTextAlignmentCenter;
    numValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    [midView addSubview:numValueLab];
    self.numValueLab = numValueLab;
    
    UILabel *stateLab = [[UILabel alloc] init];
    stateLab.textColor = TextColor51;
    stateLab.font = CMTextFont15;
    stateLab.textAlignment = NSTextAlignmentCenter;
    stateLab.text = @"确认中"  ;
    [midView addSubview:stateLab];
    self.stateLab = stateLab;
    
    UIView *line = [[UIView alloc]init];
    [midView addSubview:line];
    line.backgroundColor = SGColorFromRGB(0xECECEC);
    self.line = line;

    //转账地址
    UILabel *fromLab = [[UILabel alloc] init];
    NSString *title = @"转账地址"  ;
    fromLab.text = title;
    fromLab.textColor = SGColorRGBA(142, 146, 163, 1);
    fromLab.font = CMTextFont15;
    fromLab.textAlignment = NSTextAlignmentLeft;
    [midView addSubview:fromLab];
    self.fromLab = fromLab;
    
    UILabel *fromValueLab = [[UILabel alloc] init];
    fromValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    fromValueLab.font = CMTextFont15;
    fromValueLab.numberOfLines = 1;
    fromValueLab.textAlignment = NSTextAlignmentRight;
    fromValueLab.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [midView addSubview:fromValueLab];
    self.fromValueLab = fromValueLab;
    fromValueLab.userInteractionEnabled = YES;
    UITapGestureRecognizer *labelTapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(labelTouchUpInside:)];
    [fromValueLab addGestureRecognizer:labelTapGestureRecognizer];
    
    
    UIButton *copyBtn1 = [[UIButton alloc] init];
    [copyBtn1 setImage:[UIImage imageNamed:@"icon_copy"] forState:UIControlStateNormal];
    [midView addSubview:copyBtn1];
    self.btnCopy1 = copyBtn1;
    
    //收款地址
    UILabel *toLab = [[UILabel alloc] init];
    toLab.text = @"收款地址"  ;
    toLab.textColor = SGColorRGBA(142, 146, 163, 1);
    toLab.font = CMTextFont15;
    toLab.textAlignment = NSTextAlignmentLeft;
    [midView addSubview:toLab];
    self.toLab = toLab;
    
    UILabel *toValueLab = [[UILabel alloc] init];
    toValueLab.textAlignment = NSTextAlignmentRight;
    toValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    toValueLab.font = CMTextFont15;
    [midView addSubview:toValueLab];
    self.toValueLab = toValueLab;
    toValueLab.lineBreakMode = NSLineBreakByTruncatingMiddle;
    toValueLab.userInteractionEnabled = YES;
    UITapGestureRecognizer *labelTapGestureRecognizer1 = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(labelTouchUpInside:)];
    [toValueLab addGestureRecognizer:labelTapGestureRecognizer1];
    
    UIButton *copyBtn2 = [[UIButton alloc] init];
    [copyBtn2 setImage:[UIImage imageNamed:@"icon_copy"] forState:UIControlStateNormal];
    [midView addSubview:copyBtn2];
    self.btnCopy2 = copyBtn2;
    
    //矿工费
    UILabel *feeLab = [[UILabel alloc] init];
    feeLab.text = @"矿工费"  ;
    feeLab.textColor = SGColorRGBA(142, 146, 163, 1);
    feeLab.font = CMTextFont15;
    feeLab.textAlignment = NSTextAlignmentLeft;
    [midView addSubview:feeLab];
    feeLab.hidden = YES;
    self.feeLab = feeLab;
    
    UILabel *feeValueLab = [[UILabel alloc] init];
    feeValueLab.textAlignment = NSTextAlignmentRight;
    feeValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    feeValueLab.font = CMTextFont15;
    [midView addSubview:feeValueLab];
    feeValueLab.hidden = YES;
    self.feeValueLab = feeValueLab;
    
    UIView *line2 = [[UIView alloc]init];
    [midView addSubview:line2];
    line2.backgroundColor = SGColorFromRGB(0xECECEC);
    self.line2 = line2;
    
    //区块信息
    UILabel *blockInfoLab = [[UILabel alloc] init];
    blockInfoLab.text = @"区块信息"  ;
    blockInfoLab.textColor = SGColorRGBA(142, 146, 163, 1);
    blockInfoLab.font = CMTextFont15;
    blockInfoLab.textAlignment = NSTextAlignmentLeft;
    [midView addSubview:blockInfoLab];
    self.blockInfoLab = blockInfoLab;
    
    UILabel *blockInfoValueLab = [[UILabel alloc] init];
    blockInfoValueLab.textAlignment = NSTextAlignmentRight;
    blockInfoValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    blockInfoValueLab.font = CMTextFont15;
    [midView addSubview:blockInfoValueLab];
    self.blockInfoValueLab = blockInfoValueLab;
    
    //交易哈希
    UILabel *hashLab = [[UILabel alloc] init];
    hashLab.text = @"交易哈希"  ;
    hashLab.textColor = SGColorRGBA(142, 146, 163, 1);
    hashLab.font = CMTextFont15;
    hashLab.textAlignment = NSTextAlignmentLeft;
    [midView addSubview:hashLab];
    self.hashLab = hashLab;
    
    UILabel *hashValueLab = [[UILabel alloc] init];
    hashValueLab.textAlignment = NSTextAlignmentRight;
    hashValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    hashValueLab.font = CMTextFont15;
    hashValueLab.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [midView addSubview:hashValueLab];
    self.hashValueLab = hashValueLab;
    hashValueLab.userInteractionEnabled = YES;
    UITapGestureRecognizer *labelTapGestureRecognizer2 = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(queryHash)];
    [hashValueLab addGestureRecognizer:labelTapGestureRecognizer2];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(copyHash:)];
    [hashValueLab addGestureRecognizer:longPress];
    
    //交易时间
    UILabel *timeLab = [[UILabel alloc] init];
    timeLab.text = @"交易时间"  ;
    timeLab.textColor = SGColorRGBA(142, 146, 163, 1);
    timeLab.font = CMTextFont15;
    timeLab.textAlignment = NSTextAlignmentLeft;
    [midView addSubview:timeLab];
    self.timeLab = timeLab;
    
    UILabel *timeValueLab = [[UILabel alloc] init];
    timeValueLab.font = CMTextFont15;
    timeValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    timeValueLab.textAlignment = NSTextAlignmentRight;
    [midView addSubview:timeValueLab];
    self.timeValueLab = timeValueLab;
    
    //上链备注
    UILabel *remarksLab = [[UILabel alloc] init];
    remarksLab.text = @"上链备注"  ;
    remarksLab.textColor = SGColorRGBA(142, 146, 163, 1);
    remarksLab.font = CMTextFont15;
    remarksLab.textAlignment = NSTextAlignmentLeft;
    [midView addSubview:remarksLab];
    self.remarksLab = remarksLab;
    
    UILabel *remarksValueLab = [[UILabel alloc] init];
    remarksValueLab.text = IS_BLANK(self.orderModel.note) ? @"无"   : self.orderModel.note;
    remarksValueLab.textAlignment = NSTextAlignmentRight;
    remarksValueLab.textColor = SGColorRGBA(51, 54, 73, 1);
    remarksValueLab.font = CMTextFont15;
    remarksValueLab.numberOfLines = 0;
    [midView addSubview:remarksValueLab];
    self.remarksValueLab = remarksValueLab;
    if([_coin.coin_type isEqualToString:@"ZWGYBA"])
    {
        self.remarksValueLab.text = @"无"  ;
    }
   
    //添加联系人
    UIButton *addContactBtn = [[UIButton alloc] init];
    [addContactBtn setTitle:@"添加联系人"   forState:UIControlStateNormal];
    addContactBtn.titleLabel.font = CMTextFont15;
    addContactBtn.backgroundColor = SGColorRGBA(51, 54, 73, 1);
    addContactBtn.layer.cornerRadius = 6;
    addContactBtn.layer.masksToBounds = true;
//    [midView addSubview:addContactBtn];
    self.addContactBtn = addContactBtn;
//    [addContactBtn addTarget:self action:@selector(addFriendAction) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.cancelTradeBtn.hidden = YES;
    self.qucikenTradeBtn.hidden = YES;
    self.cancelTradeImageView.hidden = YES;
    self.quickenTradeImageView.hidden = YES;
    if ([_coin.coin_chain isEqualToString:@"ETH"]) {
        if ([self.orderModel.type isEqualToString:@"send"]) {
            if (self.orderModel.state == TransferFromStatusEnsureing) {
                self.cancelTradeBtn.hidden = NO;
                self.qucikenTradeBtn.hidden = NO;
                self.cancelTradeImageView.hidden = NO;
                self.quickenTradeImageView.hidden = NO;
                
                [self.quickenTradeImageView mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.right.equalTo(self.midView).offset(-19);
                    make.width.mas_equalTo(30);
                    make.height.mas_equalTo(27);
                    make.top.equalTo(self.midView).offset(22);
                }];
                [self.qucikenTradeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.right.equalTo(self.midView).offset(-14);
                    make.width.mas_equalTo(41);
                    make.height.mas_equalTo(14);
                    make.top.equalTo(self.quickenTradeImageView.mas_bottom).offset(4);
                }];
                [self.cancelTradeImageView mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.right.equalTo(self.midView).offset(-19);
                    make.width.mas_equalTo(30);
                    make.height.mas_equalTo(27);
                    make.top.equalTo(self.qucikenTradeBtn.mas_bottom).offset(15);
                }];
                [self.cancelTradeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.right.equalTo(self.midView).offset(-14);
                    make.width.mas_equalTo(41);
                    make.height.mas_equalTo(14);
                    make.top.equalTo(self.cancelTradeImageView.mas_bottom).offset(4);
                }];
            }
        }
    }
    
    [self.stateImg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(44);
        make.top.equalTo(self.midView).offset(10);
        make.centerX.equalTo(self.midView);
    }];
    
    [self.numValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.midView);
        make.top.equalTo(self.stateImg.mas_bottom).with.offset(15);
        make.height.mas_equalTo(37);
    }];

    
    [self.stateLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.midView);
        make.top.equalTo(self.numValueLab.mas_bottom).with.offset(9);
        make.height.mas_equalTo(21);
    }];
    
    [self.line mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.midView);
        make.height.mas_equalTo(1);
        make.top.equalTo(self.stateLab.mas_bottom).offset(9);
    }];
    
    
    [self.fromLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.midView).with.offset(16);
        make.height.mas_equalTo(21);
        make.width.mas_equalTo(120);
        make.top.equalTo(self.line.mas_bottom).offset(17);
    }];
    
    
    [self.fromValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.fromLab.mas_centerY);
        make.right.equalTo(self.midView).with.offset(-38);
    }];
    
    [self.btnCopy1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(12);
        make.height.mas_equalTo(14);
        make.right.equalTo(self.midView).with.offset(-16);
        make.centerY.equalTo(self.fromValueLab);
    }];
    
    
    [self.toLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.fromLab);
        make.height.equalTo(self.fromLab);
        make.width.mas_equalTo(self.fromLab);
        make.top.equalTo(self.fromLab.mas_bottom).offset(17);
    }];
    
    [self.toValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.toLab.mas_right).with.offset(50);
        make.centerY.equalTo(self.toLab);
        make.right.equalTo(self.fromValueLab);
    }];
    
    [self.btnCopy2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(self.btnCopy1);
        make.width.equalTo(self.btnCopy1);
        make.right.equalTo(self.btnCopy1);
        make.centerY.equalTo(self.toValueLab);
    }];
    
//    [self.feeLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(self.toLab);
//        make.height.equalTo(self.toLab);
//        make.top.equalTo(self.toLab.mas_bottom).offset(17);
//     }];
//        
//    [self.feeValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(self.toValueLab);
//        make.centerY.equalTo(self.feeLab);
//        make.right.equalTo(self.midView).offset(-16);
//        make.height.equalTo(self.toValueLab);
//    }];
   
    [self.line2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.toLab);
        make.right.equalTo(self.midView);
        make.height.mas_equalTo(1);
        make.top.equalTo(self.toLab.mas_bottom).offset(16);
    }];
    
    //区块信息
    [self.blockInfoLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.toLab);
        make.height.equalTo(self.toLab);
        make.width.equalTo(self.toLab);
        make.top.equalTo(self.line2.mas_bottom).offset(17);
    }];
    
    [self.blockInfoValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.toValueLab);
        make.centerY.equalTo(self.blockInfoLab);
        make.right.equalTo(self.toValueLab);
    }];
    
    //交易哈希
    [self.hashLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.blockInfoLab);
        make.height.equalTo(self.blockInfoLab);
        make.width.equalTo(self.blockInfoLab);
        make.top.equalTo(self.blockInfoLab.mas_bottom).with.offset(17);
    }];
    
    [self.hashValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.blockInfoValueLab);
        make.right.equalTo(self.blockInfoValueLab);
        make.centerY.equalTo(self.hashLab);
    }];
    
    //交易时间
    [self.timeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.hashLab);
        make.height.equalTo(self.hashLab);
        make.width.equalTo(self.hashLab);
        make.top.equalTo(self.hashLab.mas_bottom).with.offset(17);
    }];
    
    [self.timeValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.hashValueLab);
        make.centerY.equalTo(self.timeLab);
    }];
    
    CGRect rect = [self.remarksLab.text boundingRectWithSize:CGSizeMake(kScreenWidth - 100, MAXFLOAT)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15.f]}
                                                     context:nil];
    [self.remarksLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.timeLab);
        make.height.equalTo(self.timeLab);
        make.width.mas_equalTo(rect.size.width + 5);
        make.top.equalTo(self.timeLab.mas_bottom).with.offset(17);
    }];
    
    [self.remarksValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.hashValueLab);
        make.top.equalTo(self.remarksLab);
    }];
    
//    [self.localRemarksLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(self.remarksLab);
//        //接收方不显示本地备注
//        if (![self.orderModel.type isEqualToString:@"send"]) {
//            make.height.mas_equalTo(0);
//        } else {
//            make.width.equalTo(self.remarksLab);
//            make.height.equalTo(self.remarksLab);
//        }
//        make.top.equalTo(self.remarksValueLab.mas_bottom).with.offset(17);
//    }];
    
//    [self.editLocalRemarksBtn mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.right.equalTo(self.remarksValueLab).offset(15);
//        //接收方不显示本地备注
//        if (![self.orderModel.type isEqualToString:@"send"]) {
//            make.height.mas_equalTo(0);
//        } else {
//            make.width.height.mas_equalTo(44);
//        }
//        make.centerY.equalTo(self.localRemarksLab);
//    }];
//
//    [self.localRemarksValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(self.remarksValueLab);
//        make.right.equalTo(self.editLocalRemarksBtn.mas_left);
//        make.top.equalTo(self.localRemarksLab);
//        //接收方不显示本地备注
//        if (![self.orderModel.type isEqualToString:@"send"]) {
//            make.height.mas_equalTo(0);
//        }
//    }];
    
//    [self.addContactBtn mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(self.midView).offset(16);
//        make.right.equalTo(self.midView).offset(-16);
//        make.height.mas_equalTo(44);
//        make.top.equalTo(self.remarksValueLab.mas_bottom).offset(55);
//    }];
}

- (void)queryHash
{
    if ([self.brower isURL]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.brower] options:@{} completionHandler:nil];
    }
}

//长按复制hash
- (void)copyHash:(UILongPressGestureRecognizer*)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.hashValueLab.text;
        [self showCustomMessage:@"复制成功"   hideAfterDelay:2.0];
    }
}

- (void)updateScrollViewContentSize {
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width, kTopOffset + 387 + self.remarksValueLab.frame.size.height + self.localRemarksValueLab.frame.size.height + 100 + kIphoneXBottomOffset);
}

/**
 * 复制地址点击事件
 */
-(void)labelTouchUpInside:(UITapGestureRecognizer *)recognizer{
    
    UILabel *label=(UILabel*)recognizer.view;
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = label.text;
    [self showCustomMessage:@"复制成功"   hideAfterDelay:2.0];
}

- (void)setViewValue
{
    if (!IS_BLANK(self.orderModel.blockHash))
    {
        [self getBrower:self.coin.coin_type platform:self.coin.coin_platform];
    }
    
    
    self.title = [NSString stringWithFormat:@"%@%@",self.coin.optional_name,@"交易详情"  ];
    
    NSString *feeStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%f",_orderModel.fee]];
    
    //平行链币修改单位
    if (_coin.isBtyChild){
        
        if ([_coin.coin_platform isEqualToString:@"tschain"])
        {
            self.feeValueLab.text = @"0.005  TSC";
        }
        else if ([_coin.coin_platform isEqualToString:@"dagchain"])
        {
            self.feeValueLab.text =  @"0.1  DAG";
        }
        else if ([_coin.coin_platform isEqualToString:@"beechain"])
        {
            self.feeValueLab.text = @"0.001  BECC";
        }
        else if ([_coin.coin_platform isEqualToString:@"gbtchain"])
        {
            self.feeValueLab.text = @"0.1  GBT";
        }
        else if ([_coin.coin_platform isEqualToString:@"cpfchain"])
        {
            self.feeValueLab.text = @"1  CPF";
        }
        else if ([_coin.coin_platform isEqualToString:@"sakurachain"])
        {
            self.feeValueLab.text = @"0  SFT";
        }
        else if ([_coin.coin_platform isEqualToString:@"healthylifechain"])
        {
            self.feeValueLab.text = @"0.002 HL";
        }
        else if ([_coin.coin_platform isEqualToString:@"mbtcchain"])
        {
            self.feeValueLab.text = @"0.2 MBTC";
        }
        else if ([_coin.coin_platform isEqualToString:@"mcsschain"])
        {
            self.feeValueLab.text = @"0.01 MCSS";
        }
        else if ([_coin.coin_platform isEqualToString:@"bangbangchain"])
        {
            self.feeValueLab.text = @"0.001 BBH";
        }
        else if ([_coin.coin_platform isEqualToString:@"kchain"])
        {
            self.feeValueLab.text = @"0.5 KPC8";
        }

        
    }else{
        CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:_coin.coin_type platform:_coin.coin_platform andTreaty:_coin.treaty];
        if([_coin.coin_type isEqualToString:@"YCC"] || [_coin.coin_type isEqualToString:@"BTY"]){
            self.feeValueLab.text = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%@  %@", feeStr,_coin.coin_type]];
        }else{
            self.feeValueLab.text = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%@  %@", feeStr,coinPrice.coinprice_chain]];
        }
        
        // ybf的币特殊处理
        if([coinPrice.coinprice_chain isEqualToString:@"ETH"] && ![coinPrice.coinprice_platform isEqualToString:@"ethereum"]){
            // 当fee为0的时候，手续费扣的是YBF币本身。其他情况扣的是bty
            self.feeValueLab.text = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%@  %@", feeStr.floatValue == 0 ? @"0.5" : feeStr,feeStr.floatValue == 0 ? _coin.coin_type : @"BTY"]];
        }
    }
    
    [self getContactsWithAddress:_orderModel];
    NSTimeInterval interval    = [_orderModel.time doubleValue];
    NSDate *date               = [NSDate dateWithTimeIntervalSince1970:interval];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSString *dateString       = [formatter stringFromDate: date];
    self.timeValueLab.text = dateString;
    if ([_orderModel.time isEqual:@(0)]) {
        [self.timeValueLab setHidden:YES];
    }else
    {
        [self.timeValueLab setHidden:NO];
    }
    
    NSString *numStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%f",_orderModel.coinNum]];
    NSString *str;
    if ([_orderModel.type isEqualToString:@"send"]) {
        
        str = [NSString stringWithFormat:@"-%@%@",numStr,_coin.optional_name];
    } else {
        str = [NSString stringWithFormat:@"+%@%@",numStr,_coin.optional_name];
    }
    
    NSMutableAttributedString *attStr = [[NSMutableAttributedString alloc]initWithString:str];
    [attStr addAttributes:@{NSForegroundColorAttributeName:SGColorRGBA(51, 54, 73, 1),NSFontAttributeName:[UIFont boldSystemFontOfSize:32]} range:NSMakeRange(0, str.length)];
    [attStr addAttributes:@{NSForegroundColorAttributeName:SGColorRGBA(51, 54, 73, 1),NSFontAttributeName:[UIFont systemFontOfSize:32]} range:NSMakeRange(0, 1)];
    if (!IS_BLANK(_coin.optional_name)) {
         [attStr addAttributes:@{NSForegroundColorAttributeName:SGColorRGBA(51, 54, 73, 1),NSFontAttributeName:[UIFont boldSystemFontOfSize:16]} range:NSMakeRange(str.length - _coin.optional_name.length, _coin.optional_name.length)];
    }
    self.numValueLab.attributedText = attStr;
    
    if ([@"" isEqualToString:_orderModel.fromAddress]) {
        if ([_orderModel.category isEqualToString:@"unfreeze"] || [_orderModel.category isEqualToString:@"freeze"])
        {
            self.fromValueLab.text = self.orderModel.toAddress;
            [self.fromValueLab mas_updateConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.fromLab.mas_right).with.offset(50);
            }];
        }
        else
        {
            self.fromValueLab.text = self.orderModel.category_name;
        }
        
    }else{
        self.fromValueLab.text = _orderModel.fromAddress;
        [self.fromValueLab mas_updateConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.fromLab.mas_right).with.offset(50);
        }];
    }
    
    if ([@"" isEqualToString:_orderModel.toAddress]) {
        if ([_orderModel.category isEqualToString:@"unfreeze"] || [_orderModel.category isEqualToString:@"freeze"])
        {
            self.toValueLab.text = self.orderModel.fromAddress;
        }
        else
        {
            self.toValueLab.text = self.orderModel.category_name;
        }
       
    }else{
        self.toValueLab.text = _orderModel.toAddress;
    }
    
    self.blockInfoValueLab.text = [NSString stringWithFormat:@"%@",_orderModel.blockHeight];
   
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]initWithString:_orderModel.blockHash];
    [text addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(0, text.length)];
    text.yy_font = [UIFont systemFontOfSize:15];
    [text yy_setTextHighlightRange:NSMakeRange(0, text.length) color:SGColorRGBA(113, 144, 255, 1) backgroundColor:[UIColor whiteColor] userInfo:nil];
    self.hashValueLab.attributedText = text;
    
    self.hashLab.hidden = NO;
    self.hashValueLab.hidden = NO;
    self.addContactBtn.hidden = NO;
    [self updateScrollViewContentSize];
    
}

//获取区块链浏览器地址
- (void)getBrower:(NSString *)coinType platform:(NSString *)platstr{
//    NSString *chain = [[PWDataBaseManager shared]queryCoinPriceBasedOn:coinType].coinprice_platform;
    NSString *chain = platstr;
    if (IS_BLANK(chain)) {
        chain = @"";
    }
    chain = [chain isEqualToString:@"omni"] ? @"btc" : chain;
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodGET serverUrl:WalletURL apiPath:[NSString stringWithFormat:@"%@%@", TRADEGETBROWER,chain] parameters:@{} progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
        
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        NSInteger code = [result[@"code"] integerValue];
        if((code == 0) && (!IS_BLANK(result[@"data"]))) {
            self.brower =  [NSString stringWithFormat:@"%@%@",[result[@"data"] objectForKey:@"brower_url"],self.orderModel.blockHash];
        }
    } failure:^(NSString * _Nullable errorMessage) {
        
    }];
}
//UIScrollView截图
- (UIImage*)screenshot {
    UIScrollView *scrollView = self.scrollView;
    
    //记录用户点击分享时视图的偏移量、位置 数据
    CGRect savedFrame = scrollView.frame;
    NSAttributedString *attHash = self.hashValueLab.attributedText;
    self.hashValueLab.attributedText = nil;
    self.hashValueLab.text = self.orderModel.blockHash;
    
    //隐藏本地备注
    self.localRemarksLab.alpha = 0;
    self.localRemarksValueLab.alpha = 0;
    self.editLocalRemarksBtn.alpha = 0;
    BOOL need = false;
    if (self.addContactBtn.alpha == 1) {
        self.addContactBtn.alpha = 0;
        need = true;
    }
    //contentSize减去本地备注的高度和kTopOffset的高度 加上二维码的高度
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width,397 + self.remarksValueLab.frame.size.height + 218);
    
    UIImage* viewImage = nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(scrollView.contentSize.width, scrollView.contentSize.height), scrollView.opaque, 0.0);

    //把偏移量置为0 ，从顶部开始截图
    scrollView.contentOffset = CGPointZero;
    scrollView.frame = CGRectMake(0, 0, scrollView.contentSize.width, scrollView.contentSize.height);
    [scrollView.layer renderInContext:UIGraphicsGetCurrentContext()];
    viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //恢复
    self.localRemarksLab.alpha = 1;
    self.localRemarksValueLab.alpha = 1;
    self.editLocalRemarksBtn.alpha = 1;
    
    if (need) {
        self.addContactBtn.alpha = 1;
    }
    self.hashValueLab.attributedText = attHash;
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width, kTopOffset + 387 + self.remarksValueLab.frame.size.height + self.localRemarksValueLab.frame.size.height + 100 + kIphoneXBottomOffset);
    scrollView.frame = savedFrame;
    return viewImage;
}

#pragma mark - 根据地址查找联系人
- (void)getContactsWithAddress:(OrderModel *)orderModel
{
    if (orderModel.state == TransferFromStatusFailure) {
        self.stateLab.textColor = TipRedColor;
        self.stateLab.text = [@"交易失败"   stringByAppendingString:@""];
        [self.stateImg setImage:[UIImage imageNamed:@"tradeFailure"]];
    }else if(orderModel.state == TransferFromStatusEnsureing)
    {
        self.stateLab.textColor = MainColor;
        self.stateLab.text = [@"确认中"   stringByAppendingString:@""];
        [self.stateImg setImage:[UIImage imageNamed:@"icon_ensuring"]];
    }else if (orderModel.state == TransferFromStatusSuccess)
    {
        self.stateLab.textColor = PlaceHolderColor;
        self.stateLab.text = [@"交易成功"   stringByAppendingString:@""];
        [self.stateImg setImage:[UIImage imageNamed:@"icon_check"]];
    }
}


@end
