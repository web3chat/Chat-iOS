//
//  DappSheetCell.m
//  PWallet
//
//  Created by 郑晨 on 2021/5/27.
//  Copyright © 2021 fzm. All rights reserved.
//

#import "DappSheetCell.h"
#import "Depend.h"

@implementation DappSheetCell

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
        self.backgroundColor = UIColor.whiteColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self initView];
    }
    
    return self;
}

- (void)initView
{
    [self.contentView addSubview:self.contentsView];
    [self.contentsView addSubview:self.titleLab];
    [self.contentsView addSubview:self.subtitleLab];
    [self.contentsView addSubview:self.toBtn];
    
    [self.contentsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(12);
        make.top.equalTo(self.contentsView).offset(17);
        make.width.mas_equalTo(55);
        make.height.mas_equalTo(18);
    }];
    
    [self.subtitleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(80);
        make.top.equalTo(self.contentsView).offset(8);
        make.right.equalTo(self.contentsView).offset(-9);
        make.height.mas_equalTo(51);
    }];
    
   
    [self.toBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentsView).offset(-10);
        make.width.height.mas_equalTo(20);
        make.top.equalTo(self.contentsView).offset(15);
    }];
    
}

#pragma mark - getter and setter

- (UIView *)contentsView
{
    if (!_contentsView) {
        _contentsView = [[UIView alloc] init];
        _contentsView.backgroundColor = UIColor.whiteColor;

    }
    
    return _contentsView;
}

- (UILabel *)titleLab
{
    if (!_titleLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x8492a3);
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        
        _titleLab = lab;
    }
    return _titleLab;
}

- (UILabel *)subtitleLab
{
    if (!_subtitleLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.numberOfLines = 0;
        
        _subtitleLab = lab;
    }
    return _subtitleLab;
}


- (UIButton *)toBtn
{
    if (!_toBtn) {
        UIButton *btn = [[UIButton alloc] init];
        [btn setImage:[UIImage imageNamed:@"accessory"] forState:UIControlStateNormal];
        
        _toBtn = btn;
    }
    
    return _toBtn;
}

@end
