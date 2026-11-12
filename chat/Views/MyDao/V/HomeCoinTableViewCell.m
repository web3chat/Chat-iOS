//
//  HomeCoinTableViewCell.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/22.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "HomeCoinTableViewCell.h"
#import "Depend.h"
#import "CommonFunction.h"
// sd_cancelCurrentImageLoad 声明在 UIView+WebCache.h（SDWebImage 4.0 的 UIImageView+WebCache.h 不会引它，必须显式引）
#import "UIView+WebCache.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]

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
@property (nonatomic, strong) UIView *lineView;
/** 约束只装一次（见 layoutSubviews 里的说明） */
@property (nonatomic, assign) BOOL didInstallConstraints;

@end

@implementation HomeCoinTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self createView];
        self.backgroundColor = SGColorFromRGB(0xFFFFFF);
    }
    return self;
}

- (void)createView
{
    UIView *cellBgView = [[UIView alloc] init];
    cellBgView.backgroundColor = [UIColor whiteColor];
//    cellBgView.layer.cornerRadius = 6;
//    cellBgView.layer.shadowRadius = 2;
//    cellBgView.layer.shadowOpacity = 1;
//    cellBgView.layer.shadowColor = SGColorRGBA(217, 220, 233, 0.4).CGColor;
//    cellBgView.layer.shadowOffset = CGSizeMake(0, 0);
    [self.contentView addSubview:cellBgView];
    self.cellBgView = cellBgView;
    
    UIButton *leftBtn = [[UIButton alloc] init];
    [leftBtn setTitle:L(@"转账") forState:UIControlStateNormal];
    [leftBtn setBackgroundColor:SGColorFromRGB(0x333649)];
    [leftBtn setImage:[UIImage imageNamed:@"home_out"] forState:UIControlStateNormal];
    [leftBtn.layer setCornerRadius:6.f];
    leftBtn.tag = 100;
    [self.contentView addSubview:leftBtn];
    self.leftBtn = leftBtn;
    self.leftBtn.hidden = YES;

    UIButton *rightBtn = [[UIButton alloc] init];
    [rightBtn setTitle:L(@"收款") forState:UIControlStateNormal];
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
    
    UIView *lineView = [[UIView alloc] init];
    lineView.backgroundColor = SGColorFromRGB(0xf8f8f8);
    self.lineView = lineView;
    [self.cellBgView addSubview:self.lineView];
    
    coinNameLab.text = @"BTC";
    chineseNameLab.text = L(@"(比特币)");
    lastValueLab.text = @"0.00";
    balanceLab.text = @"≈￥0.00";
    RMBLab.text = @"≈￥0.00";
    platformLab.text = @"btc";

}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // ⚠️ 这里只能装一次：mas_makeConstraints 不会清理旧约束，写在 layoutSubviews 里每布局一次就新增一份，
    // cell 反复复用时约束越堆越多，长列表会越来越卡。
    if (self.didInstallConstraints) { return; }
    self.didInstallConstraints = YES;
    
    [self.cellBgView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(self.contentView);
//        make.right.equalTo(self.contentView);
//        make.top.equalTo(self.contentView);
//        make.bottom.equalTo(self.contentView);
        make.edges.equalTo(self.contentView);
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

    [self.balanceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.coinNameLab.mas_bottom).offset(5);
        make.left.equalTo(self.coinNameLab);
    }];
    
    [self.chineseNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coinNameLab.mas_right);
        make.centerY.equalTo(self.coinNameLab);
    }];
    [self.lastValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.coinNameLab.mas_centerY);
        make.right.equalTo(self.cellBgView).with.offset(-13);
    }];
    
    [self.lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.cellBgView);
        make.left.equalTo(self.coinNameLab);
        make.height.mas_equalTo(1);
        make.bottom.equalTo(self.cellBgView);
    }];
}

- (void)setCoin:(LocalCoin *)coin
{
    // 防御：数据源被并发替换时可能拿到 nil/半成品对象，这里直接清空而不是继续读属性
    if (!coin) {
        _coin = nil;
        _coinPrice = nil;
        self.coinNameLab.text = @"";
        self.chineseNameLab.text = @"";
        self.platformLab.text = @"";
        self.lastValueLab.text = @"";
        return;
    }

    _coin = [coin copy];
    //如果没有可选名用币名
    self.coinNameLab.text = coin.coin_type ?: @"";

//    [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:coin.icon]];
    self.lastValueLab.text = [CommonFunction removeZeroFromMoney:[CommonFunction removeZeroFromMoney:coin.coin_balance withMaxLength:6]];

    // coin_type / coin_platform 可能是 nil（历史数据 / 服务端新币）：
    // FMDB 对 nil 参数本身是安全的（会绑成 SQL NULL），但拿空 key 查出来的结果没意义，
    // 而且下游 `%@` 拼接到 nil 会显示成 "(null)"，所以这里直接跳过查询。
    CoinPrice *coinPrice = nil;
    if (_coin.coin_type.length > 0 && _coin.coin_platform.length > 0) {
        coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:_coin.coin_type platform:_coin.coin_platform andTreaty:_coin.treaty];
    }
    _coinPrice = coinPrice;
    [self.platformLab setHidden:NO];
    self.balanceLab.text = [NSString stringWithFormat:@"≈$%.2f", coinPrice ? coinPrice.coinprice_dollarPrice : 0];
    [self.balanceLab setHidden:YES];
//        self.RMBLab.text = [NSString stringWithFormat:@"≈￥%.2f",coinPrice.coinprice_price * _coin.coin_balance];
    self.platformLab.text = coinPrice ? [NSString stringWithFormat:@" %@  ", coinPrice.coinprice_platform ?: @""] : @"";
    NSString *nickname = coinPrice.coinprice_nickname;
    if ([nickname isKindOfClass:[NSString class]] && nickname.length > 0) {
        self.chineseNameLab.text = [NSString stringWithFormat:@"(%@)",nickname];
    }else
    {
        self.chineseNameLab.text = [NSString stringWithFormat:@""];
    }
    
    // 图标：服务端没返回图标时用「币种名首字母 + 色底圆」占位（否则列表里是一排空白圆，像没加载出来）；
    // 有图标时也用占位图垫底，避免加载完成前/失败后留下上一个币的图标（cell 复用）
    NSString *iconURL = coinPrice.coinprice_icon;
    UIImage *placeholderIcon = [CommonFunction coinPlaceholderImageWithName:self.coinNameLab.text diameter:32];
    if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
        [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:iconURL] placeholderImage:placeholderIcon];
    } else {
        [self.coinIcon sd_cancelCurrentImageLoad];
        self.coinIcon.image = placeholderIcon;
    }
    
    if ([_coin.coin_type isEqualToString:@"PMM"]) {
        self.coinIcon.image = [UIImage imageNamed:@"PMM"];
    }
}

- (void)setCoinPrice:(CoinPrice *)coinPrice{
    return;
//    if(coinPrice == nil)
//    {
//        self.balanceLab.text = @"≈￥0.0";
//        self.RMBLab.text = @"≈￥0.0";
//        self.chineseNameLab.text = @"";
//        [self.platformLab setHidden:YES];
//        [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:@""]];
//    }else{
        coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coinPrice.coinprice_name platform:coinPrice.coinprice_platform andTreaty:coinPrice.treaty];
        _coinPrice = coinPrice;
        [self.platformLab setHidden:NO];
        self.balanceLab.text = [NSString stringWithFormat:@"≈$%.2f",coinPrice.coinprice_dollarPrice];
        [self.balanceLab setHidden:YES];
//        self.RMBLab.text = [NSString stringWithFormat:@"≈￥%.2f",coinPrice.coinprice_price * _coin.coin_balance];
        self.platformLab.text = [NSString stringWithFormat:@" %@  ",coinPrice.coinprice_platform];
        if (![coinPrice.coinprice_nickname isEqualToString:@""] || coinPrice.coinprice_nickname != nil) {
            self.chineseNameLab.text = [NSString stringWithFormat:@"(%@)",coinPrice.coinprice_nickname];
        }else
        {
            self.chineseNameLab.text = [NSString stringWithFormat:@""];
        }
        
        if (![coinPrice.coinprice_icon isEqual:[NSNull null]]) {
            [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:coinPrice.coinprice_icon]];
        }
//    }
}
@end
