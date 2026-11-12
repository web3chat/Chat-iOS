//
//  PWBannerView.h
//  PWallet
//
//  Created by 于优 on 2018/12/17.
//  Copyright © 2018 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CWCarousel.h"
@class PWBannerModel;
@class PWBannerAndBillModel;

NS_ASSUME_NONNULL_BEGIN

@interface PWBannerView : UIView 

+ (instancetype)shopView;

- (void)controllerWillAppear;
- (void)controllerWillDisAppear;

@property (nonatomic, strong) NSArray <PWBannerModel *> *bannerArray;
@property (nonatomic, strong) NSArray <PWBannerAndBillModel *> *bannerAndBillArray;
@property (nonatomic, strong) CWCarousel *bannerView;
/** didBanner */
@property (nonatomic, copy) void(^didBannerHandle)(PWBannerModel *banner);

@end

NS_ASSUME_NONNULL_END
