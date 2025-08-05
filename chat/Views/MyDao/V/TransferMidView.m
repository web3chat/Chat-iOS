//
//  TransferMidView.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "TransferMidView.h"
#import "UITextView+Placeholder.h"
#import "Depend.h"
@interface TransferMidView() <UITextViewDelegate>
@property (nonatomic,strong) UILabel *titleLab;
@property (nonatomic,strong) UILabel *nameLab;
@property (nonatomic, strong) UIView *nameBottomLine;
@property (nonatomic,strong) UIButton *scanBtn;
@property (nonatomic,strong) UIButton *personBtn;

@property (nonatomic,strong) UILabel *hLine;
@property (nonatomic,strong) UILabel *launchTitleLab;
@property (nonatomic,strong) UILabel *walletNameLab;

@end

@implementation TransferMidView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self createView];
    }
    return self;
}

- (void)createView {
    
    UILabel *launchTitleLab = [[UILabel alloc] init];
    launchTitleLab.text = @"转账"  ;
    launchTitleLab.textColor = CMColorFromRGB(0x0F0F0F);
    launchTitleLab.font = [UIFont boldSystemFontOfSize:30];
    launchTitleLab.textAlignment = NSTextAlignmentLeft;
    [self addSubview:launchTitleLab];
    self.launchTitleLab = launchTitleLab;
    
    UIView *nameBottomLine = [[UIView alloc] init];
    nameBottomLine.backgroundColor = CMColorFromRGB(0x7190FF);
    [self addSubview:nameBottomLine];
    self.nameBottomLine = nameBottomLine;
    self.nameBottomLine.hidden = true;
    UILabel *walletNameLab = [[UILabel alloc] init];
    walletNameLab.text = @"";
    walletNameLab.textColor = CMColorFromRGB(0x333649);
    walletNameLab.textAlignment = NSTextAlignmentRight;
    walletNameLab.font = [UIFont boldSystemFontOfSize:16];
    [self addSubview:walletNameLab];
    self.walletNameLab = walletNameLab;
    self.walletNameLab.hidden = true;
    
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = [NSString stringWithFormat:@"  %@",@"收币地址"  ];
    
    titleLab.textColor = CMColorFromRGB(0x333333);
    titleLab.font = [UIFont boldSystemFontOfSize:14];
    titleLab.textAlignment = NSTextAlignmentLeft;
    [self addSubview:titleLab];
    self.titleLab = titleLab;
    
    UILabel *nameLab = [[UILabel alloc] init];
    nameLab.text = @"";
    nameLab.textColor = CMColorFromRGB(0x333649);
    nameLab.font = CMTextFont12;
    nameLab.layer.cornerRadius = 3;
    nameLab.layer.borderColor = CMColorFromRGB(0xD8E1FF).CGColor;
    nameLab.textAlignment = NSTextAlignmentCenter;
    [self addSubview:nameLab];
    self.nameLab = nameLab;
    [nameLab setHidden:YES];
    
    UIButton *scanBtn = [[UIButton alloc] init];
    [scanBtn setImage:[UIImage imageNamed:@"trade_scan"] forState:UIControlStateNormal];
    [self addSubview:scanBtn];
    self.scanBtn = scanBtn;
    
    UIButton *personBtn = [[UIButton alloc] init];
    [personBtn setImage:[UIImage imageNamed:@"trade_contact"] forState:UIControlStateNormal];
    [self addSubview:personBtn];
    self.personBtn = personBtn;
//    personBtn.hidden = YES;
    
    UITextView *addressLab = [[UITextView alloc] init];
    addressLab.textAlignment = NSTextAlignmentLeft;
    addressLab.textColor = TextColor51;
    addressLab.backgroundColor = [UIColor whiteColor];
    addressLab.font = CMTextFont16;
    addressLab.text = @"";
    addressLab.delegate = self;
    addressLab.keyboardType = UIKeyboardTypeEmailAddress;
    addressLab.placeholder = @"输入/扫一扫地址"  ;
    addressLab.placeholderColor = CMColorFromRGB(0xD9DCE9);
    [self addSubview:addressLab];
    self.addressText = addressLab;
    NSMutableAttributedString *resultAttr = [[NSMutableAttributedString alloc] initWithString:self.addressText.text];
    [resultAttr addAttribute:NSFontAttributeName value:CMTextFont16 range:NSMakeRange(0, self.addressText.text.length)];
    addressLab.attributedText = resultAttr;
 
    UILabel *hLine = [[UILabel alloc] init];
    hLine.backgroundColor = LineColor;
    [self addSubview:hLine];
    self.hLine = hLine;
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.launchTitleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(15);
        make.top.equalTo(self).with.offset(0);
        make.height.mas_equalTo(42);
    }];
    
    [self.walletNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.launchTitleLab.mas_centerY);
        make.right.equalTo(self).with.offset(-15);
        make.height.mas_equalTo(13);
    }];
    [self.walletNameLab setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    CGFloat walletNameWidth = [self stringWidthWithText:self.walletNameLab.text font:[UIFont boldSystemFontOfSize:16]];
    
    [self.nameBottomLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self).with.offset(-15);
        make.bottom.equalTo(self.walletNameLab.mas_bottom).offset(4);
        make.width.mas_equalTo(walletNameWidth);
        make.height.mas_equalTo(7);
    }];

    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(15);
        make.top.equalTo(self.launchTitleLab.mas_bottom).with.offset(40);
        make.height.mas_equalTo(14);
    }];
    
    [self.nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLab.mas_right).with.offset(15);
        make.centerY.equalTo(self.titleLab.mas_centerY);
        make.height.mas_equalTo(22);
    }];
    
    [self.personBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(44);
        make.centerY.equalTo(self.titleLab.mas_centerY);
        make.right.equalTo(self).with.offset(-6);
    }];
    
    [self.scanBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(44);
        make.centerY.equalTo(self.titleLab.mas_centerY);
        make.right.equalTo(self.personBtn.mas_left).with.offset(-5);
    }];
    
    [self.addressText mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(15);
        make.top.equalTo(self.titleLab.mas_bottom).with.offset(20);
        make.height.mas_equalTo(48);
        make.width.equalTo(self).with.offset(-60);
    }];
    
    [self.hLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(15);
        make.right.equalTo(self).offset(-15);
        make.height.mas_equalTo(0.5);
        make.bottom.equalTo(self.mas_bottom).offset(0);
    }];
    
    [self borderForView:self.titleLab color:CMColorFromRGB(0x7190FF) borderWidth:3 borderType:2];
}

- (void)addContactTarget:(nullable id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {
    [self.personBtn addTarget:target action:action forControlEvents:controlEvents];
}

- (void)addScanTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {
    [self.scanBtn addTarget:target action:action forControlEvents:controlEvents];
}

- (void)setCoin:(LocalCoin *)coin {
    _coin = coin;
    NSString *title = @"转账"  ;
    self.launchTitleLab.text = [NSString stringWithFormat:@"%@%@",coin.optional_name,title];
    self.addressText.placeholder = [NSString stringWithFormat:@"%@%@%@",@"输入/扫一扫"  ,coin.optional_name,@"地址"  ];
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWallet:coin.coin_walletid];
    self.walletNameLab.text = wallet.wallet_name;
}

- (CGFloat)stringWidthWithText:(NSString *)text font:(UIFont *)font {
    
    return [text boundingRectWithSize:CGSizeMake(MAXFLOAT, font.lineHeight) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:font} context:nil].size.width + 2;
}

- (UIView *)borderForView:(UIView *)originalView color:(UIColor *)color borderWidth:(CGFloat)borderWidth borderType:(NSInteger)borderType { // 1 下 2 左
    
    /// 线的路径
    UIBezierPath * bezierPath = [UIBezierPath bezierPath];
    
    /// 左侧
    if (borderType == 2) {
        /// 左侧线路径
        [bezierPath moveToPoint:CGPointMake(0.0f, originalView.frame.size.height)];
        [bezierPath addLineToPoint:CGPointMake(0.0f, 0.0f)];
    }
    
    /// 底部
    if (borderType == 1) {
        /// bottom线路径
        [bezierPath moveToPoint:CGPointMake(0.0f, originalView.frame.size.height)];
        [bezierPath addLineToPoint:CGPointMake( originalView.frame.size.width, originalView.frame.size.height)];
    }
   
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


- (void)setContactIsHidden:(BOOL)contactIsHidden {
    _contactIsHidden = contactIsHidden;
    if (contactIsHidden) {
        self.personBtn.hidden = YES;
    }
}

- (NSString *)getFromAddress
{
    return _coin.coin_address;
}

- (NSString *)getToAddress
{
    return [PWUtils removeSpaceAndNewline:self.addressText.text];
}

- (void)setDestinationAddress:(NSString *)address
{
    self.addressText.text = address;
    NSMutableAttributedString *resultAttr = [[NSMutableAttributedString alloc] initWithString:self.addressText.text];
    if (self.addressText.text.length > 4) {
        [resultAttr addAttribute:NSForegroundColorAttributeName value:MainColor range:NSMakeRange(self.addressText.text.length - 4, 4)];
    }
    [resultAttr addAttribute:NSFontAttributeName value:CMTextFont16 range:NSMakeRange(0, self.addressText.text.length)];

    self.addressText.attributedText = resultAttr;
}

- (void)setExclusiveAddress:(NSString *)address
{
    if (address.length > 0) {
        self.addressText.text = address;
        NSMutableAttributedString *resultAttr = [[NSMutableAttributedString alloc] initWithString:self.addressText.text];
        if (self.addressText.text.length > 4) {
            [resultAttr addAttribute:NSForegroundColorAttributeName value:MainColor range:NSMakeRange(self.addressText.text.length - 4, 4)];
        }
        [resultAttr addAttribute:NSFontAttributeName value:CMTextFont16 range:NSMakeRange(0, self.addressText.text.length)];
        
        self.addressText.attributedText = resultAttr;
        self.addressText.editable = NO;
    }
    
}


- (void)setKeybordBtn:(UIButton *)keybordBtn action:(SEL) action
{
    [self.addressText setKeyBoardInputView:keybordBtn action:action];
}

- (void)textViewDidChange:(UITextView *)textView
{
    self.nameLab.text = @"";
    [self.nameLab setHidden:YES];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    // 停止编辑
    NSLog(@"我停止了");
    if (self.midViewBlock) {
        self.midViewBlock(textView.text);
    }
}

@end
