//
//  PWBtyDomainNameOrAddressView.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/8/11.
//  Copyright © 2022 fzm. All rights reserved.
//

#import "PWBtyDomainNameOrAddressView.h"
#import "Depend.h"
@interface PWBtyDomainNameOrAddressView()
<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *dataArray;
@end
@implementation PWBtyDomainNameOrAddressView

- (instancetype)initWithData:(NSArray *)dataArray
{
    self = [super init];
    
    if (self) {
        
        self.dataArray = dataArray;
        [self addSubview:self.tableView];
        [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    
    return self;
}

#pragma mark - tableView Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identity = @"domaincell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identity];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identity];
    }
    cell.textLabel.text = self.dataArray[indexPath.row];
    cell.textLabel.textColor = SGColorFromRGB(0x7190ff);
    cell.textLabel.font = [UIFont systemFontOfSize:18];
    cell.backgroundColor = UIColor.whiteColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.dataArray.count == 1 ? 44 : 22;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *str = self.dataArray[indexPath.row];
    if (self.domainNameOrAddressChoiceBlock) {
        self.domainNameOrAddressChoiceBlock(str);
    }
}

#pragma mark - getter setter
- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.backgroundColor = UIColor.whiteColor;
    }
    return _tableView;
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
