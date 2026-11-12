//
//  DappSheetCell.h
//  PWallet
//
//  Created by 郑晨 on 2021/5/27.
//  Copyright © 2021 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


@interface DappSheetCell : UITableViewCell

@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UILabel *subtitleLab;
@property (nonatomic, strong) UIView *contentsView;
@property (nonatomic, strong) UIButton *toBtn;

@end

NS_ASSUME_NONNULL_END
