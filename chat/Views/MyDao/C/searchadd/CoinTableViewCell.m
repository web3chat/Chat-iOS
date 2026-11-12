//
//  CoinTableViewCell.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/28.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "CoinTableViewCell.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
#import "Depend.h"
// sd_cancelCurrentImageLoad 声明在 UIView+WebCache.h（SDWebImage 4.0 的 UIImageView+WebCache.h 不会引它，必须显式引）
#import "UIView+WebCache.h"
@interface CoinTableViewCell()
@property (nonatomic,strong) UIImageView *bgIcon;
@property (nonatomic,strong) UIImageView *coinIcon;
@property (nonatomic,strong) UILabel *coinNameLab;
@property (nonatomic,strong) UILabel *chineseLab;
@property (nonatomic,strong) UILabel *sidLab;
@property (nonatomic,strong) UILabel *addedLab;
@property (nonatomic,strong) UILabel *hyAddress;
/** 约束只装一次（见 layoutSubviews） */
@property (nonatomic, assign) BOOL didInstallConstraints;
@end

@implementation CoinTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self createView];
    }
    return self;
}

- (void)createView
{
    UIImageView *bgIcon = [[UIImageView alloc] init];
    bgIcon.layer.cornerRadius = 25;
    bgIcon.layer.masksToBounds = YES;
    bgIcon.backgroundColor = [UIColor whiteColor];
    bgIcon.layer.borderWidth = 0.5;
    bgIcon.layer.borderColor = CMColorFromRGB(0xF3F3F3).CGColor;
    [self.contentView addSubview:bgIcon];
    self.bgIcon = bgIcon;
    bgIcon.alpha = 0;
    
    UIImageView *coinIcon = [[UIImageView alloc] init];
    coinIcon.layer.cornerRadius = 15;
    coinIcon.layer.masksToBounds = YES;
    [self.contentView addSubview:coinIcon];
    self.coinIcon = coinIcon;
    
    UILabel *coinNameLab = [[UILabel alloc] init];
    coinNameLab.textColor = CMColor(51, 51, 51);
    coinNameLab.font = [UIFont boldSystemFontOfSize:18];
    coinNameLab.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:coinNameLab];
    self.coinNameLab = coinNameLab;
    
    UILabel *chineseLab = [[UILabel alloc] init];
    chineseLab.textColor = PlaceHolderColor;
    chineseLab.font = CMTextFont13;
    chineseLab.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:chineseLab];
    self.chineseLab = chineseLab;
    
    UILabel *sidLab = [[UILabel alloc] init];
    sidLab.textColor = PlaceHolderColor;
    sidLab.font = CMTextFont14;
    sidLab.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:sidLab];
    self.sidLab = sidLab;
    
    UILabel *hyAddress = [[UILabel alloc] init];
    hyAddress.font = CMTextFont12;
    hyAddress.textColor = SGColor(142, 146, 163);
    hyAddress.textAlignment = NSTextAlignmentLeft;
    hyAddress.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.contentView addSubview:hyAddress];
    self.hyAddress = hyAddress;
    
    PWSwitchView *switchBtn = [[PWSwitchView alloc] init];
    [switchBtn addTarget:self action:@selector(swhClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:switchBtn];
    self.switchBtn = switchBtn;
    
    UILabel *addedLab = [[UILabel alloc] init];
    addedLab.text = L(@"已添加");
    addedLab.textColor = SGColor(142, 146, 163);
    addedLab.font = CMTextFont14;
    addedLab.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:addedLab];
    self.addedLab = addedLab;
    [self.addedLab setHidden:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.contentView.backgroundColor = UIColor.whiteColor;
    
    // ⚠️ 约束只装一次：mas_makeConstraints 不会清理旧约束，写在 layoutSubviews 里每布局一次就多一份，
    // cell 复用（列表滚动）时约束会越堆越多，越滚越卡。
    if (self.didInstallConstraints) { return; }
    self.didInstallConstraints = YES;
    
    [self.bgIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(50);
        make.left.equalTo(self.contentView).with.offset(10);
        make.centerY.equalTo(self.contentView);
    }];

    [self.coinIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(32);
        make.centerX.equalTo(self.bgIcon.mas_centerX);
        make.centerY.equalTo(self.bgIcon.mas_centerY);
    }];

//    [self.coinNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(self.bgIcon.mas_right).with.offset(7);
//        make.top.equalTo(self.contentView).offset(19);
//    }];

    [self.chineseLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coinNameLab.mas_right);
        make.centerY.equalTo(self.coinNameLab.mas_centerY);
        make.height.mas_equalTo(13);
    }];

    [self.sidLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coinNameLab);
        make.top.equalTo(self.coinNameLab.mas_bottom).offset(3);
    }];

    [self.hyAddress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coinNameLab);
        make.top.equalTo(self.sidLab.mas_bottom).offset(3);
        make.right.equalTo(self.switchBtn.mas_left).offset(-5);
    }];

    [self.switchBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(self.contentView.mas_height).offset(-10);
        make.height.equalTo(self.contentView);
        make.centerY.equalTo(self.contentView);
        make.right.equalTo(self.contentView);
    }];

    [self.addedLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(100);
        make.height.equalTo(self.contentView);
        make.centerY.equalTo(self.contentView);
        make.right.equalTo(self.contentView).offset(-10);
    }];
}

- (void)setDataStr:(NSString *)title{
    self.coinNameLab.text = title;
    NSString *imgName = [NSString stringWithFormat:@"wallet_%@_logo",title];
    self.coinIcon.image = [UIImage imageNamed:imgName];
    self.switchBtn.hidden = YES;
}

- (void)setCoin:(LocalCoin *)coin
{
    _coin = [coin copy];
    if ([coin.optional_name isEqualToString:@"BESC"]) {
        NSLog(@"哈哈");
    }
    if (coin.coin_show == 0) {
        [self.switchBtn setOn:NO];
    }else if (coin.coin_show == 1)
    {
        [self.switchBtn setOn:YES];
    }
    
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coin.coin_type platform:coin.coin_platform andTreaty:coin.treaty];
    
    if (!IS_BLANK(coinPrice.coinprice_optional_name)) {
        self.coinNameLab.text = coinPrice.coinprice_optional_name;
    }else{
        self.coinNameLab.text = coin.coin_type;
    }

    // 没有图标时用「币种名首字母 + 色底圆」占位（不能留空白圆，看着像没加载出来）
    NSString *iconURL = coinPrice.coinprice_icon;
    UIImage *placeholderIcon = [CommonFunction coinPlaceholderImageWithName:self.coinNameLab.text diameter:32];
    if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
        [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:iconURL] placeholderImage:placeholderIcon];
    } else {
        [self.coinIcon sd_cancelCurrentImageLoad];
        self.coinIcon.image = placeholderIcon;
    }

    if(![coinPrice.coinprice_nickname isEqualToString:@""])
    {
        self.chineseLab.text = [NSString stringWithFormat:@"（%@）",coinPrice.coinprice_nickname];
    }else{
        self.chineseLab.text = @"";
    }
    
    if (![coinPrice.coinprice_sid isEqualToString:@""]) {
        self.sidLab.text = coinPrice.coinprice_sid;
    }
    else
    {
        self.sidLab.text = coinPrice.coinprice_sid;
    }
    
    if (![coinPrice.coinprice_heyueAddress isEqualToString:@""]) {
        self.hyAddress.text = coinPrice.coinprice_heyueAddress;
        
        [self.coinNameLab mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bgIcon.mas_right).with.offset(7);
            make.top.equalTo(self.contentView).offset(10);
        }];
    }else{
        [self.coinNameLab mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bgIcon.mas_right).with.offset(7);
            make.top.equalTo(self.contentView).offset(19);
        }];

    }
}

- (void)setSearchDic:(NSDictionary *)searchDic
{
    _searchDic = searchDic;
    
    if (!IS_BLANK(searchDic[@"optional_name"])) {
        self.coinNameLab.text = searchDic[@"optional_name"];
    }else{
        self.coinNameLab.text = searchDic[@"name"];
    }
    
    if (IS_BLANK(searchDic[@"sid"])) {
        self.sidLab.text = @"";
    } else {
        self.sidLab.text = searchDic[@"sid"];
    }
    
    // 图标：没有（或类型不对）时用「币种名首字母 + 色底圆」占位，有图标时也用它垫底
    NSString *iconURL = [searchDic[@"icon"] isKindOfClass:[NSString class]] ? searchDic[@"icon"] : nil;
    UIImage *placeholderIcon = [CommonFunction coinPlaceholderImageWithName:self.coinNameLab.text diameter:32];
    if (iconURL.length == 0)
    {
        [self.coinIcon sd_cancelCurrentImageLoad];
        self.coinIcon.image = placeholderIcon;
    }
    else
    {
        [self.coinIcon sd_setImageWithURL:[NSURL URLWithString:iconURL]
                         placeholderImage:placeholderIcon];
    }
    
    if ([searchDic[@"nickname"] isEqual:[NSNull null]])
    {
        
    }
    else
    {
        if(![searchDic[@"nickname"] isEqualToString:@""])
        {
            self.chineseLab.text = [NSString stringWithFormat:@"(%@)",searchDic[@"nickname"]];
        }
    }
   
    
    for (int i = 0; i < _coinArray.count ; i ++) {
        LocalCoin *coin = [_coinArray objectAtIndex:i];
        
        if([searchDic[@"name"] isEqualToString:coin.coin_type] && coin.coin_show == 1 && [coin.coin_platform isEqualToString:searchDic[@"platform"]]
           && coin.treaty == [_searchDic[@"treaty"] integerValue])
        {
            self.coin = coin;
            [self.switchBtn setOn:YES];
            [self.switchBtn setHidden:YES];
            [self.addedLab setHidden:NO];
            return;
        }
    }
    
    [self.switchBtn setOn:NO];
    [self.switchBtn setHidden:NO];
    [self.addedLab setHidden:YES];
    //原来统一处理的逻辑
}

- (void)swhClick:(PWSwitchView *)swh
{
    
    CoinPrice *coinPrice = [[CoinPrice alloc] init];
    if(_searchDic != nil)
    {
        coinPrice.coinprice_name = _searchDic[@"name"];
        coinPrice.coinprice_price = 0;
        coinPrice.coinprice_icon = _searchDic[@"icon"];
        coinPrice.coinprice_sid = _searchDic[@"sid"];
        coinPrice.coinprice_nickname = _searchDic[@"nickname"];
        coinPrice.coinprice_id = [_searchDic[@"id"] integerValue];
        coinPrice.coinprice_chain = _searchDic[@"chain"];
        coinPrice.coinprice_platform = _searchDic[@"platform"];
        coinPrice.coinprice_heyueAddress = _searchDic[@"contract_address"];
        coinPrice.treaty = [_searchDic[@"treaty"] integerValue];
        coinPrice.coinprice_optional_name = _searchDic[@"optional_name"];
        self.selectTemCoin(coinPrice,swh.isOn);
        return;
    }
  // 添加币种，判断主链币的添加
    NSArray *localCoinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    NSMutableArray *chainMarray = [[NSMutableArray alloc] init];
    for (LocalCoin *coin in localCoinArray) {
        [chainMarray addObject:coin.coin_chain == nil ? coin.coin_type : coin.coin_chain];
        if ([self.coin.coin_chain isEqualToString:coin.coin_chain])
        {
            self.coin.coin_address = coin.coin_address;
        }
    }
        
    if ([chainMarray containsObject:self.coin.coin_chain == nil ? self.coin.coin_type : self.coin.coin_chain])
    {
        BOOL isOn = swh.isOn;
        if (isOn)
        {
            if(self.coin == nil)
            {
                return;
            }
            else
            {
                self.coin.coin_show = 1;
            }
        }
        else
        {
            self.coin.coin_show = 0;
        }
        [[PWDataBaseManager shared] updateCoin:self.coin];
    }
    else
    {
        self.addCoin(self.coin,swh.isOn);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeleteWalletNotification object:nil userInfo:nil];
    
}


@end
