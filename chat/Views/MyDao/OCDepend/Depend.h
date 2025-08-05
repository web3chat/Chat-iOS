//
//  PW-PrefixHeader.pch
//  PWalletInterfaceSDk
//
//  Created by fzm on 2021/8/25.
//

#ifndef PW_PrefixHeader_pch
#define PW_PrefixHeader_pch


#import <Masonry/Masonry.h>
#import "NSData+Binary.h"
#import "UIImageView+WebCache.h"
#import "NSObject+Empty.h"
#import "LocalWallet.h"
#import "Fee.h"
#import "CoinPrice.h"
#import "LocalCoin.h"
#import "OrderModel.h"
#import "CommonFunction.h"
#import <YYText.h>
#import "CommonViewController.h"
#import <Walletapi/Walletapi.h>
#import "PWUtils.h"
#import "GoFunction.h"
#import "UITextField+KeyBoard.h"
#import "UITextView+KeyBoard.h"
#import "NSData+Binary.h"
#import <RTRootNavigationController.h>
#import "UIViewController+ShowInfo.h"
#import "UILabel+getLab.h"
#import "CommonTextField.h"
#import <MJRefresh/MJRefresh.h>
#import "UILabel+Width.h"
#import "PWDataBaseManager.h"
#import "UINavigationBar+Extend.h"
#import <AFNetworking/AFNetworking.h>
#import "SGNetWork.h"
#import "NSString+CommonUseTool.h"
#import "YZAuthID.h"
#import "PWNetworkingTool.h"
#import "BlueButton.h"
#import "NoRecordView.h"
#import "PWNFTRequest.h"
#import "SAMKeychain.h"



typedef NS_ENUM(NSUInteger, ParentViewControllerFrom) {
    /**
     *  备份钱包
     */
    ParentViewControllerFromKeyBackUpWallet,
    /**
     *  创建钱包
     */
    ParentViewControllerFromKeyCreateWallet,
};

typedef NS_ENUM(NSUInteger, TransferFrom) {
    /**
     *  联系人
     */
    TransferFromContact = 0,
    /**
     *  币种信息
     */
    TransferFromCoinDetail,
};



#define isIPhoneXR ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(828, 1792), [[UIScreen mainScreen] currentMode].size) : NO)
#define isIPhoneXS ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1125, 2436), [[UIScreen mainScreen] currentMode].size) : NO)
#define isIPhoneSMax ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2688), [[UIScreen mainScreen] currentMode].size) : NO)
#define isIPhoneX ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1125, 2436), [[UIScreen mainScreen] currentMode].size) : NO)
#define isIPhone6 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ?  CGSizeEqualToSize(CGSizeMake(750, 1334), [[UIScreen mainScreen] currentMode].size) : NO)
#define isIPhone6P ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2208), [[UIScreen mainScreen] currentMode].size) : NO)
#define isIPhone5 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)
#define isIPhoneXSeries (isIPhoneX || isIPhoneXS || isIPhoneXR || isIPhoneSMax)

#define IS_BLANK(obj) [NSObject empty:obj]
#define FZM_IS_NULL(string) (!string || [string isEqual:@""] || [string isEqual:[NSNull null]])

#define SGColorRGBA(r, g, b, a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]
#define SGColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define SGColor(r, g, b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]
#define CMColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#define CMColor(r, g, b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]
#define TextColor51 CMColor(51, 51, 51)
#define CMTextFont18  [UIFont systemFontOfSize:18]
#define CMTextFont17  [UIFont systemFontOfSize:17]
#define CMTextFont16  [UIFont systemFontOfSize:16]
#define CMTextFont15  [UIFont systemFontOfSize:15]
#define CMTextFont14  [UIFont systemFontOfSize:14]
#define CMTextFont13  [UIFont systemFontOfSize:13]
#define CMTextFont12  [UIFont systemFontOfSize:12]

#define PlaceHolderColor CMColor(153,153,153)
#define MainColor (SGColorRGBA(47, 134, 242, 1))
#define SCREENBOUNDS [[UIScreen mainScreen] bounds]
#define TipRedColor CMColor(220,40,40)
#define ErrorColor CMColor(220,40,40)
#define scrollViewHeight self.view.frame.size.height < 600 ? 600 : self.view.frame.size.height
#define kPUBLICNUMBERFONT_SIZE(fontSize) [UIFont fontWithName:@"DINAlternate-Bold" size:fontSize]
#define LineColor CMColorFromRGB(0xD2D8E1)
#define CodeBgColor CMColorRGBA(246, 250, 255, 1)
//判断xxxx是否为空(支持类型NSString、NSArray、NSDictionary、NSSet)
#define IS_BLANK(obj) [NSObject empty:obj]
//状态栏高度
#define PageVCStatusBarHeight (isIPhoneX ? 44.f : 20.f)
//导航栏高度
#define PageVCNavBarHeight (44.f+PageVCStatusBarHeight)

#define kScreenHeight ([UIScreen mainScreen].bounds.size.height)
#define kScreenWidth  ([UIScreen mainScreen].bounds.size.width)
#define kScreenRatio  ([UIScreen mainScreen].bounds.size.width/375.0)
#define kScreenSize   ([[UIScreen mainScreen] bounds].size)
#define kTopOffset (isIPhoneXSeries ? 88  : 64)
#define kBottomOffset (isIPhoneXSeries ? 83 : 49)
#define kIphoneXBottomOffset (isIPhoneXSeries ? 34 : 0)
#define kIphoneXTopOffset (isIPhoneXSeries ? 24 : 0)
#define FZMWalletNameTest @"本链钱包"
#define WEAKSELF  __typeof(self) __weak weakSelf = self;
#define kAppName [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]

#define GoNodeURL  [NSString stringWithFormat:@"%@-%@",@"gonodeurl",kAppName]

#define APPSYMBOL @"open_wallet"
#define APPKEY    @"0425823a38b591b104ca0c3fcf1f3d9d"

//删除钱包通知名
static NSString *const kDeleteWalletNotification = @"kDeleteWalletNotification";
// 切换语言通知
static NSString *const kChangeLanguageNotification = @"kChangeLanguaeNotification";
#define SEARCHCOINNOTIFICATION @"searchcoinnotification"

#define CMTextBoldFont(size) [UIFont boldSystemFontOfSize:size]
// 是否为导入私钥钱包
#define isPriKeyWallet [[PWDataBaseManager shared] queryWalletIsSelected].wallet_issmall == 2
#define COINDEFAULT @"ETH,BTY,YCC"
#define PLATFORMDEFAULT @"btc,ethereum,bty,ethereum,dcr"
#define BgColor CMColor(246,248,250)
#define ErrorColor CMColor(220,40,40)
#define CMColorRGBA(r, g, b, a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]
#define WalletURL  @""
#define GoNodeUrl  @""
#define SLGNFTURL @""
//获取区块链浏览器地址
#define TRADEGETBROWER @"/goapi/interface/tokenview/explore?platform="
//钱包信息（下载地址）
#define WalletInfo @"/v1/data/download-info"
#define UPDATEJSON @"https://mydao.s3.ap-northeast-2.amazonaws.com/Mydao/mydaoios.json"
// 探索
#define PWallet_Banners @"/interface/banner"
#define Explore_Apps @"/interface/explore"
#define Explore_Banners @"/interface/explore/banner"
#define Explore_AppsByIDs @"/interface/explore/search"
//分组下的全部应用
#define Explore_Category @"/interface/explore/category"
//获取应用分类
#define PW_APPLICATION_GET_CLASSIFY  @"/interface/application/cate-app-info"
#define SUPPORTEDCHAIN @"/interface/supported-chain" // 钱包支持的链
#define RECOMCOIN @"/interface/recommend-coin/top" // 新版币种管理接口首页推荐
#define HOMECOININDEX @"/interface/coin/coin-index" // NFT详情
#define SEARCHCOINBYCHAINANDPLATFORM @"/interface/wallet-coin/search" // 币种搜索
#define SEARCHCOINBYNAME @"/interface/coin/search-coin-by-name" // 根据币种名字搜索币种
#define RECOMMENDCOIN @"/interface/recommend-coin" // 新版币种管理接口推荐
// 首页消息
#define HOME_NOTICE_URL @"/interface/notice/list"
//消息
#define PW_NOTICE  @"/interface/notice/list"
#define PW_NOTICE_DETAIL  @"/interface/notice/detail"

#endif /* PW_PrefixHeader_pch */
