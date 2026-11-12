//
//  ExploreNewCell.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/12/22.
//  Copyright © 2022 fzm. All rights reserved.
//

#import "ExploreNewCell.h"
#import "Depend.h"
@implementation ExploreNewCell

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
    self = [super initWithStyle: style reuseIdentifier:reuseIdentifier];
    if(self){
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        [self initView];
    }
    return self;
}

- (void)initView
{
    _contentImgView = [[UIImageView alloc] init];
    _contentImgView.contentMode = UIViewContentModeScaleToFill;
    
    [self.contentView addSubview:_contentImgView];
    
    _titleLab = [UILabel getLabWithFont:[UIFont boldSystemFontOfSize:20]
                              textColor:UIColor.whiteColor
                          textAlignment:NSTextAlignmentRight
                                   text:@""];
    
//    [_toBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 0, 0, -10)];
//    [_toBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    
    [self.contentView addSubview:_titleLab];
    
    [_contentImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.height.mas_equalTo(140);
        make.top.equalTo(self.contentView);
    }];
    
    [_titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-34);
        make.height.mas_equalTo(28);
        make.bottom.equalTo(self.contentView).offset(-17);
    }];
}



@end
