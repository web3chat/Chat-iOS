//
//  NoRecordView.m
//  PWallet
//
//  Created by 宋刚 on 2018/6/20.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "NoRecordView.h"
#import "Depend.h"
@interface NoRecordView()
@property (nonatomic,strong) UIImage *image;
@property (nonatomic,copy) NSString *titleStr;

@property (nonatomic,strong) UIImageView *recordImg;
@property (nonatomic,strong) UILabel *titleLab;
@end

@implementation NoRecordView

- (instancetype)initWithImage:(UIImage *)image title:(NSString *)titleStr
{
    self = [super init];
    if(self)
    {
        _image = image;
        _titleStr = titleStr;
        [self createView];
    }
    return self;
}

- (void)createView{
    UIImageView *image = [[UIImageView alloc] init];
    [image setImage:_image];
    [self addSubview:image];
    self.recordImg = image;
    
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.font = CMTextFont15;
    titleLab.textColor = PlaceHolderColor;
    titleLab.textAlignment = NSTextAlignmentCenter;
    titleLab.text = _titleStr;
    [self addSubview:titleLab];
    self.titleLab = titleLab;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self.recordImg mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(130);
        make.centerX.equalTo(self);
        make.centerY.equalTo(self).with.offset(-20);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(15);
        make.left.right.equalTo(self);
        make.top.equalTo(self.recordImg.mas_bottom).with.offset(10);
    }];
}
@end
