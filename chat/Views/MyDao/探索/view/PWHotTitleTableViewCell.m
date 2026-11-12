//
//  PWHotTitleTableViewCell.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "PWHotTitleTableViewCell.h"
#import "PWHotTitleSubCollectionViewCell.h"
#import "Depend.h"
@interface PWHotTitleTableViewCell()<UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
@property(nonatomic,strong) UICollectionView* collectionView;
@property(nonatomic,strong)NSMutableArray *array;

@end

@implementation PWHotTitleTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.whiteColor;
        [self createViews];
    }
    return self;
}

- (void)createViews{
    [self.contentView addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.right.equalTo(self.contentView);
        make.left.mas_offset(14 * kScreenRatio);
    }];
}

- (void)setModel:(PWExploreModel *)model{
    _model = model;
    [self.array removeAllObjects];
    [self.array addObjectsFromArray:model.array];
    [self.collectionView reloadData];
    
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout * layout = [UICollectionViewFlowLayout alloc];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _collectionView.backgroundColor = [UIColor whiteColor];
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        [_collectionView registerClass:[PWHotTitleSubCollectionViewCell class] forCellWithReuseIdentifier:@"PWHotTitleSubCollectionViewCell"];
    }
    return _collectionView;
}

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    WEAKSELF;
    PWHotTitleSubCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PWHotTitleSubCollectionViewCell" forIndexPath:indexPath];
    cell.ClickCell = ^(NSInteger subIndex) {
        [weakSelf clickCollection:indexPath.item withTableIndex:subIndex];
    };
    cell.ClickTap = ^(NSInteger idStr) {
        [weakSelf clickTap:idStr];
    };
    PWExploreModel *model = self.array[indexPath.row];
    cell.model = model;
    return cell;
}

- (void)clickTap:(NSInteger )idStr{
    if (self.ClickTapCell) {
        self.ClickTapCell(idStr);
    }
}

- (void)clickCollection:(NSInteger )collectionIndex withTableIndex:(NSInteger )tableIndex{
    PWExploreModel *model = self.array[collectionIndex];
    PWApplication *model1 = model.apps[tableIndex];
    self.block(model1);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(295 * kScreenRatio, 270 * kScreenRatio);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 4.5 * kScreenRatio;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.array.count;
}

- (NSMutableArray *)array{
    if (_array == nil) {
        _array = [NSMutableArray array];
    }
    return _array;
}



@end
