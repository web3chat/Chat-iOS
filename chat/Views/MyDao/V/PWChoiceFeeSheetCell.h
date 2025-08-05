//
//  PWChoiceFeeSheetCell.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/11/17.
//  Copyright © 2023 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWChoiceFeeSheetCell : UITableViewCell

@property (nonatomic, strong) UIView *contentsView;
@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UILabel *subtitleLab;
@property (nonatomic, strong) UILabel *detailLab;
@property (nonatomic, strong) UIButton *toBtn;

@property (nonatomic, strong) UIView *customView;
@property (nonatomic, strong) UILabel *customGasPirceLab;
@property (nonatomic, strong) UITextField *customGasPriceTextField;
@property (nonatomic, strong) UILabel *customGasLab;
@property (nonatomic, strong) UITextField *customGasTextField;
@property (nonatomic, strong) UILabel *gasTipLab;
@property (nonatomic, strong) UILabel *gasPriceTipLab;

@end

NS_ASSUME_NONNULL_END
