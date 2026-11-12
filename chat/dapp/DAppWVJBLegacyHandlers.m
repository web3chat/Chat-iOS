//
//  DAppWVJBLegacyHandlers.m
//  chat
//
//  与 WebViewController 中 _bridge 注册的 H5 通道行为对齐（Swift 浏览器内复用）。
//

#import "DAppWVJBLegacyHandlers.h"
#import <WKWebViewJavascriptBridge.h>
#import "chat-Swift.h"
#import "Depend.h"
#import "GameGoFunction.h"
#import "ScanViewController.h"
#import "GoFunction.h"
#import "PWDataBaseManager.h"
#import "LocalWallet.h"
#import "PWAlertController.h"
#import "UIViewController+ShowInfo.h"
#import "SGNetWork.h"
#import "PWUtils.h"

/// 与全仓 `L()` 同源：走 `LanguageManager` 的 lproj 包，跟随 App 内切换的语言
/// （`NSLocalizedString` 读 Bundle.main，只会跟随系统语言，两者会不一致）。
#define DAppL(key) [[LanguageManager shared] localizedStringForKey:key]

static double gDappBtyFeeValue = 0;
static NSString *DAppRemv(NSString *menc) {
    if (menc == nil) { return nil; }
    NSString *codeStr = [PWUtils removeSpaceAndNewline:menc];
    if ([PWUtils isChineseWithstr:codeStr]) {
        NSMutableString *str = [NSMutableString new];
        for (NSUInteger i = 0; i < codeStr.length; i++) {
            [str appendString:[codeStr substringWithRange:NSMakeRange(i, 1)]];
            if (i != codeStr.length - 1) {
                [str appendString:@" "];
            }
        }
        return [NSString stringWithString:str];
    }
    return menc;
}

static void DAppPresentUnsupportedWallet(UIViewController *host) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:DAppL(@"提示") message:DAppL(@"当前钱包不支持该项目") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:DAppL(@"知道了") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [host.navigationController popViewControllerAnimated:YES];
    }]];
    [host presentViewController:alert animated:YES completion:nil];
}

/// JSON-RPC 2.0 错误码：参数非法 / 用户拒绝。
static NSInteger const DAppErrorInvalidParams = -32602;
static NSInteger const DAppErrorUserRejected = -32000;

/// 回包兜底：`WVJBResponseCallback` 可能为空（页面没要返回值时），直接调用会崩。
static void DAppRespond(WVJBResponseCallback responseCallback, NSDictionary *payload) {
    if (responseCallback) { responseCallback(payload); }
}

#pragma mark - 按站点授权（只存内存，App 重启即清空）

static NSMutableSet<NSString *> *DAppApprovedOrigins(void) {
    static NSMutableSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ set = [NSMutableSet set]; });
    return set;
}

static BOOL DAppIsOriginApproved(NSString *origin) {
    if (origin.length == 0) { return NO; }
    @synchronized (DAppApprovedOrigins()) {
        return [DAppApprovedOrigins() containsObject:origin.lowercaseString];
    }
}

static void DAppApproveOrigin(NSString *origin) {
    if (origin.length == 0) { return; }
    @synchronized (DAppApprovedOrigins()) {
        [DAppApprovedOrigins() addObject:origin.lowercaseString];
    }
}

/// 交易签名的「按站点授权」闸门。
///
/// - 已授权的站点：直接放行；
/// - 未授权：弹窗展示来源，用户明确同意后才放行；
/// - 拿不到来源（`webView.url` 为空等）：直接拒绝，宁可不签。
static void DAppAuthorizeSigning(UIViewController *host,
                                 NSString *origin,
                                 void (^granted)(void),
                                 void (^denied)(void)) {
    NSString *normalized = [[origin stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (normalized.length == 0) {
        if (denied) { denied(); }
        return;
    }
    if (DAppIsOriginApproved(normalized)) {
        if (granted) { granted(); }
        return;
    }

    NSString *message = [NSString stringWithFormat:
        @"%@\n\n%@：%@\n\n%@",
        DAppL(@"该站点请求「交易签名」权限。授权后，它可以在你每次确认的情况下发起签名请求。"),
        DAppL(@"站点"), normalized,
        DAppL(@"请只在你完全信任该站点时继续。")];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:DAppL(@"签名权限申请")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:DAppL(@"拒绝")
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action) {
        if (denied) { denied(); }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:DAppL(@"信任并继续")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        DAppApproveOrigin(normalized);
        // 等这个弹窗收完再进下一步，否则紧接着弹密码框会报 present 冲突
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (granted) { granted(); }
        });
    }]];
    [host presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 原始交易签名：格式校验与逐笔确认

/// 校验 `createHash`。
///
/// - `sign`：走 `WalletapiHexTobyte`，必须是十六进制；
/// - `signTxGroup`：`rawTx` 是 `Wallet.CreateRawTransaction` 返回的原始串，不一定是纯 hex，
///   所以只要求非空（多笔用逗号分隔，逐段非空）。
static BOOL DAppIsValidCreateHash(NSString *hash, BOOL requireHex) {
    if (hash.length == 0) { return NO; }
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    for (NSString *part in [hash componentsSeparatedByString:@","]) {
        NSString *h = part;
        if (!requireHex) {
            if (h.length == 0) { return NO; }
            continue;
        }
        if ([h hasPrefix:@"0x"] || [h hasPrefix:@"0X"]) { h = [h substringFromIndex:2]; }
        if (h.length == 0) { return NO; }
        if ([h rangeOfCharacterFromSet:nonHex].location != NSNotFound) { return NO; }
    }
    return YES;
}

static NSString *DAppShortHash(NSString *hash) {
    if (hash.length <= 26) { return hash ?: @"-"; }
    return [NSString stringWithFormat:@"%@…%@",
            [hash substringToIndex:20],
            [hash substringFromIndex:hash.length - 6]];
}

/// 每笔签名前的逐笔确认：明确告诉用户本地无法解析这笔交易的内容。
static void DAppPresentRawSignConfirm(UIViewController *host,
                                      NSString *coinType,
                                      NSString *exer,
                                      NSString *hash,
                                      void (^proceed)(void),
                                      void (^cancelled)(void)) {
    NSMutableString *message = [NSMutableString string];
    [message appendString:DAppL(@"该网页请求对一段原始交易数据签名。钱包无法在本地解析出这笔交易的收款地址与金额，请确认你完全信任当前站点。")];
    [message appendFormat:@"\n\n%@：%@", DAppL(@"币种"), (coinType.length > 0 ? coinType : @"-")];
    if (exer.length > 0) {
        [message appendFormat:@"\n%@：%@", DAppL(@"执行器"), exer];
    }
    [message appendFormat:@"\n%@：%@", DAppL(@"待签哈希"), DAppShortHash(hash)];
    [message appendString:@"\n\n"];
    [message appendString:DAppL(@"签名一经确认不可撤销，可能导致资产被转走。")];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:DAppL(@"确认签名")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:DAppL(@"取消")
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action) {
        if (cancelled) { cancelled(); }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:DAppL(@"我已确认，继续")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (proceed) { proceed(); }
        });
    }]];
    [host presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 原始交易签名（单笔）

static void DAppWVJBSignRawTxPerform(UIViewController *host, NSDictionary *dic, WVJBResponseCallback responseCallback) {
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    if (wallet.wallet_issmall == 3) {
        DAppPresentUnsupportedWallet(host);
        DAppRespond(responseCallback, @{@"error": DAppL(@"当前钱包不支持该项目"), @"code": @(DAppErrorUserRejected)});
        return;
    }
    LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    // 已开启面容/指纹：直接做人脸/指纹验证取密聊密码；未开启、验证失败或取消 → 回落密聊密码输入框。
    // 两条路拿到的都是同一个「密聊密码」，下面照旧用 checkPassword 校验。
    [ChatPasswordGate requestVerifiedPasswordWithTitle:DAppL(@"请输入密聊密码")
                                             cancelled:^{
        DAppRespond(responseCallback, @{@"error": DAppL(@"取消支付"), @"code": @(DAppErrorUserRejected)});
    } success:^(NSString * _Nonnull text) {
        if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
            NSString *hashTx = dic[@"createHash"];
            NSString *coinType = dic[@"cointype"];
            NSString *rememberCode = [GoFunction deckey:selectedWallet.wallet_remembercode password:text];
            WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2(@"ETH", DAppRemv(rememberCode), nil);
            NSString *priKey = [[hdWallet newKeyPriv:0 error:nil] hexString];
            LocalWallet *w = [[PWDataBaseManager shared] queryWalletIsSelected];
            if (w.wallet_issmall == 2) {
                priKey = rememberCode;
            }
            NSData *hashData = WalletapiHexTobyte(hashTx);
            WalletapiSignData *signData = [[WalletapiSignData alloc] init];
            signData.data = hashData;
            signData.cointype = [coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY";
            signData.privKey = priKey;
            signData.addressID = [coinType isEqualToString:@"YCC"] ? 2 : 0;
            NSString *signedHash = WalletapiSignRawTransaction(signData, nil);
            if (signedHash.length == 0) {
                DAppRespond(responseCallback, @{@"error": DAppL(@"签名失败"), @"code": @(DAppErrorUserRejected)});
                return;
            }
            DAppRespond(responseCallback, @{@"signHash": signedHash});
        } else {
            [host showCustomMessage:DAppL(@"密码错误") hideAfterDelay:1];
            DAppRespond(responseCallback, @{@"error": DAppL(@"取消支付"), @"code": @(DAppErrorUserRejected)});
        }
    }];
}

static void DAppWVJBSignTxGroupPerform(UIViewController *host, NSDictionary *dic, WVJBResponseCallback responseCallback) {
    LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    if (wallet.wallet_issmall == 3) {
        DAppPresentUnsupportedWallet(host);
        DAppRespond(responseCallback, @{@"error": DAppL(@"当前钱包不支持该项目"), @"code": @(DAppErrorUserRejected)});
        return;
    }
    LocalWallet *selectedWallet = [[PWDataBaseManager shared] queryWalletIsSelected];
    // 已开启面容/指纹：直接做人脸/指纹验证取密聊密码；未开启、验证失败或取消 → 回落密聊密码输入框。
    // 两条路拿到的都是同一个「密聊密码」，下面照旧用 checkPassword 校验。
    [ChatPasswordGate requestVerifiedPasswordWithTitle:DAppL(@"请输入密聊密码")
                                             cancelled:^{
        DAppRespond(responseCallback, @{@"error": DAppL(@"取消支付"), @"code": @(DAppErrorUserRejected)});
    } success:^(NSString * _Nonnull text) {
        if ([GoFunction checkPassword:text hash:selectedWallet.wallet_password]) {
            NSString *hashTx = dic[@"createHash"];
            NSString *coinType = dic[@"cointype"];
            NSString *rememberCode = [GoFunction deckey:selectedWallet.wallet_remembercode password:text];
            WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2([coinType isEqualToString:@"YCC"] ? @"ETH" : @"BTY", DAppRemv(rememberCode), nil);
            NSString *priKey = [[hdWallet newKeyPriv:0 error:nil] hexString];
            LocalWallet *w = [[PWDataBaseManager shared] queryWalletIsSelected];
            if (w.wallet_issmall == 2) {
                priKey = rememberCode;
            }
            NSInteger length = 3;
            if ([hashTx containsString:@","]) {
                NSArray *array = [hashTx componentsSeparatedByString:@","];
                if (array.count != 0) {
                    length = array.count + 2;
                }
            }
            WalletapiGWithoutTx *gtx = [[WalletapiGWithoutTx alloc] init];
            [gtx setFeepriv:priKey];
            [gtx setTxpriv:priKey];
            [gtx setRawTx:hashTx];
            [gtx setNoneExecer:dic[@"exer"]];
            [gtx setFee:gDappBtyFeeValue * length];
            [gtx setFeeAddressID:[coinType isEqualToString:@"YCC"] ? 2 : 0];
            NSError *error;
            WalletapiGsendTxResp *resp = WalletapiCoinsWithoutTxGroup(gtx, &error);
            NSString *signedHash = resp.signedTx;
            if (signedHash.length == 0) {
                [host showCustomMessage:DAppL(@"操作失败，请重新进入页面") hideAfterDelay:2.f];
                // 必须回包：否则页面 Promise 会永久挂起
                DAppRespond(responseCallback, @{@"error": DAppL(@"操作失败"), @"code": @(DAppErrorUserRejected)});
                return;
            }
            DAppRespond(responseCallback, @{@"signHash": signedHash});
        } else {
            [host showCustomMessage:DAppL(@"密码错误") hideAfterDelay:1];
            DAppRespond(responseCallback, @{@"error": DAppL(@"取消支付"), @"code": @(DAppErrorUserRejected)});
        }
    }];
}

/// `sign` 入口：格式校验 → 逐笔确认 → 原有密码/面容流程。
static void DAppWVJBSignRawTx(UIViewController *host, NSDictionary *dic, WVJBResponseCallback responseCallback) {
    NSString *hashTx = dic[@"createHash"];
    if (!DAppIsValidCreateHash(hashTx, YES)) {
        DAppRespond(responseCallback, @{@"error": DAppL(@"签名数据格式非法"), @"code": @(DAppErrorInvalidParams)});
        return;
    }
    DAppPresentRawSignConfirm(host, dic[@"cointype"], dic[@"exer"], hashTx, ^{
        DAppWVJBSignRawTxPerform(host, dic, responseCallback);
    }, ^{
        DAppRespond(responseCallback, @{@"error": DAppL(@"用户取消"), @"code": @(DAppErrorUserRejected)});
    });
}

/// `signTxGroup` 入口：同上（`rawTx` 不一定是 hex，只校验非空）。
static void DAppWVJBSignTxGroup(UIViewController *host, NSDictionary *dic, WVJBResponseCallback responseCallback) {
    NSString *hashTx = dic[@"createHash"];
    if (!DAppIsValidCreateHash(hashTx, NO)) {
        DAppRespond(responseCallback, @{@"error": DAppL(@"签名数据格式非法"), @"code": @(DAppErrorInvalidParams)});
        return;
    }
    DAppPresentRawSignConfirm(host, dic[@"cointype"], dic[@"exer"], hashTx, ^{
        DAppWVJBSignTxGroupPerform(host, dic, responseCallback);
    }, ^{
        DAppRespond(responseCallback, @{@"error": DAppL(@"用户取消"), @"code": @(DAppErrorUserRejected)});
    });
}

@implementation DAppWVJBLegacyHandlers

+ (void)prefetchBtyFeeConfig {
    NSDictionary *param = @{@"platform": @"bty", @"coinname": @"BTY"};
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodGET serverUrl:WalletURL apiPath:@"/interface/coin/get-with-hold" parameters:param progress:nil success:^(BOOL isSuccess, id _Nullable responseObject) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        NSInteger code = [result[@"code"] integerValue];
        if (code == 0) {
            NSDictionary *dict = result[@"data"];
            if ([dict isKindOfClass:[NSNull class]] || dict == nil) {
                gDappBtyFeeValue = 0;
            } else {
                gDappBtyFeeValue = [result[@"data"][@"bty_fee"] doubleValue];
            }
        }
    } failure:^(NSString *_Nullable errorMessage) {
    }];
}

+ (void)registerHandlersWithBridge:(WKWebViewJavascriptBridge *)bridge host:(UIViewController *)host {
    [self registerHandlersWithBridge:bridge host:host originProvider:nil];
}

+ (void)registerHandlersWithBridge:(WKWebViewJavascriptBridge *)bridge
                              host:(UIViewController *)host
                    originProvider:(DAppOriginProvider _Nullable)originProvider {
    if (!bridge || !host) { return; }

    __weak UIViewController *weakHost = host;

    /// 主框架当前站点：桥接 JS 是用 `evaluateJavaScript` 注入的，只作用于主框架，
    /// 所以 `webView.url.host` 就是发起签名请求的真实来源。
    NSString *(^currentOrigin)(void) = ^NSString * {
        return originProvider ? originProvider() : nil;
    };

    [bridge registerHandler:@"closeCurrentWebview" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong UIViewController *h = weakHost;
        [h.navigationController popViewControllerAnimated:YES];
        if (responseCallback) {
            responseCallback(nil);
        }
    }];

    // ── 原始交易签名：保留能力，但必须「按站点授权 + 逐笔确认」─────────────────
    //
    // `sign` / `signTxGroup` 收的是页面自己构造的哈希 / 裸交易：BTY 的执行器、代扣、
    // 平行链等交易类型钱包侧没有构造能力，这个通道必须保留。但它不能「谁都能调」——
    // 任何被打开的网页都能对任意摘要签名，等价于把钱包交给页面。所以：
    //   ① 首次从某个站点签：弹「签名权限申请」，用户同意后才放行（只存内存）；
    //   ② 每一笔都弹「确认签名」，如实告知本地无法解析收款地址与金额。
    // 新接入的 DApp 建议改用 EIP-1193 的 `eth_sendTransaction`（由 App 构造交易并完整展示）。
    [bridge registerHandler:@"sign" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong UIViewController *h = weakHost;
        if (![data isKindOfClass:[NSDictionary class]]) {
            DAppRespond(responseCallback, @{@"error": @"invalid data", @"code": @(DAppErrorInvalidParams)});
            return;
        }
        DAppAuthorizeSigning(h, currentOrigin(), ^{
            DAppWVJBSignRawTx(h, (NSDictionary *)data, responseCallback);
        }, ^{
            DAppRespond(responseCallback, @{@"error": DAppL(@"用户拒绝了该站点的签名权限"), @"code": @(DAppErrorUserRejected)});
        });
    }];

    [bridge registerHandler:@"signTxGroup" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong UIViewController *h = weakHost;
        if (![data isKindOfClass:[NSDictionary class]]) {
            DAppRespond(responseCallback, @{@"error": @"invalid data", @"code": @(DAppErrorInvalidParams)});
            return;
        }
        DAppAuthorizeSigning(h, currentOrigin(), ^{
            DAppWVJBSignTxGroup(h, (NSDictionary *)data, responseCallback);
        }, ^{
            DAppRespond(responseCallback, @{@"error": DAppL(@"用户拒绝了该站点的签名权限"), @"code": @(DAppErrorUserRejected)});
        });
    }];

    [bridge registerHandler:@"browserOpen" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong UIViewController *h = weakHost;
        NSDictionary *dict = [data isKindOfClass:[NSDictionary class]] ? data : nil;
        NSString *urlStr = dict[@"url"];
        if (urlStr.length == 0) {
            [h showCustomMessage:DAppL(@"发生了错误，请稍后再试") hideAfterDelay:2.f];
            return;
        }
        NSURL *url = [NSURL URLWithString:urlStr];
        // 只允许 http/https；`itms-apps:` / `tel:` / `sms:` 等自定义 scheme 不应由页面静默唤起。
        NSString *scheme = url.scheme.lowercaseString ?: @"";
        if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
            NSLog(@"DApp browserOpen 拒绝非 http(s) scheme: %@", scheme);
            if (responseCallback) { responseCallback(@{@"error": @"unsupported scheme"}); }
            return;
        }
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
        if (responseCallback) {
            responseCallback(nil);
        }
    }];

    [bridge registerHandler:@"getCurrentBTYAddress" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *addr = [GameGoFunction querySelectedBtyAddress];
        responseCallback(addr ?: @"");
    }];

    [bridge registerHandler:@"getAddress" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSDictionary *dict = [data isKindOfClass:[NSDictionary class]] ? data : nil;
        NSString *coinType = dict[@"cointype"];
        NSString *address = @"";
        if ([coinType isEqualToString:@"BTY"]) {
            address = [GameGoFunction querySelectedBtyAddress];
        } else {
            address = [GameGoFunction queryAddressByChain:coinType ?: @""];
        }
        responseCallback(@{@"address": address ?: @""});
    }];

    [bridge registerHandler:@"scanQRCode" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong UIViewController *h = weakHost;
        ScanViewController *vc = [[ScanViewController alloc] init];
        [h.navigationController pushViewController:vc animated:NO];
        vc.scanResult = ^(NSString *address) {
            if ([address containsString:@","]) {
                NSArray *array = [address componentsSeparatedByString:@","];
                if (array.count == 3) {
                    responseCallback(array[2]);
                } else if (array.count == 2) {
                    responseCallback(array[1]);
                } else {
                    responseCallback(address);
                }
            } else {
                responseCallback(address);
            }
        };
    }];
}

@end
