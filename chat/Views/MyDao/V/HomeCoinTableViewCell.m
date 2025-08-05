//
//  HomeCoinTableViewCell.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/22.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "HomeCoinTableViewCell.h"
#import "Depend.h"
#import "CommonFunction.h"


@interface HomeCoinTableViewCell()
@property (nonatomic,strong) UIImageView *coinIcon;
@property (nonatomic,strong) UILabel *coinNameLab;
@property (nonatomic,strong) UILabel *lastValueLab;
@property (nonatomic,strong) UILabel *balanceLab;
@property (nonatomic,strong) UILabel *RMBLab;
@property (nonatomic,strong) UILabel *chineseNameLab;
@property (nonatomic,strong) UIView *cellBgView;
@property (nonatomic,strong) UILabel *platformLab;
@property (nonatomic, strong) UIImageView *chainImageView;

@end

@implementation HomeCoinTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self createView];
        self.backgroundColor = SGColorFromRGB(0xFCFCFF);
    }
    return self;
}

- (void)createView
{
    UIView *cellBgView = [[UIView alloc] init];
    cellBgView.backgroundColor = [UIColor whiteColor];
    cellBgView.layer.cornerRadius = 6;
    cellBgView.layer.shadowRadius = 2;
    cellBgView.layer.shadowOpacity = 1;
    cellBgView.layer.shadowColor = SGColorRGBA(217, 220, 233, 0.4).CGColor;
    cellBgView.layer.shadowOffset = CGSizeMake(0, 0);
    [self.contentView addSubview:cellBgView];
    self.cellBgView = cellBgView;
    
    UIButton *leftBtn = [[UIButton alloc] init];
    [leftBtn setTitle:@"转账" forState:UIControlStateNormal];
    [leftBtn setBackgroundColor:SGColorFromRGB(0x333649)];
    [leftBtn setImage:[UIImage imageNamed:@"home_out"] forState:UIControlStateNormal];
    [leftBtn.layer setCornerRadius:6.f];
    leftBtn.tag = 100;
    [self.contentView addSubview:leftBtn];
    self.leftBtn = leftBtn;
    self.leftBtn.hidden = YES;

    UIButton *rightBtn = [[UIButton alloc] init];
    [rightBtn setTitle:@"收款" forState:UIControlStateNormal];
    [rightBtn setBackgroundColor:SGColorFromRGB(0x7190ff)];
    [rightBtn setImage:[UIImage imageNamed:@"home_in"] forState:UIControlStateNormal];
    [rightBtn.layer setCornerRadius:6.f];
    rightBtn.tag = 200;
    [self.contentView addSubview:rightBtn];
    self.rightBtn = rightBtn;
    self.rightBtn.hidden = YES;
    
    [leftBtn.titleLabel setFont:[UIFont systemFontOfSize:16]];
    [leftBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 70, 0, 0)];
    [leftBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 24)];
    [rightBtn.titleLabel setFont:[UIFont systemFontOfSize:16]];
    [rightBtn setImageEdgeInsets:UIEdgeInsetsMake(0, -20, 0, 0)];
    [rightBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, -10, 0, 0)];
    
    
    UIImageView *coinIcon = [[UIImageView alloc] init];
    coinIcon.layer.cornerRadius = 17;
    coinIcon.layer.masksToBounds = YES;
    [self.cellBgView addSubview:coinIcon];
    self.coinIcon = coinIcon;

    UILabel *coinNameLab = [[UILabel alloc] init];
    coinNameLab.textColor = CMColor(51, 51, 51);
    coinNameLab.font = [UIFont boldSystemFontOfSize:18];
    coinNameLab.textAlignment = NSTextAlignmentLeft;
    [self.cellBgView addSubview:coinNameLab];
    self.coinNameLab = coinNameLab;

    UILabel *chineseNameLab = [[UILabel alloc] init];
    chineseNameLab.textColor = CMColorFromRGB(0x999999);
    chineseNameLab.textAlignment = NSTextAlignmentLeft;
    chineseNameLab.font = [UIFont systemFontOfSize:13];
    [self.cellBgView addSubview:chineseNameLab];
    self.chineseNameLab = chineseNameLab;
    
    UILabel *platformLab = [[UILabel alloc] init];
    platformLab.textColor = SGColorRGBA(158, 162, 173, 1);
    platformLab.textAlignment = NSTextAlignmentCenter;
    platformLab.font = [UIFont systemFontOfSize:12];
    platformLab.layer.borderWidth = 1;
    platformLab.layer.cornerRadius = 2;
    platformLab.layer.masksToBounds = YES;
    platformLab.layer.borderColor = SGColorRGBA(158, 162, 173, 1).CGColor;
    [self.cellBgView addSubview:platformLab];
    self.platformLab = platformLab;
    
    UILabel *lastValueLab = [[UILabel alloc] init];
    lastValueLab.textAlignment = NSTextAlignmentRight;
    lastValueLab.font = [UIFont systemFontOfSize:18];;
    lastValueLab.textColor = CMColor(51, 51, 51);
    [self.cellBgView addSubview:lastValueLab];
    self.lastValueLab = lastValueLab;

    UILabel *balanceLab = [[UILabel alloc] init];
    balanceLab.textColor = CMColor(153, 153, 153);
    balanceLab.font = [UIFont systemFontOfSize:14];
    balanceLab.textAlignment = NSTextAlignmentLeft;
    [self.cellBgView addSubview:balanceLab];
    self.balanceLab = balanceLab;

    UILabel *RMBLab = [[UILabel alloc] init];
    RMBLab.textColor = CMColor(153, 153, 153);
    RMBLab.font = [UIFont systemFontOfSize:14];
    RMBLab.textAlignment = NSTextAlignmentRight;
    [self.cellBgView addSubview:RMBLab];
    self.RMBLab = RMBLab;

    
    UIImageView *chainImageView= [[UIImageView alloc] init];
    chainImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.cellBgView addSubview:chainImageView];
    self.chainImageView = chainImageView;
    
    coinNameLab.text = @"BTC";
    chineseNameLab.text = @"(比特币)";
    lastValueLab.text = @"0.00";
    balanceLab.text = @"≈￥0.00";
    RMBLab.text = @"≈￥0.00";
    platformLab.text = @"btc";

}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.cellBgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).with.offset(15);
        make.right.equalTo(self.contentView).with.offset(-15);
        make.top.equalTo(self.contentView);
        make.bottom.equalTo(self.contentView);
    }];
    
    [self.coinIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(32);
        make.left.equalTo(self.cellBgView).with.offset(13);
        make.centerY.equalTo(self.cellBgView);
    }];

    [self.coinNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coinIcon.mas_right).with.offset(10);
        make.centerY.equalTo(self.coinIcon);
    }];

    [self.chineseNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coinNameLab.mas_right);
        make.centerY.equalTo(self.coinNameLab);
    }];
    [self.lastValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.coinNameLab.mas_centerY);
        make.right.equalTo(self.cellBgView).with.offset(-13);
    }];
}

- (void)setCoin:(LocalCoin *)coin
{
    _coin = [coin copy];
    //如果没有可选名用币名
    self.coinNameLab.text = coin.coin_type;

//    [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:coin.icon]];
    self.lastValueLab.text = [CommonFunction removeZeroFromMoney:[CommonFunction removeZeroFromMoney:coin.coin_balance withMaxLength:6]];


    
}

- (void)setCoinPrice:(CoinPrice *)coinPrice{
    if(coinPrice == nil)
    {
        self.balanceLab.text = @"≈￥0.0";
        self.RMBLab.text = @"≈￥0.0";
        self.chineseNameLab.text = @"";
        [self.platformLab setHidden:YES];
        [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:@""]];
    }else{
        _coinPrice = coinPrice;
        [self.platformLab setHidden:NO];
        self.balanceLab.text = [NSString stringWithFormat:@"≈￥%.2f",coinPrice.coinprice_price];
        self.RMBLab.text = [NSString stringWithFormat:@"≈￥%.2f",coinPrice.coinprice_price * _coin.coin_balance];
        self.platformLab.text = [NSString stringWithFormat:@" %@  ",coinPrice.coinprice_platform];
        if (![coinPrice.coinprice_nickname isEqualToString:@""]) {
           self.chineseNameLab.text = [NSString stringWithFormat:@"(%@)",coinPrice.coinprice_nickname];
        }else
        {
            self.chineseNameLab.text = [NSString stringWithFormat:@""];
        }
        
        if (![coinPrice.coinprice_icon isEqual:[NSNull null]]) {
            [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:coinPrice.coinprice_icon]];
        }
    }
}
@end
