//
//  PWActionSheetView.m
//  PWallet
//
//  Created by 郑晨 on 2019/12/10.
//  Copyright © 2019 陈健. All rights reserved.
//

#import "PWActionSheetView.h"
#import "CoinPrice.h"
#import "PWActionCell.h"
#import "PWDataBaseManager.h"
#import "Depend.h"

@interface PWActionSheetView()
<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *backView;
@property (nonatomic, strong) NSArray *dataArray;
@property (nonatomic, strong) NSArray *coinArray;
@property (nonatomic, strong) NSArray *coinpriceArray;
@property (nonatomic, strong) NSString *titleStr;
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *lineView;
@property (nonatomic, strong) UIButton *cancelBtn;

@end

@implementation PWActionSheetView

- (instancetype)initWithFrame:(CGRect)frame Title:(NSString *)title dataArray:(NSArray *)dataArray type:(ActionViewType)actionViewType
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.frame = frame;
        self.backgroundColor = SGColorRGBA(0, 0, 0, 0.5f);
        _actionViewType = actionViewType;
        switch (_actionViewType) {
            case ActionViewTypeHome:
            {
                _dataArray = dataArray;
                _coinArray = dataArray[0];
            }
                
                break;
                case ActionViewTypePrikey:
            {
                _coinArray = dataArray;
            }
                break;
            default:
                break;
        }
        _titleStr = title;
        
        
        [self createView];
    }
    return self;
}

- (void)createView
{
//    _backView = [[UIView alloc] init];
//    _backView.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
//    _backView.backgroundColor = SGColorRGBA(0, 0, 0, .3f);
//    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
//    tap.numberOfTapsRequired = 1;
//    _backView.userInteractionEnabled = YES;
//    [_backView addGestureRecognizer:tap];
//    
//    [self addSubview:_backView];
//    
    _contentView = [[UIView alloc] initWithFrame:CGRectMake(0, kScreenHeight, kScreenWidth, kBottomOffset + 290)];
    _contentView.backgroundColor = UIColor.clearColor;
    
    [self addSubview:_contentView];
    
    _titleLab = [UILabel getLabWithFont:[UIFont fontWithName:@"PingFangSC-Medium" size:17]
                                      textColor:SGColorFromRGB(0x333649)
                                  textAlignment:NSTextAlignmentCenter
                                           text:_titleStr];
    _titleLab.backgroundColor = SGColorFromRGB(0xffffff);
    _titleLab.frame = CGRectMake(0, 0, kScreenWidth, 50);
    
    [PWUtils setViewTopRightandLeftRaduisForView:_titleLab size:CGSizeMake(20, 20)];
    
    [_contentView addSubview:_titleLab];
    
    _cancelBtn = [[UIButton alloc] initWithFrame:CGRectMake(16, 0, 40, 50)];
    [_cancelBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [_cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
    
    [_cancelBtn.titleLabel setFont:[UIFont systemFontOfSize:16.f]];
    [_cancelBtn setTitleColor:SGColorFromRGB(0x8e92a3) forState:UIControlStateNormal];
    CGRect rect = [_cancelBtn.titleLabel.text boundingRectWithSize:CGSizeMake(200, MAXFLOAT)
       options:NSStringDrawingUsesLineFragmentOrigin
    attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16.f]}
       context:nil];
    _cancelBtn.frame = CGRectMake(16, 0, rect.size.width + 5, 50);
    
    [_contentView addSubview:_cancelBtn];
    
    switch (_actionViewType) {
        case ActionViewTypeHome:
        {
            _cancelBtn.hidden = YES;
        }
            break;
        case ActionViewTypePrikey:
        {
           _cancelBtn.hidden = NO;
        }
            break;
        default:
            break;
    }
    
    
    _lineView = [[UIView alloc] initWithFrame:CGRectMake(0, 49.5, kScreenWidth, .5f)];
    _lineView.backgroundColor = SGColorFromRGB(0xd9dce9);
    
    [_contentView addSubview:_lineView];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, kScreenWidth, kBottomOffset + 240) style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.estimatedRowHeight = 0;
    _tableView.estimatedSectionFooterHeight = 0;
    _tableView.estimatedSectionHeaderHeight = 0;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.scrollEnabled = YES;
    if (_coinArray.count < 5) {
        _tableView.scrollEnabled = NO;
    }
    _tableView.backgroundColor = UIColor.whiteColor;
    [_contentView addSubview:_tableView];

   
}

- (void)show
{

//    self.backView.transform = CGAffineTransformMakeScale(1.21f, 1.21f);
//    self.backView.alpha = 0;
//    self.contentView.transform = CGAffineTransformMakeScale(1.21f, 1.21f);
//    self.contentView.alpha = 0;
//
//    
//    [UIView animateWithDuration:.7f
//                          delay:0.f
//         usingSpringWithDamping:.7f
//          initialSpringVelocity:1
//                        options:UIViewAnimationOptionCurveEaseInOut animations:^{
//                            self.backView.transform = CGAffineTransformMakeScale(1.0, 1.0);
//                            self.backView.alpha = 1.0;
//                            self.contentView.transform = CGAffineTransformMakeScale(1.0, 1.0);
//                            self.contentView.alpha = 1.0;
//                            
//    } completion:nil];
//    self.backView.alpha = 0;
//    self.contentView.alpha = 0;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;

    [window addSubview:self];
    [UIView animateWithDuration:.3 animations:^{
        CGRect frame = self.contentView.frame;
        frame.origin.y -= frame.size.height;
        self.contentView.frame = frame;
    }];
}

- (void)dismiss
{
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.contentView.frame;
        frame.origin.y += frame.size.height;
        self.contentView.frame = frame;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeFromSuperview];
    });
//    [UIView animateWithDuration:0.3f animations:^{
//           self.backView.transform = CGAffineTransformMakeScale(1.21f, 1.21f);
//           self.backView.alpha = 0;
//           self.contentView.transform = CGAffineTransformMakeScale(1.21f, 1.21f);
//           self.contentView.alpha = 0;
//       } completion:^(BOOL finished) {
//           [self removeFromSuperview];
//           
//       }];
}

#pragma mark - tableviewdelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    return  _coinArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identity = @"actioncell";
    PWActionCell *cell = [tableView dequeueReusableCellWithIdentifier:identity];
    if (!cell) {
        cell = [[PWActionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identity];
    }
    cell.actionViewType = _actionViewType;
    cell.coin = _coinArray[indexPath.row];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.f;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self dismiss];
    switch (_actionViewType) {
        case ActionViewTypeHome:
        {
            if (_actionSheetViewBlock)
            {
                LocalCoin *coin = _coinArray[indexPath.row];
                CoinPrice *coinprice = [[PWDataBaseManager shared] queryCoinPriceBasedOn:coin.coin_type
                                                                                platform:coin.coin_platform
                                                                               andTreaty:coin.treaty];
                _actionSheetViewBlock(coin,coinprice);
            }
        }//坡下承  丢吧袋  绘揭青  挂铒湾  志速龙
            break;
        case ActionViewTypePrikey:
        {
            if (_actionSheetViewBlock)
            {
                _actionSheetViewBlock(_coinArray[indexPath.row],_coinpriceArray[indexPath.row]);
            }
        }
            break;
        default:
            break;
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
