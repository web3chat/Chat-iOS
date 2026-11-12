//
//  PWHotTitleTableViewCell.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <UIKit/UIKit.h>
#import "PWExploreModel.h"

@class PWExploreModel;
@class PWApplication;
typedef void(^appClicked)(PWApplication* app);
@interface PWHotTitleTableViewCell : UITableViewCell

@property(nonatomic,copy)void (^ClickCollectionAndTable)(NSInteger,NSInteger);
@property(nonatomic,copy) appClicked block;
@property(nonatomic,copy)void (^ClickTapCell)(NSInteger);
@property(nonatomic,strong)PWExploreModel *model;

@end


