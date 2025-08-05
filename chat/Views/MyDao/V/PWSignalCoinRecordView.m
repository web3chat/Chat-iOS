//
//  PWSignalCoinRecordView.m
//  PWallet
//
//  Created by 郑晨 on 2021/7/12.
//  Copyright © 2021 陈健. All rights reserved.
//

#import "PWSignalCoinRecordView.h"
#import "Depend.h"
@implementation PWSignalCoinRecordView

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        [self createView];
    }
    
    return self;
}

- (void)createView
{
    self.backgroundColor = CMColorFromRGB(0xf3fdff);
    self.recordCountLab = [[UILabel alloc] init];
    self.recordCountLab.layer.cornerRadius = 4.f;
    self.recordCountLab.layer.borderWidth = 1;
    self.recordCountLab.layer.borderColor = CMColorFromRGB(0x37aec4).CGColor;
    self.recordCountLab.backgroundColor = CMColorFromRGB(0xf3fdff);
    self.recordCountLab.textColor = CMColorFromRGB(0x37aec4);
    self.recordCountLab.font = [UIFont systemFontOfSize:12.f];
    self.recordCountLab.textAlignment = NSTextAlignmentCenter;
    
    [self addSubview:self.recordCountLab];
    
    self.recordBtn = [[UIButton alloc] init];
    [self.recordBtn setTitle:@"查看历史转账记录" forState:UIControlStateNormal];
    [self.recordBtn setTitleColor:CMColorFromRGB(0x37aec4) forState:UIControlStateNormal];
    [self.recordBtn.titleLabel setFont:[UIFont systemFontOfSize:12]];
    [self.recordBtn addTarget:self action:@selector(clickBtn:) forControlEvents:UIControlEventTouchUpInside];
    
    [self addSubview:self.recordBtn];
    
    [self.recordCountLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(20);
        make.top.equalTo(self).offset(9);
        make.height.mas_equalTo(28);
        make.width.mas_equalTo(100);
    }];
    
    [self.recordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(kScreenWidth - 116);
        make.top.height.equalTo(self.recordCountLab);
        make.width.mas_equalTo(100);
    }];
    
    
}

- (void)setRecordCount:(NSInteger)recordCount
{
    _recordCount = recordCount;
    self.recordCountLab.text = [NSString stringWithFormat:@"   已转%li次",recordCount];
    NSTextAttachment *attach = [[NSTextAttachment alloc] init];
    attach.image = [UIImage imageNamed:@"trans_safe"];
    attach.bounds = CGRectMake(0, -4, 12, 14);
    NSAttributedString *imgStr = [NSAttributedString attributedStringWithAttachment:attach];
    NSMutableAttributedString *abs = [[NSMutableAttributedString alloc] initWithString:self.recordCountLab.text];
    [abs insertAttributedString:imgStr atIndex:0];
    self.recordCountLab.attributedText = abs;
    if (_recordCount == 0) {
        self.recordBtn.hidden = YES;
        self.recordCountLab.textColor = UIColor.redColor;
    }
    
}


- (void)clickBtn:(UIButton *)sender
{
    if (self.recordListBlock) {
        self.recordListBlock();
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
