//
//  TransferTopView.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "TransferTopView.h"
#import "YYUnitTextField.h"
#import "Depend.h"
@interface TransferTopView()<UITextFieldDelegate>
@property (nonatomic,strong) UILabel *titleLab;
@property (nonatomic,strong) UILabel *balanceLab;

@property (nonatomic, strong) YYUnitTextField *rmbUnitView;
@property (nonatomic,strong) UILabel *hLine;
@property (nonatomic, strong) UILabel *symbolLab;

@property (nonatomic, strong) UIButton *showMoreNFTIDBtn;

@end

@implementation TransferTopView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self createView];
    }
    return self;
}

- (void)createView {
    
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = [NSString stringWithFormat:@"  %@",@"发送数量"  ];
    titleLab.textAlignment = NSTextAlignmentLeft;
    titleLab.textColor = CMColorFromRGB(0x333333);
    titleLab.font = [UIFont boldSystemFontOfSize:14];
    [self addSubview:titleLab];
    self.titleLab = titleLab;
    
    UILabel *balanceLab = [[UILabel alloc] init];
    balanceLab.font = [UIFont systemFontOfSize:14];
    balanceLab.textAlignment = NSTextAlignmentRight;
    balanceLab.textColor = CMColorFromRGB(0x7190FF);
    balanceLab.text = @"余额：--BTC"  ;
    [self addSubview:balanceLab];
    self.balanceLab = balanceLab;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapForTotal:)];
    tap.numberOfTapsRequired = 1;
    self.balanceLab.userInteractionEnabled = YES;
    [self.balanceLab addGestureRecognizer:tap];
    
    UIButton *btn = [[UIButton alloc] init];
    [btn setTitle:@"请选择编号"   forState:UIControlStateNormal];
    [btn setBackgroundColor:CMColorFromRGB(0xF8F8FA)];
    [btn setTitleColor:CMColorFromRGB(0x333649) forState:UIControlStateNormal];
    [btn.titleLabel setFont:[UIFont systemFontOfSize:18]];
    [btn addTarget:self action:@selector(choiceMoreNFTID:) forControlEvents:UIControlEventTouchUpInside];
    self.showMoreNFTIDBtn = btn;
    [self addSubview:self.showMoreNFTIDBtn];
    
    
    UITextField *moneyText = [[UITextField alloc] init];
    moneyText.backgroundColor = CMColorFromRGB(0xF8F8FA);
    moneyText.font = [UIFont systemFontOfSize:24];
    moneyText.textColor = CMColorFromRGB(0x333649);
    moneyText.textAlignment = NSTextAlignmentCenter;
    moneyText.layer.cornerRadius = 3.f;
    moneyText.placeholder = @"请输入数量"  ;
    [moneyText setValue:CMColorFromRGB(0xC8CEE5) forKeyPath:@"placeholderLabel.textColor"];
    
    moneyText.adjustsFontSizeToFitWidth = true;
    moneyText.keyboardType = UIKeyboardTypeDecimalPad;
    moneyText.delegate = self;
    [self addSubview:moneyText];
    self.moneyText = moneyText;
    [moneyText addTarget:self action:@selector(textValueDidChanged:) forControlEvents:UIControlEventEditingChanged];
    
    UILabel *hLine = [[UILabel alloc] init];
    hLine.backgroundColor = LineColor;
    [self addSubview:hLine];
    self.hLine = hLine;
}

- (void)choiceMoreNFTID:(UIButton *)sender
{
    if (self.choiceNFTIDBlock) {
        self.choiceNFTIDBlock(sender);
    }
}


- (void)tapForTotal:(id)sender
{
    CGFloat fee = 0;
     NSString *balanceStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%f",_coin.coin_balance - fee]];
    self.moneyText.text = balanceStr;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).with.offset(20);
        make.left.equalTo(self).with.offset(15);
        make.height.mas_equalTo(14);
    }];
    
    [self.balanceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.titleLab.mas_centerY);
        make.right.equalTo(self).with.offset(-15);
        make.height.mas_equalTo(13);
        make.left.equalTo(self.titleLab.mas_right);
    }];
    if (_coin.coin_type_nft == 1) {
        // NFT下不需要输入数量，只能转一个
        self.moneyText.hidden = YES;
        CGFloat width = (kScreenWidth - 60);
        [self.showMoreNFTIDBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.titleLab.mas_bottom).with.offset(10);
            make.left.equalTo(self).with.offset(30);
            make.height.mas_equalTo(48);
            make.width.mas_equalTo(width);
        }];
        
    }else{
        self.moneyText.hidden = NO;
        CGFloat width = (kScreenWidth - 60 - 15 * 2) * 0.5;
        [self.moneyText mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.titleLab.mas_bottom).with.offset(10);
            make.left.equalTo(self).with.offset(15);
            make.height.mas_equalTo(48);
            make.width.mas_equalTo(width);
        }];
        
        [self.symbolLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self);
            make.centerY.equalTo(self.moneyText);
            make.width.mas_equalTo(25);
            make.height.mas_equalTo(25);
        }];
        
        [self.rmbUnitView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self).with.offset(-15);
            make.centerY.equalTo(self.moneyText);
            make.width.mas_equalTo(width);
            make.height.mas_equalTo(48);
        }];
    }
    
    
    [self.hLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(15);
        make.right.equalTo(self).offset(-15);;
        make.height.mas_equalTo(0.5);
        make.bottom.equalTo(self.mas_bottom).with.offset(0);
    }];
    
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

- (void)setCoin:(LocalCoin *)coin {
    _coin = coin;
    if ([_coin.coin_chain isEqualToString:@"NEO"]) {
        self.rmbUnitView.textField.enabled = NO;
    }
    else
    {
        self.rmbUnitView.textField.enabled = YES;
    }
    NSString *balanceStr = [CommonFunction removeZeroFromMoney:[NSString stringWithFormat:@"%f",coin.coin_balance]];
    self.balanceLab.text = [NSString stringWithFormat:@"%@:%@%@",@"余额"  ,balanceStr,coin.optional_name];
    
    /**  */
    self.coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coin.coin_type platform:coin.coin_platform andTreaty:coin.treaty];
    if (self.coinPrice.coinprice_price == 0) {
        self.rmbUnitView.userInteractionEnabled = false;
    }
}

- (void)textValueDidChanged:(UITextField *)textField {
    
    CGFloat price = self.coinPrice.coinprice_country_rate;
    
    CGFloat inputText = [textField.text doubleValue];

    if (textField == self.moneyText) {
        self.rmbUnitView.contentNumber = [NSString stringWithFormat:@"%.2f",price * inputText];
    } else {
        if (inputText > 0) {
            NSString *numberStr = [self filterZeroWith:[NSString stringWithFormat:@"%.4f", inputText/ price]];
            self.moneyText.text = numberStr;
        } else {
            self.moneyText.text = @"";
        }
    }
}

- (NSString *)filterZeroWith:(NSString *)numberStr {
    if ([numberStr hasSuffix:@".0000"]) {
        return [numberStr substringToIndex:numberStr.length - 5];
    }
    else if ([numberStr hasSuffix:@"000"]) {
        return [numberStr substringToIndex:numberStr.length - 3];
    }
    else if ([numberStr hasSuffix:@"00"]) {
        return [numberStr substringToIndex:numberStr.length - 2];
    }
    else if ([numberStr hasSuffix:@"0"]) {
        return [numberStr substringToIndex:numberStr.length - 1];
    }
    else {
        return numberStr;
    }
}



- (double)getInputMoney
{
    double input = [self stringChangeToDoubleForJingdu:self.moneyText.text];
    if (self.moneyText.text == nil || [self.moneyText.text isEqualToString:@""])
    {
        return 0;
    }
    if (_coin.isBtyChild) {
        input = [self addFee:[NSString stringWithFormat:@"%.4f", _feeValue] inputMoeny:self.moneyText.text];
    }
   return input;
}

- (double )getTokenInputMoney
{
    double input = [self stringChangeToDoubleForJingdu:self.moneyText.text];
    
    return input;
}

- (double)addFee:(NSString *)fee inputMoeny:(NSString *)inputMoeny
{
    NSDecimalNumber *feeNum = [NSDecimalNumber decimalNumberWithString:fee];
    NSDecimalNumber *inputNum = [NSDecimalNumber decimalNumberWithString:inputMoeny];
    NSDecimalNumber *num = [feeNum  decimalNumberByAdding:inputNum];
    
    return [self stringChangeToDoubleForJingdu:[NSString stringWithFormat:@"%@",num]];
}

- (double)stringChangeToDoubleForJingdu:(NSString *)str
{
    if (str == nil || [str isEqualToString:@""]) {
        return 0.0;
    }
    
    NSNumberFormatter *format = [[NSNumberFormatter alloc] init];
    [format setNumberStyle:NSNumberFormatterDecimalStyle];
    [format setMaximumFractionDigits:8];
    return [[format numberFromString:str] doubleValue];
}


- (double)inputCNY {
    CGFloat price = self.coinPrice.rmb_country_rate;
    double inputCny = price * self.moneyText.text.floatValue;
    return inputCny;
}

- (NSString *)inputNumber {
    return self.moneyText.text;
}

- (void)setScanMoney:(NSString *)scanMoney
{
    if (scanMoney.floatValue > 0) {
        self.moneyText.text = scanMoney;
        CGFloat price = self.coinPrice.coinprice_country_rate;
        
        CGFloat inputText = [self.moneyText.text doubleValue];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.rmbUnitView.contentNumber = [NSString stringWithFormat:@"%.2f",price * inputText];
        });
        
    }
    
}


- (void)setKeybordBtn:(UIButton *)keybordBtn action:(SEL) action
{
    [self.moneyText setKeyBoardInputView:keybordBtn action:action];
    [self.rmbUnitView.textField setKeyBoardInputView:keybordBtn action:action];
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSMutableString *futureString = [NSMutableString stringWithString:textField.text];
    [futureString insertString:string atIndex:range.location];
    NSInteger flag = 0;
    const NSInteger limited = [_coin.coin_chain isEqualToString:@"NEO"] ? 0 : 6; // 限制小数位数

    for (int i =(int)(futureString.length -1); i>=0; i--) {
        if ([futureString characterAtIndex:i] == '.') {
            if (flag >limited) {
                return NO;
            }
            break;
        }
        flag++;
    }
    
    return YES;
    
}

@end
