//
//  WebViewController_Private.h
//  仅供 WebViewController / WebViewMetaMaskCoordinator 访问宿主属性（勿在其它处 import）
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <WKWebViewJavascriptBridge.h>
#import <CoreLocation/CoreLocation.h>
#import "Web3ProviderHandler.h"
#import "WebViewController.h"
#import "LocalCoin.h"
#import "DappAlertSheetView.h"

@class WebViewMetaMaskCoordinator;
@class WalletapiExecers;
@class WalletapiXgo;
@class WalletapiUtil;

NS_ASSUME_NONNULL_BEGIN

extern NSString * _Nullable const BTYRPCUrl;
extern NSString * _Nullable const BNBRPCUrl;
extern NSString * _Nullable const ETHRPCUrl;
@interface WebViewController () <WKUIDelegate,
WKNavigationDelegate,
UIScrollViewDelegate,
CLLocationManagerDelegate,
WKScriptMessageHandler,
WKURLSchemeHandler>
{
    WVJBResponseCallback _Nullable _toPayResultrCallback;
    WKWebViewConfiguration * _Nullable _configuration;
}

@property (nonatomic, strong, nullable) UIProgressView *progressView;
@property (nonatomic, strong, nullable) WKWebView *webView;
@property (nonatomic, strong, nullable) WKWebViewJavascriptBridge *bridge;
@property (nonatomic, copy, nullable) NSString *feePrikey;
@property (nonatomic, assign) CGFloat btyFeeValue;
@property (nonatomic, copy, nullable) NSString *priKey;

@property (nonatomic, strong, nullable) WalletapiExecers *execers;
@property (nonatomic, strong, nullable) WalletapiXgo *xgo;
@property (nonatomic, strong, nullable) WalletapiUtil *util;
@property (nonatomic, strong, nullable) NSMutableArray *deviceList;
@property (nonatomic, copy, nullable) WVJBResponseCallback getDeviceCallback;
@property (nonatomic, copy, nullable) WVJBResponseCallback getWifiCallback;
@property (nonatomic, strong, nullable) CLLocationManager *locationManager;

@property (nonatomic, copy, nullable) NSString *nonce;
@property (nonatomic, copy, nullable) NSString *gasPrice;
@property (nonatomic, strong, nullable) LocalCoin *localCoin;
@property (nonatomic, strong, nullable) DappAlertSheetView *sheetView;
@property (nonatomic, assign) BOOL isLiked;

@property (nonatomic, copy, nullable) NSString *selectedChain;
@property (nonatomic, copy, nullable) NSString *selectedRpcUlr;
@property (nonatomic, assign) NSInteger selectedChainID;
@property (nonatomic, copy, nullable) NSString *selectedChainName;

/// eth_call：NSOperationQueue 限并发 JSON-RPC（与 Web3ProviderHandler 一致，默认 8）
@property (nonatomic, strong, nullable) Web3ProviderHandler *web3ProviderHandler;

/// 所有 sendResponseToJS 的 evaluateJavaScript 经此串行队列再派主线程，避免多笔回包并发 evaluate 顺序错乱、与 requestId 错位
@property (nonatomic, strong, nullable) dispatch_queue_t walletJsResponseSerialQueue;

@property (nonatomic, strong, nullable) WebViewMetaMaskCoordinator *metaMaskCoordinator;

/// 供 WebViewMetaMaskCoordinator 调用的宿主方法（在 WebViewController.m 主 @implementation 中实现）
- (NSString *)tenToSixteen:(long long)decimal isUppercase:(BOOL)uppercase;
- (NSString *)sixteenToTen:(nullable NSString *)str;
- (NSString *)remv:(nullable NSString *)menc;
- (NSString *)base64Encoding:(nullable NSString *)input;

- (void)sendResponseToJS:(nullable NSString *)requestId result:(nullable id)result error:(nullable id)error method:(nullable NSString *)method;
- (void)sendResponseToJS:(nullable NSString *)requestId result:(nullable id)result error:(nullable id)error method:(nullable NSString *)method skipEmitAfterConnect:(BOOL)skipEmitAfterConnect;

- (void)notifyChainChanged:(nullable NSString *)newChainId;

@end

NS_ASSUME_NONNULL_END
