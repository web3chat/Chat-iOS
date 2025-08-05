//
//  PWNoCoinViewCell.m
//  PWallet
//
//  Created by 杨威 on 2019/12/23.
//  Copyright © 2019 陈健. All rights reserved.
//

#import "PWNoCoinViewCell.h"
#import "Depend.h"

@interface PWNoCoinViewCell()
//上链通背景
@property (nonatomic, weak) UIImageView *bgView;
@property (nonatomic, weak) UILabel *bgLabel;
@end


@implementation PWNoCoinViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeLanguage) name:kChangeLanguageNotification object:nil];
    if (self) {
        self.backgroundColor = SGColorRGBA(247, 247, 251, 1);
        [self showNoCoinView];
        return self;
    }
    return nil;
}

- (void)changeLanguage{
    NSString *artText=@"暂无资产，快去添加吧";
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    NSMutableAttributedString *artString = [[NSMutableAttributedString alloc] initWithString:artText attributes: @{NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Regular" size:14],NSForegroundColorAttributeName: [UIColor colorWithRed:142/255.0 green:146/255.0 blue:163/255.0 alpha:1.0],NSParagraphStyleAttributeName:paragraphStyle}];
    self.bgLabel.attributedText = artString;
}

-(void)showNoCoinView{
    UIImageView *view= [[UIImageView alloc] init];
    self.bgView=view;
    [self.contentView addSubview:view];
    view.image=[UIImage imageNamed:@"no_coin"];
    [view mas_makeConstraints:^(MASConstraintMaker *make){
        make.width.mas_equalTo(95);
        make.height.mas_equalTo(94);
        make.centerX.equalTo(self.contentView);
        make.centerY.equalTo(self.contentView).offset(-100);
    }];
    
    UILabel *label= [[UILabel alloc] init];
    self.bgLabel=label;
    [self.contentView addSubview:label];
    NSString *artText=@"暂无资产，快去添加吧";
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    NSMutableAttributedString *artString = [[NSMutableAttributedString alloc] initWithString:artText attributes: @{NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Regular" size:14],NSForegroundColorAttributeName: [UIColor colorWithRed:142/255.0 green:146/255.0 blue:163/255.0 alpha:1.0],NSParagraphStyleAttributeName:paragraphStyle}];
    label.attributedText = artString;
    label.textAlignment = NSTextAlignmentCenter;
    [label mas_makeConstraints:^(MASConstraintMaker *make){
        make.width.mas_equalTo(150);
        make.height.mas_equalTo(20);
        make.top.equalTo(self.bgView.mas_bottom).offset(30);
        make.centerX.equalTo(self.bgView.mas_centerX);
    }];
}


@end
