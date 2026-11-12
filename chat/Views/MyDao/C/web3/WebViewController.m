//
//  WebViewController.m
//  PWallet
//
//  Created by lee on 2018/10/17.//  Created by fzm on 2021/12/7.
//
#import "WebViewController.h"
#import "WebViewController_Private.h"
#import "Web3ProviderHandler.h"
#import "GameGoFunction.h"
#include <CommonCrypto/CommonCrypto.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "PWNewsHomeViewController.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "SGNetWork.h"
#import "chat-Swift.h"
#import "WKWebViewConfiguration+Extension.h"
#import "DappAlertSheetView.h"
#import <JKBigInteger/JKBigInteger.h>
#import "WebSheetView.h"
#import "ETHInputParser.h"
#import "PWContractRequest.h"
#import "chat-Swift.h"
#import "WebViewMetaMaskCoordinator.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
#define kMethodArr @[@"sendTransaction",@"signTransaction",@"signPersonalMessage",@"signMessage",@"signTypedMessage",@"ethCall",@"walletSwitchEthereumChain",@"walletAddEthereumChain",@"iosHost"]
#define rootVC  UIApplication.sharedApplication.keyWindow.rootViewController


NSString *const kInitVectorForGame = @"33878402";

NSString *const DESKeyForGame = @"008f80e79e6b8c6a500e54e216e38ac2";
NSString *const FeePrikey = @"0xcc38546e9e659d15e6b4893f0ab32a06d103931a8230b0bde71459d2b27d6944";
static NSString * const dbPath = @"privacy.db";
NSString *const BTYRPCUrl = @"https://mainnet.bityuan.com/eth";
NSString *const BNBRPCUrl = @"https://bsc-dataseed.bnbchain.org/"; //@"https://bsc-dataseed.binance.org/"; //
NSString *const ETHRPCUrl = @"https://rpc.flashbots.net";

/// NSJSONSerialization 的顶层只能是 NSArray/NSDictionary，不能直接传 NSString（会抛异常闪退）。
/// 将字符串序列化为 JSON 字符串字面量（含转义），供拼进 evaluateJavaScript。
static NSString *BenefyJsonStringForJsLiteral(NSString *s) {
    if (s.length == 0) {
        return @"null";
    }
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[s] options:0 error:&err];
    if (!data || err) {
        NSString *escaped = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
        return [NSString stringWithFormat:@"\"%@\"", escaped];
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length >= 2 && [json hasPrefix:@"["] && [json hasSuffix:@"]"]) {
        return [json substringWithRange:NSMakeRange(1, json.length - 2)];
    }
    return json;
}

/// 将任意可 JSON 序列化的单值转为 JS 表达式片段（用于 _onResponse 的 result/error），避免手写引号导致脚本语法错误或 Uncaught(in promise)。
static NSString *BenefyJsonFragmentForJs(id value) {
    if (value == nil) {
        return @"null";
    }
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value] options:0 error:&err];
    if (!data || err) {
        NSString *fallback = [NSString stringWithFormat:@"%@", value];
        return BenefyJsonStringForJsLiteral(fallback);
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length >= 2 && [json hasPrefix:@"["] && [json hasSuffix:@"]"]) {
        return [json substringWithRange:NSMakeRange(1, json.length - 2)];
    }
    return @"null";
}

@implementation WebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // zhaohui.cn不需要清除缓存
    self.view.backgroundColor = UIColor.whiteColor;
    [self setNavBar];
    
    [self setNetAndLoadView];
    self.metaMaskCoordinator = [[WebViewMetaMaskCoordinator alloc] initWithHost:self];
}

// 设置网络
- (void)setNetAndLoadView
{
    NetType net = [[PWAppsettings instance] getAPPNetType];
    switch (net) {
        case NetBTY:
            _selectedChain = @"BTY";
            _selectedRpcUlr = BTYRPCUrl;
            _selectedChainID = 2999;
            _selectedChainName = @"BitYuan Mainnet";
            break;
        case NetETH:
            _selectedChain = @"ETH";
            _selectedRpcUlr = ETHRPCUrl;
            _selectedChainID = 1;
            _selectedChainName = @"Ethereum Mainnet";
            break;
        case NetBNB:
            _selectedChain = @"BNB";
            _selectedRpcUlr = BNBRPCUrl;
            _selectedChainID = 56;
            _selectedChainName = @"BNB Smart Chain";
            break;
        default:
            _selectedChain = @"BNB";
            _selectedRpcUlr = BNBRPCUrl;
            _selectedChainID = 56;
            _selectedChainName = @"BNB Smart Chain";
            break;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self loadWKWebView:[PWUtils getEthBtyAddress]];
        [self loadWKWebView:[GameGoFunction queryAddressByChain:self.selectedChain]];
    });
}

- (void)loadWKWebView:(NSString *)address
{
    for (UIView *view in self.view.subviews) {
        [view removeFromSuperview];
    }
    if (self.webView) {
        self.webView = nil;
    }
    
    if ([self.webUrl containsString:@" "]) {
        self.webUrl = [self.webUrl stringByReplacingOccurrencesOfString:@" " withString:@""];
    }
    if( ([[[UIDevice currentDevice] systemVersion] doubleValue]>=7.0))
    {
        self.edgesForExtendedLayout = UIRectEdgeNone; //页面延伸到的边界
    }
    
    
    
//    WKWebViewConfiguration *configuration =   [WKWebViewConfiguration initBroswerAddr:address
//                                                                             rpcUrl:_selectedRpcUlr
//                                                                            chainId:_selectedChainID]; // 2999 bty  1 eth  56 bnb

    
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    NSString *providerjs =  [[NSBundle mainBundle] pathForResource:@"provider" ofType:@"js"];
    NSError *error;
    NSString *style = [NSString stringWithContentsOfFile:providerjs encoding:NSUTF8StringEncoding error:&error];
    
    
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:style
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:NO];
    [configuration.userContentController addUserScript:userScript];
    // 文档结束再 ping 一次，适配部分在 DOMContentLoaded 后才监听钱包的 DApp
    NSString *endPing = @"(function(){try{if(typeof window.__tanxinWalletBridgePing==='function')window.__tanxinWalletBridgePing();}catch(e){}})();";
    WKUserScript *endScript = [[WKUserScript alloc] initWithSource:endPing
                                                     injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                  forMainFrameOnly:NO];
    [configuration.userContentController addUserScript:endScript];
    
    [kMethodArr enumerateObjectsUsingBlock:^(NSString *method, NSUInteger idx, BOOL * _Nonnull stop) {
        [configuration.userContentController addScriptMessageHandler:self name:method];
    }];

    WKPreferences *preferences = [WKPreferences new];
    preferences.javaScriptCanOpenWindowsAutomatically = YES;
    configuration.preferences = preferences;
    if (@available(iOS 14.0, *)) {
        WKWebpagePreferences *wp = [[WKWebpagePreferences alloc] init];
        wp.allowsContentJavaScript = YES;
        configuration.defaultWebpagePreferences = wp;
    }
    
//    self->_configuration = configuration;
    
    WKWebView * webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight) configuration:configuration];
    webView.scrollView.delegate = self;
    webView.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:webView];
    
    if (![_webUrl containsString:@"zhaohui.cn"])
       {
           if (@available(iOS 9.0, *)) {
                   //清除网页离线缓存
                   NSArray * types=@[WKWebsiteDataTypeDiskCache,//硬盘缓存
                                     WKWebsiteDataTypeOfflineWebApplicationCache,//离线应用缓存
                                     WKWebsiteDataTypeMemoryCache,//内存缓存
                                     WKWebsiteDataTypeIndexedDBDatabases,//索引数据库
                                     WKWebsiteDataTypeWebSQLDatabases];
                   NSSet *websiteDataTypes= [NSSet setWithArray:types];
                   NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
                   [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
                       
                   }];
               } else {
                   // Fallback on earlier versions
               }
           
           [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.webUrl] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:20.f]];
       }
    else
    {
        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.webUrl]]];
    }
    //kvo 添加进度监控
    [webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    self.webView = webView;

    [self.view addSubview:self.progressView];
    
    [self.webView addObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress)) options:0 context:nil];

    [WKWebViewJavascriptBridge enableLogging];
    _bridge = [WKWebViewJavascriptBridge bridgeForWebView:webView];
    [_bridge setWebViewDelegate:self];

    [webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
        NSString *userAgent = [NSString stringWithFormat:@"%@",result];
        NSString *addStr = [NSString stringWithFormat:@";wallet;%@",currentVersion];
        NSString *newUserAgent = [userAgent stringByAppendingString:addStr];//自定义需要拼接的字符串
        NSString *userClient = [NSString stringWithFormat:@"AlphaWallet/%@%@",currentVersion,@" 1inchWallet"];
        newUserAgent = [newUserAgent stringByAppendingString:userClient];
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:newUserAgent, @"UserAgent", nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
        [self.webView setCustomUserAgent:newUserAgent];
        [self->_bridge setWebViewDelegate:self];
    }];
    

    WEAKSELF
    [_bridge registerHandler:@"closeCurrentWebview" handler:^(id data, WVJBResponseCallback responseCallback) {
        [weakSelf.navigationController popViewControllerAnimated:YES];
    }];
    

    // 普通交易签名
    [_bridge registerHandler:@"sign" handler:^(id data, WVJBResponseCallback responseCallback) {
        [self authPayWithFaceIDType:FaceIDTypeSignRawTransaction res:responseCallback data:data];
        
    }];
    
   // 组交易签名
    [_bridge registerHandler:@"signTxGroup" handler:^(id data, WVJBResponseCallback responseCallback) {
        [self authPayWithFaceIDType:FaceIDTypeCoinsWithoutTxGroup res:responseCallback data:data];
        
    }];
    

    // 在浏览器中打开
    [_bridge registerHandler:@"browserOpen" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *urlStr = [data objectForKey:@"url"];
        if (urlStr == nil) {
            [self showCustomMessage:L(@"发生了错误，请稍后再试") hideAfterDelay:2.f];
            return;
        }
        NSURL *url = [NSURL URLWithString:urlStr];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                
            }];
        }
    }];
    // 获取当前钱包BTY地址
    [_bridge registerHandler:@"getCurrentBTYAddress" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"-------- 0");
       
        NSString *btyAddressStr = [GameGoFunction querySelectedBtyAddress];

        NSLog(@"-------- %@",btyAddressStr);
        responseCallback(btyAddressStr);
    }];
    
    // 从H5得到主链的信息，然后返回给H5当前主链的地址
    [_bridge registerHandler:@"getAddress" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *coinType = data[@"cointype"];
        NSString *address = @"";
        if ([coinType isEqualToString:@"BTY"]) {
            address = [GameGoFunction querySelectedBtyAddress];
        }else{
            address = [GameGoFunction queryAddressByChain:coinType];
        }
        
        
        responseCallback(@{@"address":address});
    }];
    
    // 扫码
    [_bridge registerHandler:@"scanQRCode" handler:^(id data, WVJBResponseCallback responseCallback) {
        [weakSelf scanAction:responseCallback];
    }];
    

}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
//    [self.navigationController.navigationBar lt_setBackgroundColor:UIColor.whiteColor];

    if (@available(iOS 13.0, *)) {
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
    } else {
           // Fallback on earlier versions
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    }
    
    if (@available(iOS 15, *))
    {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        // iOS 26/27：不显式 opaque 会被画成「液态玻璃」，backgroundColor 只作用于状态栏区域
        [appearance configureWithOpaqueBackground];
        // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
        appearance.buttonAppearance.normal.backgroundImage = [UIImage new];
        appearance.buttonAppearance.highlighted.backgroundImage = [UIImage new];
        appearance.doneButtonAppearance.normal.backgroundImage = [UIImage new];
        appearance.doneButtonAppearance.highlighted.backgroundImage = [UIImage new];
        appearance.backButtonAppearance.normal.backgroundImage = [UIImage new];
        appearance.backButtonAppearance.highlighted.backgroundImage = [UIImage new];

        appearance.backgroundColor = SGColorFromRGB(0xffffff);
        appearance.backgroundEffect = nil;
        appearance.shadowColor = UIColor.clearColor;
         appearance.titleTextAttributes = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:16], NSForegroundColorAttributeName : SGColorFromRGB(0x333649)};
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    else
    {
        [self.navigationController.navigationBar setBackgroundImage:[CommonFunction createImageWithColor:SGColorFromRGB(0xffffff)] forBarMetrics:UIBarMetricsDefault];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self getFeePrikeyWithPlatform:@"bty" CoinName:@"BTY"];
        [self getNonce];
        [self getGasPrice];
    });
    
   
    
    
}

- (void)dealloc
{
    [self.webView removeObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
//    [self.navigationController.navigationBar lt_reset];
   
    
}

- (void)showNotSupport
{
    // 暂不支持观察钱包，请切换至普通助记词钱包
    UIAlertController *alertvc = [UIAlertController alertControllerWithTitle:L(@"提示")
                                                                     message:L(@"当前钱包不支持该项目")
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:L(@"知道了")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
        [self homeAction];
    }];
    
    [alertvc addAction:action];
    
    [self.navigationController presentViewController:alertvc animated:YES completion:nil];

}

- (void)setNavBar{
    // 使用系统 UIBarButtonItem
    // ⚠️ 自定义 view（initWithCustomView）在交互式转场里不会跟着淡出，会一直挂在导航栏上，
    //    用户 2026-10-23 反馈「右滑返回时顶部按钮一直不消失」就是这个原因。
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"webBack"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(backAction)];
    leftItem.tintColor = SGColorFromRGB(0x24374E);
    self.navigationItem.leftBarButtonItem = leftItem;

    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"web_more"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(moreAction)];
    rightItem.tintColor = SGColorFromRGB(0x24374E);
    self.navigationItem.rightBarButtonItem = rightItem;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return nil;
}



- (void)backAction {
    if (self.webView.canGoBack == YES) {
        //返回上级页面
        [self.webView goBack];
    }else{
        [self homeAction];
    }
}

-(void)homeAction {
    [self.navigationController popViewControllerAnimated:YES];
    
}

-(void)reloadWeb {
    NSURL *url = self.webView.URL;
    if (url)
    {
        [self.webView reloadFromOrigin];
    }
    else
    {
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.webUrl]]];
    }
}

- (void)scanAction:(WVJBResponseCallback)responseCallback {
    [self.view endEditing:true];
    ScanViewController *vc = [[ScanViewController alloc] init];
    [self.navigationController pushViewController:vc animated:false];
    vc.scanResult = ^(NSString *address) {
        if ([address containsString:@","])
        {
            NSArray *array = [address componentsSeparatedByString:@","];
            if (array.count == 3) {
                NSString *add = [NSString stringWithFormat:@"%@",array[2]];
                responseCallback(add);
            }
            else if (array.count == 2)
            {
                NSString *add = [NSString stringWithFormat:@"%@",array[1]];
                responseCallback(add);
            }
        }
        else
        {
            responseCallback(address);
        }

    };
}

-(void)moreAction {
    
    // 先判断该网址是否已经收藏，用于显示收藏按钮图标
    
    WebSheetView *sheetVew = [[WebSheetView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight) isLiked:false];
    
    sheetVew.sheetBlock = ^(WebSheetType sheetType) {
        switch (sheetType) {
            case WebSheetTypeRefresh:
            {
                [self reloadWeb];
            }
                break;
            case WebSheetTypeCopyUrl:
            {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = self.webUrl;
                [self showCustomMessage:L(@"复制成功")  hideAfterDelay:2.0];
            }
                break;
            case WebSheetTypeOpenUrl:
            {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.webUrl]  options:@{}
                                         completionHandler:^(BOOL success) {
                    NSLog(@"Open %d",success);
                }];
            }
                break;
            case WebSheetTypeExit:
            {
                [self homeAction];
            }
                break;
                
            default:
                break;
        }
    };
    
    [sheetVew showWithView:self.view];
    return;
    
    
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

   
    UIAlertAction *action2 = [UIAlertAction actionWithTitle:L(@"复制链接")  style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.webUrl;
        [self showCustomMessage:L(@"复制成功")  hideAfterDelay:2.0];
    }];
    UIAlertAction *action3 = [UIAlertAction actionWithTitle:L(@"在浏览器中打开")  style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
       
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.webUrl]  options:@{}
                                 completionHandler:^(BOOL success) {
            NSLog(@"Open %d",success);
        }];
        
    }];

    UIAlertAction *action6 = [UIAlertAction actionWithTitle:L(@"取消")  style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"取消");
    }];

    [actionSheet addAction:action2];
    [actionSheet addAction:action3];
    [actionSheet addAction:action6];
//#endif
    //相当于之前的[actionSheet show];
    [self presentViewController:actionSheet animated:YES completion:nil];

}


- (NSString *)convertToJsonData:(NSDictionary *)dict
{

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString;

    if (!jsonData) {
        NSLog(@"%@",error);
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    NSRange range = {0,jsonString.length};
    //去掉字符串中的空格
    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
    NSRange range2 = {0,mutStr.length};
    //去掉字符串中的换行符
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
    
    return mutStr;

}

#pragma mark -- 面容or指纹支付
- (void)authPayWithFaceIDType:(FaceIDType )faceidType res:(WVJBResponseCallback)responseCallBack data:(NSDictionary *)dic
{
    // 判断是否需要面容支付
    NSString *passwd = @"";
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    if(wallet.wallet_issmall == 3){
        [self showNotSupport];
        return;
    }
   // 当前钱包没有密码数据，指纹or面容支付没有开启
    [self facePayState:faceidType passwd:@"" data:dic res:responseCallBack succeed:NO];
           
   
}


- (void)facePayState:(FaceIDType)faceidType  passwd:(NSString *)text data:(NSDictionary *)dic res:(WVJBResponseCallback)responseCallback succeed:(BOOL)succeed
{
    LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    switch (faceidType) {
        case FaceIDTypeImportSeed:
        {
        }
            break;
        case  FaceIDTypeSignRawTransaction:
        {
            if (succeed) {
                // 指纹or面容成功
                if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
                    NSString *hashTx = dic[@"createHash"];
                    NSString *coinType = dic[@"cointype"];
                    NSString *rememberCode = [GoFunction deckey:selectedWallet.wallet_remembercode password:text];
                    WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2( @"ETH",[self remv:rememberCode],nil );
                    NSString *priKey = [[hdWallet newKeyPriv:0 error:nil] hexString];
                    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
                    if (wallet.wallet_issmall == 2) {
                        // 私钥钱包的话，保存的助记词就是私钥
                        priKey = rememberCode;
                    }
                    NSData* hashData = WalletapiHexTobyte(hashTx);
                    WalletapiSignData *signData = [[WalletapiSignData alloc] init];
                    signData.data = hashData;
                    signData.cointype = [coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY";
                    signData.privKey = priKey;
                    signData.addressID =  [coinType isEqualToString:@"YCC"] ? 2 : 0;
                    NSString *signedHash =  WalletapiSignRawTransaction(signData, nil);
                    NSDictionary *param = @{@"signHash":signedHash};
                    responseCallback(param);
                } else {
                    [self showCustomMessage:L(@"密码错误") hideAfterDelay:1];
                    NSDictionary *param = @{@"error":L(@"取消支付")  };
                    responseCallback(param);
                }
            }else{
                // 各种失败情况
                [self signAction:responseCallback object:dic];
            }
        }
            break;
        case FaceIDTypeCoinsWithoutTxGroup:
        {
            if (succeed) {
                // 指纹or面容成功
                if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
                    NSString *hashTx = dic[@"createHash"];
                    NSString *coinType = dic[@"cointype"];
                    NSString *rememberCode = [GoFunction deckey:selectedWallet.wallet_remembercode password:text];
                    WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2([coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY",[self remv:rememberCode],nil );
                    
                    NSString *priKey = [[hdWallet newKeyPriv:0 error:nil] hexString];
                    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
                    if (wallet.wallet_issmall == 2) {
                        // 私钥钱包的话，保存的助记词就是私钥
                        priKey = rememberCode;
                    }
                    
                    NSInteger length = 3;
                    if ([hashTx containsString:@","])
                    {
                        NSArray *array = [hashTx componentsSeparatedByString:@","];
                        if (array.count != 0 ) {
                            length = array.count + 2;
                        }
                    }
                    WalletapiGWithoutTx *gtx = [[WalletapiGWithoutTx alloc] init];
//                    if([dic[@"withhold"] isEqualToNumber:@-1]){
                        [gtx setFeepriv:priKey];// 用户私钥
//                    }else{
//                        [gtx setFeepriv:self.feePrikey];// 接口获取代扣私钥
//                    }
                    [gtx setTxpriv:priKey];
                    [gtx setRawTx:hashTx];
                    [gtx setNoneExecer:dic[@"exer"]];
                    [gtx setFee:self.btyFeeValue*length];
                    [gtx setFeeAddressID:[coinType isEqualToString:@"YCC"] ? 2 : 0];
                    NSError *error;
                    WalletapiGsendTxResp *resp = WalletapiCoinsWithoutTxGroup(gtx, &error);
                    NSString *signedHash = resp.signedTx;
                    if (signedHash == nil) {
                        [self showCustomMessage:L(@"操作失败，请重新进入页面") hideAfterDelay:2.f];
                        return;
                    }
                    NSDictionary *param = @{@"signHash":signedHash};
                    responseCallback(param);
                } else {
                    [self showCustomMessage:L(@"密码错误") hideAfterDelay:1];
                    NSDictionary *param = @{@"error":L(@"取消支付")  };
                    responseCallback(param);
                }
            }else{
                // 各种失败情况
                [self signTxroup:responseCallback object:dic];
            }
        }
            break;
        default:
            break;
    }
}


//签名
- (void)signAction:(WVJBResponseCallback)responseCallback  object:(NSDictionary *)dic{
    
    if (!IS_BLANK(self.priKey)) {
        NSString *hashTx = dic[@"createHash"];
        NSString *coinType = dic[@"cointype"];
        NSData* hashData = WalletapiHexTobyte(hashTx);
        
        WalletapiSignData *signData = [[WalletapiSignData alloc] init];
        signData.data = hashData;
        signData.cointype = [coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY";
        signData.privKey = self.priKey;
        signData.addressID =  [coinType isEqualToString:@"YCC"] ? 2 : 0;
        NSString *signedHash =  WalletapiSignRawTransaction(signData, nil);
        
        NSDictionary *param = @{@"signHash":signedHash};
        responseCallback(param);
        return;
    }
    
    LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    PWAlertController *alertVC = [[PWAlertController alloc] initWithTitle:L(@"请输入密聊密码")  withTextValue:@""leftButtonName:nil rightButtonName:L(@"确定")  handler:^(ButtonType type, NSString *text) {
        if (type == ButtonTypeLeft){
            NSDictionary *param = @{@"error":L(@"取消支付") };
            responseCallback(param);
        }
        if (type == ButtonTypeRight) {
            if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
                NSString *hashTx = dic[@"createHash"];
                NSString *coinType = dic[@"cointype"];
                NSString *rememberCode = [GoFunction deckey:selectedWallet.wallet_remembercode password:text];
                WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2([coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY",[self remv:rememberCode],nil );
                NSString *priKey = [[hdWallet newKeyPriv:0 error:nil] hexString];
                LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
                if (wallet.wallet_issmall == 2) {
                    // 私钥钱包的话，保存的助记词就是私钥
                    priKey = rememberCode;
                }
                NSData* hashData = WalletapiHexTobyte(hashTx);
                WalletapiSignData *signData = [[WalletapiSignData alloc] init];
                signData.data = hashData;
                signData.cointype = [coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY";
                signData.privKey = priKey;
                signData.addressID =  [coinType isEqualToString:@"YCC"] ? 2 : 0;
                NSString *signedHash =  WalletapiSignRawTransaction(signData, nil);
                NSDictionary *param = @{@"signHash":signedHash};
                responseCallback(param);
            } else {
                [self showCustomMessage:L(@"密码错误")  hideAfterDelay:1];
                NSDictionary *param = @{@"error":L(@"取消支付") };
                responseCallback(param);
            }
        }
    }];
    alertVC.closeVC = ^{
        NSLog(@"取消支付");
        NSDictionary *param = @{@"error":L(@"取消支付") };
        responseCallback(param);
        
    };
    alertVC.view.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    [self presentViewController:alertVC animated:false completion:nil];
}

- (void)signTxroup:(WVJBResponseCallback)responseCallback object:(NSDictionary *)dic
{
    
    if (!IS_BLANK(self.priKey)) {
        NSString *hashTx = dic[@"createHash"];
        NSString *coinType = dic[@"cointype"];
        NSInteger length = 3;
        if ([hashTx containsString:@","])
        {
            NSArray *array = [hashTx componentsSeparatedByString:@","];
            if (array.count != 0 ) {
                length = array.count + 2;
            }
        }
        WalletapiGWithoutTx *gtx = [[WalletapiGWithoutTx alloc] init];
//        if([dic[@"withhold"] isEqualToNumber:@-1]){
            [gtx setFeepriv:self.priKey];// 用户私钥
//        }else{
//            [gtx setFeepriv:self.feePrikey];// 接口获取代扣私钥
//        }
        [gtx setTxpriv:self.priKey];
        [gtx setRawTx:hashTx];
        [gtx setNoneExecer:dic[@"exer"]];
        [gtx setFee:self.btyFeeValue*length];
        [gtx setFeeAddressID:[coinType isEqualToString:@"YCC"] ? 2 : 0];
       
        NSError *error;
        WalletapiGsendTxResp *resp = WalletapiCoinsWithoutTxGroup(gtx, &error);
        NSString *signedHash = resp.signedTx;
        if (resp == nil) {
            [self showCustomMessage:L(@"操作失败，请重新进入页面")  hideAfterDelay:2.f];
            return;
        }
        NSDictionary *param = @{@"signHash":signedHash};
        responseCallback(param);
        return;
    }
    LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    PWAlertController *alertVC = [[PWAlertController alloc] initWithTitle:L(@"请输入密聊密码")  withTextValue:@""leftButtonName:nil rightButtonName:L(@"确定")  handler:^(ButtonType type, NSString *text) {
        if (type == ButtonTypeLeft){
            NSDictionary *param = @{@"error":L(@"取消支付")};
            responseCallback(param);
        }
        if (type == ButtonTypeRight) {
            if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
                NSString *hashTx = dic[@"createHash"];
                NSString *coinType = dic[@"cointype"];
                NSString *rememberCode = [GoFunction deckey:selectedWallet.wallet_remembercode password:text];
                WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2([coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY",[self remv:rememberCode],nil );
                
                NSString *priKey = [[hdWallet newKeyPriv:0 error:nil] hexString];
                LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
                if (wallet.wallet_issmall == 2) {
                    // 私钥钱包的话，保存的助记词就是私钥
                    priKey = rememberCode;
                }
                
                NSInteger length = 3;
                if ([hashTx containsString:@","])
                {
                    NSArray *array = [hashTx componentsSeparatedByString:@","];
                    if (array.count != 0 ) {
                        length = array.count + 2;
                    }
                }
                WalletapiGWithoutTx *gtx = [[WalletapiGWithoutTx alloc] init];
//                if([dic[@"withhold"] isEqualToNumber:@-1]){
                    [gtx setFeepriv:priKey];// 用户私钥
//                }else{
//                    [gtx setFeepriv:self.feePrikey];// 接口获取代扣私钥
//                }
                [gtx setTxpriv:priKey];
                [gtx setRawTx:hashTx];
                [gtx setNoneExecer:dic[@"exer"]];
                [gtx setFee:self.btyFeeValue*length];
                [gtx setFeeAddressID:[coinType isEqualToString:@"YCC"] ? 2 : 0];
                NSError *error;
                WalletapiGsendTxResp *resp = WalletapiCoinsWithoutTxGroup(gtx, &error);
                NSString *signedHash = resp.signedTx;
                if (signedHash == nil) {
                    [self showCustomMessage:L(@"操作失败，请重新进入页面") hideAfterDelay:2.f];
                    return;
                }
                NSDictionary *param = @{@"signHash":signedHash};
                responseCallback(param);
            } else {
                [self showCustomMessage:L(@"密码错误") hideAfterDelay:1];
                NSDictionary *param = @{@"error":L(@"取消支付")};
                responseCallback(param);
            }
        }
    }];
    alertVC.closeVC = ^{
        NSLog(@"取消支付");
        NSDictionary *param = @{@"error":L(@"取消支付")};
        responseCallback(param);
        
    };
    alertVC.view.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    [self presentViewController:alertVC animated:false completion:nil];
}

- (NSString *)remv:(nullable NSString *)menc
{
    NSString *codeStr = [PWUtils removeSpaceAndNewline:menc];
    if([PWUtils isChineseWithstr:codeStr]){
        NSMutableString *str = [NSMutableString new];
        for (int i = 0; i < codeStr.length; i ++) {
            [str appendString:[codeStr substringWithRange:NSMakeRange(i, 1)]];
            if (i != codeStr.length - 1) {
                [str appendString:@" "];
            }
        }
        
        return [NSString stringWithString:str];
    }else{
        return menc;
    }
    
   
}

/// 将合约 `data` 的十六进制串（可无 `0x`）转为二进制再做 Base64，供签名构造 JSON 里的 `input` 字段（见 WebViewMetaMaskCoordinator）。
- (NSString *)base64Encoding:(nullable NSString *)input {
    if (input == nil || input.length == 0) {
        return @"";
    }
    NSString *s = [[input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if ([s hasPrefix:@"0x"]) {
        s = [s substringFromIndex:2];
    }
    NSData *data = WalletapiHexTobyte(s);
    if (data.length == 0 && s.length > 0 && (s.length % 2) == 0) {
        NSMutableData *md = [NSMutableData dataWithLength:s.length / 2];
        unsigned char *p = md.mutableBytes;
        for (NSUInteger i = 0; i < s.length; i += 2) {
            unsigned int v = 0;
            if (![[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&v]) {
                return @"";
            }
            p[i / 2] = (unsigned char)(v & 0xff);
        }
        data = md;
    }
    if (data == nil || data.length == 0) {
        return @"";
    }
    return [data base64EncodedStringWithOptions:0];
}

#pragma mark - 获取代扣私钥
- (void)getFeePrikeyWithPlatform:(NSString *)platform CoinName:(NSString *)coinName
{
    NSDictionary *param =  @{@"platform":platform,@"coinname":coinName};
    WEAKSELF
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodGET serverUrl:WalletURL apiPath:@"/interface/coin/get-with-hold" parameters:param progress:nil success:^(BOOL isSuccess, id  _Nullable responseObject) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        
        NSInteger code = [result[@"code"] integerValue];
        if(code == 0) {
            NSDictionary *dict = result[@"data"];
            if ([dict isKindOfClass:[NSNull class]])
            {
                weakSelf.feePrikey = @"";
                weakSelf.btyFeeValue = 0;
            }
            else
            {
                weakSelf.feePrikey = [self decodeDesWithString:result[@"data"][@"private_key"]];
                weakSelf.btyFeeValue = [result[@"data"][@"bty_fee"] doubleValue];
            }
            
        }else{
            
        }
    } failure:^(NSString * _Nullable errorMessage) {
        
    }];
}

- (NSString *)decodeDesWithString:(NSString *)str{
    NSData *encryptData = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    size_t plainTextBufferSize = [encryptData length];
    const void *vplainText = [encryptData bytes];
    CCCryptorStatus ccStatus;
    uint8_t *bufferPtr = NULL;
    size_t bufferPtrSize = 0;
    size_t movedBytes = 0;
    bufferPtrSize = (plainTextBufferSize + kCCBlockSizeDES) & ~(kCCBlockSizeDES - 1);
    bufferPtr = malloc( bufferPtrSize * sizeof(uint8_t));
    memset((void *)bufferPtr, 0x0, bufferPtrSize);
    const void *vkey = (const void *) [DESKeyForGame UTF8String];
    const void *vinitVec = (const void *) [kInitVectorForGame UTF8String];
    ccStatus = CCCrypt(kCCDecrypt,
                       kCCAlgorithmDES,
                       kCCOptionPKCS7Padding,
                       vkey,
                       kCCKeySizeDES,
                       vinitVec,
                       vplainText,
                       plainTextBufferSize,
                       (void *)bufferPtr,
                       bufferPtrSize,
                       &movedBytes);
    if (ccStatus == kCCSuccess)
    {
        NSString *result = [[NSString alloc] initWithData:[NSData dataWithBytes:(const void *)bufferPtr length:(NSUInteger)movedBytes] encoding:NSUTF8StringEncoding];
        return result;
    }
   
    return @"";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *loadUrl = [url absoluteString];

    NSLog(@"---------------->URL变化%@",loadUrl);

//    decisionHandler(WKNavigationActionPolicyCancel);
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    if (navigationAction.request.URL) {
        NSURL *url = navigationAction.request.URL;
        NSString *urlPath = url.absoluteString;
        if ([urlPath rangeOfString:@"https://"].location != NSNotFound || [urlPath rangeOfString:@"http://"].location != NSNotFound) {
            
            [[UIApplication sharedApplication] openURL:url];
        }
    }
    return nil;
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask{
    if (urlSchemeTask.request.URL.path != nil) {
        NSString *fileExtension = urlSchemeTask.request.URL.pathExtension;
        if ([fileExtension isEqualToString:@"otf"]){
            NSString *nameWithoutExtengsion = urlSchemeTask.request.URL.URLByDeletingPathExtension.lastPathComponent;
            NSURL *url = [NSBundle.mainBundle URLForResource:nameWithoutExtengsion withExtension:fileExtension];
            NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:nil];
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:urlSchemeTask.request.URL MIMEType:@"font/opentype" expectedContentLength:data.length textEncodingName:nil];
            [urlSchemeTask didReceiveResponse:response];
            [urlSchemeTask didReceiveData:data];
            [urlSchemeTask didFinish];
            return;
            
        }
    }
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask{
   
}



- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if (webView != self.webView) {
        return;
    }
    // SPA（如 Vue hash 路由）首屏后壳子才就绪；再广播一次，便于 wagmi / EIP-6963 发现钱包
    NSString *ping = @"typeof window.__tanxinWalletBridgePing==='function' && window.__tanxinWalletBridgePing()";
    [webView evaluateJavaScript:ping completionHandler:^(id _Nullable r, NSError * _Nullable err) {
        if (err) {
            NSLog(@"[WebView] bridge ping: %@", err);
        }
    }];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"error %@",error);
}

//KVO监听进度条
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))] && object == self.webView) {
        [self.progressView setAlpha:1.0f];
        BOOL animated = self.webView.estimatedProgress > self.progressView.progress;
        [self.progressView setProgress:self.webView.estimatedProgress animated:animated];
        if(self.webView.estimatedProgress >= 1.0f) {
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                [self.progressView setAlpha:0.0f];
            } completion:^(BOOL finished) {
                [self.progressView setProgress:0.0f animated:NO];
            }];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark ---- 进度条 ------
- (UIProgressView *)progressView{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 3);
        
        // 设置进度条的色彩
        [_progressView setTrackTintColor:[UIColor colorWithRed:240.0/255 green:240.0/255 blue:240.0/255 alpha:1.0]];
        _progressView.progressTintColor = [UIColor colorWithRed:113.0/255 green:144.0/255 blue:255.0/255 alpha:1.0];
    }
    return _progressView;
}


#pragma mark - js method

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
    NSLog(@"message->%@",message.body);
    NSDictionary *mesDict = message.body;
     if ([message.name isEqualToString:@"iosHost"]){
        // WKScriptMessageHandler 可能在非主线程调用；推迟到主队列处理。
        id idVal = mesDict[@"id"];
        NSString *requestId = [idVal isKindOfClass:[NSString class]] ? idVal : ([idVal isKindOfClass:[NSNumber class]] ? [(NSNumber *)idVal stringValue] : (idVal ? [NSString stringWithFormat:@"%@", idVal] : nil));
        NSString *method = mesDict[@"method"];
        NSArray *params = mesDict[@"params"];
        if (!requestId || requestId.length == 0) {
            // 避免与 JS 侧 fallback 或其它空 id 并发时撞同一时间戳，导致 requestId 重复、回包对错请求
            requestId = [NSString stringWithFormat:@"%.6f-%@", [[NSDate date] timeIntervalSince1970], [[NSUUID UUID] UUIDString]];
        }
        NSDictionary *payload = @{@"requestId": requestId, @"method": method ?: @"", @"params": params ?: @[]};
        dispatch_async(dispatch_get_main_queue(), ^{
            [self routeMetaMaskIosHostRequestWithMethod:payload[@"method"]
                                               requestId:payload[@"requestId"]
                                                  params:payload[@"params"]];
        });
    }
    
}

#pragma mark - MetaMask（iosHost 仅经此路由至 WebViewMetaMaskCoordinator）

static NSSet<NSString *> *WebViewMetaMaskGenericRpcMethodSet(void) {
    static NSSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[
            @"eth_getBalance",
            @"eth_gasPrice",
            @"eth_blockNumber",
            @"eth_getTransactionCount",
            @"eth_getTransactionReceipt",
            @"eth_getBlockByNumber",
            @"eth_getBlockByHash",
            @"eth_getTransactionByHash",
            @"eth_getCode",
            @"eth_getLogs",
            @"eth_getStorageAt",
            @"eth_getBlockTransactionCountByHash",
            @"eth_getBlockTransactionCountByNumber",
            @"eth_getUncleByBlockHashAndIndex",
            @"eth_getUncleByBlockNumberAndIndex",
            @"eth_protocolVersion",
            @"eth_syncing",
            @"eth_feeHistory",
            @"eth_maxPriorityFeePerGas",
            @"eth_createAccessList",
            @"eth_sendRawTransaction",
            @"eth_newFilter",
            @"eth_newBlockFilter",
            @"eth_newPendingTransactionFilter",
            @"eth_uninstallFilter",
            @"eth_getFilterChanges",
            @"eth_getFilterLogs",
        ]];
    });
    return set;
}

/// 将 `iosHost` 注入的 JSON-RPC `method` 分发给协调器；未识别的 method 与旧逻辑一致直接忽略。
- (void)routeMetaMaskIosHostRequestWithMethod:(NSString *)m requestId:(NSString *)rid params:(NSArray *)p {
    WebViewMetaMaskCoordinator *coord = self.metaMaskCoordinator;
    if (!coord || m.length == 0) {
        return;
    }
    if ([m isEqualToString:@"eth_requestAccounts"] || [m isEqualToString:@"eth_accounts"]) {
        [coord handleEthRequestAccounts:rid method:m];
        return;
    }
    if ([m isEqualToString:@"eth_chainId"]) {
        [coord handleEthChainId:rid method:m];
        return;
    }
    if ([m isEqualToString:@"net_version"]) {
        [coord handleNetVersion:rid method:m];
        return;
    }
    if ([m isEqualToString:@"personal_sign"]) {
        [coord handlePersonalSign:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"eth_sign"]) {
        [coord handleEthSign:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"eth_signTypedData"]) {
        [coord handleEthSignTypedData:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"eth_signTypedData_v4"]) {
        [coord handleEthSignTypedDataV4:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"eth_sendTransaction"]) {
        [coord handleEthSendTransaction:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"eth_call"]) {
        [coord handleEthCall:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"wallet_switchEthereumChain"]) {
        [coord handleSwitchEthereumChain:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"wallet_addEthereumChain"]) {
        [coord handleWalletAddEthereumChain:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"wallet_getPermissions"]) {
        [coord handleWalletGetPermissions:rid method:m];
        return;
    }
    if ([m isEqualToString:@"wallet_requestPermissions"]) {
        [coord handleWalletRequestPermissions:rid params:p method:m];
        return;
    }
    if ([m isEqualToString:@"web3_clientVersion"]) {
        [coord handleWeb3ClientVersion:rid method:m];
        return;
    }
    if ([m isEqualToString:@"eth_estimateGas"]) {
        [coord handleEthEstimateGas:rid params:p method:m];
        return;
    }
    if ([WebViewMetaMaskGenericRpcMethodSet() containsObject:m]) {
        [coord handleGenericRpc:rid method:m params:p];
    }
}

- (Web3ProviderHandler *)web3ProviderHandler {
    if (!_web3ProviderHandler) {
        _web3ProviderHandler = [[Web3ProviderHandler alloc] init];
    }
    return _web3ProviderHandler;
}

#pragma mark - 通知 JS 层 chainChanged 事件
- (void)notifyChainChanged:(nullable NSString *)newChainId {
    NSString *cid = [newChainId lowercaseString];
    unsigned long long v = 0;
    [[NSScanner scannerWithString:cid] scanHexLongLong:&v];
    NSString *netVer = [NSString stringWithFormat:@"%llu", v];
    NSString *js = [NSString stringWithFormat:@"if(window.ethereum){window.ethereum.chainId='%@';window.ethereum.networkVersion='%@';window.ethereum.emit('chainChanged','%@');}", cid, netVer, cid];
    [self.webView evaluateJavaScript:js completionHandler:^(id _Nullable res, NSError * _Nullable err) {
        if (err){ NSLog(@"Evaluate JS Error: %@", err);}
        else{
            [self getNonce];
            [self getGasPrice];
        }
    }];
}

#pragma mark - Response to JS

- (void)sendResponseToJS:(nullable NSString *)requestId result:(nullable id)result error:(nullable id)error method:(nullable NSString *)method {
    
    [self sendResponseToJS:requestId result:result error:error method:method skipEmitAfterConnect:NO];
}

- (void)sendResponseToJS:(nullable NSString *)requestId result:(nullable id)result error:(nullable id)error method:(nullable NSString *)method skipEmitAfterConnect:(BOOL)skipEmitAfterConnect {
    NSString *resultJson = BenefyJsonFragmentForJs(result);
    NSString *errorJson = BenefyJsonFragmentForJs(error);

    // 执行 JS：requestId 用 JSON 字符串字面量（不可对 NSString 直接 dataWithJSONObject，会闪退）
    NSString *ridJson = BenefyJsonStringForJsLiteral(requestId);
    NSMutableString *inner = [NSMutableString stringWithFormat:@"try{if(window.ethereum&&window.ethereum._onResponse){window.ethereum._onResponse(%@,%@,%@);}else{console.warn('[wallet] ethereum bridge not ready');}}catch(e){console.error('[wallet] _onResponse',e);}", ridJson, resultJson, errorJson];
    if ([method isEqualToString:@"eth_chainId"] && result && [result isKindOfClass:[NSString class]] && !error) {
        NSString *chId = [(NSString *)result lowercaseString];
        unsigned long long chainVal = 0;
        [[NSScanner scannerWithString:chId] scanHexLongLong:&chainVal];
        NSString *netVer = [NSString stringWithFormat:@"%llu", chainVal];
        NSString *assign = [NSString stringWithFormat:@"if(window.ethereum){window.ethereum.chainId='%@';window.ethereum.networkVersion='%@';}", chId, netVer];
        [inner insertString:assign atIndex:0];
    }
    // JS 侧：下一个事件循环再执行 _onResponse，避免与 postMessage 后注册 _callbacks 的时序竞态（全速运行时常见，单步会掩盖）
    NSString *jsBody = [NSString stringWithFormat:@"setTimeout(function(){%@},0);", inner];

    /// 仅在上链成功时推进本地 nonce；失败或用户取消仍 +1 会导致本地 nonce 高于链上，RPC 报 nonce too high。
    BOOL shouldBumpNonceAfterEthSend = NO;
    if ([method isEqualToString:@"eth_sendTransaction"] && (error == nil || error == [NSNull null]) && result != nil && result != [NSNull null]) {
        if ([result isKindOfClass:[NSString class]]) {
            shouldBumpNonceAfterEthSend = [(NSString *)result length] > 0;
        } else {
            shouldBumpNonceAfterEthSend = YES;
        }
    }

    WEAKSELF
    void (^emitAfterConnect)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (skipEmitAfterConnect) {
            return;
        }
        if (![method isEqualToString:@"eth_requestAccounts"] || !result || ![result isKindOfClass:[NSArray class]] || [(NSArray *)result count] == 0) {
            return;
        }
        NSString *emitJs = [strongSelf.metaMaskCoordinator tanxinJsForEmitConnectAndAccountsChanged:(NSArray *)result];
        dispatch_queue_t q = strongSelf.walletJsResponseSerialQueue;
        if (q) {
            dispatch_async(q, ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf.webView evaluateJavaScript:emitJs completionHandler:nil];
                });
            });
        } else {
            [strongSelf.webView evaluateJavaScript:emitJs completionHandler:nil];
        }
    };

    void (^onEvalDone)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (shouldBumpNonceAfterEthSend) {
            NSInteger nonce = strongSelf.nonce.integerValue;
            nonce += 1;
            strongSelf.nonce = [NSString stringWithFormat:@"%li", (long)nonce];
        }
        emitAfterConnect();
    };

    void (^runEvalOnce)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf.webView) {
            return;
        }
        [strongSelf.webView evaluateJavaScript:jsBody completionHandler:^(id _Nullable res, NSError * _Nullable err) {
            if (err) {
                NSLog(@"Evaluate JS Error: %@", err);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf2 = weakSelf;
                    if (!strongSelf2.webView) {
                        return;
                    }
                    [strongSelf2.webView evaluateJavaScript:jsBody completionHandler:^(id _Nullable res2, NSError * _Nullable err2) {
                        if (err2) {
                            NSLog(@"Evaluate JS retry failed: %@", err2);
                        } else {
                            onEvalDone();
                        }
                    }];
                });
            } else {
                onEvalDone();
            }
        }];
    };

    if (!self.walletJsResponseSerialQueue) {
        self.walletJsResponseSerialQueue = dispatch_queue_create("com.tanxin.wallet.jsresponse", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(self.walletJsResponseSerialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            runEvalOnce();
        });
    });
}

#pragma mark -- nonce  gasprice
- (void)getNonce{
    
    /// `pending` 含内存池未上链交易，与 DApp / 节点「下一笔可用 nonce」一致；`latest` 易与本地缓存不同步。
    NSArray *param = @[[GameGoFunction queryAddressByChain:self.selectedChain], @"pending"];
    NSDictionary *params = @{@"id":@1,
                             @"jsonrpc":@"2.0",
                             @"method":@"eth_getTransactionCount",
                             @"params":param};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:_selectedRpcUlr
                                          apiPath:@""
                                       parameters:params
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        
        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"eth_getTransactionCount is %@",jsonData);
        NSString *result = jsonData[@"result"];
        if (result != nil && [result isKindOfClass:[NSString class]] && [(NSString *)result length] > 0) {
            self.nonce = [self sixteenToTen:result];
        }
       
    } failure:^(NSString * _Nullable errorMessage) {
        NSLog(@"error is %@",errorMessage);
        
    }];
}

- (void)getGasPrice{
    
    NSDictionary *params = @{@"id":@1,
                             @"jsonrpc":@"2.0",
                             @"method":@"eth_gasPrice",
                             @"params":@[]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:_selectedRpcUlr
                                          apiPath:@""
                                       parameters:params
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        
        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"eth_gasPrice is %@",jsonData);
        NSString *result = jsonData[@"result"];
        if(result != nil || result.length != 0){
            self.gasPrice = [self sixteenToTen:result];
        }
       
    } failure:^(NSString * _Nullable errorMessage) {
        NSLog(@"error is %@",errorMessage);
        
    }];
}

- (NSString *)sixteenToTen:(nullable NSString *)str{

    if(str == nil){
        return @"0";
    }
    if ([str isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"%@", (NSNumber *)str];
    }
    if (![str isKindOfClass:[NSString class]]) {
        str = [NSString stringWithFormat:@"%@", str];
    }
    NSString *s = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) {
        return @"0";
    }
    // 统一 0x / 0X，兼容 EIP-1193 常见十六进制 chainId 写法
    if ([s hasPrefix:@"0x"] || [s hasPrefix:@"0X"]) {
        s = [s substringFromIndex:2];
    }

    JKBigInteger *hexint = [[JKBigInteger alloc] initWithString:s andRadix:16];

    return [NSString stringWithFormat:@"%@",hexint];

}
/**
 @param decimal 10进制数字
 @param uppercase 是否大写
 @return 16进制字符串
**/
 - (NSString *)tenToSixteen:(long long)decimal isUppercase:(BOOL)uppercase{
     NSString *format = uppercase ? @"%llX" : @"%llx";
     NSString *sixStr =[NSString stringWithFormat:format, decimal];

     return [NSString stringWithFormat:@"0x%@",sixStr];
}

// 补齐工具方法
- (NSString *)padHexTo32Bytes:(NSString *)hex {
    if (![hex isKindOfClass:[NSString class]] || ![hex hasPrefix:@"0x"]) return hex;
    NSString *cleanHex = [hex stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    if (cleanHex.length > 0 && cleanHex.length < 64) {
        NSString *padding = [@"" stringByPaddingToLength:(64 - cleanHex.length) withString:@"0" startingAtIndex:0];
        return [@"0x" stringByAppendingString:[padding stringByAppendingString:cleanHex]];
    }
    return hex;
}

@end

