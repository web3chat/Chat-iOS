//
//  PWNewInfoAlertView.m
//  PWallet
//
//  Created by 陈健 on 2018/11/15.
//  Copyright © 2018 陈健. All rights reserved.
//

#import "PWNewInfoAlertView.h"

@interface PWNewInfoAlertView()

@end
@implementation PWNewInfoAlertView

- (instancetype)initWithTitle:(NSString*)title message:(NSString*)message buttonName:(NSString*)buttonName {
    self = [super init];
    if (self) {
        [self createViewWithTitle:title message:message buttonName:buttonName];
    }
    return self;
}
- (void)createViewWithTitle:(NSString*)title message:(NSString*)message buttonName:(NSString*)buttonName {
    
    //白色Cover view
    UIView *whiteView = [[UIView alloc]init];
    [self addSubview:whiteView];
    whiteView.backgroundColor = [UIColor whiteColor];
    whiteView.layer.cornerRadius = 6;
    whiteView.layer.masksToBounds = true;
    CGFloat whiteViewHeight = 480;
    [whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(whiteViewHeight);
        make.left.equalTo(self).offset(25);
        make.right.equalTo(self).offset(-25);
        make.centerY.equalTo(self);
    }];
    
    //title label
    UILabel *titleLab = [[UILabel alloc]init];
    [whiteView addSubview:titleLab];
    titleLab.text = title;
    titleLab.font = [UIFont boldSystemFontOfSize:17];
    titleLab.textColor = SGColorRGBA(51, 54, 73, 1);
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(whiteView).offset(15);
        make.left.equalTo(whiteView).offset(25);
    }];
    
    //叉叉(取消)按钮
    UIButton *cancelBtn = [[UIButton alloc]init];
    [whiteView addSubview:cancelBtn];
    [cancelBtn setImage:[UIImage imageNamed:@"叉叉"] forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [cancelBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(44);
        make.height.mas_equalTo(44);
        make.right.equalTo(whiteView).offset(-10);
        make.centerY.equalTo(titleLab);
    }];
    
    UIView *line = [[UIView alloc]init];
    line.backgroundColor = SGColorRGBA(113, 144, 255, 1);
    [whiteView addSubview:line];
    [line mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(titleLab);
        make.top.equalTo(titleLab.mas_bottom).offset(12);
        make.height.mas_equalTo(4);
        make.width.mas_equalTo(45);
    }];
    
    YYLabel *messageLab = [[YYLabel alloc]init];
    [whiteView addSubview:messageLab];
    messageLab.text = message;
    messageLab.font = [UIFont systemFontOfSize:15];
    messageLab.textColor = SGColorRGBA(102, 102, 102, 1);
    messageLab.textVerticalAlignment = YYTextVerticalAlignmentCenter;
    messageLab.numberOfLines = 0;
    [messageLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(line.mas_bottom).offset(22);
        make.left.equalTo(whiteView).offset(25);
        make.right.equalTo(whiteView).offset(-25);
        make.height.mas_equalTo(132);
    }];
    
    UIImageView *qrcodeImg = [[UIImageView alloc]init];
    qrcodeImg.image = [CommonFunction createImgQRCodeWithString:message centerImage:nil];
    [whiteView addSubview:qrcodeImg];
    [qrcodeImg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(messageLab.mas_bottom).offset(15);
        make.centerX.equalTo(self);
        make.left.mas_offset(88);
        make.width.height.mas_offset(150);
    }];

    UILabel *noticeLabel = [[UILabel alloc]init];
    [whiteView addSubview:noticeLabel];
    noticeLabel.text = @"二维码";
    noticeLabel.font = [UIFont boldSystemFontOfSize:14];
    noticeLabel.textColor = SGColorRGBA(51, 54, 73, 1);
    [noticeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.top.equalTo(qrcodeImg.mas_bottom).offset(9);
    }];
    //okBtn
    UIButton *okBtn = [[UIButton alloc]init];
    [whiteView addSubview:okBtn];
    [okBtn setTitle:buttonName forState:UIControlStateNormal];
    okBtn.titleLabel.font = [UIFont systemFontOfSize:17];
    [okBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [okBtn setBackgroundColor:SGColorRGBA(113, 144, 255, 1)];
    okBtn.layer.cornerRadius = 6;
    okBtn.layer.masksToBounds = true;
    okBtn.layer.borderColor = SGColorRGBA(113, 144, 255, 1).CGColor;
    okBtn.layer.borderWidth = 0.5;
    [okBtn addTarget:self action:@selector(okBtnPress:) forControlEvents:UIControlEventTouchUpInside];
    [okBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(120);
        make.height.mas_equalTo(40);
        make.bottom.equalTo(whiteView).offset(-18);
        make.centerX.equalTo(whiteView);
    }];
    
}


// 确定按钮
- (void)okBtnPress:(UIButton*)sender {
    
    if (self.okBlock) {
        self.okBlock(nil);
    }
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.1;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)hide
{
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.1;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
