//
//  ChoiceCoinCell.h
//  chat
//
//  Created by 郑晨 on 2025/3/5.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChoiceCoinCell : UITableViewCell

@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *coinTypeLab;
@property (nonatomic, strong) UILabel *balanceLab;

@property (nonatomic, strong) LocalCoin *coin;

@end

NS_ASSUME_NONNULL_END
