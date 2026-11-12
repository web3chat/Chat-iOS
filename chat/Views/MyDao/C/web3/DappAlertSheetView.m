//
//  DappAlertSheetView.m
//  PWallet
//
//  Created by 郑晨 on 2021/5/27.
//  Copyright © 2021 fzm. All rights reserved.
//

#import "DappAlertSheetView.h"
#import "DappSheetCell.h"
#import <JKBigInteger/JKBigInteger.h>
#import "PWChoiceFeeSheetView.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface DappAlertSheetView()
<UITextFieldDelegate,UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITextView *msgTextView;
@property (nonatomic, strong) UIView *contentsView;
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UIImageView *iconImgView;
@property (nonatomic, strong) UILabel *nameLab;
@property (nonatomic, strong) UILabel *urlLab;
@property (nonatomic, strong) UILabel *addrLab;
@property (nonatomic, strong) UILabel *addrInfoLab;
@property (nonatomic, strong) UIView *addrInfoView;
@property (nonatomic, strong) UILabel *messageLab;
@property (nonatomic, strong) UILabel *messageInfoLab;
@property (nonatomic, strong) UIButton *confirmBtn;// 确定按钮
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) NSDictionary *dataDict;
@property (nonatomic, strong) UITextField *passwdText;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) BOOL showPasswd;
@property (nonatomic, assign) BOOL showIcon; // 是否显示图标
@property (nonatomic, strong) LocalCoin *localCoin;
@property (nonatomic, strong) UILabel *selectedFeeLab;
@property (nonatomic, strong) NSDictionary *selectedDict;
@property (nonatomic, copy) NSString *feeStr;
@property (nonatomic, assign) BOOL isRightGas;

@end

@implementation DappAlertSheetView

- (instancetype)initWithFrame:(CGRect)frame
                     withType:(DappAlertSheetType)dappType
                     withData:(NSDictionary *)dict
                     withCoin:(LocalCoin *)coin
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = SGColorRGBA(0, 0, 0, .5f);
       
        _dataDict = dict;
        _showIcon = [_dataDict[@"icon_url"] length] != 0 ? YES : NO;
        _showPasswd = NO;
        _localCoin = coin;
        _dappType = dappType;
        switch (dappType) {
            case DappAlertSheetTypeSign:
            {
                [self initSignView];
            }
                break;
            case  DappAlertSheetTypePersonalSign:
            {
                [self initPersonalSignView];
            }
                break;
            case DappAlertSheetTypePay:
            {
                [self initPayView];
            }
                break;
            default:
                break;
        }
    }
    return self;
    
}

#pragma mark - signView
- (void)initSignView
{
    [self addSubview:self.contentsView];
    [self.contentsView addSubview:self.closeBtn];
    [self.contentsView addSubview:self.titleLab];
    self.titleLab.text = L(@"消息签名");
    [self.contentsView addSubview:self.iconImgView];
    if (_showIcon) {
        [self.iconImgView sd_setImageWithURL:[NSURL URLWithString:_dataDict[@"icon_url"]]];
    }
    [self.contentsView addSubview:self.nameLab];
    self.nameLab.text = _dataDict[@"name"];
    [self.contentsView addSubview:self.urlLab];
    self.urlLab.text = _dataDict[@"url"];
    [self.contentsView addSubview:self.addrLab];
    self.addrLab.text = L(@"地址");
    [self.contentsView addSubview:self.addrInfoView];
    [self.addrInfoView addSubview:self.addrInfoLab];
    self.addrInfoLab.text = _dataDict[@"addr"];
    [self.contentsView addSubview:self.messageLab];
    self.messageLab.text = L(@"消息");
    [self.contentsView addSubview:self.msgTextView];
    self.msgTextView.text = _dataDict[@"message"];
    self.msgTextView.editable = NO;
    [self.contentsView addSubview:self.confirmBtn];
    
    self.contentsView.frame = CGRectMake(0, kScreenHeight, kScreenWidth, 532);
    [PWUtils setViewTopRightandLeftRaduisForView:self.contentsView size:CGSizeMake(6,6)];
    
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.contentsView).offset(6);
        make.top.equalTo(self.contentsView);
        make.width.mas_equalTo(52);
        make.height.mas_equalTo(50);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(64);
        make.top.equalTo(self.contentsView);
        make.right.equalTo(self.contentsView).offset(-64);
        make.height.mas_equalTo(50);
    }];
    
    [self.iconImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentsView);
        make.top.equalTo(self.titleLab.mas_bottom).offset(32);
        make.width.height.mas_equalTo(_showIcon ? 60 : 1);
    }];
    
    [self.nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.iconImgView.mas_bottom).offset(19);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
    
    [self.urlLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.nameLab.mas_bottom).offset(5);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(17);
    }];
    
    [self.addrLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.urlLab.mas_bottom).offset(46);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
    
    [self.addrInfoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.addrLab.mas_bottom).offset(8);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(62);
    }];
    [self.addrInfoLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.addrInfoView).offset(13);
        make.top.equalTo(self.addrInfoView).offset(10);
        make.right.equalTo(self.addrInfoView).offset(-13);
        make.height.mas_equalTo(42);
    }];
    
    [self.messageLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.addrInfoLab.mas_bottom).offset(24);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
        
    [self.msgTextView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.messageLab.mas_bottom).offset(8);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(44);
    }];

    [self.confirmBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.right.equalTo(self.contentsView).offset(-16);
        make.bottom.equalTo(self.contentsView).offset(-28);
        make.height.mas_equalTo(44);
    }];
}

- (void)initPersonalSignView
{
    [self addSubview:self.contentsView];
    [self.contentsView addSubview:self.closeBtn];
    [self.contentsView addSubview:self.titleLab];
    self.titleLab.text = L(@"消息签名");
    [self.contentsView addSubview:self.iconImgView];
    if (_showIcon) {
        [self.iconImgView sd_setImageWithURL:[NSURL URLWithString:_dataDict[@"icon_url"]]];
    }
    [self.contentsView addSubview:self.nameLab];
    self.nameLab.text = _dataDict[@"name"];
    [self.contentsView addSubview:self.urlLab];
    self.urlLab.text = _dataDict[@"url"];
    [self.contentsView addSubview:self.addrLab];
    self.addrLab.text = L(@"地址");
    [self.contentsView addSubview:self.addrInfoView];
    [self.addrInfoView addSubview:self.addrInfoLab];
    self.addrInfoLab.text = _dataDict[@"addr"];
    [self.contentsView addSubview:self.messageLab];
    self.messageLab.text = L(@"消息");
    [self.contentsView addSubview:self.msgTextView];
    self.msgTextView.text = _dataDict[@"message"];
    self.msgTextView.editable = NO;
    [self.contentsView addSubview:self.confirmBtn];
    
    self.contentsView.frame = CGRectMake(0, kScreenHeight, kScreenWidth, 532);
    [self.confirmBtn setTitle:L(@"下一步") forState:UIControlStateNormal];
    [PWUtils setViewTopRightandLeftRaduisForView:self.contentsView size:CGSizeMake(6,6)];
    
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.contentsView).offset(6);
        make.top.equalTo(self.contentsView);
        make.width.mas_equalTo(52);
        make.height.mas_equalTo(50);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(64);
        make.top.equalTo(self.contentsView);
        make.right.equalTo(self.contentsView).offset(-64);
        make.height.mas_equalTo(50);
    }];
    
    [self.iconImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentsView);
        make.top.equalTo(self.titleLab.mas_bottom).offset(32);
        make.width.height.mas_equalTo(_showIcon ? 60 : 1);
    }];
    
    [self.nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.iconImgView.mas_bottom).offset(19);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
    
    [self.urlLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.nameLab.mas_bottom).offset(5);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(17);
    }];
    
    [self.addrLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.urlLab.mas_bottom).offset(46);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
    
    [self.addrInfoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.addrLab.mas_bottom).offset(8);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(62);
    }];
    [self.addrInfoLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.addrInfoView).offset(13);
        make.top.equalTo(self.addrInfoView).offset(10);
        make.right.equalTo(self.addrInfoView).offset(-13);
        make.height.mas_equalTo(42);
    }];
    
    [self.messageLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.addrInfoLab.mas_bottom).offset(24);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
        
    [self.msgTextView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.messageLab.mas_bottom).offset(8);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(44);
    }];

    [self.confirmBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.right.equalTo(self.contentsView).offset(-16);
        make.bottom.equalTo(self.contentsView).offset(-28);
        make.height.mas_equalTo(44);
    }];
}

#pragma mark - payView
- (void)initPayView
{
    
    [self addSubview:self.contentsView];
    [self.contentsView addSubview:self.closeBtn];
    [self.contentsView addSubview:self.titleLab];
    self.titleLab.text = L(@"支付详情");
    [self.contentsView addSubview:self.iconImgView];
    if (_showIcon) {
        [self.iconImgView sd_setImageWithURL:[NSURL URLWithString:_dataDict[@"icon_url"]]];
    }
    [self.contentsView addSubview:self.nameLab];
    self.nameLab.text = _dataDict[@"name"];
    [self.contentsView addSubview:self.urlLab];
    self.urlLab.text = _dataDict[@"url"];
    [self.contentsView addSubview:self.addrLab];
    [self.contentsView addSubview:self.tableView];
    
    [self.contentsView addSubview:self.confirmBtn];
    [self.confirmBtn setTitle:L(@"下一步") forState:UIControlStateNormal];
    self.contentsView.frame = CGRectMake(0, kScreenHeight, kScreenWidth, 632);
    [PWUtils setViewTopRightandLeftRaduisForView:self.contentsView size:CGSizeMake(6,6)];
    
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.contentsView).offset(6);
        make.top.equalTo(self.contentsView);
        make.width.mas_equalTo(52);
        make.height.mas_equalTo(50);
    }];
    
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(64);
        make.top.equalTo(self.contentsView);
        make.right.equalTo(self.contentsView).offset(-64);
        make.height.mas_equalTo(50);
    }];
    
    [self.iconImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentsView);
        make.top.equalTo(self.titleLab.mas_bottom).offset(32);
        make.width.height.mas_equalTo(_showIcon ? 60 : 1);
    }];
    
    [self.nameLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.iconImgView.mas_bottom).offset(19);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
    
    [self.urlLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.nameLab.mas_bottom).offset(5);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(17);
    }];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.urlLab.mas_bottom).offset(22);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(320);
    }];
    
    [self.confirmBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.right.equalTo(self.contentsView).offset(-16);
        make.bottom.equalTo(self.contentsView).offset(-28);
        make.height.mas_equalTo(44);
    }];
}

#pragma mark - uitableview
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *array = _dataDict[@"paramArray"];
    return array.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identity = @"dappcell";
    DappSheetCell *cell = [tableView dequeueReusableCellWithIdentifier:identity];
    if (!cell) {
        cell = [[DappSheetCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identity];
    }
    NSArray *array = _dataDict[@"paramArray"];
    cell.titleLab.text = [array[indexPath.row] objectForKey:@"name"];
//    if ([[array[indexPath.row] objectForKey:@"info"] isKindOfClass:[NSNumber class]]) {
//        cell.subtitleLab.text = [NSString stringWithFormat:@"%f",[[array[indexPath.row] objectForKey:@"info"] floatValue]];
//    }else{
        cell.subtitleLab.text = [NSString stringWithFormat:@"%@",[array[indexPath.row] objectForKey:@"info"]];
//    }
    cell.toBtn.hidden = YES;
    if (indexPath.row == (array.count - 1)) {
        cell.toBtn.hidden = NO;
        self.selectedFeeLab = cell.subtitleLab;
        self.feeStr = cell.subtitleLab.text;
    }
    if (indexPath.row == 0 || indexPath.row == (array.count - 1)) {
        [cell.subtitleLab mas_updateConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(cell.contentsView).offset(80);
            make.top.equalTo(cell.contentsView).offset(17);
            make.right.equalTo(cell.contentsView).offset(-20);
            make.height.mas_equalTo(18);
        }];
    }else{
        [cell.subtitleLab mas_updateConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(cell.contentsView).offset(80);
            make.top.equalTo(cell.contentsView).offset(8);
            make.width.mas_equalTo(254);
            make.height.mas_equalTo(50);
        }];
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        return 50;
    }else{
        return 67;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 0)];
    
    UILabel *lab = [[UILabel alloc] init];
    lab.textColor = SGColorFromRGB(0x333649);
    lab.font = [UIFont fontWithName:@"PingFangSC-Medium" size:28];
    lab.textAlignment = NSTextAlignmentCenter;
    
    NSString *values = [NSString stringWithFormat:@"%@", _dataDict[@"value"]];
    NSString *trimmed = [values stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDecimalNumber *wei = [NSDecimalNumber decimalNumberWithString:trimmed];
    static NSDecimalNumber *kWeiPerEther;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kWeiPerEther = [NSDecimalNumber decimalNumberWithString:@"1000000000000000000"];
    });
    NSString *displayAmount = @"0";
    if (![wei isEqualToNumber:[NSDecimalNumber notANumber]]) {
        NSDecimalNumber *human = [wei decimalNumberByDividingBy:kWeiPerEther];
        NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.numberStyle = NSNumberFormatterDecimalStyle;
        fmt.maximumFractionDigits = 8;
        fmt.minimumFractionDigits = 0;
        fmt.usesGroupingSeparator = YES;
        displayAmount = [fmt stringFromNumber:human];
        if (displayAmount.length == 0) {
            displayAmount = human.stringValue;
        }
    }
    NSString *coinType = self.localCoin.coin_type;
    lab.text = [NSString stringWithFormat:@"%@ %@", displayAmount, coinType];
    lab.attributedText = [PWUtils getAttritubeStringWithString:lab.text
                                                  andChangeStr:coinType
                                                       andFont:[UIFont systemFontOfSize:24]
                                                      andColor:SGColorFromRGB(0x333649)];
    [view addSubview:lab];
    
    [lab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(view);
    }];
    
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 70.f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.dappType == DappAlertSheetTypePay) {
        NSArray *array = _dataDict[@"paramArray"];
        if (indexPath.row == (array.count - 1)) {
            if (self.feeStr == nil) { return; }
            NSDictionary *dict = @{@"value":self.feeStr,
                                   @"gas":_dataDict[@"gas"],
                                   @"gasPrice":_dataDict[@"gasPrice"],
                                   @"index":@(4)};
            PWChoiceFeeSheetView *choiceFeeView = [[PWChoiceFeeSheetView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight) withCoin:self.localCoin withDict:dict];
            choiceFeeView.choiceFeeBlock = ^(NSDictionary * _Nonnull dict) {
                self.selectedDict = dict;
                NSString *fee = dict[@"value"];
                self.selectedFeeLab.text = fee;
            };
            
            [choiceFeeView show];
        }
    }
    
}


#pragma mark - passwdView
- (void)initPasswdView
{
    _showPasswd = YES;
    if (_addrInfoLab) {
        [_addrInfoLab removeFromSuperview];
    }
    if (_addrInfoView) {
        [_addrInfoView removeFromSuperview];
    }
    if (_messageLab) {
        [_messageLab removeFromSuperview];
    }
    if (_messageInfoLab) {
        [_messageInfoLab removeFromSuperview];
    }
    if (_addrLab) {
        [_addrLab removeFromSuperview];
    }
    if (_msgTextView) {
        [_msgTextView removeFromSuperview];
    }
    if (_tableView) {
        [_tableView removeFromSuperview];
    }
    self.titleLab.text = L(@"密码");
    self.addrLab.text = L(@"密聊密码");
    self.confirmBtn.enabled = NO;
    self.confirmBtn.backgroundColor = SGColorFromRGB(0xe5e6e9);
    [self.contentsView addSubview:self.addrLab];
    [self.contentsView addSubview:self.passwdText];
    [self.confirmBtn setTitle:L(@"确认") forState:UIControlStateNormal];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textFieldValueChanged:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:nil];
    [self.addrLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.urlLab.mas_bottom).offset(46);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(21);
    }];
    [self.passwdText mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentsView).offset(16);
        make.top.equalTo(self.addrLab.mas_bottom).offset(8);
        make.right.equalTo(self.contentsView).offset(-16);
        make.height.mas_equalTo(44);
    }];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

}

#pragma mark : UIKeyboardWillShowNotification/UIKeyboardWillHideNotification
- (void)keyboardWillShow:(NSNotification *)notification{
    
    NSDictionary *userInfo = [notification userInfo];
    NSValue* aValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];//获取弹出键盘的fame的value值
    CGRect keyboardRect = [aValue CGRectValue];
    keyboardRect = [self convertRect:keyboardRect fromView:self.window];//获取键盘相对于self.view的frame ，传window和传nil是一样的
    NSNumber * animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];//获取键盘弹出动画时间值
    NSTimeInterval animationDuration = [animationDurationValue doubleValue];
    [UIView animateWithDuration:animationDuration animations:^{
        self.frame = CGRectMake(0, -keyboardRect.size.height, kScreenWidth, kScreenHeight);
    }];
    
}
- (void)keyboardWillHide:(NSNotification *)notification{
    NSDictionary *userInfo = [notification userInfo];
    NSNumber * animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];//获取键盘隐藏动画时间值
    NSTimeInterval animationDuration = [animationDurationValue doubleValue];
    if (self.frame.origin.y < 0) {//如果有偏移，当影藏键盘的时候就复原
        [UIView animateWithDuration:animationDuration animations:^{
            self.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
        }];
    }
}

#pragma mark - confirm
- (void)confirm:(id)sender
{
    if (!_showPasswd) {
        [self initPasswdView];
    }else{
        // 输入密码
        if (self.dappBlock) {
            self.dappBlock(self.passwdText.text,self.selectedDict == nil ? @"0" : self.selectedDict[@"gas"],self.selectedDict == nil ? @"0" : self.selectedDict[@"gasPrice"]);
        }
    }
}

- (void)textFieldValueChanged:(UITextField *)textField
{
    if (self.passwdText.text.length != 0) {
        self.confirmBtn.enabled = YES;
        self.confirmBtn.backgroundColor = SGColorFromRGB(0x7190ff);
    }else{
        self.confirmBtn.enabled = NO;
        self.confirmBtn.backgroundColor = SGColorFromRGB(0xe5e6e9);
    }
}


#pragma mark - show
- (void)showWithView:(UIView *)view
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"showAlert"];
   
    [[PWUtils getKeyWindowWithView:view] addSubview:self];
    
    [UIView animateWithDuration:.3 animations:^{
        CGRect frame = self.contentsView.frame;
        frame.origin.y -= frame.size.height;
        self.contentsView.frame = frame;
    }];

}

#pragma mark - hide
- (void)dismiss
{
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"showAlert"];
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.contentsView.frame;
        frame.origin.y += frame.size.height;
        self.contentsView.frame = frame;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeFromSuperview];
    });
}

- (void)clickCancelBtn:(UIButton *)sender
{
    if (self.dappBlock) {
        self.dappBlock(L(@"取消"),@"0",@"0");
    }
    [self dismiss];
}

#pragma mark - getter setter

- (UITableView *)tableView
{
    if (!_tableView) {
        UITableView *tab = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        tab.delegate = self;
        tab.dataSource = self;
        tab.estimatedRowHeight = 0;
        tab.separatorStyle = UITableViewCellSeparatorStyleNone;
        tab.estimatedSectionFooterHeight = 0;
        tab.estimatedSectionHeaderHeight = 0;
        tab.scrollEnabled = NO;
        tab.layer.cornerRadius = 5.f;
        tab.backgroundColor = UIColor.whiteColor;
        
        _tableView = tab;
        
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

- (UILabel *)titleLab
{
    if (!_titleLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont fontWithName:@"PingFangSC-Medium" size:17.f];
        lab.textAlignment = NSTextAlignmentCenter;
        
        _titleLab = lab;
    }
    return _titleLab;
}

- (UIButton *)closeBtn
{
    if (!_closeBtn) {
        UIButton *btn = [[UIButton alloc] init];
        [btn setTitle:L(@"取消") forState:UIControlStateNormal];
        [btn setTitleColor:SGColorFromRGB(0x8e92a3) forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(clickCancelBtn:) forControlEvents:UIControlEventTouchUpInside];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:16.f]];
        
        _closeBtn = btn;
    }
    
    return _closeBtn;
}

- (UIImageView *)iconImgView
{
    if (!_iconImgView) {
        UIImageView *imgView = [[UIImageView alloc] init];
        _iconImgView = imgView;
    }
    
    return _iconImgView;
}

- (UILabel *)nameLab
{
    if (!_nameLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont fontWithName:@"PingFangSC-Medium" size:15.f];
        lab.textAlignment = NSTextAlignmentCenter;
        
        _nameLab = lab;
    }
    return _nameLab;
}

- (UILabel *)urlLab
{
    if (!_urlLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x8e92a3);
        lab.font = [UIFont systemFontOfSize:12];
        lab.textAlignment = NSTextAlignmentCenter;
        
        _urlLab = lab;
    }
    return _urlLab;
}

- (UILabel *)addrLab
{
    if (!_addrLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:15];
        lab.textAlignment = NSTextAlignmentLeft;
        
        _addrLab = lab;
    }
    return _addrLab;
}

- (UILabel *)addrInfoLab
{
    if (!_addrInfoLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:15.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.backgroundColor = SGColorFromRGB(0xffffff);
        lab.layer.cornerRadius = 5.f;
        lab.numberOfLines = 0;
        lab.tag = 100;
        _addrInfoLab = lab;
    }
    return _addrInfoLab;
}

- (UIView *)addrInfoView
{
    if (!_addrInfoView) {
        UIView *addrInfoView = [[UIView alloc] init];
        addrInfoView.backgroundColor = UIColor.whiteColor;
        addrInfoView.layer.cornerRadius = 5.f;
        
        _addrInfoView = addrInfoView;
    }
    
    return _addrInfoView;
}

- (UILabel *)messageLab
{
    if (!_messageLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:15.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.tag = 100;
        _messageLab = lab;
    }
    return _messageLab;
}

- (UILabel *)messageInfoLab
{
    if (!_messageInfoLab) {
        UILabel *lab = [[UILabel alloc] init];
        lab.textColor = SGColorFromRGB(0x333649);
        lab.font = [UIFont systemFontOfSize:15.f];
        lab.textAlignment = NSTextAlignmentLeft;
        lab.backgroundColor = UIColor.whiteColor;
        lab.layer.cornerRadius = 5.f;
        lab.numberOfLines = 0;
        lab.tag = 100;
        _messageInfoLab = lab;
    }
    return _messageInfoLab;
}

- (UITextView *)msgTextView
{
    if (!_msgTextView) {
        UITextView *textView = [[UITextView alloc] init];
        textView.textColor = SGColorFromRGB(0x333649);
        textView.font = [UIFont systemFontOfSize:15.f];
        textView.textAlignment = NSTextAlignmentLeft;
        textView.backgroundColor = UIColor.whiteColor;
        textView.layer.cornerRadius = 5.f;
        
        _msgTextView = textView;
    }
    return _msgTextView;
}


- (UIButton *)confirmBtn
{
    if (!_confirmBtn) {
        UIButton *btn = [[UIButton alloc] init];
        [btn setTitle:L(@"确认") forState:UIControlStateNormal];
        [btn setTitleColor:SGColorFromRGB(0xffffff) forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(confirm:) forControlEvents:UIControlEventTouchUpInside];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:17.f]];
        btn.backgroundColor = SGColorFromRGB(0x7190ff);
        btn.layer.cornerRadius = 5;
        
        _confirmBtn = btn;
    }
    
    return _confirmBtn;
}

- (UITextField *)passwdText
{
    if (!_passwdText) {
        UITextField *tfield = [[UITextField alloc] init];
        tfield.backgroundColor = UIColor.whiteColor;
        tfield.placeholder = L(@"请输入密聊密码");
        tfield.textColor = SGColorFromRGB(0x333649);
        tfield.secureTextEntry = YES;
        tfield.layer.cornerRadius = 5.f;
        tfield.font = CMTextFont15;
        tfield.delegate = self;
        tfield.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
        tfield.leftViewMode = UITextFieldViewModeAlways;
        NSMutableAttributedString *placeholder = [[NSMutableAttributedString alloc] initWithString:tfield.placeholder];
        [placeholder addAttribute:NSForegroundColorAttributeName
                            value:SGColorFromRGB(0x8e92a3)
                            range:NSMakeRange(0, tfield.placeholder.length)];
        [placeholder addAttribute:NSFontAttributeName
                            value:CMTextFont14
                            range:NSMakeRange(0, tfield.placeholder.length)];
        tfield.attributedPlaceholder = placeholder;
        _passwdText = tfield;
        
    }
    return _passwdText;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/



@end
