//
//  RecentlyUsedAppTool.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//
//  保存和获取最近使用的app的id

#import <Foundation/Foundation.h>
#import "PWApplication.h"
NS_ASSUME_NONNULL_BEGIN

@interface RecentlyUsedAppTool : NSObject
+(void)setAppID:(NSString *)appID;
+(NSArray *)getAppIDArray;

/// 是否已确认过该域名（host）的第三方 DApp 免责声明（按域名去重）
+ (BOOL)hasConfirmedDAppDisclaimerForHost:(NSString *)host;
/// 记录已确认过免责声明的域名（host）
+ (void)markDAppDisclaimerConfirmedForHost:(NSString *)host;

+ (void)setLikeApp:(NSDictionary*)app;
+ (NSArray *)getLikeAppArray;
+ (void)deleteLikeApp:(NSDictionary *)app;
@end

NS_ASSUME_NONNULL_END
