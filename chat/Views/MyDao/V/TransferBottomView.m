//
//  TransferBottomView.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/30.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "TransferBottomView.h"
#import "PWChoiceFeeSheetView.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface TransferBottomView()
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

@property (nonatomic, strong) UIView *choiceFeeView;
@property (nonatomic, strong) UILabel *detailLab;
@property (nonatomic, strong) UIButton *toBtn;
@property (nonatomic, strong) NSDictionary *selecetdFeeDict;

// 新的矿工费展示（链上 gas / 固定档位）
@property (nonatomic, assign) BOOL useNewFeeMode;
@property (nonatomic, copy) NSString *feeUnit;
@property (nonatomic, strong) NSArray *feeTiersDataArr;
@property (nonatomic, assign) NSInteger feeDefaultIndex;
@property (nonatomic, strong) UIImageView *feeArrow;

@end

@implementation TransferBottomView

- (void)setCoin:(LocalCoin *)coin {
    _coin = coin;
    // 新矿工费模式（链上/固定档）由 apply... 设置，这里不再覆盖
    if (self.useNewFeeMode) {
        return;
    }
    /// BTY 主链上的非 BTY 币种（如平行链代币）：隐藏滑动条场景下矿工费固定 0.001 BTY
    if (coin != nil && [coin.coin_chain isEqualToString:@"BTY"] && ![coin.coin_type isEqualToString:@"BTY"]) {
        [self setHiddenSlider:YES];
        if ([_coin.coin_type isEqualToString:@"PMM"]) {
            self.feeValue = 0.06;
            self.moneyLab.text = @"0.06 BTY";
        }else{
            self.feeValue = 0.001;
            self.moneyLab.text = @"0.001 BTY";
        }
    }
}

-(instancetype)init {
    self = [super init];
    if (self) {
        [self createView];
        
    }
    return self;
}

- (void)createView {
    
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = [NSString stringWithFormat:@"  %@",L(@"矿工费")];
    titleLab.textColor = CMColorFromRGB(0x333649);
    titleLab.font = [UIFont boldSystemFontOfSize:14];
    titleLab.textAlignment = NSTextAlignmentLeft;
    [self addSubview:titleLab];
    self.titleLab = titleLab;
    
    UILabel *moneyLab = [[UILabel alloc] init];
    moneyLab.textAlignment = NSTextAlignmentRight;
    moneyLab.font = CMTextFont14;
    moneyLab.text = @"0.00";
    moneyLab.textColor = TextColor51;
    [self addSubview:moneyLab];
    self.moneyLab = moneyLab;
    
    UILabel *realMoneyLab = [[UILabel alloc] init];
    realMoneyLab.textAlignment = NSTextAlignmentRight;
    realMoneyLab.font = CMTextFont12;
    realMoneyLab.text = @"0.00";
    realMoneyLab.textColor = SGColorFromRGB(0xda3866);
    [self addSubview:realMoneyLab];
    self.realMoneyLab = realMoneyLab;
    self.realMoneyLab.hidden = YES;

    SGSlider *slider = [[SGSlider alloc] init];
    slider.minimumTrackTintColor = CMColorFromRGB(0x7190FF);
    slider.maximumTrackTintColor = CMColorFromRGB(0xC6D2FE);
    slider.thumbTintColor =[UIColor blackColor];
    [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateNormal];
    slider.continuous = NO;
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:slider];
    self.slider = slider;
    if (isIPhoneXSeries) {
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateNormal];
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateHighlighted];
    }else{
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateNormal];
         [slider setThumbImage:[UIImage imageNamed:@"trade_slide"] forState:UIControlStateHighlighted];
    }
    
    UILabel *speedSlow = [[UILabel alloc] init];
    speedSlow.text = L(@"慢")  ;
    speedSlow.font = CMTextFont13;
    speedSlow.textColor = CMColorFromRGB(0x8E92A3);
    speedSlow.textAlignment = NSTextAlignmentLeft;
    [self addSubview:speedSlow];
    self.speedLow = speedSlow;
    
    UILabel *speedMid = [[UILabel alloc] init];
    speedMid.text = L(@"最佳")  ;
    speedMid.font = CMTextFont13;
    speedMid.textColor = CMColorFromRGB(0x8E92A3);
    speedMid.textAlignment = NSTextAlignmentCenter;
    [self addSubview:speedMid];
    self.speedMid = speedMid;
    
    UILabel *speedHigh = [[UILabel alloc] init];
    speedHigh.text = L(@"快")  ;
    speedHigh.font = CMTextFont13;
    speedHigh.textColor = CMColorFromRGB(0x8E92A3);
    speedHigh.textAlignment = NSTextAlignmentRight;
    [self addSubview:speedHigh];
    self.speedHigh = speedHigh;
    
    UILabel *hLine = [[UILabel alloc] init];
    hLine.backgroundColor = LineColor;
    [self addSubview:hLine];
    self.hLine = hLine;
    
    UIButton *tipBtn = [[UIButton alloc] init];
    [tipBtn setImage:[UIImage imageNamed:@"trade_message"] forState:UIControlStateNormal];
    tipBtn.contentMode = UIViewContentModeScaleAspectFit;
    [tipBtn addTarget:self action:@selector(showTi:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:tipBtn];
    
    self.showTipBtn = tipBtn;
    
    [self addSubview:self.choiceFeeView];
    [self.choiceFeeView addSubview:self.detailLab];
    [self.choiceFeeView addSubview:self.toBtn];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toChoiceFee)];
    [self.choiceFeeView addGestureRecognizer:tap];
    tap.numberOfTapsRequired = 1;
    self.choiceFeeView.userInteractionEnabled = YES;
    [self.toBtn addTarget:self action:@selector(toChoiceFee) forControlEvents:UIControlEventTouchUpInside];
    self.choiceFeeView.hidden = YES;

    // 新的矿工费模式：整行可点选（弹档位/手输面板）
    UITapGestureRecognizer *feeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(feeRowTapped)];
    [self addGestureRecognizer:feeTap];

    UIImageView *feeArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"accessory"]];
    feeArrow.contentMode = UIViewContentModeScaleAspectFit;
    feeArrow.hidden = YES;
    [self addSubview:feeArrow];
    self.feeArrow = feeArrow;
    
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(15);
        make.top.equalTo(self).with.offset(20);
        make.height.mas_equalTo(13);
    }];
    
    [self.moneyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self).with.offset(-40);
        make.centerY.equalTo(self.titleLab);
        make.left.equalTo(self.titleLab.mas_right);
        make.height.mas_equalTo(13);
    }];
    
    [self.realMoneyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.moneyLab);
        make.top.equalTo(self.moneyLab.mas_bottom).offset(5);
        make.height.mas_equalTo(17);
    }];
    
    [self.choiceFeeView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(15);
        make.right.equalTo(self).offset(-15);
        make.top.equalTo(self.titleLab.mas_bottom);
        make.height.mas_equalTo(40);
    }];
    
    [self.detailLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.choiceFeeView).offset(10);
        make.left.equalTo(self.choiceFeeView);
        make.right.equalTo(self.choiceFeeView).offset(-40);
    }];
    
    [self.toBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.choiceFeeView).offset(-10);
        make.width.height.mas_equalTo(20);
        make.top.equalTo(self.choiceFeeView).offset(10);
    }];
    
    [self.slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(39);
        make.centerY.equalTo(self);
        make.right.equalTo(self).with.offset(-39);
        make.height.mas_equalTo(16);
    }];
    
    [self.speedLow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(17);
        make.bottom.equalTo(self).with.offset(-15);
        make.left.equalTo(self.slider.mas_left).with.offset(0);
    }];
    
    [self.speedMid mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(17);
        make.bottom.equalTo(self).with.offset(-15);
        make.centerX.equalTo(self.slider);
    }];
    
    [self.speedHigh mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(17);
        make.bottom.equalTo(self).with.offset(-15);
        make.right.equalTo(self.slider.mas_right).with.offset(0);
    }];
    
    [self.hLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(15);
        make.right.equalTo(self).offset(-15);;
        make.height.mas_equalTo(0.5);
        make.bottom.equalTo(self.mas_bottom).with.offset(0);
    }];
    
    [self.showTipBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self).offset(-15);
        make.top.equalTo(self).offset(15);
        make.width.height.mas_equalTo(25);
    }];

    [self.feeArrow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(16);
        make.right.equalTo(self).offset(-16);
        make.centerY.equalTo(self.titleLab);
    }];

    self.moneyLab.hidden = NO;
    self.showTipBtn.hidden = YES;
    
    [self borderForView:self.titleLab color:CMColorFromRGB(0x7190FF) borderWidth:3];
}

- (UIView *)borderForView:(UIView *)originalView color:(UIColor *)color borderWidth:(CGFloat)borderWidth {
    
    /// 线的路径
    UIBezierPath * bezierPath = [UIBezierPath bezierPath];
    
    /// 左侧线路径
    [bezierPath moveToPoint:CGPointMake(0.0f, originalView.frame.size.height)];
    [bezierPath addLineToPoint:CGPointMake(0.0f, 0.0f)];
    
    CAShapeLayer * shapeLayer = [CAShapeLayer layer];
    shapeLayer.strokeColor = color.CGColor;
    shapeLayer.fillColor  = [UIColor clearColor].CGColor;
    /// 添加路径
    shapeLayer.path = bezierPath.CGPath;
    /// 线宽度
    shapeLayer.lineWidth = borderWidth;
    
    [originalView.layer addSublayer:shapeLayer];
    
    return originalView;
}


#pragma mark-
#pragma mark 类方法
- (void)roundSelectedAction:(UIButton *)sender
{
    CGFloat width = (SCREENBOUNDS.size.width - 30)/8;
    NSInteger tag = sender.tag;
    self.showRound.frame = CGRectMake(15 + tag * width - 10, 44 - 10, 20, 20);
}

- (void)showTi:(UIButton *)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(showTips:)]) {
        [self.delegate showTips:sender];
    }
}

- (void)setHiddenSlider:(BOOL)hiddenSlider {
    _hiddenSlider = hiddenSlider;
    
    if (hiddenSlider) {
        self.slider.hidden = YES;
        self.speedLow.hidden = YES;
        self.speedMid.hidden = YES;
        self.speedHigh.hidden = YES;
    }else{
        self.slider.hidden = NO;
        self.speedLow.hidden = NO;
        self.speedMid.hidden = NO;
        self.speedHigh.hidden = NO;
    }
}

- (void)setFeeModel:(Fee *)feeModel {
    // 新矿工费模式（链上/固定档）下忽略后台费率，避免覆盖已选费用
    if (self.useNewFeeMode) {
        return;
    }
    
    if(_hiddenSlider){
        /// BTY 主链 + 非 BTY 币种：矿工费固定 0.001（与接口返回无关）
        if ([_coin.coin_chain isEqualToString:@"BTY"] && ![_coin.coin_type isEqualToString:@"BTY"]) {
            if ([_coin.coin_type isEqualToString:@"PMM"]) {
                self.feeValue = 0.06;
                self.moneyLab.text = @"0.06 BTY";
            }else{
                self.feeValue = 0.001;
                self.moneyLab.text = @"0.001 BTY";
            }
           
            return;
        }
       
        if([_coin.coin_platform isEqualToString:@"Benefy"]){
            
            self.moneyLab.text = @"0.01";
            self.feeValue = 0.01;
        }else{
            if (_coin.treaty == 2
                && [_coin.coin_platform isEqualToString:self.coin.coin_platform])
            {
                NSString *numString = [NSString stringWithFormat:@"%lf", self.feeValue];
                self.moneyLab.text = [NSString stringWithFormat:@"%@  %@", [CommonFunction removeZeroFromMoney: numString],_coin.coin_type];
            }
            else
            {
                if (_coin.treaty == 1
                    && [_coin.coin_platform isEqualToString:self.coin.coin_platform]
                    && [self.coin isBtyChild])
                {
                    NSString *numString = [NSString stringWithFormat:@"%lf", self.feeValue];
                    self.moneyLab.text = [NSString stringWithFormat:@"%@  %@", [CommonFunction removeZeroFromMoney: numString],self.coin.coin_type];
                }
            }
        }
        return;
    }
    
    _feeModel = feeModel;
    self.slider.minimumValue = feeModel.low;
    self.slider.maximumValue = feeModel.high;
    self.slider.value = feeModel.average;
    
    NSString *coinMoneyStr = @"0";
    double feeValue = 0.00;
     
    self.realMoneyLab.hidden = YES;
    
    coinMoneyStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%.8f",self.slider.value]];
    feeValue = self.slider.value;
    if ([self.coin.coin_type isEqualToString:@"YCC"] && ([self.coin.coin_chain isEqualToString:@"ETH"] || [self.coin.coin_chain isEqualToString:@"BTC"])) {
       
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",coinMoneyStr,feeModel.name];
    }else if ([self.coin.coin_type isEqualToString:@"BTY"] && [self.coin.coin_chain isEqualToString:@"ETH"]){
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",coinMoneyStr,@"BTY"];
    }else if ([self.coin.coin_platform isEqualToString:@"Benefy"]){
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",coinMoneyStr,@"BTY"];
    }else{
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",coinMoneyStr,self.coin.coin_chain];
        
    }
    
    
}

- (void)sliderValueChanged:(UISlider *)sender
{
    NSString *sliderValue = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%.8f",sender.value]];
    
    if ([self.coin.coin_type isEqualToString:@"YCC"] && ([self.coin.coin_chain isEqualToString:@"ETH"] || [self.coin.coin_chain isEqualToString:@"BTC"])) {
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",sliderValue,self.feeModel.name];
    }else if ([self.coin.coin_type isEqualToString:@"BTY"] && [self.coin.coin_chain isEqualToString:@"ETH"]){
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",sliderValue,@"BTY"];
    }else if ([self.coin.coin_chain isEqualToString:@"ETH"] && [self.coin.coin_platform isEqualToString:@"yhchain"]){
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",sliderValue,@"BTY"];
    }
    else{
        self.moneyLab.text = [NSString stringWithFormat:@"%@%@",sliderValue,self.coin.coin_chain];
    }

}

- (CGFloat)getFee {
    
    NSString *feeValue = @"0";
    feeValue = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%.8f",self.slider.value]];

    if(_hiddenSlider){
        return _feeValue;
    }
    if (self.feeModel.type == 2) {
        return _feeValue;
    }
    
   
    return [feeValue doubleValue];
}

#pragma mark - gasprice
- (void)setGasPrice:(NSString *)gasPrice
{
    self.choiceFeeView.hidden = NO;
    // 只适配ETH和BNB
    double gasPr = [gasPrice doubleValue] / 1000000000.0;
    NSString *chain = self.coin.coin_chain;
    double lowGasPrice = gasPr * 1.5;
    double lowFee = lowGasPrice * 21000 / 1000000000.0;
    self.detailLab.text =  [NSString stringWithFormat:@"%.6f %@ = Gas(21000)*GasPrice(%.2f GWEI)",lowFee,chain,lowGasPrice];
    _feeValue = lowFee; // 默认最低
    self.moneyLab.text = [NSString stringWithFormat:@"%.6f",lowFee];
    self.hiddenSlider = YES;
    self.slider.hidden = YES;
    self.speedLow.hidden = YES;
    self.speedMid.hidden = YES;
    self.speedHigh.hidden = YES;
}

- (void)toChoiceFee
{
//    NSDictionary *dict = @{@"value":self.selectedFeeStr,
//                           @"gas":self.selectedGas,
//                           @"gasPrice":self.selectedGasPrice,
//                           @"index":@(self.selectedInx)};
    NSString *unit = self.feeUnit.length > 0 ? self.feeUnit : self.coin.coin_chain;
    PWChoiceFeeSheetView *choiceFeeView = nil;
    if (self.useNewFeeMode && self.feeTiersDataArr.count > 0) {
        NSDictionary *first = self.feeTiersDataArr.firstObject;
        choiceFeeView = [[PWChoiceFeeSheetView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)
                                                            dataArr:self.feeTiersDataArr
                                                           gasLimit:first[@"gas"]
                                                      selectedIndex:self.feeDefaultIndex];
    } else {
        choiceFeeView = [[PWChoiceFeeSheetView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight) withCoin:self.coin withDict:self.selecetdFeeDict];
    }
    choiceFeeView.choiceFeeBlock = ^(NSDictionary * _Nonnull dict) {
        self.selecetdFeeDict = dict;
        double feeNum = [dict[@"value"] doubleValue];
        self.feeValue = feeNum;
        self.moneyLab.text = [self feeStringWithValue:feeNum unit:unit];
        NSInteger idx = [dict[@"index"] integerValue];
        if (idx >= 0 && idx <= 3) {
            self.feeDefaultIndex = idx;
        }
    };
    
    [choiceFeeView show];
}

#pragma mark - 新的矿工费展示（链上 gas / 固定档位）

- (void)applyChainGasFeeWithGasPriceWei:(NSString *)gasPriceWei
                               gasLimit:(double)gasLimit
                                   unit:(NSString *)unit {
    double gpGwei = gasPriceWei.doubleValue / 1000000000.0;
    double fast = gasLimit * gpGwei * 3.0 / 1000000000.0;
    double nor  = gasLimit * gpGwei * 2.0 / 1000000000.0;
    double low  = gasLimit * gpGwei * 1.5 / 1000000000.0;
    NSString *gasStr = gasLimit > 0 ? [NSString stringWithFormat:@"%.0f", gasLimit] : @"";
    [self applyTiersFast:fast nor:nor low:low gasLimitStr:gasStr gasPriceGwei:gpGwei unit:unit defaultIndex:1 chainMode:YES];
}

- (void)applyFixedFeeTiers:(NSArray<NSString *> *)tiers
              defaultIndex:(NSInteger)defaultIndex
                      unit:(NSString *)unit {
    if (tiers.count < 3) {
        return;
    }
    if (defaultIndex < 0 || defaultIndex > 2) {
        defaultIndex = 2;
    }
    double fast = [tiers[0] doubleValue];
    double nor  = [tiers[1] doubleValue];
    double low  = [tiers[2] doubleValue];
    // 固定档位不是 gas 计算：自定义手输时的默认 Gas 用 21000
    [self applyTiersFast:fast nor:nor low:low gasLimitStr:@"21000" gasPriceGwei:0 unit:unit defaultIndex:defaultIndex chainMode:NO];
}

- (NSString *)feeStringWithValue:(double)value unit:(NSString *)unit {
    NSString *num = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%.8f", value]];
    return [NSString stringWithFormat:@"%@ %@", num, unit.length > 0 ? unit : @""];
}

- (void)applyTiersFast:(double)fast nor:(double)nor low:(double)low
           gasLimitStr:(NSString *)gasLimitStr
          gasPriceGwei:(double)gpGwei
                  unit:(NSString *)unit
          defaultIndex:(NSInteger)defaultIndex
             chainMode:(BOOL)chainMode {
    self.useNewFeeMode = YES;
    self.feeUnit = unit;

    NSArray *names = @[L(@"最快"), L(@"标准"), L(@"经济")];
    NSArray *values = @[[self feeStringWithValue:fast unit:unit],
                        [self feeStringWithValue:nor unit:unit],
                        [self feeStringWithValue:low unit:unit]];
    NSArray *nums = @[@(fast), @(nor), @(low)];

    NSMutableArray *arr = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        NSString *gasPriceStr = @"";
        NSString *detail = values[i];
        if (chainMode) {
            gasPriceStr = [NSString stringWithFormat:@"%.2f", gpGwei * (i == 0 ? 3.0 : (i == 1 ? 2.0 : 1.5))];
            detail = [NSString stringWithFormat:@"%@ = Gas(%@)*GasPrice(%@ GWEI)", values[i], gasLimitStr, gasPriceStr];
        }
        [arr addObject:@{@"name": names[i],
                         @"value": values[i],
                         @"detail": detail,
                         @"gas": gasLimitStr ?: @"",
                         @"gasPrice": gasPriceStr}];
    }
    [arr addObject:@{@"name": L(@"自定义"),
                     @"value": @"",
                     @"detail": @"",
                     @"gas": gasLimitStr ?: @"",
                     @"gasPrice": @""}];
    self.feeTiersDataArr = arr;
    self.feeDefaultIndex = defaultIndex;

    // 隐藏滑块、显示可点选箭头，并回填默认档费用
    [self setHiddenSlider:YES];
    self.feeArrow.hidden = NO;
    self.feeValue = [nums[defaultIndex] doubleValue];
    self.moneyLab.text = values[defaultIndex];
}

- (void)feeRowTapped {
    if (!self.useNewFeeMode) {
        return;
    }
    [self toChoiceFee];
}

- (void)resetFeeMode {
    self.useNewFeeMode = NO;
    self.feeArrow.hidden = YES;
    self.feeTiersDataArr = nil;
    self.feeUnit = nil;
    self.feeValue = 0;
}

#pragma mark ---getter

- (UIView *)choiceFeeView
{
    if (!_choiceFeeView) {
        _choiceFeeView = [[UIView alloc] init];
        _choiceFeeView.backgroundColor = UIColor.whiteColor;

    }
    
    return _choiceFeeView;
}

- (UILabel *)detailLab
{
    if (!_detailLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x8492a3);
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.numberOfLines = 0;
        _detailLab = lab;
    }
    return _detailLab;
}

- (UIButton *)toBtn
{
    if (!_toBtn) {
        UIButton *btn = [[UIButton alloc] init];
        [btn setImage:[UIImage imageNamed:@"accessory"] forState:UIControlStateNormal];
        
        _toBtn = btn;
    }
    
    return _toBtn;
}


@end

