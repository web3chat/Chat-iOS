//
//  HistoryWebSiteCell.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/12/22.
//  Copyright © 2022 fzm. All rights reserved.
//

#import "HistoryWebSiteCell.h"
#import "Depend.h"

@implementation HistoryWebSiteCell

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
    
    if(self){
        self.backgroundColor = UIColor.whiteColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        [self initView];
    }
    return self;
}

- (void)initView
{
    _titleLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:12]
                              textColor:SGColorFromRGB(0x333649)
                          textAlignment:NSTextAlignmentLeft
                                   text:@""];
    
    [self.contentView addSubview:self.titleLab];
    
    _deleteBtn = [[UIButton alloc] init];
    [_deleteBtn setImage:[UIImage imageNamed:@"叉叉"] forState:UIControlStateNormal];
    [_deleteBtn addTarget:self action:@selector(deleteHis:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView addSubview:self.deleteBtn];
    
    _lineView = [[UIView alloc] init];
    _lineView.backgroundColor = LineColor;
    
    [self.contentView addSubview:self.lineView];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.top.equalTo(self.contentView).offset(12);
        make.height.mas_equalTo(20);
    }];
    
    [self.deleteBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-16);
        make.top.equalTo(self.contentView).offset(15);
        make.width.height.mas_equalTo(14);
    }];
    
    [self.lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.contentView);
        make.height.mas_equalTo(.5);
        
    }];
}

- (void)deleteHis:(UIButton *)sender
{
    if(self.deleteBlock){
        self.deleteBlock(self);
    }
}

@end
