//
//  WebSheetView.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2024/1/10.
//  Copyright © 2024 fzm. All rights reserved.
//

#import "WebSheetView.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface WebSheetView()

@property (nonatomic, strong) UIView *contentsView;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, assign) BOOL isLiked;
@end

@implementation WebSheetView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (instancetype)initWithFrame:(CGRect)frame isLiked:(BOOL)isLiked
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.backgroundColor = SGColorRGBA(0, 0, 0, .5f);
        self.isLiked = isLiked;
        [self initView];
    }
    
    return self;
}

- (void)initView
{
    
    [self addSubview:self.bgView];
    [self.bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self);
        make.height.mas_equalTo(kScreenHeight - 120);
    }];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    tap.numberOfTapsRequired = 1;
    [self.bgView addGestureRecognizer:tap];
    self.bgView.userInteractionEnabled = YES;
    
    
    [self addSubview:self.contentsView];
    
    [self.contentsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.left.right.equalTo(self);
        make.height.mas_equalTo(240);
    }];
    
    NSArray *arr = @[@{@"name":L(@"刷新"),
                       @"image":@"web_refresh"},
                     @{@"name":L(@"复制链接"),
                       @"image":@"web_copy"},
                     @{@"name":L(@"在浏览器打开"),
                       @"image":@"web_openurl"},
                     @{@"name":L(@"退出"),
                       @"image":@"web_exit"}];
    CGFloat width = (kScreenWidth - 40) / 3;
    CGFloat height = 80;
    for (int i = 0; i < arr.count; i++) {
        NSDictionary *dict = arr[i];
        NSString *name = dict[@"name"];
        NSString *imgName = dict[@"image"];
        
        UIButton *btn = [[UIButton alloc] init];
        [btn setTitle:name forState:UIControlStateNormal];
        [btn setImage:[UIImage imageNamed:imgName] forState:UIControlStateNormal];
        btn.tag = i;
        [btn addTarget:self action:@selector(clickBtn:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:SGColorFromRGB(0x333649) forState:UIControlStateNormal];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:12.f]];
        [self.contentsView addSubview:btn];
        CGFloat y = 10;
        CGFloat x = 10;
        if (i <= 2) {
            x = 10 + (width + 5) * i;
            y = 10;
        }else{
            x = 10 + (width + 5) * (i - 3);
            y = 10 + 80 + 10;
        }
        
        btn.frame = CGRectMake(x ,y, width, height);
        
        [btn setImageEdgeInsets:UIEdgeInsetsMake(0, 40, 20, 40)];
        [btn setTitleEdgeInsets:UIEdgeInsetsMake(50, -35, 0, 0)];
    }
    
    
}

- (void)clickBtn:(UIButton *)sender
{
    switch (sender.tag) {
        case 0:
            //刷新
            self.sheetType = WebSheetTypeRefresh;
            break;
        case 1:
            //复制链接
            self.sheetType = WebSheetTypeCopyUrl;
            break;
        case 2:
            //在浏览器打开
            self.sheetType = WebSheetTypeOpenUrl;
            break;
        case 3:
             //退出
            self.sheetType = WebSheetTypeExit;
            break;
        default:
            break;
    }
    
    if (self.sheetBlock) {
        self.sheetBlock(self.sheetType);
    }
    
    [self dismiss];
}

#pragma mark - show
- (void)showWithView:(UIView *)view
{
    
    UIWindow *window = [PWUtils getKeyWindowWithView:view];
    [window addSubview:self];
    [UIView animateWithDuration:.3 animations:^{
        CGRect frame = self.contentsView.frame;
        frame.origin.y -= frame.size.height;
        self.contentsView.frame = frame;
    }];

}

#pragma mark - hide
- (void)dismiss
{
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.contentsView.frame;
        frame.origin.y += frame.size.height;
        self.contentsView.frame = frame;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeFromSuperview];
    });
}
#pragma mark - getter setter 
- (UIView *)contentsView
{
    if (!_contentsView) {
        UIView *contentView = [[UIView alloc] init];
        contentView.backgroundColor = SGColorFromRGB(0xf8f8fa);
        
        _contentsView = contentView;
    }
    return _contentsView;
}
- (UIView *)bgView
{
    if (!_bgView) {
        UIView *contentView = [[UIView alloc] init];
        contentView.backgroundColor = SGColorRGBA(0, 0, 0, .5f);
        
        _bgView = contentView;
    }
    return _bgView;
}

@end
