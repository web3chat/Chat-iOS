//
//  ChoiceCoinView.m
//  chat
//
//  Created by 郑晨 on 2025/3/5.
//

#import "ChoiceCoinView.h"
#import "ChoiceCoinCell.h"
#import "Depend.h"

@interface ChoiceCoinView()<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *coinArr;
@property (nonatomic, strong) UIView *contentsView;
@property (nonatomic, strong) UIView *backView;
@property (nonatomic, strong) UIView *bgView;
@end


@implementation ChoiceCoinView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        _coinArr = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
        
        [self initView];
    }
    
    return self;
}

- (void)showwithView:(UIView *)view
{
    [[PWUtils getKeyWindowWithView:view] addSubview:self];
    
    [UIView animateWithDuration:.3 animations:^{
        CGRect frame = self.bgView.frame;
        frame.origin.x -= frame.size.width;
        self.bgView.frame = frame;
    }];
}

- (void)dismiss
{
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.bgView.frame;
        frame.origin.x += frame.size.width;
        self.bgView.frame = frame;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeFromSuperview];
    });
}

- (void)initView
{
    [self addSubview:self.bgView];
    self.bgView.frame = CGRectMake(kScreenWidth, 0, kScreenWidth, kScreenHeight);
    [self.bgView addSubview:self.backView];
    self.backView.frame = CGRectMake(0, 0, kScreenWidth - 268, kScreenHeight);
    [self.bgView addSubview:self.contentsView];
    self.contentsView.frame = CGRectMake(kScreenWidth - 268, 0, 268, kScreenHeight);
    [self.contentsView addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentsView);
    }];
}
#pragma mark - uitableview
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reu = @"choicecoincell";
    ChoiceCoinCell *cell = [[ChoiceCoinCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reu];
    if (!cell) {
        cell = [[ChoiceCoinCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reu];
    }
    
    cell.coin = _coinArr[indexPath.row];
    
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _coinArr.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    LocalCoin *coin = _coinArr[indexPath.row];
    
    if (self.choiceCoinBlock) {
        [self dismiss];
        self.choiceCoinBlock(coin);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 70;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 268, 50)];
    
    UILabel *titleLab = [UILabel getLabWithFont:[UIFont boldSystemFontOfSize:20]
                                      textColor:SGColorFromRGB(0x333649)
                                  textAlignment:NSTextAlignmentLeft
                                           text:@"选择资产"];
    [view addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(view).offset(13);
        make.height.mas_equalTo(50);
        make.top.equalTo(view);
    }];
    
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 70;
}

#pragma mark - setting and getting
- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.backgroundColor = SGColorFromRGB(0xf8f8fa);
    }
    return _tableView;
}

- (UIView *)contentsView
{
    if (!_contentsView) {
        UIView *contentView = [[UIView alloc] init];
        contentView.backgroundColor = SGColorFromRGB(0xf8f8fa);
        
        _contentsView = contentView;
    }
    return _contentsView;
}

- (UIView *)backView
{
    if (!_backView) {
        UIView *contentView = [[UIView alloc] init];
        contentView.backgroundColor = SGColorRGBA(0, 0, 0, .5f);
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
        tap.numberOfTapsRequired = 1;
        
        [contentView addGestureRecognizer:tap];
        contentView.userInteractionEnabled = YES;
        
        _backView = contentView;
    }
    
    return _backView;
}

- (UIView *)bgView
{
    if (!_bgView) {
        UIView *contentView = [[UIView alloc] init];
        contentView.backgroundColor = UIColor.clearColor;
        
        _bgView = contentView;
    }
    
    return _bgView;
}

@end
