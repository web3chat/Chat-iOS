//
//  PWHotSubTableViewCell.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//  
//

#import "PWHotSubTableViewCell.h"
#import "Depend.h"
@interface PWHotSubTableViewCell ()

@property(nonatomic,strong)UIImageView *logoImgView;
@property(nonatomic,strong)UILabel *nameLabel;
@property(nonatomic,strong)UILabel *inforLabel;

@end

@implementation PWHotSubTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self createViews];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setModel:(PWApplication *)model{
    _model = model;
    [self.logoImgView sd_setImageWithURL:[NSURL URLWithString:model.icon]];
    if (model.name.length > 25) {
        self.nameLabel.text = [model.name substringToIndex:25];
    }else{
        self.nameLabel.text = model.name;
    }
    
    if (model.advertise.length > 25) {
        self.inforLabel.text = [model.advertise substringToIndex:25];
    }else{
        self.inforLabel.text = model.advertise;
    }
}

- (void)createViews{
    [self.contentView addSubview:self.logoImgView];
    [self.contentView addSubview:self.nameLabel];
    [self.contentView addSubview:self.inforLabel];
    [self.logoImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self);
        make.left.mas_offset(18 * kScreenRatio);
        make.width.height.mas_offset(39 * kScreenRatio);
    }];
    
    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.logoImgView.mas_top).offset(1 * kScreenRatio);
        make.left.equalTo(self.logoImgView.mas_right).offset(8 * kScreenRatio);
    }];
    
    [self.inforLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.nameLabel.mas_bottom).offset(5 * kScreenRatio);
        make.leading.equalTo(self.nameLabel);
    }];
}

- (UIImageView *)logoImgView{
    if (_logoImgView == nil) {
        _logoImgView = [[UIImageView alloc]init];
        _logoImgView.image = [UIImage imageNamed:@"appiconcopy"];
        _logoImgView.userInteractionEnabled = YES;
        _logoImgView.layer.masksToBounds = YES;
        _logoImgView.layer.cornerRadius = 8;
    }
    return _logoImgView;
}

- (UILabel *)nameLabel{
    if (_nameLabel == nil) {
        _nameLabel = [[UILabel alloc]init];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.font = [UIFont boldSystemFontOfSize:13];
        _nameLabel.text = @"";
        _nameLabel.userInteractionEnabled = YES;
    }
    return _nameLabel;
}

- (UILabel *)inforLabel{
    if (_inforLabel == nil) {
        _inforLabel = [[UILabel alloc]init];
        _inforLabel.textColor = [UIColor whiteColor];
        _inforLabel.font = [UIFont systemFontOfSize:10];
        _inforLabel.text = @"";
        _inforLabel.userInteractionEnabled = YES;
    }
    return _inforLabel;
}




@end
