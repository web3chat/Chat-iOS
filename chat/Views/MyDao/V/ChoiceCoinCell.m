//
//  ChoiceCoinCell.m
//  chat
//
//  Created by 郑晨 on 2025/3/5.
//

#import "ChoiceCoinCell.h"
#import "Depend.h"

@implementation ChoiceCoinCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    self =  [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        [self initView];
    }
    
    return self;
}

- (void)initView
{
    UIImageView *coinIcon = [[UIImageView alloc] init];
    coinIcon.layer.cornerRadius = 17;
    coinIcon.layer.masksToBounds = YES;
    [self.contentView addSubview:coinIcon];
    self.iconImageView = coinIcon;

    UILabel *coinNameLab = [[UILabel alloc] init];
    coinNameLab.textColor = CMColor(51, 51, 51);
    coinNameLab.font = [UIFont boldSystemFontOfSize:18];
    coinNameLab.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:coinNameLab];
    self.coinTypeLab = coinNameLab;

    UILabel *balanceLab = [[UILabel alloc] init];
    balanceLab.textColor = CMColor(153, 153, 153);
    balanceLab.font = [UIFont systemFontOfSize:14];
    balanceLab.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:balanceLab];
    self.balanceLab = balanceLab;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    [self.iconImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(32);
        make.left.equalTo(self.contentView).with.offset(13);
        make.centerY.equalTo(self.contentView);
    }];

    [self.coinTypeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.iconImageView.mas_right).with.offset(10);
        make.top.equalTo(self.iconImageView).offset(-2);
    }];
    
    [self.balanceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.coinTypeLab.mas_bottom).offset(5);
        make.left.equalTo(self.coinTypeLab);
    }];
}

- (void)setCoin:(LocalCoin *)coin
{
    _coin = [coin copy];
    //如果没有可选名用币名
    self.coinTypeLab.text = coin.coin_type;
    [self.iconImageView sd_setImageWithURL:[NSURL URLWithString:coin.icon]];
    self.balanceLab.text = [CommonFunction removeZeroFromMoney:[CommonFunction removeZeroFromMoney:coin.coin_balance withMaxLength:6]];

}

@end
