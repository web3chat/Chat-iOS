//
//  PWChoiceFeeSheetCell.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/11/17.
//  Copyright © 2023 fzm. All rights reserved.
//

#import "PWChoiceFeeSheetCell.h"
#import "Depend.h"

@interface PWChoiceFeeSheetCell()
<UITextFieldDelegate>

@end

@implementation PWChoiceFeeSheetCell

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
        self.backgroundColor = UIColor.clearColor;
        
        [self initView];
    }
    
    return self;
}

- (void)initView 
{
    [self.contentView addSubview:self.contentsView];
    self.contentsView.layer.cornerRadius = 5;
    [self.contentsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(10);
        make.top.equalTo(self.contentView);
        make.right.equalTo(self.contentView).offset(-10);
        make.height.mas_equalTo(70);
    }];
    
    [self.contentsView addSubview:self.titleLab];
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(10);
        make.top.equalTo(self.contentsView).offset(10);
        make.height.mas_equalTo(20);
    }];
    
    [self.contentsView addSubview:self.subtitleLab];
    [self.subtitleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentsView).offset(-10);
        make.top.equalTo(self.contentsView).offset(10);
        make.height.mas_equalTo(20);
    }];
    [self.contentsView addSubview:self.toBtn];
    [self.toBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentsView).offset(-10);
        make.width.height.mas_equalTo(20);
        make.top.equalTo(self.contentsView).offset(10);
    }];
    [self.contentsView addSubview:self.detailLab];
    [self.detailLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(10);
        make.right.equalTo(self.contentsView).offset(-10);
        make.top.equalTo(self.titleLab.mas_bottom).offset(10);
        make.height.mas_equalTo(20);
    }];
    
    [self.contentsView addSubview:self.customView];
    [self.customView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.contentsView);
        make.top.equalTo(self.titleLab.mas_bottom).offset(10);
    }];
    
    [self.customView addSubview:self.customGasPirceLab];
    [self.customGasPirceLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.customView).offset(10);
        make.top.equalTo(self.customView).offset(10);
        make.height.mas_equalTo(20);
    }];
    
    [self.customView addSubview:self.gasPriceTipLab];
    [self.gasPriceTipLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.customGasPirceLab.mas_right).offset(5);
        make.top.height.equalTo(self.customGasPirceLab);
    }];
    
    [self.customView addSubview:self.customGasPriceTextField];
    [self.customGasPriceTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.customView).offset(10);
        make.right.equalTo(self.customView).offset(-10);
        make.top.equalTo(self.customGasPirceLab.mas_bottom).offset(10);
        make.height.mas_equalTo(40);
    }];
    
    [self.customView addSubview:self.customGasLab];
    [self.customGasLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.customView).offset(10);
        make.top.equalTo(self.customGasPriceTextField.mas_bottom).offset(10);
        make.height.mas_equalTo(20);
    }];
    
    [self.customView addSubview:self.gasTipLab];
    [self.gasTipLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.customGasLab.mas_right).offset(5);
        make.top.height.equalTo(self.customGasLab);
    }];
    
    [self.customView addSubview:self.customGasTextField];
    [self.customGasTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.customView).offset(10);
        make.right.equalTo(self.customView).offset(-10);
        make.top.equalTo(self.customGasLab.mas_bottom).offset(10);
        make.height.mas_equalTo(40);
    }];
    
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSInteger theInteger = 100;
    NSInteger theDecimal = 100;
    if (textField.tag == 100) {
        theInteger = 8;
        theDecimal = 2;

    }
    if (textField.tag == 101) {
        theInteger = 9;
        theDecimal = 0;

    }
    NSString *text = textField.text;
    NSInteger length = textField.text.length;
    if ([string isEqualToString:@""]) {
        return YES;
    }
    
    // 第一个字符不能输入“.”
    if (length == 0) {
        if ([string isEqualToString:@"."]) {
            return NO;
        }
    } else {
        if ([text containsString:@"."]) {
            if ([string isEqualToString:@"."]) {
                return NO;
            }
            // 限制小数位数
            NSRange pointRange = [text rangeOfString:@"."];
            if (length >= pointRange.location + pointRange.length + theDecimal) {
                return NO;
            }
        } else {
            if (length == 1) {
                // 第一个字符为“0”时，第二个字符必须为“.”
                if ([text isEqualToString:@"0"]) {
                    if (![string isEqualToString:@"."]) {
                        return NO;
                    }
                }
            }
            if ([string isEqualToString:@"."]) {
                return YES;
            }
            // 限制整数位数
            if (length >= theInteger) {
                return NO;
            }
        }
    }
    return YES;

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
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:16.f];
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
        lab.font = [UIFont systemFontOfSize:14.f];
        lab.textAlignment = NSTextAlignmentRight;
        lab.numberOfLines = 0;
        _subtitleLab = lab;
    }
    return _subtitleLab;
}

- (UILabel *)detailLab
{
    if (!_detailLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x8492a3);
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.numberOfLines = 0;
        lab.text = @"矿费";
        _detailLab = lab;
    }
    return _detailLab;
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

- (UIView *)customView
{
    if (!_customView) {
        _customView = [[UIView alloc] init];
        _customView.backgroundColor = UIColor.whiteColor;

    }
    
    return _customView;
}

- (UILabel *)customGasPirceLab
{
    if (!_customGasPirceLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.numberOfLines = 0;
        lab.text = @"GasPrice";
        _customGasPirceLab = lab;
    }
    return _customGasPirceLab;
}

- (UILabel *)gasPriceTipLab{
    if (!_gasPriceTipLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = UIColor.redColor;
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.numberOfLines = 0;
        lab.text = @"请输入gasPrice";
        _gasPriceTipLab = lab;
    }
    return _gasPriceTipLab;
}



- (UITextField *)customGasPriceTextField
{
    if (!_customGasPriceTextField) {
        UITextField *textfield = [[UITextField alloc] init];
        textfield.layer.cornerRadius = 5.f;
        textfield.backgroundColor = SGColorFromRGB(0xf8f8f8);
        textfield.placeholder = @"GasPrice";
        UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
        textfield.leftView = leftView;
        textfield.leftViewMode = UITextFieldViewModeAlways;
        textfield.textColor = SGColorFromRGB(0x333649);
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 40)];
        lab.text = @"GWEI   ";
        lab.font = [UIFont systemFontOfSize:13];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.textAlignment = NSTextAlignmentLeft;
        textfield.rightView = lab;
        textfield.rightViewMode = UITextFieldViewModeAlways;
        textfield.tag = 100;
        textfield.keyboardType = UIKeyboardTypeDecimalPad;
        textfield.delegate = self;
       
        _customGasPriceTextField = textfield;
        
        
    }
    
    return _customGasPriceTextField;
}

- (UILabel *)customGasLab
{
    if (!_customGasLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.numberOfLines = 0;
        lab.text = @"Gas";
        _customGasLab = lab;
    }
    return _customGasLab;
}

- (UILabel *)gasTipLab{
    if (!_gasTipLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = UIColor.redColor;
        lab.font = [UIFont systemFontOfSize:13.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.numberOfLines = 0;
        lab.text = @"请输入gas";
        _gasTipLab = lab;
    }
    return _gasTipLab;
}

- (UITextField *)customGasTextField
{
    if (!_customGasTextField) {
        UITextField *textfield = [[UITextField alloc] init];
        textfield.layer.cornerRadius = 5.f;
        textfield.backgroundColor = SGColorFromRGB(0xf8f8f8);
        textfield.placeholder = @"Gas";
        UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
        textfield.leftView = leftView;
        textfield.leftViewMode = UITextFieldViewModeAlways;
        textfield.textColor = SGColorFromRGB(0x333649);
        textfield.tag = 101;
        textfield.keyboardType = UIKeyboardTypeNumberPad;
        textfield.delegate = self;
       
        _customGasTextField = textfield;
        
    }
    
    return _customGasTextField;
}


@end
