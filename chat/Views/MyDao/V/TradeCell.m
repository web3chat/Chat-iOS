//
//  TradeCell.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "TradeCell.h"
#import "Depend.h"

@interface TradeCell()
@property (nonatomic,strong) UILabel *moneyLab;
@property (nonatomic,strong) UILabel *stateLab;
@property (nonatomic,strong) UIButton *addressBtn;
@property (nonatomic,strong) UILabel *timeLab;
@property (nonatomic,strong) YYLabel *nameLab;
@end

@implementation TradeCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self createView];
        self.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

- (void)createView
{
    UILabel *moneyLab = [[UILabel alloc] init];
    moneyLab.textColor = TextColor51;
    moneyLab.font = CMTextFont18;
    moneyLab.textAlignment = NSTextAlignmentLeft;
    moneyLab.text = @"";
    [self addSubview:moneyLab];
    self.moneyLab = moneyLab;
    
    UILabel *stateLab = [[UILabel alloc] init];
    stateLab.textColor = PlaceHolderColor;
    stateLab.font = CMTextFont14;
    stateLab.textAlignment = NSTextAlignmentRight;
    stateLab.text = @"";
    [self addSubview:stateLab];
    self.stateLab = stateLab;
    
    UIButton *addressBtn = [[UIButton alloc] init];
    [addressBtn setTitle:@"" forState:UIControlStateNormal];
    [addressBtn setTitleColor:PlaceHolderColor forState:UIControlStateNormal];
    addressBtn.titleLabel.font = CMTextFont14;
    addressBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self addSubview:addressBtn];
    self.addressBtn = addressBtn;
    
    YYLabel *nameLab = [[YYLabel alloc] init];
    nameLab.textColor = SGColorRGBA(51, 54, 73, 1);
    nameLab.backgroundColor = SGColorRGBA(216, 225, 255, 1);
    nameLab.layer.cornerRadius = 3;
    nameLab.layer.masksToBounds = true;
    nameLab.font = CMTextFont12;
    nameLab.textContainerInset = UIEdgeInsetsMake(3, 8, 0, 8);
    [self addSubview:nameLab];
    self.nameLab = nameLab;
    [nameLab setHidden:YES];
    
    UILabel *timeLab = [[UILabel alloc] init];
    timeLab.text = @"";
    timeLab.font = CMTextFont13;
    timeLab.textColor = PlaceHolderColor;
    timeLab.textAlignment = NSTextAlignmentRight;
    [self addSubview:timeLab];
    self.timeLab = timeLab;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.moneyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(19);
        make.top.equalTo(self).with.offset(15);
        make.height.mas_equalTo(25);
    }];
    
    [self.nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.moneyLab.mas_right).with.offset(19);
        make.centerY.equalTo(self.moneyLab);
        make.height.mas_equalTo(22);
        
    }];

    [self.stateLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.moneyLab.mas_centerY);
        make.right.equalTo(self).with.offset(-19);
        make.height.mas_equalTo(14);
    }];
    
    [self.addressBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(19);
        make.top.equalTo(self.moneyLab.mas_bottom).with.offset(5);
        make.height.mas_equalTo(17);
    }];
    
    
    [self.timeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self).with.offset(-19);
        make.top.equalTo(self.addressBtn.mas_top);
        make.width.mas_equalTo(150);
        make.height.mas_equalTo(14);
    }];
}

- (void)setOrderModel:(OrderModel *)orderModel
{
    _orderModel = orderModel;
    NSString *coinNumStr = [NSString stringWithFormat:@"%f",orderModel.coinNum];
    
    if ([orderModel.type isEqualToString:@"send"]) {
       
        self.moneyLab.text = [NSString stringWithFormat:@"-%@ %@",[CommonFunction removeZeroFromMoney:coinNumStr],_coin.optional_name];
        
        if ([@"" isEqualToString:orderModel.toAddress]) {
            [self.addressBtn setTitle:orderModel.category_name forState:UIControlStateNormal];
            [self.addressBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.mas_equalTo(250);
            }];
            [self.nameLab setHidden:YES];
        }else{
            [self.addressBtn setTitle:orderModel.toAddress forState:UIControlStateNormal];
            [self.addressBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.mas_equalTo(150);
            }];
        }

    }
    else
    {
        
        self.moneyLab.text = [NSString stringWithFormat:@"+%@ %@",[CommonFunction removeZeroFromMoney:coinNumStr],_coin.optional_name];
        
        if ([@"" isEqualToString:orderModel.fromAddress]) {

            [self.addressBtn setTitle:orderModel.category_name forState:UIControlStateNormal];
            [self.addressBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.mas_equalTo(250);
            }];
            [self.nameLab setHidden:YES];
        }else{
            [self.addressBtn setTitle:orderModel.fromAddress forState:UIControlStateNormal];
            [self.addressBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.mas_equalTo(150);
            }];
        }
    }
    
    NSTimeInterval interval    = [orderModel.time doubleValue];
    NSDate *date               = [NSDate dateWithTimeIntervalSince1970:interval];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy/MM/dd HH:mm"];
    NSString *dateString       = [formatter stringFromDate: date];
    self.timeLab.text = dateString;
    
    if ([orderModel.time isEqual:@(0)]) {
        [self.timeLab setHidden:YES];
    }else
    {
        [self.timeLab setHidden:NO];
    }

    if (orderModel.state == TransferFromStatusFailure) {
        self.stateLab.textColor = SGColorFromRGB(0xec5151);
        self.stateLab.text = @"失败"  ;
    }else if(orderModel.state == TransferFromStatusEnsureing)
    {
        self.stateLab.textColor = SGColorFromRGB(0x7190ff);
        self.stateLab.text = @"确认中"  ;
    }else if (orderModel.state == TransferFromStatusSuccess || orderModel.state == TransferFromStatusSuccess2)
    {
        self.stateLab.textColor = SGColorFromRGB(0x37aec4);
        self.stateLab.text = @"完成"  ;
    }
    
}

- (void)setContactInfoArray:(NSArray *)contactInfoArray
{
//    _contactInfoArray = contactInfoArray;
//     self.nameLab.hidden = YES;
//    if ([_orderModel.type isEqualToString:@"send"])
//    {
//        if (![@"" isEqualToString:_orderModel.toAddress])
//        {
//            for (PWContacts *contacts in contactInfoArray) {
//                for (PWContactsCoin *contactsCoin in contacts.coinArray) {
//                    if ([_orderModel.toAddress isEqualToString:contactsCoin.coinAddress]) {
//                        self.nameLab.text = contacts.nickName;
//                        if (self.nameLab.text.length == 0)
//                        {
//                            self.nameLab.hidden = YES;
//                        }
//                        else
//                        {
//                            self.nameLab.hidden = NO;
//                        }
//                    }
//                }
//            }
//        }
//    }
//    else
//    {
//        if (![@"" isEqualToString:_orderModel.fromAddress])
//        {
//            for (PWContacts *contacts in contactInfoArray) {
//                for (PWContactsCoin *contactsCoin in contacts.coinArray) {
//                    if ([_orderModel.toAddress isEqualToString:contactsCoin.coinAddress]) {
//                        self.nameLab.text = contacts.nickName;
//                        if (self.nameLab.text.length == 0)
//                        {
//                            self.nameLab.hidden = YES;
//                        }
//                        else
//                        {
//                            self.nameLab.hidden = NO;
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
    
}

@end
