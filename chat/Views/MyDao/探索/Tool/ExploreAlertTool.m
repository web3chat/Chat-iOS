//
//  ExploreAlertTool.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//  
//

#import "ExploreAlertTool.h"
#import "Depend.h"
@interface ExploreAlertTool()
@property(nonatomic,strong) UIView* oneBtnView;
@property(nonatomic,strong) UILabel* titleLab;
@property(nonatomic,strong) UILabel* textLab;
@property(nonatomic,strong) UIButton* startBtn;

@property(nonatomic,strong) UIView* twoBtnView;
@property(nonatomic,strong) UILabel* questionLab;
@property(nonatomic,strong) UILabel* messageLab;
@property(nonatomic,strong) UIButton* leftBtn;
@property(nonatomic,strong) UIButton* rightBtn;
@property(nonatomic,copy) clicked block;
@end
static ExploreAlertTool *tool;
@implementation ExploreAlertTool
+ (instancetype)defaultManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!tool) {
            tool = [[ExploreAlertTool alloc] init];
        }
    });
    return tool;
}

-(void)showOneBtnViewWithTitle:(NSString*)title detailText:(NSString*)detail btnText:(NSString*)btnText andBlock:(clicked)block{
    
    
    UIWindow* window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self.oneBtnView];
    [self.oneBtnView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.mas_equalTo(0);
    }];
    
    self.titleLab.text = title;
    [self.startBtn setTitle:btnText forState:normal];
    self.textLab.attributedText = [self attributedStringByStr:detail andTextAlignment:NSTextAlignmentCenter];
    self.block = block;
}

-(void)showTwoBtnViewWithQuestion:(NSString*)question messageText:(NSString*)message leftBtnText:(NSString*)leftBtnText rightBtnText:(NSString*)rightBtnText andBlock:(clicked)block{

    
    UIWindow* window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self.twoBtnView];
    [self.twoBtnView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.mas_equalTo(0);
    }];

    self.questionLab.attributedText = [self attributedStringByStr:question andTextAlignment:NSTextAlignmentCenter];
    self.messageLab.attributedText = [self attributedStringByStr:message andTextAlignment:NSTextAlignmentLeft];
    [self.leftBtn setTitle:leftBtnText forState:normal];
    [self.rightBtn setTitle:rightBtnText forState:normal];
    self.block = block;
    
    if (!IS_BLANK(message)) {
        [self.messageLab mas_updateConstraints:^(MASConstraintMaker *make) {
            make.bottom.mas_equalTo(-96);
        }];

    }else{
        [self.messageLab mas_updateConstraints:^(MASConstraintMaker *make) {
            make.bottom.mas_equalTo(-82);
        }];
    }
    
    if (leftBtnText.length == 0) {
        self.leftBtn.hidden = YES;
        [_rightBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.bottom.mas_equalTo(-23);
            make.right.mas_equalTo(-25);
            make.left.mas_equalTo(25);
            make.height.mas_equalTo(44);
        }];
    }
    else
    {
        self.leftBtn.hidden = NO;
        [_rightBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.bottom.mas_equalTo(-23);
            make.right.mas_equalTo(-25);
            make.width.mas_equalTo(120);
            make.height.mas_equalTo(44);
        }];
    }
}

-(NSAttributedString*)attributedStringByStr:(NSString*)str andTextAlignment :(NSTextAlignment)textAlignment{
    NSMutableParagraphStyle *bottomParagraphStyle = [NSMutableParagraphStyle new];
    bottomParagraphStyle.maximumLineHeight = 20;
    bottomParagraphStyle.minimumLineHeight = 20;
    bottomParagraphStyle.alignment = textAlignment;
    NSMutableDictionary *bottomAttributes = [NSMutableDictionary dictionary];
    bottomAttributes[NSParagraphStyleAttributeName] = bottomParagraphStyle;
    return [[NSAttributedString alloc] initWithString:str attributes:bottomAttributes];
}

- (UIView *)oneBtnView{
    if (_oneBtnView==nil) {
        _oneBtnView = [[UIView alloc] init];
        _oneBtnView.backgroundColor = CMColorRGBA(51, 54, 73, 0.5);
        
        UIView* whiteView = [[UIView alloc] init];
        whiteView.backgroundColor = UIColor.whiteColor;
        whiteView.layer.cornerRadius = 8;
        [_oneBtnView addSubview:whiteView];
        [whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(25);
            make.right.mas_equalTo(-25);
            make.height.mas_equalTo(210);
            make.centerY.mas_equalTo(0);
        }];
        
        _titleLab = [[UILabel alloc] init];
        _titleLab.textColor = CMColorFromRGB(0x333649);
        _titleLab.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:17];
        [whiteView addSubview:_titleLab];
        [_titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(23);
            make.centerX.mas_equalTo(0);
        }];
        
        _textLab = [[UILabel alloc] init];
        _textLab.textColor = CMColorFromRGB(0x8E92A3);
        _textLab.font = [UIFont systemFontOfSize:14];
        _textLab.textAlignment = NSTextAlignmentCenter;
        _textLab.numberOfLines = 0;
        [whiteView addSubview:_textLab];
        [_textLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(_titleLab.mas_bottom).offset(28);
            make.width.mas_lessThanOrEqualTo(250);
            make.centerX.mas_equalTo(0);
        }];
        
        _startBtn = [[UIButton alloc] init];
        _startBtn.backgroundColor = CMColorFromRGB(0x7190ff);
        _startBtn.layer.cornerRadius = 22;
        _startBtn.titleLabel.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:16];
        [whiteView addSubview:_startBtn];
        [_startBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.mas_equalTo(-23);
            make.centerX.mas_equalTo(0);
            make.width.mas_equalTo(150);
            make.height.mas_equalTo(44);
        }];
        
       @weakify(self)
        [[_startBtn rac_signalForControlEvents:UIControlEventTouchUpInside]
         subscribeNext:^(__kindof UIControl * _Nullable x) {
            @strongify(self)
            self.block();
            [self->_oneBtnView removeFromSuperview];
                  
        }];

        
    }
    return _oneBtnView;
}

- (UIView *)twoBtnView{
    if (_twoBtnView==nil) {
        _twoBtnView = [[UIView alloc] init];
        _twoBtnView.backgroundColor = CMColorRGBA(51, 54, 73, 0.5);

        UIView* whiteView = [[UIView alloc] init];
        whiteView.backgroundColor = UIColor.whiteColor;
        whiteView.layer.cornerRadius = 8;
        [_twoBtnView addSubview:whiteView];
        [whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(25);
            make.right.mas_equalTo(-25);
            make.centerY.mas_equalTo(0);
        }];
        
        _questionLab = [[UILabel alloc] init];
        _questionLab.textColor = CMColorFromRGB(0x333649);
        _questionLab.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:16];
        _questionLab.numberOfLines = 0;
        [whiteView addSubview:_questionLab];
        [_questionLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(33);
            make.width.mas_equalTo(180);
            make.centerX.mas_equalTo(0);
        }];
        
        _messageLab = [[UILabel alloc] init];
        _messageLab.textColor = CMColorFromRGB(0x8E92A3);
        _messageLab.font = [UIFont systemFontOfSize:14];
        _messageLab.textAlignment = NSTextAlignmentLeft;
        _messageLab.numberOfLines = 0;
        [_messageLab setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [_messageLab setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
        [whiteView addSubview:_messageLab];
        [_messageLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(_questionLab.mas_bottom).offset(21);
            make.width.mas_lessThanOrEqualTo(250);
            make.centerX.mas_equalTo(0);
            make.bottom.mas_equalTo(-96);
        }];
        
        _leftBtn = [[UIButton alloc] init];
        _leftBtn.layer.cornerRadius = 3;
        _leftBtn.titleLabel.font = [UIFont systemFontOfSize:16];
        _leftBtn.layer.borderWidth = 1;
        _leftBtn.layer.borderColor = CMColorFromRGB(0xD9DCE9).CGColor;
        [_leftBtn setTitleColor:CMColorFromRGB(0x8E92A3) forState:normal];
        [whiteView addSubview:_leftBtn];
        [_leftBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.mas_equalTo(-23);
            make.left.mas_equalTo(25);
            make.width.mas_equalTo(120);
            make.height.mas_equalTo(44);
        }];
        @weakify(self)
        [[_leftBtn rac_signalForControlEvents:UIControlEventTouchUpInside]
         subscribeNext:^(__kindof UIControl * _Nullable x) {
            @strongify(self)
            [self->_twoBtnView removeFromSuperview];
        }];
        
        _rightBtn = [[UIButton alloc] init];
        _rightBtn.layer.cornerRadius = 3;
        _rightBtn.titleLabel.font = [UIFont systemFontOfSize:16];
        _rightBtn.backgroundColor = CMColorFromRGB(0x7190FF);
        _rightBtn.titleLabel.numberOfLines = 0;
        
        [whiteView addSubview:_rightBtn];
        [_rightBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.mas_equalTo(-23);
            make.right.mas_equalTo(-25);
            make.width.mas_equalTo(120);
            make.height.mas_equalTo(44);
        }];
        [[_rightBtn rac_signalForControlEvents:UIControlEventTouchUpInside]
         subscribeNext:^(__kindof UIControl * _Nullable x) {
            @strongify(self)
            self.block();
            [self->_twoBtnView removeFromSuperview];
        }];
    }
    return _twoBtnView;
}

@end
