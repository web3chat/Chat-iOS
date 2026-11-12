//
//  DAppWVJBLegacyHandlers.h
//  chat
//
//  与 WebViewController 中 WKWebViewJavascriptBridge（_bridge）注册的 H5 通道对齐。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WKWebViewJavascriptBridge;

/// 取当前主框架页面的站点 host（小写）。拿不到返回 nil —— 此时交易签名通道一律拒绝。
typedef NSString * _Nullable (^DAppOriginProvider)(void);

@interface DAppWVJBLegacyHandlers : NSObject

+ (void)registerHandlersWithBridge:(WKWebViewJavascriptBridge *)bridge host:(UIViewController *)host;

/// 带来源的注册。
///
/// `sign` / `signTxGroup` 收的是页面自己构造的哈希 / 裸交易，钱包无法在本地反解出
/// 收款地址与金额，所以这两条通道必须「按站点授权 + 逐笔确认」：
///   · 第一次从某个站点发起签名时弹「签名权限申请」，用户明确同意后才放行（只存内存）；
///   · 每一笔签名前弹「确认签名」，展示币种 / 执行器 / 待签哈希，并说明本地无法解析内容。
///
/// `originProvider` 必须返回**主框架**当前页面的 host（`webView.url.host`）。
/// `WKWebViewJavascriptBridge` 的 JS 是用 `evaluateJavaScript` 注入的，只作用于主框架，
/// 所以这个 host 就是发起请求的真实来源。provider 为 nil 等价于「拿不到来源」，直接拒绝签名。
+ (void)registerHandlersWithBridge:(WKWebViewJavascriptBridge *)bridge
                              host:(UIViewController *)host
                    originProvider:(DAppOriginProvider _Nullable)originProvider;

/// 与 WebViewController `-getFeePrikeyWithPlatform:CoinName:` 一致，供组交易签名计算 fee。
+ (void)prefetchBtyFeeConfig;

@end

NS_ASSUME_NONNULL_END
