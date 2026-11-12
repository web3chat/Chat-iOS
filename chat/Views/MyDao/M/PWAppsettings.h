//
//  PWAppsettings.h
//  chat
//
//  Created by 郑晨 on 2025/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define declareSingleton(ClassName)\
+(ClassName*)instance;

#define implementSingleton(ClassName)\
static ClassName* instance;\
+(ClassName*)instance\
{\
@synchronized (self)\
{\
if (! instance)\
instance = [[ClassName alloc] init];\
}\
return instance;\
}

typedef NS_ENUM(NSInteger,NetType) {
    NetBTY,
    NetETH,
    NetBNB,
};

@interface PWAppsettings : NSObject
declareSingleton(PWAppsettings)


// 缓存探索页面输入过的网址
- (void)saveEWebsite:(NSMutableArray *)websitrMarry;
- (NSMutableArray *)getEWebsite;
- (void)deleteEWebsite;

// 搜索历史的自定义显示名称：key = 历史里存的原始网址串，value = 用户自定义名称
- (void)saveEWebsiteNames:(NSDictionary<NSString *, NSString *> *)names;
- (NSDictionary<NSString *, NSString *> *)getEWebsiteNames;

// 切换网络
- (void)setAPPNetType:(NetType)type;
- (NetType)getAPPNetType;


// 缓存登录过的账户数据
// 缓存的数据：1、用户头像  2、根据密聊密码和助记词生成的加密数据 3、用户昵称 （助记词作为主键）
- (void)setLoginUserInfo:(NSMutableArray *)userInfoArray;
- (NSMutableArray *)getLoginUserInfo;
- (void)deleteLoginUserInfo;

@end

NS_ASSUME_NONNULL_END
