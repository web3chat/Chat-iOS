//
//  PWExploreModel.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <Foundation/Foundation.h>
#import "PWApplication.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWExploreModel : NSObject

/** APPS */
@property (nonatomic, strong) NSArray<PWApplication *> *apps;

@property(nonatomic,copy)NSArray<PWExploreModel *> *array;//新增stype==4 

/**  */
@property (nonatomic, copy) NSString *banner_image_url;
///**  */
@property (nonatomic, copy) NSString *banner_url;
///**  */
@property (nonatomic, copy) NSString *icon_url;
/**  */
@property (nonatomic, assign) NSInteger Id;
/**  */
@property (nonatomic, copy) NSString *name;

@property (nonatomic, assign) NSInteger style;
@end

@interface PWExploreAPPModel : NSObject

@end

NS_ASSUME_NONNULL_END
