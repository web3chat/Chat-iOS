//
//  PWApplication.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <Foundation/Foundation.h>

@interface PWApplication : NSObject
/**应用所属分类id*/
@property (nonatomic,strong) NSString *cateID;
///**应用id*/
@property (nonatomic,strong) NSString *appID;
///**app logo url*/
@property (nonatomic,strong) NSString *icon;
///**app名称*/
@property (nonatomic,strong) NSString *name;
///**排序值*/
@property (nonatomic,strong) NSString *sort;
/**类型(1 非原生页面 2 原生页面)*/
@property (nonatomic,strong) NSString *type;
/**网页代开方式(1：钱包内打开，2：Safari打开)*/
@property (nonatomic,copy) NSString *openType;
/**原生链接*/
@property (nonatomic,strong) NSString *nativeURL;
///**h5链接*/
@property (nonatomic,strong) NSString *h5URL;
///**ios企业版链接*/
@property (nonatomic,strong) NSString *iosURL;
/**ios商店版链接*/
@property (nonatomic,strong) NSString *appStoreURL;
/**跳转方式(1 跳转应用详情 2 跳转h5)*/
@property (nonatomic,strong) NSString *redirectType;
/**用户数量*/
@property (nonatomic,strong) NSString *appUserNum;
///**应用简介*/
@property (nonatomic,strong) NSString *advertise;
///**应用简介*/
//@property (nonatomic,strong) NSString *type;
@property (nonatomic, strong) NSString *app_url;

@property (nonatomic, strong) NSString *platformType;
// 准入条件 － 邮箱 0 否 1 是
@property (nonatomic, strong) NSNumber *email;
//准入条件 － 电话 0 否 1 是
@property (nonatomic, strong) NSNumber *phone;
// 准入条件 － 实名 0 否 1 是
@property (nonatomic, strong) NSNumber *real_name;

@end
