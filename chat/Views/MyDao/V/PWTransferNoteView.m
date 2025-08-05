//
//  PWTransferNoteView.m
//  PWallet
//
//  Created by 于优 on 2018/11/16.
//  Copyright © 2018 陈健. All rights reserved.
//

#import "PWTransferNoteView.h"
#import "Depend.h"

#define maxLength 80

@interface PWTransferNoteView () <UITextFieldDelegate,UITextViewDelegate>

@property (nonatomic, strong) UILabel *noteLab;
@property (nonatomic, strong) UILabel *hLine;
@property (nonatomic, strong) UIButton *messageBtn;

@end

@implementation PWTransferNoteView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self createView];
    }
    return self;
}

- (void)createView {
    
    UILabel *noteLab = [[UILabel alloc] init];
    noteLab.text = @"";
    noteLab.font = [UIFont boldSystemFontOfSize:14];
    noteLab.textAlignment = NSTextAlignmentLeft;
    noteLab.textColor = CMColorFromRGB(0x333649);
    [self addSubview:noteLab];
    self.noteLab = noteLab;
    
    UIButton *messageBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [messageBtn setImage:[UIImage imageNamed:@"trade_message"] forState:UIControlStateNormal];
    [self addSubview:messageBtn];
    self.messageBtn = messageBtn;
    [messageBtn addTarget:self action:@selector(messageBtnAction) forControlEvents:UIControlEventTouchUpInside];

    UITextView *noteTextView = [[UITextView alloc] init];
    noteTextView.font = CMTextFont13;
    noteTextView.textColor = TextColor51;
    noteTextView.backgroundColor = [UIColor whiteColor];
    [self addSubview:noteTextView];
    self.noteTextView = noteTextView;
    noteTextView.delegate = self;
    
    UILabel *hLine = [[UILabel alloc] init];
    hLine.backgroundColor = LineColor;
    [self addSubview:hLine];
    self.hLine = hLine;

}

- (void)layoutSubviews {
    
    [self.noteLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).offset(20);
        make.left.equalTo(self).with.offset(15);
        make.width.mas_equalTo(self.noteLab.textWidth + 5);
        make.height.mas_equalTo(14);
    }];
    
    [self.messageBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.noteLab);
        make.left.equalTo(self.noteLab.mas_right).offset(0);
        make.width.mas_equalTo(35);
        make.height.mas_equalTo(35);
    }];
    
    [self.noteTextView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.noteLab.mas_bottom);
        make.left.equalTo(self).with.offset(18);
        make.bottom.equalTo(self.hLine).offset(0);
        make.right.equalTo(self).with.offset(-15);
    }];
    
    [self.hLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(15);
        make.right.equalTo(self).offset(-15);
        make.height.mas_equalTo(0.5);
        make.bottom.equalTo(self.mas_bottom).with.offset(0);
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self borderForView:self.noteLab color:CMColorFromRGB(0x7190FF) borderWidth:3];
    });
}

- (void)textFieldDidChange:(UITextField *)textField {
    
    if (textField.text.length > 80) {
        UITextRange *markedRange = [textField markedTextRange];
        if (markedRange) {
            return;
        }
        //Emoji占2个字符，如果是超出了半个Emoji，用15位置来截取会出现Emoji截为2半
        //超出最大长度的那个字符序列(Emoji算一个字符序列)的range
        NSRange range = [textField.text rangeOfComposedCharacterSequenceAtIndex:80];
        textField.text = [textField.text substringToIndex:range.location];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    UITextRange *selectedRange = [textView markedTextRange];
    //获取高亮部分
    UITextPosition *pos = [textView positionFromPosition:selectedRange.start offset:0];
    
    //如果在变化中是高亮部分在变，就不要计算字符了
    if (selectedRange && pos) {
        return;
    }
    NSRange selection = textView.selectedRange;
    
    NSInteger realLength = textView.text.length; //实际总长度
    
    NSString *headText = [textView.text substringToIndex:selection.location]; //光标前的文本
    NSString *tailText = [textView.text substringFromIndex:selection.location];//光标后的文本
    
    NSInteger restLength = maxLength - tailText.length; //光标后允许输入的文本长度
    
    if (realLength > maxLength) {
        NSString *subHeadText = [headText substringToIndex:restLength];
        textView.text = [subHeadText stringByAppendingString:tailText];
        [textView setSelectedRange:NSMakeRange(restLength, 0)];
    }
}

#pragma mark - Action

- (void)messageBtnAction {
    if (self.didExplainMessageHandle) {
        self.didExplainMessageHandle();
    }
}

- (UIView *)borderForView:(UIView *)originalView color:(UIColor *)color borderWidth:(CGFloat)borderWidth {
    
    /// 线的路径
    UIBezierPath * bezierPath = [UIBezierPath bezierPath];
    
    /// 左侧线路径
    [bezierPath moveToPoint:CGPointMake(0.0f, originalView.frame.size.height)];
    [bezierPath addLineToPoint:CGPointMake(0.0f, 0.0f)];
    
    CAShapeLayer * shapeLayer = [CAShapeLayer layer];
    shapeLayer.strokeColor = color.CGColor;
    shapeLayer.fillColor  = [UIColor clearColor].CGColor;
    /// 添加路径
    shapeLayer.path = bezierPath.CGPath;
    /// 线宽度
    shapeLayer.lineWidth = borderWidth;
    
    [originalView.layer addSublayer:shapeLayer];
    
    return originalView;
}

- (void)setKeybordBtn:(UIButton *)keybordBtn action:(SEL) action
{
    [self.noteTextView setKeyBoardInputView:keybordBtn action:action];
}

#pragma mark - setter & getter

- (void)setTitleStr:(NSString *)titleStr {
    _titleStr = titleStr;
    NSRange strRange = [_titleStr rangeOfString:@"("];
    if (strRange.location != NSNotFound)
    {
        NSMutableAttributedString *attributedStr = [[NSMutableAttributedString alloc] initWithString:titleStr];
        
        [attributedStr addAttribute:NSForegroundColorAttributeName value:CMColorFromRGB(0xD9DCE9) range:NSMakeRange(strRange.location, _titleStr.length - strRange.location)];
        self.noteLab.attributedText = attributedStr;
    }
   
}

@end
