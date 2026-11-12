//
//  PWReloadView.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "PWReloadView.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface PWReloadView()

@property (nonatomic, strong) UIImageView *reloadImageView;
@property (nonatomic, strong) UILabel *errorTipLab;
@property (nonatomic, strong) UIButton *reloadBtn;
@property (nonatomic, strong) NSString *errorStr;
@property (nonatomic, strong) NSString *imageStr;

@end

@implementation PWReloadView

- (instancetype)initWithFrame:(CGRect)frame withError:(NSError *)error
{
    self = [super initWithFrame:frame];
    
    if (self) {
        
        NSData * _Nullable afNetworking_errorMsg = [error.userInfo objectForKey:AFNetworkingOperationFailingURLResponseDataErrorKey];
        if (!afNetworking_errorMsg)
        {
            _errorStr = L(@"网络不给力，请稍后重试");
            _imageStr = @"loaderror";
        }
        else
        {
            _errorStr = L(@"服务器异常");
            _imageStr = @"hosterror";
        }
        [self createView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(changeLanguage)
                                                     name:kChangeLanguageNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)changeLanguage
{
    self.errorTipLab.text = _errorStr;
    [_reloadBtn setTitle:L(@"重新加载") forState:UIControlStateNormal];
}



- (void)createView
{
    self.reloadImageView.image = [UIImage imageNamed:_imageStr];
    [self addSubview:self.reloadImageView];
    self.errorTipLab.text = _errorStr;
    [self addSubview:self.errorTipLab];
    [self addSubview:self.reloadBtn];
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.reloadImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.width.height.mas_equalTo(150);
        make.top.equalTo(self);
    }];
    
    [self.errorTipLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.height.mas_equalTo(21);
        make.top.equalTo(self.reloadImageView.mas_bottom).offset(10);
    }];
    
    [self.reloadBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.height.mas_equalTo(30);
        make.top.equalTo(self.errorTipLab.mas_bottom).offset(25);
    }];
    
}

#pragma mark -- reload
- (void)reload:(id)sender
{
    if (self.reloadBlock) {
        self.reloadBlock();
    }
}

#pragma mark -- getter and setter
- (UIImageView *)reloadImageView
{
    if (!_reloadImageView) {
        _reloadImageView = [[UIImageView alloc] init];
        _reloadImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    return _reloadImageView;
}

- (UILabel *)errorTipLab
{
    if (!_errorTipLab) {
        _errorTipLab = [UILabel getLabWithFont:[UIFont systemFontOfSize:15.f]
                                     textColor:SGColorFromRGB(0x999999)
                                 textAlignment:NSTextAlignmentCenter
                                          text:L(@"服务器异常")];
        
    }
    return _errorTipLab;;
}

- (UIButton *)reloadBtn
{
    if (!_reloadBtn) {
        _reloadBtn = [[UIButton alloc] init];
        [_reloadBtn setTitle:L(@"重新加载") forState:UIControlStateNormal];
        [_reloadBtn setTitleColor:SGColorFromRGB(0x2f86f2) forState:UIControlStateNormal];
        [_reloadBtn.titleLabel setFont:[UIFont systemFontOfSize:17.f]];
        NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:_reloadBtn.titleLabel.text];
        NSRange strRange = NSMakeRange(0, str.length);
        [str addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:strRange];
        [_reloadBtn setAttributedTitle:str forState:UIControlStateNormal];
        [_reloadBtn addTarget:self action:@selector(reload:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _reloadBtn;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
