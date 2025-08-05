//
//  PWTransTipAlertView.m
//  PWallet
//
//  Created by 郑晨 on 2021/7/13.
//  Copyright © 2021 陈健. All rights reserved.
//

#import "PWTransTipAlertView.h"
#import "Depend.h"
@interface PWTransTipAlertView()
{
    NSTimer *_timer;
    NSInteger _secondsCountDown;
}
@property (nonatomic, strong) UIView *contentsView;
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) UIView *lineView;
@property (nonatomic, strong) UIImageView *tipImgView;
@property (nonatomic, strong) UILabel *tipLab;
@property (nonatomic, strong) UIButton *knowBtn;

@property (nonatomic, copy) NSString *tipStr;


@end

@implementation PWTransTipAlertView

- (instancetype)initWithTipStr:(NSString *)tipStr
{
    self = [super init];
    if (self) {
        self.tipStr = tipStr;
        self.backgroundColor = CMColorRGBA(0, 0, 0, .5);
        [self initView];
    }
    
    return self;
}


- (void)initView
{
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self];
    self.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    
    [self addSubview:self.contentsView];
    [self.contentsView addSubview:self.titleLab];
    [self.contentsView addSubview:self.lineView];
    [self.contentsView addSubview:self.tipImgView];
    [self.contentsView addSubview:self.tipLab];
    self.tipLab.text = self.tipStr;
    [self.contentsView addSubview:self.knowBtn];
    
    self.knowBtn.enabled = NO;
    [self.knowBtn setTitle:@"已知晓 (3s)" forState:UIControlStateNormal];
    self.knowBtn.backgroundColor = CMColorFromRGB(0xc3c9d1);
    _secondsCountDown = 3;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1
                                              target:self
                                            selector:@selector(timeDown)
                                            userInfo:nil
                                             repeats:YES];
    
    
    [self.contentsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(38);
        make.right.equalTo(self).offset(-38);
        make.height.mas_equalTo(280);
        make.center.equalTo(self);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(18);
        make.top.equalTo(self.contentsView).offset(13);
        make.width.mas_equalTo(64);
        make.height.mas_equalTo(24);
    }];
    
    [self.lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLab);
        make.width.mas_equalTo(45);
        make.height.mas_equalTo(4);
        make.top.equalTo(self.titleLab.mas_bottom).offset(12);
    }];
    
    [self.tipImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentsView);
        make.top.equalTo(self.lineView.mas_bottom).offset(35);
        make.width.mas_equalTo(129);
        make.height.mas_equalTo(26);
    }];
    
    [self.tipLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(17);
        make.right.equalTo(self.contentsView).offset(-17);
        make.top.equalTo(self.tipImgView.mas_bottom).offset(29);
        make.height.mas_equalTo(48);
    }];
    
    self.knowBtn.frame = CGRectMake(0, 230, kScreenWidth - 76, 50);
    [PWUtils setViewBottomRightandLeftRaduisForView:self.knowBtn];
}

- (void)timeDown
{
    _secondsCountDown-- ;
    self.knowBtn.enabled = NO;
    [self.knowBtn setTitle:[NSString stringWithFormat:@"已知晓 (%lis)",_secondsCountDown] forState:UIControlStateNormal];
    self.knowBtn.backgroundColor = CMColorFromRGB(0xc3c9d1);
    if (_secondsCountDown <= 0) {
        self.knowBtn.enabled = YES;
        [self.knowBtn setTitle:[NSString stringWithFormat:@"已知晓"] forState:UIControlStateNormal];
        self.knowBtn.backgroundColor = CMColorFromRGB(0x333649);
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)show
{
    self.contentsView.transform = CGAffineTransformMakeScale(1.11f, 1.11f);
    self.contentsView.alpha = 0;
    [UIView animateWithDuration:.7f
                          delay:0.f
         usingSpringWithDamping:.7f
          initialSpringVelocity:1
                        options:UIViewAnimationOptionCurveEaseInOut animations:^{
                            self.contentsView.transform = CGAffineTransformMakeScale(1.0, 1.0);
                            self.contentsView.alpha = 1.0;
                            
    } completion:nil];
}

- (void)dismiss
{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    if (self.tipBlock) {
        self.tipBlock();
    }
    [UIView animateWithDuration:0.3f animations:^{
           self.contentsView.transform = CGAffineTransformMakeScale(1.11f, 1.11f);
           self.contentsView.alpha = 0;
       } completion:^(BOOL finished) {
           
           [self removeFromSuperview];
           
       }];
}

- (void)know:(UIButton *)sender
{
    [self dismiss];
    if (self.tipBlock) {
        self.tipBlock();
    }
}

#pragma mark
#pragma mark - getter setter
- (UIView *)contentsView
{
    if (!_contentsView) {
        _contentsView = [[UIView alloc] init];
        _contentsView.layer.cornerRadius = 6.f;
        _contentsView.backgroundColor = UIColor.whiteColor;
    }
    return _contentsView;
}

- (UILabel *)titleLab
{
    if (!_titleLab) {
        _titleLab = [UILabel getLabWithFont:[UIFont fontWithName:@"PingFang-Medium" size:17]
                                  textColor:CMColorFromRGB(0x333649)
                              textAlignment:NSTextAlignmentLeft
                                       text:@"转账"];
    }
    
    return _titleLab;
}

- (UIView *)lineView
{
    if (!_lineView) {
        _lineView = [[UIView alloc] init];
        _lineView.backgroundColor = CMColorFromRGB(0x7190ff);
    }
    return _lineView;
}

- (UIButton *)closeBtn
{
    if (!_closeBtn) {
        _closeBtn = [[UIButton alloc] init];
        [_closeBtn setImage:[UIImage imageNamed:@"trans_close"] forState:UIControlStateNormal];
        [_closeBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closeBtn;
}

- (UIImageView *)tipImgView
{
    if (!_tipImgView) {
        _tipImgView = [[UIImageView alloc] init];
        _tipImgView.image = [UIImage imageNamed:@"trans_tip"];
    }
    return _tipImgView;
}

- (UILabel *)tipLab
{
    if (!_tipLab) {
        _tipLab = [UILabel getLabWithFont:[UIFont fontWithName:@"PingFang-Semibold" size:17]
                                textColor:CMColorFromRGB(0x333649)
                            textAlignment:NSTextAlignmentCenter
                                     text:@""];
        _tipLab.numberOfLines = 0;
    }
    return _tipLab;
}

- (UIButton *)knowBtn
{
    if (!_knowBtn) {
        _knowBtn = [[UIButton alloc] init];
        [_knowBtn addTarget:self action:@selector(know:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _knowBtn;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
