//
//  WebCollectionViewCell.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "WebCollectionViewCell.h"
#import "PWApplication.h"
#import "UIView+AddHiglightGesture.h"
#import "Depend.h"
@interface WebCollectionViewCell()
@property(nonatomic,strong)UIImageView* webIcon;
@property(nonatomic,strong)UILabel* titleLab;
@end
@implementation WebCollectionViewCell
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        @weakify(self)
        [self.contentView addTapAndLongPressWith:^{
            @strongify(self)
            self.block();
        }];
    }
    return self;
}

- (void)setApp:(PWApplication *)app{
    _app = app;
    [self.webIcon sd_setImageWithURL:[NSURL URLWithString:app.icon]];
    
    self.titleLab.text = app.name;
}

- (UIImageView *)webIcon{
    if (_webIcon == nil) {
        _webIcon = [[UIImageView alloc] init];
        _webIcon.layer.cornerRadius = 8;
        _webIcon.clipsToBounds = YES;
        [self.contentView addSubview:_webIcon];
        [_webIcon mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.contentView);
            make.top.mas_equalTo(9);
            make.width.height.mas_equalTo(52*kScreenRatio);
        }];
    }
    return _webIcon;
}
- (UILabel *)titleLab{
    if (_titleLab == nil) {
        _titleLab = [[UILabel alloc] init];
        _titleLab.textColor = CMColorFromRGB(0x333649);
        _titleLab.font = [UIFont systemFontOfSize:13];
        _titleLab.numberOfLines = 1;
        _titleLab.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_titleLab];
        [_titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.contentView);
            make.top.equalTo(self.webIcon.mas_bottom).offset(5);
            //限制标题最多显示五个字
            make.width.mas_lessThanOrEqualTo(70);
        }];
    }
    return _titleLab;
}
@end
