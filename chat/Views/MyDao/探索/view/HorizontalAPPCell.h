//
//  HorizontalAPPCell.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class PWExploreModel;
@class PWApplication;
typedef void(^appClicked)(PWApplication* app);
@interface HorizontalAPPCell : UITableViewCell
@property(nonatomic,strong) PWExploreModel* model;
@property(nonatomic,copy) appClicked block;
@end

NS_ASSUME_NONNULL_END
