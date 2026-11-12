//
//  PWBannerModel.h
//  PWallet
//
//  Created by 于优 on 2018/12/19.
//  Copyright © 2018 fzm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWBannerModel : NSObject

/**  */
@property (nonatomic, copy) NSString *image_url;
/**  */
@property (nonatomic, copy) NSString *banner_url;
/**  */
@property (nonatomic, assign) NSInteger Id;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, copy) NSString *url;

@end

NS_ASSUME_NONNULL_END
