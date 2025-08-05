//
//  PWImageAlertView.m
//  PWallet
//
//  Created by 陈健 on 2018/11/23.
//  Copyright © 2018 陈健. All rights reserved.
//

#import "PWImageAlertView.h"

@interface PWImageAlertView()

@property (nonatomic, strong) NSString *addressStr;
@end

@implementation PWImageAlertView

- (instancetype)initWithTitle:(NSString*)title image:(UIImage*)image address:(nonnull NSString *)address{
    self = [super init];
    if (self) {
        self.addressStr = address;
        [self createViewWithTitle:title image:image];
    }
    return self;
}
- (void)createViewWithTitle:(NSString*)title image:(UIImage*)image {
    
    //白色Cover view
    UIView *whiteView = [[UIView alloc]init];
    [self addSubview:whiteView];
    whiteView.backgroundColor = [UIColor whiteColor];
    whiteView.layer.cornerRadius = 6;
    whiteView.layer.masksToBounds = true;
    CGFloat whiteViewWidth = kScreenWidth - 25 * 2;
    CGFloat whiteViewHeight = 390 * kScreenRatio;
    [whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(whiteViewHeight);
        make.width.mas_equalTo(whiteViewWidth);
        make.centerX.equalTo(self);
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
    
    UIView *imageViewBg = [[UIView alloc]init];
    [whiteView addSubview:imageViewBg];
    imageViewBg.backgroundColor = SGColorFromRGB(0xCACBD0);
    [imageViewBg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(line).offset(21);
        make.width.height.mas_equalTo(whiteViewWidth * 0.677);
        make.centerX.equalTo(whiteView);
    }];
    
    UIImageView *imageView = [[UIImageView alloc]init];
    [whiteView addSubview:imageView];
    imageView.image = image;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(imageViewBg).offset(16);
        make.bottom.equalTo(imageViewBg).offset(-16);
        make.left.equalTo(imageViewBg).offset(16);
        make.right.equalTo(imageViewBg).offset(-16);
    }];

    UIView *addressView = [[UIView alloc] init];
    addressView.backgroundColor = CMColor(246, 248, 250);
    [whiteView addSubview:addressView];
     
    UILabel *addressLab = [[UILabel alloc] init];
    addressLab.text = self.addressStr;
    addressLab.numberOfLines = 0;
    addressLab.font = CMTextFont16;
    addressLab.textColor = CMColor(102,102, 102);
    addressLab.textAlignment = NSTextAlignmentLeft;
    if (addressLab.text.length != 0) {
        NSMutableAttributedString *resultAttr1 = [[NSMutableAttributedString alloc] initWithString:addressLab.text];
        //    resultAttr1.yy_lineSpacing = 3;
        if (addressLab.text.length > 4) {
            [resultAttr1 addAttributes:@{NSForegroundColorAttributeName:SGColorFromRGB(0x7190ff)} range:NSMakeRange(addressLab.text.length - 4, 4)];
        }
        
        UIImage *img = [UIImage imageNamed:@"copy_add"];
        NSTextAttachment *attach = [[NSTextAttachment alloc] init];
        attach.image = img;
        attach.bounds = CGRectMake(0, 0, 12, 14);
        NSAttributedString *imageStr = [NSAttributedString attributedStringWithAttachment:attach];
        [resultAttr1 appendAttributedString:imageStr];
        addressLab.attributedText = resultAttr1;
    }
    
    addressLab.userInteractionEnabled = YES;
    [whiteView addSubview:addressLab];
    
    
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(copyAddressAction)];
    [addressLab addGestureRecognizer:gesture];
 
    [addressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(50);
        make.left.equalTo(whiteView).offset(20);
        make.top.equalTo(imageViewBg.mas_bottom).with.offset(19);
        make.right.equalTo(whiteView).offset(-20);
    }];
    
    [addressLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(250 * kScreenRatio);
        make.height.mas_equalTo(50 * kScreenRatio);
        make.centerX.equalTo(addressView.mas_centerX);
        make.centerY.equalTo(addressView.mas_centerY);
    }];
    
}

- (void)copyAddressAction
{
    if (self.okBlock) {
        self.okBlock(self.addressStr);
    }
}

- (void)hide {
    if (self.cancelBlock) {
        self.cancelBlock(nil);
    }
}

@end
