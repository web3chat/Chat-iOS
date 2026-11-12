//
//  ExploreCell.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "ExploreCell.h"
#import "PWApplication.h"
#import "UIView+AddHiglightGesture.h"
#import "Depend.h"
@interface ExploreCell()
@property(nonatomic,strong) UIImageView* webImageView;
@property(nonatomic,strong) UILabel* titleLabel;
@property(nonatomic,strong) UILabel* detailLabel;
@property(nonatomic,strong) UIImageView* rightJT;
//@property(nonatomic,strong) UIView* translucenceView;
@end
@implementation ExploreCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.whiteColor;
        [self createView];
       WEAKSELF
        [self.contentView addTapAndLongPressWith:^{
            weakSelf.block();
        }];
    }
    return self;
}

- (void)createView{
    self.rightJT = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"exploreJT"]];
    [self.contentView addSubview:self.rightJT];
    [self.rightJT mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(-20);
        make.centerY.equalTo(self.contentView);
    }];
}

-(void)setValueWithApp:(PWApplication*)app{
    self.titleLabel.text = app.name;
    [self.webImageView sd_setImageWithURL:[NSURL URLWithString:app.icon]];
    self.detailLabel.text = app.advertise;
    
}

- (UIImageView *)webImageView{
    if (_webImageView == nil) {
        _webImageView = [[UIImageView alloc] init];
        _webImageView.layer.cornerRadius = 8;
        _webImageView.clipsToBounds = YES;
        [self.contentView addSubview:_webImageView];
        [_webImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(20);
            make.centerY.equalTo(self.contentView);
            make.width.height.mas_equalTo(52*kScreenRatio);
        }];
    }
    return _webImageView;
}

- (UILabel *)titleLabel{
    if (_titleLabel == nil) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:16];
        _titleLabel.textColor = CMColorFromRGB(0x333649);
        [self.contentView addSubview:_titleLabel];
        [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.webImageView.mas_right).offset(14);
            make.right.mas_lessThanOrEqualTo(@-30);
            make.top.equalTo(self.webImageView.mas_top).offset(2);
            make.height.mas_equalTo(22);
        }];
    }
    
    return _titleLabel;
}

- (UILabel *)detailLabel{
    if (_detailLabel == nil) {
        _detailLabel = [[UILabel alloc] init];
        _detailLabel.font = [UIFont systemFontOfSize:13];
        _detailLabel.textColor = CMColorFromRGB(0x8E92A3);
        _detailLabel.numberOfLines = 2;
        [self.contentView addSubview:_detailLabel];
        [_detailLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.webImageView.mas_right).offset(14);
            make.right.mas_lessThanOrEqualTo(@-30);
            make.top.equalTo(self.titleLabel.mas_bottom).offset(6);
            make.height.greaterThanOrEqualTo(@18);
        }];
    }
    
    return _detailLabel;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

}
@end
