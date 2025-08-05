//
//  ContactView.m
//  chat
//
//  Created by 郑晨 on 2025/3/4.
//

#import "ContactView.h"
#import "Depend.h"

@interface ContactView()

@property (nonatomic, strong) UILabel *addreLab;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIButton *selectedCoinBtn;
@property (nonatomic, strong) UILabel *toAddrLab;

@property (nonatomic, strong)UIView *contentsView;

@end


@implementation ContactView


- (instancetype)init {
    self = [super init];
    if (self) {
        [self createView];
    }
    return self;
}

- (void)createView
{
    UIButton *selectedCoinBtn = [[UIButton alloc] init];
    [selectedCoinBtn setTitle:@"转账 >" forState:UIControlStateNormal];
    [selectedCoinBtn setTitleColor:CMColorFromRGB(0x0f0f0f) forState:UIControlStateNormal];
    [selectedCoinBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:30]];
    [selectedCoinBtn addTarget:self action:@selector(choiceCoin:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:selectedCoinBtn];
    
    self.selectedCoinBtn = selectedCoinBtn;
    
    UIView *contentView = [[UIView alloc] init];
    contentView.backgroundColor = UIColor.whiteColor;
    self.contentsView = contentView;
    [self addSubview:contentView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(choiceFriend:)];
    tap.numberOfTapsRequired = 1;
    
    [self.contentsView addGestureRecognizer:tap];
    self.contentsView.userInteractionEnabled = true;
    
    UIImageView *avatarImageView = [[UIImageView alloc] init];
    avatarImageView.layer.cornerRadius = 20;
    [self.contentsView addSubview:avatarImageView];
    
    self.avatarImageView = avatarImageView;
    
    UILabel *addreLab = [[UILabel alloc] init];
    addreLab.text = @"1233333333333333333333333333333333123333333";
    addreLab.textColor = CMColorFromRGB(0x333649);
    addreLab.textAlignment = NSTextAlignmentCenter;
    addreLab.font = [UIFont boldSystemFontOfSize:16];
    [self.contentsView addSubview:addreLab];
    self.addreLab = addreLab;
    
    UILabel *toaddreLab = [[UILabel alloc] init];
    toaddreLab.text = @"1233333333333333333333333333333333123333333";
    toaddreLab.textColor = CMColorFromRGB(0x333649);
    toaddreLab.textAlignment = NSTextAlignmentCenter;
    toaddreLab.font = [UIFont systemFontOfSize:14];
    [self.contentsView addSubview:toaddreLab];
    self.toAddrLab = toaddreLab;
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.contentsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self);
        make.bottom.equalTo(self).offset(-42);
    }];
    [self.avatarImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentsView);
        make.top.equalTo(self.contentsView).offset(10);
        make.size.mas_equalTo(@40);
    }];
    
    [self.addreLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentsView);
        make.top.equalTo(self.avatarImageView.mas_bottom).offset(10);
    }];
    [self.toAddrLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentsView);
        make.top.equalTo(self.addreLab.mas_bottom).offset(10);
    }];
    [self.selectedCoinBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(15);
        make.height.mas_equalTo(42);
        make.bottom.equalTo(self);
    }];
    
    
}

- (void)setContactDict:(NSDictionary *)contactDict
{
    if (contactDict == nil) {
        self.addreLab.text = @"点击选择好友";
        self.avatarImageView.image = [UIImage imageNamed:@"avatar_persion"];
        self.toAddrLab.text = @"";
        return;
    }
    NSString *avatarUrl = contactDict[@"avatarUrl"];
    NSString *address = contactDict[@"address"];
    NSString *toAddr = contactDict[@"toAddr"];
    [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:avatarUrl] placeholderImage:[UIImage imageNamed:@"avatar_persion"]];
    
    self.addreLab.text = address;
    self.toAddrLab.text = toAddr;
    NSString *fullString = self.toAddrLab.text;
    if (fullString.length < 5) {
        return;
    }
    NSString *blueSubstring = [fullString substringFromIndex:fullString.length - 4]; // 获取后四位
    NSString *restOfString = [fullString substringToIndex:fullString.length - 4]; // 获取前面的部分
    // 创建带有属性的字符串
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:fullString];
    // 设置后四位文字的属性
    [attributedString addAttribute:NSForegroundColorAttributeName value:SGColorFromRGB(0x7190ff) range:NSMakeRange(restOfString.length, blueSubstring.length)];
    // 使用这个attributedString显示在你的UILabel或其他UI上
    self.toAddrLab.attributedText = attributedString;

}

- (void)setCoin:(LocalCoin *)coin
{
    NSString *coinName = coin.coin_type;
    
    [self.selectedCoinBtn setTitle:[NSString stringWithFormat:@"%@转账 >",coinName] forState:UIControlStateNormal];
}

- (void)choiceCoin:(UIButton *)sender
{
    if (self.contactViewBlock) {
        self.contactViewBlock(@"");
    }
}

- (void)choiceFriend:(id)sender{
    if (self.coSelectedFBlock) {
        self.coSelectedFBlock();
    }
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/



@end
