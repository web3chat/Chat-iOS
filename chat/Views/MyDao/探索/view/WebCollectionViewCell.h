//
//  WebCollectionViewCell.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class PWApplication;
typedef void(^PressBlock)(void);
@interface WebCollectionViewCell : UICollectionViewCell
@property(nonatomic,strong) PWApplication* app;
@property(nonatomic,copy) PressBlock block;
@end

NS_ASSUME_NONNULL_END
