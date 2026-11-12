//
//  PWHotTitleSubCollectionViewCell.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <UIKit/UIKit.h>
#import "PWExploreModel.h"

@interface PWHotTitleSubCollectionViewCell : UICollectionViewCell

@property(nonatomic,copy)void (^ClickCell) (NSInteger);
@property(nonatomic,strong)PWExploreModel *model;
@property(nonatomic,copy)void (^ClickTap) (NSInteger);

@end


