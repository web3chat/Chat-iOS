//
//  PWHotTitleSubCollectionViewCell.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "PWHotTitleSubCollectionViewCell.h"
#import "PWHotSubTableViewCell.h"
#import "PWApplication.h"
#import "Depend.h"
@interface PWHotTitleSubCollectionViewCell()<UITableViewDelegate,UITableViewDataSource>

@property(nonatomic,strong)UIImageView *backImgView;
@property(nonatomic,strong)UITableView *tableView;
@property(nonatomic,strong)UIView *headerView;
@property(nonatomic,strong)UILabel *titleLabel;
@property(nonatomic,strong)UIImageView *rightImgView;
@property(nonatomic,strong)NSMutableArray *array;
@property(nonatomic,strong)UIView *whiteView;

@end

@implementation PWHotTitleSubCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self createViews];
    }
    return self;
}

- (void)createViews{
    [self.contentView addSubview:self.backImgView];
    [self.backImgView addSubview:self.tableView];
    [self.headerView addSubview:self.titleLabel];
    [self.headerView addSubview:self.rightImgView];
    [self.headerView addSubview:self.whiteView];
    [self.backImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_offset(9 * kScreenRatio);
        make.top.mas_offset(5 * kScreenRatio);
        make.right.mas_offset(- 9 * kScreenRatio);
        make.bottom.mas_offset(- 10 * kScreenRatio);
    }];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.mas_offset(0);
    }];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_offset(17 * kScreenRatio);
        make.top.mas_offset(19 * kScreenRatio);
    }];
    [self.rightImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.titleLabel);
        make.left.equalTo(self.titleLabel.mas_right).offset(8 * kScreenRatio);
        make.width.mas_offset(11 * kScreenRatio);
        make.height.mas_offset(13 * kScreenRatio);
    }];
    
    [self.whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_offset(20 * kScreenRatio);
        make.centerY.equalTo(self.titleLabel);
        make.height.mas_offset(25 * kScreenRatio);
        make.right.equalTo(self.rightImgView.mas_right);
    }];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    [self.whiteView addGestureRecognizer:tap];
}

- (void)setModel:(PWExploreModel *)model{
    _model = model;
    [self.array removeAllObjects];
    if (model.name.length > 15) {
        self.titleLabel.text = [model.name substringToIndex:15];
    }else{
        self.titleLabel.text = model.name;
    }
    
    [self.array addObjectsFromArray:model.apps];
    NSInteger index = model.Id;
    NSString *imgName = [NSString stringWithFormat:@"hot%ld",index % 2];
    self.backImgView.image = [UIImage imageNamed:imgName];
    [self.tableView reloadData];
    
}

- (void)tapAction:(UITapGestureRecognizer *)sender{
    if (self.ClickTap) {
        self.ClickTap(self.model.Id);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 56 * kScreenRatio;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.array.count > 3) {
        return 3;
    }else{
        return self.array.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PWHotSubTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PWHotSubTableViewCell" forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[PWHotSubTableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PWHotSubTableViewCell"];
    }
    PWApplication *model = self.array[indexPath.row];
    cell.model = model;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.ClickCell) {
        self.ClickCell(indexPath.row);
    }
}

- (UIImageView *)backImgView{
    if (_backImgView == nil) {
        _backImgView = [[UIImageView alloc]init];
        _backImgView.image = [UIImage imageNamed:@""];
        _backImgView.layer.masksToBounds = YES;
        _backImgView.layer.cornerRadius = 8;
        _backImgView.userInteractionEnabled = YES;
    }
    return _backImgView;
}

- (UITableView *)tableView{
    if (_tableView == nil) {
        _tableView = [[UITableView alloc] init];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = NO;
        _tableView.scrollEnabled = NO;
        _tableView.backgroundColor = [UIColor clearColor];
        [_tableView registerClass:[PWHotSubTableViewCell class] forCellReuseIdentifier:@"PWHotSubTableViewCell"];
        _tableView.tableHeaderView = self.headerView;
    }
    return _tableView;
}

- (UIView *)headerView{
    if (_headerView == nil) {
        _headerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 75 * kScreenRatio)];
        _headerView.backgroundColor = [UIColor clearColor];
    }
    return _headerView;
}

- (UILabel *)titleLabel{
    if (_titleLabel == nil) {
        _titleLabel = [[UILabel alloc]init];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:20];
        _titleLabel.text = @"";
        _titleLabel.userInteractionEnabled = YES;
        
    }
    return _titleLabel;
}

- (UIImageView *)rightImgView{
    if (_rightImgView == nil) {
        _rightImgView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"右白箭头"]];
        _rightImgView.userInteractionEnabled = YES;
    }
    return _rightImgView;
}

- (NSMutableArray *)array{
    if (_array == nil) {
        _array = [NSMutableArray array];
    }
    return _array;
}

- (UIView *)whiteView{
    if (_whiteView == nil) {
        _whiteView = [[UIView alloc]init];
        _whiteView.backgroundColor = [UIColor clearColor];
    }
    return _whiteView;
}


@end
