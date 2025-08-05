//
//  CoinDetailView.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "CoinDetailView.h"
#import "Depend.h"
#import "chat-Swift.h"

@interface CoinDetailView()
@property (nonatomic,strong)UIImageView *bgIcon;
@property (nonatomic,strong)UIImageView *backgroundImage;
@property (nonatomic,strong)UILabel *coinNameLab;
@property (nonatomic,strong)UILabel *addressLab;
@property (nonatomic,weak) UIButton *cAddressBtn;
@property (nonatomic, strong) UILabel *cPlatformLab;
@property (nonatomic, strong) NSString *nftUrl;

@end

@implementation CoinDetailView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self createView];
    }
    return self;
}

- (void)createView
{
    UIImageView *backgroundImage = [[UIImageView alloc] init];
    [backgroundImage setImage:[UIImage imageNamed:@"Rectangle45"]];
    [self addSubview:backgroundImage];
    backgroundImage.userInteractionEnabled = true;
    backgroundImage.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImage = backgroundImage;
    
    UIImageView *coinImage = [[UIImageView alloc] init];
    coinImage.layer.cornerRadius = 13;
    coinImage.layer.masksToBounds = YES;
    [backgroundImage addSubview:coinImage];
    self.coinImage = coinImage;
    
    UILabel *balanceLab = [[UILabel alloc] init];
    balanceLab.textAlignment = NSTextAlignmentLeft;
    balanceLab.font = kPUBLICNUMBERFONT_SIZE(28);
    balanceLab.textColor = CMColor(51, 54, 73);
    [backgroundImage addSubview:balanceLab];
    self.balanceLab = balanceLab;
    
    UILabel *coinNameLab = [[UILabel alloc] init];
    coinNameLab.textAlignment = NSTextAlignmentLeft;
    coinNameLab.textColor =  CMColor(51, 54, 73);
    coinNameLab.font = [UIFont boldSystemFontOfSize:14];
    [backgroundImage addSubview:coinNameLab];
    self.coinNameLab = coinNameLab;
    
    UILabel *rmbLab = [[UILabel alloc] init];
    rmbLab.textColor = CMColor(142, 146, 163);
    rmbLab.font = kPUBLICNUMBERFONT_SIZE(20);
    rmbLab.textAlignment = NSTextAlignmentLeft;
    [backgroundImage addSubview:rmbLab];
    self.rmbLab = rmbLab;
    
    UILabel *addressLab = [[UILabel alloc] init];
    addressLab.textColor = CMColor(142, 146, 163);
    addressLab.font = CMTextFont14;
    addressLab.lineBreakMode = NSLineBreakByTruncatingMiddle;
    addressLab.textAlignment = NSTextAlignmentLeft;
    [backgroundImage addSubview:addressLab];
    self.addressLab = addressLab;
    
    YYAnimatedImageView *animatedImgView = [[YYAnimatedImageView alloc] init];
    animatedImgView.contentMode = UIViewContentModeScaleAspectFit;
    animatedImgView.backgroundColor = SGColorFromRGB(0xf8f8f8);
    [backgroundImage addSubview:animatedImgView];
    self.animatedImageView = animatedImgView;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickNft:)];
    tap.numberOfTapsRequired = 1;
    [self.animatedImageView addGestureRecognizer:tap];
    self.animatedImageView.userInteractionEnabled = YES;
    
    //二维码按钮
    UIButton *qrCodeBtn = [[UIButton alloc]init];
    [backgroundImage addSubview:qrCodeBtn];
    qrCodeBtn.layer.cornerRadius = 3;
    qrCodeBtn.layer.borderColor = SGColorRGBA(217, 220, 233, 1).CGColor;
    qrCodeBtn.layer.borderWidth = 0.5;
    qrCodeBtn.layer.masksToBounds = true;
    [qrCodeBtn addTarget:self action:@selector(qrCodeBtnPress:) forControlEvents:UIControlEventTouchUpInside];
    self.qrCodeBtn = qrCodeBtn;
    
    //复制按钮
    UIButton *copyAddressBtn = [[UIButton alloc]init];
    [backgroundImage addSubview:copyAddressBtn];
    [copyAddressBtn setImage:[UIImage imageNamed:@"复制2"] forState:UIControlStateNormal];
    [copyAddressBtn setImage:[UIImage imageNamed:@"复制2"] forState:UIControlStateHighlighted];
    [copyAddressBtn addTarget:self action:@selector(copyAddressBtnPress:) forControlEvents:UIControlEventTouchUpInside];
    self.cAddressBtn = copyAddressBtn;

    
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self.backgroundImage mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self);
        make.top.equalTo(self).offset(25);
    }];
    
    [self.coinImage mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(25);
        make.top.equalTo(self).offset(35 + 25);
        make.width.height.mas_equalTo(26);
    }];
    
    [self.balanceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.coinImage).offset(-2);
        make.left.equalTo(self.coinImage.mas_right).with.offset(3);
        make.height.mas_equalTo(32);
    }];
    
    [self.coinNameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.balanceLab.mas_right);
        make.bottom.equalTo(self.balanceLab).with.offset(-2);
    }];
    
    [self.animatedImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.balanceLab).offset(-4);
        make.right.equalTo(self.backgroundImage).offset(-25);
        make.height.width.mas_equalTo(70);
    }];
    [self.qrCodeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.balanceLab).offset(-4);
        make.right.equalTo(self.backgroundImage).offset(-25);
        make.height.width.mas_equalTo(70);
    }];
    
    [self.addressLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coinImage);
        make.right.equalTo(self.qrCodeBtn.mas_left).offset(-20);
        make.top.equalTo(self.balanceLab.mas_bottom).with.offset(11);
    }];
    
    [self.cAddressBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(12);
        make.height.mas_equalTo(14);
        make.left.equalTo(self.addressLab.mas_right).offset(3);
        make.centerY.equalTo(self.addressLab);
    }];
    
}

- (void)setCoin:(LocalCoin *)coin
{
    _coin = coin;
    CoinPrice *coinPrice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coin.coin_type platform:coin.coin_platform andTreaty:coin.treaty];
    
    CGFloat amount = 0.00;
    amount = coin.coin_balance * coinPrice.coinprice_country_rate;
    [self.coinImage sd_setImageWithURL:[NSURL URLWithString:coinPrice.coinprice_icon]];

    self.cPlatformLab.text = [NSString stringWithFormat:@"%@",coin.coin_platform];
    
    self.rmbLab.text = @"";

        
    self.addressLab.text = coin.coin_address;
    if (_coin.coin_type_nft == 1) {
        self.qrCodeBtn.hidden = YES;
        self.animatedImageView.hidden = NO;
//        if (self.nftUrl.length != 0) {
//            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:self.nftUrl]];
//            YYImage *img = [YYImage imageWithData:data];
//            self.animatedImageView.image = img;
//        }else{
//            [self queryNFTUrlWithCoinPrice:coinPrice];
//        }
        
    }else{
        self.animatedImageView.hidden = YES;
        self.qrCodeBtn.hidden = NO;
        BlockchainTool *tool = [[BlockchainTool alloc] init];
        NSString *targetStr = [tool getSessionId];
        NSString *platform = _coin.coin_platform;
        NSString *coinType = _coin.coin_type;
        if ([coinType isEqualToString:@"BTY"]) {
            platform = @"bty";
        }
        
        NSString *qrcodeStr = [NSString stringWithFormat:@"%@?transfer_target=%@&address=%@&chain=%@&platform=%@",@"http://54.248.215.15:8058",targetStr,coin.coin_address,coinType,platform];
        
        [self.qrCodeBtn setImage:[CommonFunction createImgQRCodeWithString:qrcodeStr centerImage:self.coinImage.image] forState:UIControlStateNormal];
        [self.qrCodeBtn setImage:[CommonFunction createImgQRCodeWithString:qrcodeStr centerImage:self.coinImage.image] forState:UIControlStateHighlighted];
    }
    

    NSString *balanceStr = [CommonFunction removeZeroFromMoney:[CommonFunction removeZeroFromMoney:coin.coin_balance withMaxLength:6]];
    self.balanceLab.text = [NSString stringWithFormat:@"%@",balanceStr];
    self.coinNameLab.text = IS_BLANK(coinPrice.coinprice_optional_name) ? coin.coin_type : coinPrice.coinprice_optional_name;
}






//button点击
- (void)copyAddressBtnPress:(UIButton*)sender {
    if (self.copyAddressBlock) {
        self.copyAddressBlock(self.coin.coin_address);
    }
}

- (void)qrCodeBtnPress:(UIButton*)sender {

    if (self.qrCodeBlock) {
        self.qrCodeBlock(sender.imageView);
    }
}
- (void)clickNft:(id)sender
{
    if (self.nfturlBlock) {
        self.nfturlBlock();
    }
}

@end
