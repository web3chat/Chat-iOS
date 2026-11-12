//
//  PWBannerView.m
//  PWallet
//
//  Created by 于优 on 2018/12/17.
//  Copyright © 2018 fzm. All rights reserved.
//

#import "PWBannerView.h"

#import "CWPageControl.h"
#import "PWBannerModel.h"
#import "Depend.h"
@interface PWBannerView () <CWCarouselDatasource, CWCarouselDelegate>


/** 数据源 */
@property (nonatomic, strong) NSArray *dataArray;


@end
@implementation PWBannerView

+ (instancetype)shopView {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.clipsToBounds = YES;
        [self crtateView];
    }
    return self;
}

- (void)crtateView {
    [self addSubview:self.bannerView];
    
    [self.bannerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.mas_equalTo(0);
//        make.width.mas_equalTo(kScreenWidth - 30);
//        make.top.equalTo(self);
//        make.height.mas_equalTo(170);
    }];
    
    [self.bannerView registerViewClass:[UICollectionViewCell class] identifier:@"cellId"];
}

- (void)controllerWillAppear {
    [self.bannerView controllerWillAppear];
}

- (void)controllerWillDisAppear {
    [self.bannerView controllerWillDisAppear];
}

#pragma mark - Delegate
- (UICollectionViewCell *)viewForCarousel:(CWCarousel *)carousel indexPath:(NSIndexPath *)indexPath index:(NSInteger)index {
    UICollectionViewCell *cell = [carousel.carouselView dequeueReusableCellWithReuseIdentifier:@"cellId" forIndexPath:indexPath];
    
    UIImageView *imgView = [cell.contentView viewWithTag:666];
    if(!imgView) {
        imgView = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
        imgView.tag = 666;
        [cell.contentView addSubview:imgView];
    }

    cell.contentView.backgroundColor = [UIColor cyanColor];
    NSString *url = [self.dataArray[index] image_url];
//    [imgView sd_setImageWithURL:[NSURL URLWithString:url] placeholderImage:[UIImage imageNamed:@"placeholder"]];
    [imgView sd_setImageWithURL:[NSURL URLWithString:url] placeholderImage:[CommonFunction createImageWithColor:SGColorFromRGB(0xefefef)]];

    
    return cell;
}

- (void)CWCarousel:(CWCarousel *)carousel didSelectedAtIndex:(NSInteger)index {
    NSLog(@"...%ld...", (long)index);
    if (self.didBannerHandle) {

        self.didBannerHandle(self.dataArray[index]);
        
    }
}

- (NSInteger)numbersForCarousel {

    return self.dataArray.count;
}

#pragma mark - setter & getter

- (void)setBannerArray:(NSMutableArray<PWBannerModel *> *)bannerArray {
    _bannerArray = bannerArray;
    
    self.dataArray = bannerArray;
    [self.bannerView freshCarousel];
}

- (void)setBannerAndBillArray:(NSArray<PWBannerAndBillModel *> *)bannerAndBillArray
{
    _bannerAndBillArray = bannerAndBillArray;
    self.dataArray = [NSMutableArray arrayWithArray: bannerAndBillArray];
    
    [self.bannerView freshCarousel];
}

- (CWCarousel *)bannerView {
    if (!_bannerView) {
        CWFlowLayout *flowLayout = [[CWFlowLayout alloc] initWithStyle:CWCarouselStyle_Normal];
        _bannerView = [[CWCarousel alloc] initWithFrame:CGRectZero delegate:self datasource:self flowLayout:flowLayout];
        _bannerView.layer.cornerRadius = 8;
        _bannerView.clipsToBounds = YES;
        _bannerView.translatesAutoresizingMaskIntoConstraints = NO;
        _bannerView.isAuto = YES;
        _bannerView.autoTimInterval = 2;
//        _bannerView.endless = YES;
        _bannerView.backgroundColor = CMColorFromRGB(0xFFFFFF);
    }
    return _bannerView;
}

- (NSArray<PWBannerModel *> *)dataArray {
    if (!_dataArray) {
        _dataArray = [[NSArray alloc] init];
    }
    return _dataArray;
}

@end
