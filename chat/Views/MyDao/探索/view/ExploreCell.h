//
//  ExploreCell.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <UIKit/UIKit.h>
@class PWApplication;
NS_ASSUME_NONNULL_BEGIN
typedef void(^PressBlock)(void);
@interface ExploreCell : UITableViewCell
-(void)setValueWithApp:(PWApplication*)app;
@property(nonatomic,copy) PressBlock block;
@end

NS_ASSUME_NONNULL_END
