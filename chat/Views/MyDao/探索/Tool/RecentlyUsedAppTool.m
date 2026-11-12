//
//  RecentlyUsedAppTool.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "RecentlyUsedAppTool.h"


static NSString *const RecentlyUsedApp = @"RecentlyUsedApp";
static NSString *const LikeUsedApp = @"LikedApps";
/// 已确认过第三方 DApp 免责声明的域名（host）列表
static NSString *const DAppDisclaimerConfirmedHosts = @"DAppDisclaimerConfirmedHosts";

/// host 统一小写并去掉 www. 前缀：bityuan.com 与 www.bityuan.com 视为同一个 dapp
static NSString *FZMDAppNormalizedHost(NSString *host){
    NSString *result = [[host stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if ([result hasPrefix:@"www."]) {
        result = [result substringFromIndex:4];
    }
    return result.length > 0 ? result : @"";
}

@implementation RecentlyUsedAppTool
+ (void)setAppID:(NSString *)appID{
    NSMutableArray *idArr = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:RecentlyUsedApp]];
    if ([idArr containsObject:appID]) {
        [idArr removeObject:appID];
    }
    [idArr insertObject:appID atIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:idArr forKey:RecentlyUsedApp];
}

+ (NSArray *)getAppIDArray{
    return  [[NSUserDefaults standardUserDefaults] objectForKey:RecentlyUsedApp];
}

+ (void)setLikeApp:(NSDictionary*)app{
    NSMutableArray *idArr = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:LikeUsedApp]];
    NSMutableArray *urlArr = [NSMutableArray array];
    for (NSDictionary *dict in idArr) {
        [urlArr addObject:dict[@"url"]];
    }
    if ([urlArr containsObject:app[@"url"]]) {
        [idArr removeObject:app];
    }
    [idArr insertObject:app atIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:idArr forKey:LikeUsedApp];
}

+ (NSArray *)getLikeAppArray{
    return  [[NSUserDefaults standardUserDefaults] objectForKey:LikeUsedApp];
}

+(void)deleteLikeApp:(NSDictionary *)app{
    NSMutableArray *idArr = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:LikeUsedApp]];
    NSMutableArray *urlArr = [NSMutableArray arrayWithArray:idArr];
    NSString *url = app[@"url"];
    for (int i = 0; i < urlArr.count; i++) {
        NSDictionary *apps = urlArr[i];
        NSString *likeUrl = apps[@"url"];
        if ([url isEqualToString:likeUrl]) {
            [urlArr removeObject:apps];
            break;
        }
    }
    idArr = [NSMutableArray arrayWithArray:urlArr];
    
    [[NSUserDefaults standardUserDefaults] setObject:idArr forKey:LikeUsedApp];
}

#pragma mark - 第三方 DApp 免责声明（按域名去重）
+ (BOOL)hasConfirmedDAppDisclaimerForHost:(NSString *)host{
    NSString *normalized = FZMDAppNormalizedHost(host);
    if (normalized.length == 0) {
        // 拿不到域名时不做拦截，交给页面直接打开
        return YES;
    }
    NSArray *confirmedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:DAppDisclaimerConfirmedHosts];
    if (![confirmedHosts isKindOfClass:[NSArray class]]) {
        return NO;
    }
    return [confirmedHosts containsObject:normalized];
}

+ (void)markDAppDisclaimerConfirmedForHost:(NSString *)host{
    NSString *normalized = FZMDAppNormalizedHost(host);
    if (normalized.length == 0) {
        return;
    }
    NSArray *confirmedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:DAppDisclaimerConfirmedHosts];
    NSMutableArray *hosts = [NSMutableArray array];
    if ([confirmedHosts isKindOfClass:[NSArray class]]) {
        [hosts addObjectsFromArray:confirmedHosts];
    }
    if ([hosts containsObject:normalized]) {
        return;
    }
    [hosts addObject:normalized];
    [[NSUserDefaults standardUserDefaults] setObject:hosts forKey:DAppDisclaimerConfirmedHosts];
}

@end
