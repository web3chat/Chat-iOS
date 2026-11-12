//
//  UIViewController   AppClicked.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//
//

#import "UIViewController+AppClicked.h"
#import "PWApplication.h"
#import "RecentlyUsedAppTool.h"
#import "chat-Swift.h"
#import "ExploreAlertTool.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@implementation UIViewController (AppClicked)
-(void)appClicked:(PWApplication *)app{
    //第一次点击应用弹框提示
    NSArray* idArr = [RecentlyUsedAppTool getAppIDArray];
    if([idArr containsObject:app.appID]){
        [self goToWebVC:app];
    }else{
        [[ExploreAlertTool defaultManager] showTwoBtnViewWithQuestion:L(@"责任声明")  messageText:L(@"您即将使用第三方DApp,确认即同意第三方的用户协议和隐私政策，您在这一DApp中的所有行为和使用情况，均由该DApp的供应商负责。")  leftBtnText:L(@"取消")  rightBtnText:L(@"确认")  andBlock:^{
            [self goToWebVC:app];
        }];
    }
}

-(void)goToWebVC:(PWApplication*)app{
    //先存一下id，如果已存在把id提到前面
    [RecentlyUsedAppTool setAppID:app.appID];
    if (![app.app_url isEqualToString:@"#"]) {
        NSURL *openURL = [NSURL URLWithString:app.app_url ?: @""];
        if (!openURL) { return; }
        DAppBrowserViewController *vc = [[DAppBrowserViewController alloc] initWithDappURL:openURL];
        vc.title = app.name;
        vc.hidesBottomBarWhenPushed = true;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
