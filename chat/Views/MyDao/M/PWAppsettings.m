//
//  PWAppsettings.m
//  chat
//
//  Created by 郑晨 on 2025/10/10.
//

#import "PWAppsettings.h"
#import "Depend.h"

@implementation PWAppsettings
implementSingleton(PWAppsettings)
static NSString *PWAPPLocalizableNetType = @"PWAPPLocalizableNetType";
// 缓存探索页面输入过的网址
- (void)saveEWebsite:(NSMutableArray *)websitrMarry
{
//    NSData *encodedPosts = [NSKeyedArchiver archivedDataWithRootObject:websitrMarry];
    NSData *encodedPosts = [NSKeyedArchiver archivedDataWithRootObject:websitrMarry requiringSecureCoding:true error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:encodedPosts forKey:[NSString stringWithFormat:@"%@%@",kAppName,@"websitemarry"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSMutableArray *)getEWebsite
{
    NSData *encodedPosts = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@%@",kAppName,@"websitemarry"]];
   
    return [NSKeyedUnarchiver unarchivedObjectOfClass:[NSMutableArray class] fromData:encodedPosts error:nil];
//    return [NSKeyedUnarchiver unarchiveObjectWithData:encodedPosts];
}
- (void)deleteEWebsite
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@%@",kAppName,@"websitemarry"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 搜索历史的自定义显示名称（只含 NSString key/value，是合法 plist 类型，直接存 UserDefaults）
- (void)saveEWebsiteNames:(NSDictionary<NSString *, NSString *> *)names
{
    [[NSUserDefaults standardUserDefaults] setObject:names forKey:[NSString stringWithFormat:@"%@%@",kAppName,@"websitenames"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSDictionary<NSString *, NSString *> *)getEWebsiteNames
{
    NSDictionary *names = [[NSUserDefaults standardUserDefaults] dictionaryForKey:[NSString stringWithFormat:@"%@%@",kAppName,@"websitenames"]];
    return names ?: @{};
}

- (void)setAPPNetType:(NetType)type{
    [[NSUserDefaults standardUserDefaults] setObject:@(type) forKey:PWAPPLocalizableNetType];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NetType)getAPPNetType{
    NSNumber *netType = [[NSUserDefaults standardUserDefaults] objectForKey:PWAPPLocalizableNetType];
    if (netType == nil) {
        return NetBTY;
    }
    NSInteger v = [netType intValue];
    /// 历史 NetBUB(3) 已下线，迁移为 BNB
    if (v == 3) {
        [[NSUserDefaults standardUserDefaults] setObject:@(NetBNB) forKey:PWAPPLocalizableNetType];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return NetBNB;
    }
    if (v < 0 || v > NetBNB) {
        return NetBTY;
    }
    return (NetType)v;
}

// 缓存登录过的账户数据
- (void)setLoginUserInfo:(NSMutableArray *)userInfoArray
{
    NSData *encodedPosts = [NSKeyedArchiver archivedDataWithRootObject:userInfoArray requiringSecureCoding:true error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:encodedPosts forKey:[NSString stringWithFormat:@"%@%@",kAppName,@"userInfoArray"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSMutableArray *)getLoginUserInfo
{
    NSData *encodedPosts = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@%@",kAppName,@"userInfoArray"]];
   
    if (encodedPosts == nil) {
        return [[NSMutableArray alloc] init];
    }
    
    return [NSKeyedUnarchiver unarchivedObjectOfClass:[NSMutableArray class] fromData:encodedPosts error:nil];
}
- (void)deleteLoginUserInfo
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@%@",kAppName,@"userInfoArray"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
