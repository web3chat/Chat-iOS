//
//  PWActionCell.h
//  PWallet
//
//  Created by 郑晨 on 2019/12/10.
//  Copyright © 2019 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CoinPrice.h"
#import "LocalCoin.h"
#import "PWActionSheetView.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWActionCell : UITableViewCell

@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UILabel *balanceLab;
@property (nonatomic, strong) UILabel *priceLab;
@property (nonatomic, strong) UIView *lineView;

@property (nonatomic, strong) CoinPrice *coinPrice;
@property (nonatomic, strong) LocalCoin *coin;
@property (nonatomic, strong) UILabel *addressLab;

@property (nonatomic) ActionViewType actionViewType;

@end

NS_ASSUME_NONNULL_END
