//
//  HistoryWebSiteCell.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/12/22.
//  Copyright © 2022 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^HisDeleteBlock)(UITableViewCell *cell);

@interface HistoryWebSiteCell : UITableViewCell

@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UIButton *deleteBtn;
@property (nonatomic, strong) UIView *lineView;

@property (nonatomic) HisDeleteBlock deleteBlock;


@end

NS_ASSUME_NONNULL_END
