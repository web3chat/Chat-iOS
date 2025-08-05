//
//  PWActionCell.m
//  PWallet
//
//  Created by 郑晨 on 2019/12/10.
//  Copyright © 2019 陈健. All rights reserved.
//

#import "PWActionCell.h"
#import "PWDataBaseManager.h"
#import "Depend.h"

@implementation PWActionCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.whiteColor;

        [self createView];
    }
    return self;
}

- (void)createView
{
    [self.contentView addSubview:self.iconImageView];
    [self.contentView addSubview:self.titleLab];
    [self.contentView addSubview:self.addressLab];
    [self.contentView addSubview:self.balanceLab];
    [self.contentView addSubview:self.priceLab];
    [self.contentView addSubview:self.lineView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.iconImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(17);
        make.top.equalTo(self.contentView).with.offset(17);
        make.width.height.mas_equalTo(28);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.iconImageView.mas_right).offset(12);
        make.top.equalTo(self.contentView).offset(20);
        make.height.mas_equalTo(22);
    }];
    
    [self.addressLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLab);
        make.top.equalTo(self.titleLab.mas_bottom);
        make.height.mas_equalTo(17);
        make.width.mas_equalTo(224);
    }];
    
    [self.balanceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-16);
        make.top.equalTo(self.contentView).offset(13);
        make.height.mas_equalTo(20);
    }];
    
    [self.priceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.balanceLab);
        make.top.equalTo(self.balanceLab.mas_bottom).offset(1);
        make.height.mas_equalTo(17);
    }];
    
    [self.lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.contentView);
        make.height.mas_equalTo(.5f);
    }];
}


- (void)setCoin:(LocalCoin *)coin
{
    _coin = coin;
    switch (_actionViewType) {
        case ActionViewTypeHome:
        {
            self.balanceLab.text = [CommonFunction removeZeroFromMoney:coin.coin_balance withMaxLength:6];
            self.addressLab.hidden = YES;
            self.priceLab.hidden = NO;
            self.balanceLab.hidden = NO;
            [self.iconImageView sd_setImageWithURL:[NSURL URLWithString:_coin.icon]];
            NSString *nickNameStr = @"";
            if ([_coinPrice.coinprice_nickname isEqual:[NSNull null]]) {
                
            }
            else
            {
                nickNameStr = [NSString stringWithFormat:@"%@",_coin.coin_type];
            }
            
            //如果有可选名用可选名
            
            self.titleLab.text = [NSString stringWithFormat:@"%@(%@)",_coin.coin_type,nickNameStr];
            if (nickNameStr.length > 0) {
                self.titleLab.attributedText = [PWUtils getAttritubeStringWithString:self.titleLab.text
                                                                        andChangeStr:[NSString stringWithFormat:@"(%@)",nickNameStr]
                                                                             andFont:[UIFont systemFontOfSize:12.f]
                                                                            andColor:SGColorFromRGB(0x333649)];
            }
            else
            {
                self.titleLab.text = [NSString stringWithFormat:@"%@",_coin.coin_type];
            }
            
            
            
            self.priceLab.text = [NSString stringWithFormat:@"≈%@%@",@"0",@"0"];
        }
            break;
        case ActionViewTypePrikey:
        {
            self.addressLab.hidden = NO;
            self.priceLab.hidden = YES;
            self.balanceLab.hidden = YES;
            self.titleLab.text = coin.coin_type;
            
            NSString *nickName = @"";
            nickName = _coin.coin_type;
            
            if (nickName.length == 0)
            {
                self.titleLab.text = coin.coin_type;
            }
            else
            {
                NSMutableAttributedString * firstPart = [[NSMutableAttributedString alloc] initWithString:[coin.coin_type stringByAppendingString:@"."]];
                NSDictionary * firstAttributes = @{};
                [firstPart setAttributes:firstAttributes range:NSMakeRange(0,firstPart.length)];
                
                NSMutableAttributedString *secondPart = [[NSMutableAttributedString alloc] initWithString:nickName];
                [secondPart addAttributes:@{NSFontAttributeName : [UIFont systemFontOfSize:12.f],NSForegroundColorAttributeName : SGColorFromRGB(0x333649)} range:NSMakeRange(0,secondPart.length)];
                
                [firstPart appendAttributedString:secondPart];
                self.titleLab.attributedText=firstPart;
            }
            
            [self.iconImageView sd_setImageWithURL:[NSURL URLWithString:_coin.icon]];
            self.addressLab.text = _coin.coin_address;
        }
            break;
        default:
            break;
    }
}

- (void)setCoinPrice:(CoinPrice *)coinPrice
{
    self.addressLab.hidden = YES;
    self.priceLab.hidden = NO;
    self.balanceLab.hidden = NO;
    _coinPrice = coinPrice;
    [self.iconImageView sd_setImageWithURL:[NSURL URLWithString:_coin.icon]];
    NSString *nickNameStr = @"";
    if ([_coinPrice.coinprice_nickname isEqual:[NSNull null]]) {
       // do nothing
    }
    else
    {
        nickNameStr = [NSString stringWithFormat:@"%@",_coinPrice.coinprice_nickname];
    }
    
    //如果有可选名用可选名
    
    self.titleLab.text = [NSString stringWithFormat:@"%@(%@)",_coinPrice.coinprice_optional_name,nickNameStr];
    if (nickNameStr.length > 0) {
        self.titleLab.attributedText = [PWUtils getAttritubeStringWithString:self.titleLab.text
                                                                andChangeStr:[NSString stringWithFormat:@"(%@)",nickNameStr]
                                                                     andFont:[UIFont systemFontOfSize:12.f]
                                                                    andColor:SGColorFromRGB(0x333649)];
    }
    else
    {
         self.titleLab.text = [NSString stringWithFormat:@"%@",_coinPrice.coinprice_optional_name];
    }
        
    
    
    NSString* rmbText = [CommonFunction removeZeroFromMoney:coinPrice.coinprice_country_rate * _coin.coin_balance withMaxLength:2];
       self.priceLab.text = [NSString stringWithFormat:@"≈%@%@",@"0",rmbText];
   
    
}

#pragma mark - getter and setter
- (UIImageView *)iconImageView
{
    if (!_iconImageView) {
        _iconImageView = [[UIImageView alloc] init];
    }
    return _iconImageView;
}

- (UILabel *)titleLab
{
    if (!_titleLab) {
        _titleLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:16.f]
                                  textColor:SGColorFromRGB(0x333649)
                              textAlignment:NSTextAlignmentLeft
                                       text:@""];
        
    }
    return _titleLab;
}

- (UILabel *)balanceLab
{
    if (!_balanceLab) {
        _balanceLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:14.f]
                                   textColor:SGColorFromRGB(0x7190ff)
                               textAlignment:NSTextAlignmentRight
                                        text:@""];
        
    }
    return _balanceLab;
}

- (UILabel *)priceLab
{
    if (!_priceLab) {
        _priceLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:12.f]
                                  textColor:SGColorFromRGB(0x8e92a3)
                              textAlignment:NSTextAlignmentRight
                                       text:@""];
    }
    
    return _priceLab;
}

- (UIView *)lineView
{
    if (!_lineView) {
        _lineView = [[UIView alloc] init];
        _lineView.backgroundColor = SGColorFromRGB(0xd9dce9);
    }
    return _lineView;
}

- (UILabel *)addressLab
{
    if (!_addressLab) {
        _addressLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:12.f]
                                    textColor:SGColorFromRGB(0x8e92a3)
                                textAlignment:NSTextAlignmentLeft
                                         text:@""];
        _addressLab.lineBreakMode = NSLineBreakByTruncatingMiddle;
    }
    return _addressLab;
}

@end
