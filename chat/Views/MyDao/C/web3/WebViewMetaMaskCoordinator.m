//
//  WebViewMetaMaskCoordinator.m
//  MetaMask / EIP-1193 注入与 RPC 实现（逻辑与 WebViewController 内联时一致，公开 API 见 .h）。
//

#import "WebViewMetaMaskCoordinator.h"
#import "WebViewController_Private.h"
#import "UIViewController+ShowInfo.h"
#import "Web3ProviderHandler.h"
#import "GameGoFunction.h"
#import "SGNetWork.h"
#import "DappAlertSheetView.h"
#import "ETHInputParser.h"
#import "PWContractRequest.h"
#import "PWDataBaseManager.h"
#import "GoFunction.h"
#import "chat-Swift.h"
#import "Depend.h"
#import <errno.h>

/// 与 `ETHInputParser` 中收录的 DEX「兑换」类方法一致；仅用 `function_selector` 判断，不依赖 `swap_token_in`。
static BOOL TanxinSelectorHexIsDexSwap(NSString *hex8) {
    if (hex8.length == 0) {
        return NO;
    }
    NSString *h = [hex8 lowercaseString];
    static NSSet *swapSelectors;
    static dispatch_once_t onceSwapSel;
    dispatch_once(&onceSwapSel, ^{
        swapSelectors = [NSSet setWithArray:@[
            @"df791e50",
            @"af9b3109", @"38ed1739",
            @"48d27b0e", @"7ff36ab5",
            @"18cbafe5", @"8803dbee", @"b6f9de95"
        ]];
    });
    return [swapSelectors containsObject:h];
}

/// ETH 作为输入的 Router 兑换（msg.value 付主链币）
static BOOL TanxinSelectorHexIsEthInputDexSwap(NSString *hex8) {
    NSString *h = [hex8 lowercaseString];
    return [h isEqualToString:@"7ff36ab5"] || [h isEqualToString:@"48d27b0e"];
}

/// Token 路径类 Router：`to` 为路由合约，不要求钱包已添加 path 上代币（不含 ETH 输入类）
static BOOL TanxinSelectorHexIsRouterTokenSwapNoCoinGate(NSString *hex8) {
    if (hex8.length == 0) {
        return NO;
    }
    NSString *h = [hex8 lowercaseString];
    static NSSet *sel;
    static dispatch_once_t onceTok;
    dispatch_once(&onceTok, ^{
        sel = [NSSet setWithArray:@[
            @"af9b3109", @"38ed1739",
            @"18cbafe5", @"8803dbee", @"b6f9de95"
        ]];
    });
    return [sel containsObject:h];
}

#pragma mark - 静态工具（拼 JS 字面量）

/// 与 WebViewController.m 中逻辑一致，供本类内拼 JS
/// 将字符串序列化为 JSON 字符串字面量（含转义），供拼进 evaluateJavaScript。
static NSString *TanxinJsonStringForJsLiteral(NSString * _Nullable s) {
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

/// 将任意可 JSON 序列化的单值转为 JS 表达式片段（供 `_onResponse` 的 result/error），避免手写引号导致脚本语法错误。
static NSString *TanxinJsonFragmentForJs(id _Nullable value) {
    if (value == nil) {
        return @"null";
    }
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value] options:0 error:&err];
    if (!data || err) {
        NSString *fallback = [NSString stringWithFormat:@"%@", value];
        return TanxinJsonStringForJsLiteral(fallback);
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length >= 2 && [json hasPrefix:@"["] && [json hasSuffix:@"]"]) {
        return [json substringWithRange:NSMakeRange(1, json.length - 2)];
    }
    return @"null";
}



#define L(key) [[LanguageManager shared] localizedStringForKey:key]
#define WEAKSELF __weak typeof(self) weakSelf = self;

/// 私有：在 init 中写入 `host`，对外保持 `readonly`。
NS_ASSUME_NONNULL_BEGIN
@interface WebViewMetaMaskCoordinator ()
@property (nonatomic, weak, readwrite, nullable) WebViewController *host;
@end
NS_ASSUME_NONNULL_END

@implementation WebViewMetaMaskCoordinator

#pragma mark - 初始化

/// 绑定宿主 WebViewController，后续 RPC 均通过 `host` 访问 WebView、链配置与回包。
- (instancetype)initWithHost:(WebViewController * _Nonnull)host {
    self = [super init];
    if (self) {
        _host = host;
    }
    return self;
}

#pragma mark - MetaMask

#pragma mark - 账户、链 ID、通用 RPC

/// eth_requestAccounts 两步投递：先发 accountsChanged/connect，再间隔后再 resolve（Revoke.cash 等需先感知事件）
static const NSTimeInterval kEthRequestAccountsEmitToResolveGap = 0.55;
/// eth_requestAccounts：开始处理前额外等待，便于 DApp 与事件顺序对齐
static const NSTimeInterval kEthRequestAccountsPreflightDelay = 1.0;
/// eth_chainId：回包前等待
static const NSTimeInterval kEthChainIdResponseDelay = 0.5;

/// 协调器支持的十进制链 ID（与 `WebViewController` 探索网一致，不含已下线的 BUB/Tanxin）
static BOOL WebViewMetaMaskSupportedNumericChainId(NSInteger chainId) {
    return chainId == 1 || chainId == 56 || chainId == 2999;
}

/// 将 DApp 传入的 chainId（NSNumber、十进制字符串、0x… hex 含 0xD11）解析为十进制链 ID；无效时返回 NSNotFound
static NSInteger WebViewMetaMaskDecimalChainIdFromParam(id raw, WebViewController *host) {
    if (raw == nil || raw == [NSNull null] || host == nil) {
        return NSNotFound;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)raw integerValue];
    }
    NSString *s = [[NSString stringWithFormat:@"%@", raw] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) {
        return NSNotFound;
    }
    if ([s hasPrefix:@"0x"] || [s hasPrefix:@"0X"]) {
        return [host sixteenToTen:s].integerValue;
    }
    return s.integerValue;
}

/// 生成在页面内设置 `chainId`/`networkVersion` 并 `emit('connect')`、`emit('accountsChanged')` 的立即执行脚本。
- (NSString *)tanxinJsForEmitConnectAndAccountsChanged:(NSArray *)accounts {
    NSString *chainHex = [self.host tenToSixteen:self.host.selectedChainID isUppercase:NO];
    NSString *cidJs = TanxinJsonStringForJsLiteral(chainHex);
    NSString *accsJs = TanxinJsonFragmentForJs(accounts);
    NSString *netVerStr = [NSString stringWithFormat:@"%li", (long)self.host.selectedChainID];
    return [NSString stringWithFormat:
        @"(function(){try{if(!window.ethereum)return;var cid=%@;var nv=%@;"
        "window.ethereum.chainId=cid;window.ethereum.networkVersion=nv;"
        "if(window.ethereum.emit){window.ethereum.emit('connect',{chainId:cid});window.ethereum.emit('accountsChanged',%@);}"
        "}catch(e){console.error('[wallet] emit',e);}})();",
        cidJs, TanxinJsonStringForJsLiteral(netVerStr), accsJs];
}

/// 在串行队列 + 主线程上对 WebView 执行上述 emit JS，完成后调用 completion。
- (void)tanxinEvaluateEmitConnectAndAccountsChanged:(NSArray *)accounts completion:(void (^ _Nullable)(void))completion {
    if (!completion) {
        return;
    }
    NSString *emitJs = [self tanxinJsForEmitConnectAndAccountsChanged:accounts];
    WEAKSELF
    if (!self.host.walletJsResponseSerialQueue) {
        self.host.walletJsResponseSerialQueue = dispatch_queue_create("com.tanxin.wallet.jsresponse", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(self.host.walletJsResponseSerialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.host.webView) {
                completion();
                return;
            }
            [strongSelf.host.webView evaluateJavaScript:emitJs completionHandler:^(id _Nullable res, NSError * _Nullable err) {
                if (err) {
                    NSLog(@"[wallet] emit connect/accountsChanged failed: %@", err);
                }
                completion();
            }];
        });
    });
}

/// 第一步：emit；第二步：间隔 kEthRequestAccountsEmitToResolveGap 后再把 Promise resolve 给 DApp（不再重复 emit）
- (void)deliverEthRequestAccountsTwoStep:(nullable NSString *)requestId accounts:(NSArray *)accounts method:(nullable NSString *)method {
    __weak typeof(self) weakSelf = self;
    [self tanxinEvaluateEmitConnectAndAccountsChanged:accounts completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kEthRequestAccountsEmitToResolveGap * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf.host sendResponseToJS:requestId result:accounts error:nil method:method skipEmitAfterConnect:YES];
        });
    }];
}

/// 按当前选中链从 GameGo / 数据库解析钱包地址，统一为带 `0x` 前缀。
- (nullable NSString *)addressForEthRequestAccounts {
    NSString *addr = [GameGoFunction queryAddressByChain:self.host.selectedChain ];
    if (addr.length > 0) {
        return [addr hasPrefix:@"0x"] ? addr : [@"0x" stringByAppendingString:addr];
    }
    LocalCoin *coin = [[PWDataBaseManager shared] queryCoinBasedOnChain:self.host.selectedChain];
    if (coin && coin.coin_address.length > 0) {
        addr = coin.coin_address;
        return [addr hasPrefix:@"0x"] ? addr : [@"0x" stringByAppendingString:addr];
    }
    NSArray *allCoins = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
    for (LocalCoin *c in allCoins) {
        BOOL match = NO;
        if ([self.host.selectedChain isEqualToString:@"BTY"]) {
            match = [c.coin_type isEqualToString:@"BTY"] && [c.coin_chain isEqualToString:@"ETH"];
        } else if ([self.host.selectedChain isEqualToString:@"ETH"]) {
            match = [c.coin_type isEqualToString:@"ETH"] && [c.coin_chain isEqualToString:@"ETH"];
        } else {
            match = [c.coin_chain isEqualToString:self.host.selectedChain];
        }
        if (match && c.coin_address.length > 0) {
            addr = c.coin_address;
            return [addr hasPrefix:@"0x"] ? addr : [@"0x" stringByAppendingString:addr];
        }
    }
    return nil;
}

/// 当前宿主链非支持的 EIP-155 主链时回 -32603，返回 YES 表示已回错并应停止处理
- (BOOL)tanxinRejectIfUnsupportedSelectedChainWithRequestId:(nullable NSString *)requestId method:(nullable NSString *)method {
    if (WebViewMetaMaskSupportedNumericChainId(self.host.selectedChainID)) {
        return NO;
    }
    NSDictionary *err = @{@"code": @-32603, @"message": @"Unsupported chain: only BNB Smart Chain (0x38) and Ethereum Mainnet(0x1) and BitYuan Mainnet(0xbb7) are supported"};
    void (^send)(void) = ^{
        [self.host sendResponseToJS:requestId result:nil error:err method:method];
    };
    if ([NSThread isMainThread]) {
        send();
    } else {
        dispatch_async(dispatch_get_main_queue(), send);
    }
    return YES;
}

/// 处理 `eth_requestAccounts` / `eth_accounts`：无地址则报错；`eth_requestAccounts` 经预延迟后两步投递，否则直接回包账户数组。
- (void)handleEthRequestAccounts:(nullable NSString *)requestId method:(nullable NSString *)method{
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    NSString *address = [self addressForEthRequestAccounts];
    if (!address || address.length == 0) {
        NSDictionary *err = @{@"code": @-32602, @"message": @"No wallet address for current chain"};
        void (^send)(void) = ^{ [self.host sendResponseToJS:requestId result:nil error:err method:method]; };
        if ([NSThread isMainThread]) {
            send();
        } else {
            dispatch_async(dispatch_get_main_queue(), send);
        }
        return;
    }
    NSArray *accounts = @[address];
    WEAKSELF
    void (^send)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if ([method isEqualToString:@"eth_requestAccounts"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kEthRequestAccountsPreflightDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) s2 = weakSelf;
                if (!s2) {
                    return;
                }
                [s2 deliverEthRequestAccountsTwoStep:requestId accounts:accounts method:method];
            });
        } else {
            [strongSelf.host sendResponseToJS:requestId result:accounts error:nil method:method];
        }
    };
    if ([NSThread isMainThread]) {
        send();
    } else {
        dispatch_async(dispatch_get_main_queue(), send);
    }
}

/// 处理 `eth_chainId`：返回小写十六进制链 ID，短延迟后主线程回包（与 DApp 时序对齐）。
- (void)handleEthChainId:(nullable NSString *)requestId method:(nullable NSString *)method{
    // EIP-1193 / viem 惯例为小写十六进制 chainId（如 0x38），大写易导致与 eth_chainId 比对失败、显示未连接
    NSString *chainIdHex = [self.host tenToSixteen:self.host.selectedChainID isUppercase:NO];
    WEAKSELF
    NSString *rid = requestId ?: @"";
    NSString *m = method ?: @"eth_chainId";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kEthChainIdResponseDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf.host sendResponseToJS:rid result:chainIdHex error:nil method:m];
    });
}

/// 通用 RPC 透传：读链/过滤器/广播已签名交易等（见 WebViewController WebViewMetaMaskGenericRpcMethodSet 与 provider.js）
- (void)handleGenericRpc:(nullable NSString *)requestId method:(nullable NSString *)method params:(nullable NSArray *)params {
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    id rpcParams = (params && params.count > 0) ? params : @[];
    NSDictionary *rpc = @{@"id": @1, @"jsonrpc": @"2.0", @"method": method, @"params": rpcParams};
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:self.host.selectedRpcUlr
                                          apiPath:@""
                                       parameters:rpc
                                         progress:nil
                                          success:^(BOOL isSuccess, id _Nullable responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
        id result = json[@"result"];
        id error = json[@"error"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self.host sendResponseToJS:requestId result:nil error:error method:method];
            } else {
                [self.host sendResponseToJS:requestId result:result error:nil method:method];
            }
        });
    } failure:^(NSString * _Nullable errorMessage) {
        NSDictionary *err = @{@"code": @(-32603), @"message": errorMessage ?: @"RPC request failed"};
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.host sendResponseToJS:requestId result:nil error:err method:method];
        });
    }];
}

/// 处理 `net_version`：返回当前链 ID 的十进制字符串。
- (void)handleNetVersion:(NSString *)requestId method:(NSString *)method{
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    NSString *netVersion = [NSString stringWithFormat:@"%li",self.host.selectedChainID];
    [self.host sendResponseToJS:requestId result:netVersion error:nil method:method];
}

/// 查询当前 `selectedChain` 对应的 `LocalCoin`。
- (nullable LocalCoin *)localCoinForSelectedChain {
    return [[PWDataBaseManager shared] queryCoinBasedOnChain:self.host.selectedChain];
}

/// 处理 `personal_sign`：展示 PersonalSign Sheet，解密助记词后对消息签名并回包（用户取消返回 4001）。
- (void)handlePersonalSign:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method{
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    if (params.count < 2) return;
    
    LocalCoin *coin = [self localCoinForSelectedChain];
    if (!coin) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @-32602, @"message": @"No wallet for current chain"} method:method];
        return;
    }
    self.host.localCoin = coin;
    
    NSString *hexMsg = params[0]; // 待签名的原始十六进制
    NSString *address = params[1]; // 签名地址
    NSString *readableMsg = [self stringFromHexString:hexMsg];
    NSString *messages  = readableMsg;
    NSDictionary *dict = @{@"name":self.host.selectedChainName,
                           @"url":self.host.webUrl,
                           @"icon_url":@"",
                           @"addr":self.host.localCoin.coin_address,
                           @"message":messages};

    
    DappAlertSheetView *sheetView = [[DappAlertSheetView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)
                                                                     withType:DappAlertSheetTypePersonalSign
                                                                     withData:dict
                                                                     withCoin:self.host.localCoin];
    sheetView.dappBlock = ^(NSString * _Nonnull passwdStr,NSString * _Nonnull selectedGas,NSString * _Nonnull selectedGasPrice) {
        if(passwdStr.length == 0){
            [self.host showCustomMessage:L(@"请输入密聊密码") hideAfterDelay:2.f];
            return;
        }else if ([passwdStr isEqualToString:L(@"取消")]){
            // 用户拒绝签名，返回错误给 JS
            NSDictionary *error = @{@"code": @4001, @"message": @"User rejected the request"};
            [self.host sendResponseToJS:requestId result:nil error:error method:method];
            return;
        }else{
            LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
            NSString *remebercode = [GoFunction deckey:wallet.wallet_remembercode password:passwdStr];
            WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2(@"ETH",[self.host remv:remebercode],nil );
            if (hdWallet == nil) {
                [self.host showCustomMessage:L(@"密码错误")  hideAfterDelay:2.f];
                return;
            }
            NSString *prikey = [[hdWallet newKeyPriv:0 error:nil] hexString];
            self.host.priKey = prikey;
            [[MessageSigner shared] signPersonalMessageWithMessage:messages privateKey:self.host.priKey completion:^(NSString * _Nullable result) {
                           NSLog(@"personalsign message %@",result);
                           [self.host.sheetView dismiss];
                           dispatch_async(dispatch_get_main_queue(), ^{
                               [self.host sendResponseToJS:requestId result:result error:nil method:method];
                           });
            }];
        }
    };
    self.host.sheetView = sheetView;
    [self.host.sheetView showWithView:self.host.view];

}

/// 将带 `0x` 前缀的十六进制消息体解码为 UTF-8 可读字符串；无前缀则原样返回。
- (NSString *)stringFromHexString:(NSString *)hexString {
    if (hexString == nil || hexString.length == 0) {
        return @"";
    }
    if (![hexString hasPrefix:@"0x"] && ![hexString hasPrefix:@"0X"]) {
        return hexString;
    }
    NSString *s = [hexString substringFromIndex:2];
    if (s.length == 0) {
        return @"";
    }
    if (s.length % 2 == 1) {
        s = [@"0" stringByAppendingString:s];
    }
    NSMutableString *newString = [[NSMutableString alloc] init];
    NSUInteger i = 0;
    while (i < s.length) {
        NSString *hexChar = [s substringWithRange:NSMakeRange(i, 2)];
        unsigned int value = 0;
        NSScanner *scanner = [NSScanner scannerWithString:hexChar];
        if (![scanner scanHexInt:&value]) {
            break;
        }
        [newString appendFormat:@"%c", (char)(value & 0xFF)];
        i += 2;
    }
    return newString;
}

/// `eth_sendTransaction` 入口：取首参交易对象并弹出支付确认 `showAlert`。
- (void)handleEthSendTransaction:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method{
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    if (params.count == 0) return;
    NSDictionary *txData = params[0];
    [self showAlert:txData requestId:requestId method:method];
   
}

#pragma mark - 交易解析与 tanxin 辅助（链、代币、calldata）

/// ERC-20 `approve(address,uint256)` 的函数选择器
- (BOOL)tanxinIsERC20ApproveCalldata:(NSString *)dataHex {
    if (![dataHex isKindOfClass:[NSString class]] || dataHex.length < 10) {
        return NO;
    }
    NSString *lower = [dataHex lowercaseString];
    if (![lower hasPrefix:@"0x"]) {
        return NO;
    }
    NSString *sel = [lower substringWithRange:NSMakeRange(2, 8)];
    return [sel isEqualToString:@"095ea7b3"];
}

/// 合约地址统一为 `0x` + 40 位小写 hex，便于与 DApp / 数据库比对（大小写、是否带 0x）
- (NSString *)tanxinNormalizedHexAddress:(nullable id)addrOrNil {
    if (addrOrNil == nil || addrOrNil == [NSNull null]) {
        return @"";
    }
    NSString *addr = [addrOrNil isKindOfClass:[NSString class]] ? (NSString *)addrOrNil : [NSString stringWithFormat:@"%@", addrOrNil];
    NSString *s = [[addr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (s.length == 0 || [s isEqualToString:@"(null)"]) {
        return @"";
    }
    if (![s hasPrefix:@"0x"]) {
        if (s.length == 40) {
            s = [@"0x" stringByAppendingString:s];
        }
    }
    return s;
}

/// 将最小单位（wei）的十进制整数字符串除以 10^18，格式化为可读数量；避免 `double` 大整数精度丢失。
- (NSString *)tanxinHumanReadableAmountFromWeiDecimalString:(nullable NSString *)weiDecimalString maximumFractionDigits:(NSUInteger)maxFrac {
    if (weiDecimalString == nil || weiDecimalString.length == 0) {
        return @"0";
    }
    NSString *trimmed = [weiDecimalString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return @"0";
    }
    NSDecimalNumber *wei = [NSDecimalNumber decimalNumberWithString:trimmed];
    if ([wei isEqualToNumber:[NSDecimalNumber notANumber]]) {
        return weiDecimalString;
    }
    static NSDecimalNumber *weiPerEther;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        weiPerEther = [NSDecimalNumber decimalNumberWithString:@"1000000000000000000"];
    });
    NSDecimalNumber *human = [wei decimalNumberByDividingBy:weiPerEther];
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    fmt.numberStyle = NSNumberFormatterDecimalStyle;
    fmt.maximumFractionDigits = maxFrac;
    fmt.minimumFractionDigits = 0;
    fmt.usesGroupingSeparator = YES;
    NSString *out = [fmt stringFromNumber:human];
    return out.length > 0 ? out : human.stringValue;
}

/// 交易 `obj` 带 `chainId` 时解析为十进制链 ID（EIP-155，可为 `0x` 十六进制或十进制字符串）；否则为 `self.host.selectedChainID`
- (NSInteger)tanxinResolvedChainNumericIdFromTxObj:(NSDictionary *)obj {
    id raw = obj[@"chainId"];
    if (raw == nil || raw == [NSNull null]) {
        return self.host.selectedChainID;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)raw integerValue];
    }
    NSString *s = [[NSString stringWithFormat:@"%@", raw] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) {
        return self.host.selectedChainID;
    }
    if ([s hasPrefix:@"0x"] || [s hasPrefix:@"0X"]) {
        return [self.host sixteenToTen:s].integerValue;
    }
    return s.integerValue;
}

/// 与钱包 `LocalCoin.coin_chain` 一致的主链键：`obj.chainId` 有值时映射常用 EIP-155 ID，否则回退 `selectedChain`
- (NSString *)tanxinResolvedCoinChainKeyFromTxObj:(NSDictionary *)obj {
    id raw = obj[@"chainId"];
    if (raw == nil || raw == [NSNull null]) {
        return self.host.selectedChain;
    }
    NSInteger n = [self tanxinResolvedChainNumericIdFromTxObj:obj];
    switch (n) {
        case 56:
            return @"BNB";
        case 2999:
            return @"BTY";
        case 1:
            return @"ETH";
        default:
            return self.host.selectedChain;
    }
}

/// 弹窗/ sheet 展示用主链名称；未知链回退当前选中链名
- (NSString *)tanxinResolvedChainDisplayNameFromTxObj:(NSDictionary *)obj {
    id raw = obj[@"chainId"];
    if (raw == nil || raw == [NSNull null]) {
        return self.host.selectedChainName.length > 0 ? self.host.selectedChainName : (self.host.selectedChain ?: @"");
    }
    NSInteger n = [self tanxinResolvedChainNumericIdFromTxObj:obj];
    switch (n) {
        case 56:
            return @"BNB Smart Chain";
        case 1:
            return @"Ethereum Mainnet";
        case 2999:
            return @"BitYuan Mainnet";
        default:
            return self.host.selectedChainName.length > 0 ? self.host.selectedChainName : (self.host.selectedChain ?: @"");
    }
}

/// 在已添加币种中按「代币合约地址」查找 LocalCoin。仅 `coin_type_nft == 10` 时 `coin_pubkey` 才是合约地址（普通币存的是公钥，不能与 `to` 比较）
- (nullable LocalCoin *)tanxinLocalCoinForContractAddress:(NSString *)contractAddr inCoins:(NSArray *)coinArray coinChain:(NSString *)coinChain {
    NSString *target = [self tanxinNormalizedHexAddress:contractAddr];
    if (target.length != 42) {
        return nil;
    }
//    NSString *chainKey = coinChain.length > 0 ? coinChain : self.host.selectedChain;
    for (LocalCoin *coin in coinArray) {
        if (coin.coin_type_nft != 10) {
            continue;
        }
//        BOOL chainOk = YES;
//        if (chainKey.length > 0 && coin.coin_chain.length > 0) {
//            /// BitYuan EVM 侧钱包内 `coin_chain` 为 ETH，与 `selectedChain` BTY 对应
//            if ([chainKey isEqualToString:@"BTY"]) {
//                chainOk = [coin.coin_chain isEqualToString:@"ETH"] || [coin.coin_chain isEqualToString:chainKey];
//            } else {
//                chainOk = [coin.coin_chain isEqualToString:chainKey];
//            }
//        }
//        if (!chainOk) {
//            continue;
//        }
        NSString *pub = [self tanxinNormalizedHexAddress:coin.coin_pubkey];
        if (pub.length == 42 && [pub isEqualToString:target]) {
            return coin;
        }
    }
    return nil;
}

/// 钱包未添加该合约代币时提示去添加；确定复制合约地址，取消仅关闭。展示前即向 H5 回错误，结束 loading（`useExecuteCallback` 为 YES 时走 `executeCallback`）
- (void)tanxinPresentMissingContractTokenAlertWithContractAddress:(NSString *)contractAddress
                                                 chainDisplayName:(NSString *)chainDisplayName
                                                        requestId:(nullable NSString *)requestId
                                                           method:(nullable NSString *)method
                                                       callbackId:(NSInteger)callbackId
                                               useExecuteCallback:(BOOL)useExecuteCallback {
    NSString *shortErrMsg = L(@"钱包暂未支持该合约币");
    NSDictionary *jsErr = @{@"code": @-32602, @"message": shortErrMsg};
    if (useExecuteCallback) {
        NSError *je = nil;
        NSData *errJsonData = [NSJSONSerialization dataWithJSONObject:jsErr options:0 error:&je];
        if (errJsonData.length > 0) {
            NSString *errJson = [[NSString alloc] initWithData:errJsonData encoding:NSUTF8StringEncoding];
            NSString *js = [NSString stringWithFormat:@"setTimeout(function(){try{executeCallback(%li,%@,null)}catch(e){console.error(e)}},0);", (long)callbackId, errJson];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.host.webView evaluateJavaScript:js completionHandler:nil];
            });
        }
    } else if (requestId.length > 0) {
        [self.host sendResponseToJS:requestId result:nil error:jsErr method:method ?: @"eth_sendTransaction"];
    }

    NSString *chainLine = chainDisplayName.length > 0 ? chainDisplayName : @"";
    NSString *msg = [NSString stringWithFormat:L(@"请先添加该合约代币后再发起交易。\n\n合约地址：%@\n主链：%@"), contractAddress, chainLine];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"提示") message:msg preferredStyle:UIAlertControllerStyleAlert];
    WEAKSELF
    [alert addAction:[UIAlertAction actionWithTitle:L(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [[UIPasteboard generalPasteboard] setString:contractAddress];
        [strongSelf.host showCustomMessage:L(@"合约地址复制成功") hideAfterDelay:2.0];
    }]];
    [self.host presentViewController:alert animated:YES completion:nil];
}

/// 用于匹配钱包内代币、弹窗「代币合约」：`swap` 时优先 `swap_token_in`；直接调 ERC20 为交易 `to`。
/// DEX Router 的 `eth_sendTransaction.to` 是路由合约，绝不能当作 ERC20 合约去库表匹配（7ff36ab5、af9b3109 等）。
- (NSString *)tanxinTokenContractAddressForDisplayAndCoinMatch:(NSDictionary *)obj parsed:(NSDictionary *)dataDict {
    id st = dataDict[@"swap_token_in"];
    if (st != nil && st != [NSNull null]) {
        NSString *s = [st isKindOfClass:[NSString class]] ? (NSString *)st : [NSString stringWithFormat:@"%@", st];
        if (s.length > 0) {
            return s;
        }
    }
    NSString *sel = [[NSString stringWithFormat:@"%@", dataDict[@"function_selector"] ?: @""] lowercaseString];
    static NSSet *kSelectorsTxToIsRouter;
    static dispatch_once_t onceRouterSel;
    dispatch_once(&onceRouterSel, ^{
        kSelectorsTxToIsRouter = [NSSet setWithArray:@[
            @"7ff36ab5", @"48d27b0e",
            @"af9b3109", @"38ed1739",
            @"18cbafe5", @"8803dbee", @"b6f9de95"
        ]];
    });
    if (sel.length > 0 && [kSelectorsTxToIsRouter containsObject:sel]) {
        return @"";
    }
    id toVal = obj[@"to"];
    return [toVal isKindOfClass:[NSString class]] ? (NSString *)toVal : (toVal != nil && toVal != [NSNull null] ? [NSString stringWithFormat:@"%@", toVal] : @"");
}

/// 交易 `to`（DApp 传入）：swap 时为目标 Router/聚合器，与 calldata 内 token 地址无关
- (NSString *)tanxinTxToAddressString:(NSDictionary *)obj {
    id toVal = obj[@"to"];
    if (toVal == nil || toVal == [NSNull null]) {
        return @"";
    }
    return [toVal isKindOfClass:[NSString class]] ? (NSString *)toVal : [NSString stringWithFormat:@"%@", toVal];
}

/// 写入 extend.data 前校验：非空返回原串，否则 nil（空则不传 data）
- (nullable NSString *)tanxinNonEmptyDataHexForExtend:(nullable id)dataRaw {
    if (dataRaw == nil || dataRaw == [NSNull null]) {
        return nil;
    }
    NSString *s = [dataRaw isKindOfClass:[NSString class]] ? (NSString *)dataRaw : [NSString stringWithFormat:@"%@", dataRaw];
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return s.length > 0 ? s : nil;
}

/// 将十六进制 calldata（可带 `0x`）转为 JSON 数组 `[0,1,...]`，供 `input` 字段使用
- (NSArray<NSNumber *> *)tanxinJsonByteArrayFromHexDataString:(NSString *)hexString {
    if (hexString == nil || hexString.length == 0) {
        return @[];
    }
    NSData *data = WalletapiHexTobyte(hexString);
    if (data.length == 0) {
        NSString *s = [[hexString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        if ([s hasPrefix:@"0x"]) {
            s = [s substringFromIndex:2];
        }
        if (s.length == 0 || (s.length % 2) != 0) {
            return @[];
        }
        NSMutableData *md = [NSMutableData dataWithLength:s.length / 2];
        unsigned char *p = md.mutableBytes;
        for (NSUInteger i = 0; i < s.length; i += 2) {
            unsigned int v = 0;
            if (![[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&v]) {
                return @[];
            }
            p[i / 2] = (unsigned char)(v & 0xff);
        }
        data = md;
    }
    const unsigned char *bytes = data.bytes;
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:data.length];
    for (NSUInteger i = 0; i < data.length; i++) {
        [arr addObject:@(bytes[i])];
    }
    return arr;
}

/// `Wallet.CreateRawTransaction` 返回 JSON 中 `result` 转签名用字符串；swap / approve 时用本地 calldata 转字节数组覆盖 `input`
- (nullable NSString *)tanxinCreateRawResultJsonStringForSignFromParsedResponse:(NSDictionary *)resultJsonData
                                                           extendDataHex:(NSString *)extendDataHex
                                                      shouldPatchInput:(BOOL)shouldPatchInput {
    id res = resultJsonData[@"result"];
    if (res == nil || res == [NSNull null]) {
        return nil;
    }
    BOOL patch = shouldPatchInput && extendDataHex.length > 0;
    NSArray<NSNumber *> *inputBytes = patch ? [self tanxinJsonByteArrayFromHexDataString:extendDataHex] : nil;
    if (patch && inputBytes.count == 0) {
        patch = NO;
    }
    if ([res isKindOfClass:[NSDictionary class]]) {
        NSDictionary *txDict = res;
        if (patch) {
            NSMutableDictionary *m = [txDict mutableCopy];
            m[@"input"] = inputBytes;
            txDict = m;
        }
        NSData *out = [NSJSONSerialization dataWithJSONObject:txDict options:NSJSONWritingPrettyPrinted error:nil];
        return out ? [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding] : nil;
    }
    if ([res isKindOfClass:[NSData class]]) {
        NSData *resData = (NSData *)res;
        if (!patch) {
            return [[NSString alloc] initWithData:resData encoding:NSUTF8StringEncoding];
        }
        NSError *err = nil;
        id inner = [NSJSONSerialization JSONObjectWithData:resData options:NSJSONReadingAllowFragments error:&err];
        if (![inner isKindOfClass:[NSDictionary class]]) {
            return [[NSString alloc] initWithData:resData encoding:NSUTF8StringEncoding];
        }
        NSMutableDictionary *m = [inner mutableCopy];
        m[@"input"] = inputBytes;
        NSData *out = [NSJSONSerialization dataWithJSONObject:m options:NSJSONWritingPrettyPrinted error:nil];
        return out ? [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding] : nil;
    }
    return nil;
}

/// 从 ETHInputParser 结果取 calldata 内对方地址与数量；代币合约：swap 见 `swap_token_in`，普通 ERC20 见交易 `to`（见 parse 的 `note`）
- (NSDictionary *)tanxinErc20PeerAndAmountFromParseResult:(NSDictionary *)dataDict {
    if (dataDict[@"error"]) {
        return @{@"peer": @"", @"amount": @0, @"from_in_call": @""};
    }
    id fnName = dataDict[@"function_name"];
    if ([fnName isKindOfClass:[NSString class]] && [fnName isEqualToString:@"withdraw(uint256)"] && dataDict[@"amount"] != nil) {
        return @{@"peer": @"", @"amount": dataDict[@"amount"] ?: @0, @"from_in_call": @""};
    }
    if (dataDict[@"spender"]) {
        return @{@"peer": dataDict[@"spender"] ?: @"", @"amount": dataDict[@"allowance"] ?: @0, @"from_in_call": @""};
    }
    if (dataDict[@"recipient"]) {
        return @{@"peer": dataDict[@"recipient"] ?: @"", @"amount": dataDict[@"amount"] ?: @0, @"from_in_call": @""};
    }
    if (dataDict[@"swap_token_in"]) {
        /// `peer` 为 calldata 内 swap_token_out（展示辅助）；swap 时 `CreateRawTransaction.to` 用 `obj[@"to"]`，`token_addr` 传空
        return @{@"peer": dataDict[@"swap_token_out"] ?: @"", @"amount": dataDict[@"amount"] ?: @0, @"from_in_call": dataDict[@"swap_token_in"] ?: @""};
    }
    if (dataDict[@"to_address"]) {
        return @{@"peer": dataDict[@"to_address"] ?: @"", @"amount": dataDict[@"amount"] ?: @0, @"from_in_call": dataDict[@"from_address"] ?: @""};
    }
    NSArray *dataArr = dataDict[@"parameters"];
    if (![dataArr isKindOfClass:[NSArray class]]) {
        return @{@"peer": @"", @"amount": @0, @"from_in_call": @""};
    }
    NSString *peer = @"";
    id amt = nil;
    for (NSDictionary *dtci in dataArr) {
        if (![dtci isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *type = [dtci objectForKey:@"type"];
        if ([type isEqualToString:@"address"]) {
            peer = [NSString stringWithFormat:@"%@", [dtci objectForKey:@"value"] ?: @""];
        } else if ([type isEqualToString:@"uint256"]) {
            amt = [dtci objectForKey:@"value"];
        }
    }
    return @{@"peer": peer, @"amount": amt ?: @0, @"from_in_call": @""};
}

/// 签名用 gasPrice（wei 十进制字符串）：优先用户在弹窗选的 Gwei；否则 DApp 的 gasPrice；EIP-1559 时用 maxFeePerGas；最后 eth_gasPrice
- (NSString *)tanxinWeiStringGasPriceForSignTx:(NSDictionary *)obj selectedSheetGasPrice:(nullable NSString *)selectedGasPrice {
    if (selectedGasPrice != nil && selectedGasPrice.length > 0 && selectedGasPrice.doubleValue > 0) {
        double wei = selectedGasPrice.doubleValue * 1000000000.0;
        return [NSString stringWithFormat:@"%.0f", wei];
    }
    id gp = obj[@"gasPrice"];
    if (gp != nil && gp != [NSNull null]) {
        NSString *s = [gp isKindOfClass:[NSString class]] ? (NSString *)gp : [NSString stringWithFormat:@"%@", gp];
        if (s.length > 0 && ![s isEqualToString:@"(null)"]) {
            return [self.host sixteenToTen:s];
        }
    }
    id mf = obj[@"maxFeePerGas"];
    if (mf != nil && mf != [NSNull null]) {
        NSString *s = [mf isKindOfClass:[NSString class]] ? (NSString *)mf : [NSString stringWithFormat:@"%@", mf];
        if (s.length > 0 && ![s isEqualToString:@"(null)"]) {
            return [self.host sixteenToTen:s];
        }
    }
    return self.host.gasPrice.length > 0 ? self.host.gasPrice : @"0";
}

/// 签名用 nonce：DApp 若在 `eth_sendTransaction` 参数里带了 `nonce`（与 EIP-1193 一致），优先采用；否则用 `eth_getTransactionCount` 拉取的缓存。
- (NSInteger)tanxinResolvedNonceForSigningTransaction:(NSDictionary *)obj {
    id raw = obj[@"nonce"];
    if (raw == nil || raw == [NSNull null]) {
        return self.host.nonce.integerValue;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        long long v = [(NSNumber *)raw longLongValue];
        if (v >= 0) {
            return (NSInteger)v;
        }
        return self.host.nonce.integerValue;
    }
    if ([raw isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length == 0 || [s isEqualToString:@"(null)"]) {
            return self.host.nonce.integerValue;
        }
        NSString *dec = [self.host sixteenToTen:s];
        if (dec.length == 0) {
            return self.host.nonce.integerValue;
        }
        errno = 0;
        long long v = strtoll([dec UTF8String], NULL, 10);
        if (errno != 0 || v < 0) {
            return self.host.nonce.integerValue;
        }
        return (NSInteger)v;
    }
    return self.host.nonce.integerValue;
}

/// 对任意带 `data` 的交易走本地构造 + Walletapi 签名 + eth_sendRawTransaction（用于 approve 等，不能走 CreateRawTransaction 转账接口）
- (void)tanxinSignAndBroadcastRawEthTransactionWithPrikey:(NSString *)prikey
                                                        obj:(NSDictionary *)obj
                                                selectedGas:(nullable NSString *)selectedGas
                                           selectedGasPrice:(nullable NSString *)selectedGasPrice
                                     enforceApproveMinGas:(BOOL)enforceApproveMinGas
                                                 completion:(void (^ _Nullable)(NSString * _Nullable txHash, NSDictionary * _Nullable rpcJsError, NSString * _Nullable signFailToast))completion {
    NSString *from = obj[@"from"];
    NSString *to = obj[@"to"];
    NSString *data = obj[@"data"];
    NSString *value = [self.host sixteenToTen:obj[@"value"]];
    NSString *gas = (selectedGas == nil || selectedGas.integerValue == 0) ? [self.host sixteenToTen:obj[@"gas"]] : selectedGas;
    if (gas.integerValue == 0) {
        NSString *gl = [self.host sixteenToTen:obj[@"gasLimit"]];
        if (gl.integerValue > 0) {
            gas = gl;
        }
    }
    if (enforceApproveMinGas && gas.integerValue < 46000) {
        gas = @"60000";
    }
    NSString *gasPriceWeiStr = [self tanxinWeiStringGasPriceForSignTx:obj selectedSheetGasPrice:selectedGasPrice];
    NSString *inputData64 = @"";
    if (data != nil && data.length > 0) {
        NSString *inputData = [data stringByReplacingOccurrencesOfString:@"0x" withString:@""];
        inputData64 = [self.host base64Encoding:inputData];
    }
    NSDictionary *resultJson = @{@"from": from,
                                   @"gas": @(gas.integerValue),
                                   @"gasPrice": [NSDecimalNumber decimalNumberWithString:gasPriceWeiStr],
                                   @"input": inputData64,
                                   @"nonce": @([self tanxinResolvedNonceForSigningTransaction:obj]),
                                   @"to": to,
                                   @"value": [NSDecimalNumber decimalNumberWithString:value]};
    NSData *resultJsonData = [NSJSONSerialization dataWithJSONObject:resultJson options:NSJSONWritingFragmentsAllowed error:nil];
    NSString *resultJsonStr = [[NSString alloc] initWithData:resultJsonData encoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *txData = WalletapiStringTobyte(resultJsonStr, &error);
    WalletapiSignData *signData = [[WalletapiSignData alloc] init];
    if ([self.host.selectedChain isEqualToString:@"BTY"]) {
        signData.cointype = @"BTYETH";
    } else {
        signData.cointype = self.host.selectedChain;
    }
    /// EIP-155：必须带当前链 chainId，否则签名 v 错误、主网/侧链会拒收
    if (self.host.selectedChainID > 0) {
        signData.chainID = (int32_t)self.host.selectedChainID;
    }
    signData.data = txData;
    signData.privKey = prikey;
    signData.addressID = 2;
    NSString *signTx = WalletapiSignRawTransaction(signData, &error);
    if (error || signTx.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, nil, L(@"操作失败，请稍后再试"));
            });
        }
        return;
    }
    [self.host.sheetView dismiss];
    NSDictionary *params = @{@"id": @1,
                             @"jsonrpc": @"2.0",
                             @"method": @"eth_sendRawTransaction",
                             @"params": @[signTx]};
    [self.host showProgressMessage:@"" hideAfterDelay:2.f];
    WEAKSELF
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:self.host.selectedRpcUlr
                                          apiPath:@""
                                       parameters:params
                                         progress:nil
                                          success:^(BOOL isSuccess, id _Nullable responseObject) {
        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"eth_sendRawTransaction response is %@", jsonData);
        NSString *result = jsonData[@"result"];
        if (result == nil || result.length == 0) {
            NSDictionary *dict = jsonData[@"error"];
            NSString *message = dict[@"message"];
            NSString *toast = (message == nil || message.length == 0) ? L(@"操作失败，请稍后再试") : message;
            NSDictionary *jsErr = @{@"code": @-32010, @"message": @"response error"};
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, jsErr, toast);
                }
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(result, nil, nil);
            }
        });
    } failure:^(NSString *_Nullable errorMessage) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil, nil, errorMessage ?: L(@"网络错误"));
            }
        });
        (void)strongSelf;
    }];
}

#pragma mark - 支付确认 Sheet 与链上广播

/// 解析 calldata/原生转账，组装 `DappAlertSheetView`；用户确认后解密私钥并调用 `metaMaskEthSendTransaction`。
- (void)showAlert:(NSDictionary *)obj requestId:(nullable NSString *)requestId method:(nullable NSString *)method
{
    [self.host.view endEditing:YES];
    NSDictionary *dict = [[NSDictionary alloc] init];
    if (obj[@"data"] != nil) { // bnb以及其他币的处理
        NSDictionary *dataDict = [ETHInputParser parseInputData:obj[@"data"]];
        NSLog(@"data str %@",dataDict);
        NSString *fn = dataDict[@"function_name"];
        if ([fn containsString:@"unknow"]) {
            [self.host showCustomMessage:L(@"暂不支持") hideAfterDelay:2.f];
            return;
        }
        if([fn isEqualToString:@"deposit()"]){
            // deposit() 是 WETH 等合约的存款方法，将 ETH 转为 WToken
            NSString *from = obj[@"from"];
            NSString *to = obj[@"to"];
            NSString *value = [self.host sixteenToTen:obj[@"value"]]; // 需要把16进制转为10进制
            // deposit 是合约调用，需要更多 gas（原21000不够）
            NSString *gas = @"60000";
            double realGas = (gas.doubleValue * self.host.gasPrice.doubleValue) / 1000000000000000000.0;

            NSArray *paramArray = @[@{@"name":L(@"支付信息"),
                                      @"info":L(@"充值")},
                                    @{@"name":L(@"合约地址"),
                                      @"info":to},
                                    @{@"name":L(@"付款地址"),
                                      @"info":from},
                                    @{@"name":L(@"矿工费"),
                                      @"info":@(realGas)}];

            dict = @{@"name":[self tanxinResolvedChainDisplayNameFromTxObj:obj],
                     @"url":self.host.webUrl,
                     @"icon_url":@"",
                     @"paramArray":paramArray,
                     @"value":value,
                     @"gas":gas,
                     @"gasPrice":self.host.gasPrice};

            NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
            NSString *txChainPlain = [self tanxinResolvedCoinChainKeyFromTxObj:obj];
            for (LocalCoin *coin in coinArray) {

                if ([txChainPlain isEqualToString:@"BTY"]) {
                    if ([coin.coin_type isEqualToString:@"BTY"] && [coin.coin_chain isEqualToString:@"ETH"]) {
                        self.host.localCoin = coin;
                        break;
                    }
                }
                else{
                    if ([coin.coin_type isEqualToString:txChainPlain]&& [coin.coin_chain isEqualToString:txChainPlain]) {
                        self.host.localCoin = coin;
                        break;
                    }
                }
            }
        }else{
            BOOL isApprove = [fn isEqualToString:@"approve(address,uint256)"] || [self tanxinIsERC20ApproveCalldata:obj[@"data"]];
            NSString *selectorHex = dataDict[@"function_selector"] ?: @"";
            BOOL isSwap = TanxinSelectorHexIsDexSwap(selectorHex);
            BOOL isWithdraw = [fn isEqualToString:@"withdraw(uint256)"];
            BOOL isETHSwap = TanxinSelectorHexIsEthInputDexSwap(selectorHex);
            BOOL isRouterTokenSwapNoCoinGate = TanxinSelectorHexIsRouterTokenSwapNoCoinGate(selectorHex);
            NSDictionary *peerAmt = [self tanxinErc20PeerAndAmountFromParseResult:dataDict];
            /// `approve` / `withdraw`：`to` 为合约地址（交易字段）；普通 ERC20 转账时为收款地址（calldata）
            NSString *toAddr = (isSwap || isApprove || isWithdraw) ? [self tanxinTxToAddressString:obj] : (peerAmt[@"peer"] ?: @"");
            NSString *swapTokenOut = @"";
            NSString *swapTokenIn = @"";
            if (isSwap) {
                id so = dataDict[@"swap_token_out"];
                id si = dataDict[@"swap_token_in"];
                swapTokenOut = (so != nil && so != [NSNull null]) ? ([so isKindOfClass:[NSString class]] ? (NSString *)so : [NSString stringWithFormat:@"%@", so]) : @"";
                swapTokenIn = (si != nil && si != [NSNull null]) ? ([si isKindOfClass:[NSString class]] ? (NSString *)si : [NSString stringWithFormat:@"%@", si]) : @"";
            }
            id amountObj = peerAmt[@"amount"];
            NSString *amount = amountObj ? [NSString stringWithFormat:@"%@", amountObj] : @"";
            NSString *fromInCall = peerAmt[@"from_in_call"] ?: @"";
            NSString *from = obj[@"from"];
            // ETH swap：value 为 msg.value；Token swap：value 为 calldata 解析数量。
            // ERC20 transfer(a9059cbb) / transferFrom：代币数量仅在 data 中，msg.value 多为 0，须用解析的 amount。
            // 其余合约调用（含 approve）：Sheet 上大额度在 paramArray，value 仍用 msg.value。
            NSString *value;
            if (isETHSwap) {
                value = [self.host sixteenToTen:obj[@"value"]];
            } else if (isSwap) {
                value = amount;
            } else if ([fn isEqualToString:@"transfer(address,uint256)"] || [fn isEqualToString:@"transferFrom(address,address,uint256)"] || isWithdraw) {
                value = amount.length > 0 ? amount : @"0";
            } else {
                value = [self.host sixteenToTen:obj[@"value"]];
            }
            NSString *conAddr = [self tanxinTokenContractAddressForDisplayAndCoinMatch:obj parsed:dataDict];
            NSString *txChain = [self tanxinResolvedCoinChainKeyFromTxObj:obj];
            NSString *gasStr = @"21000";
            double realGas;
            NSArray *paramArray;
            if (isApprove) {
                gasStr = @"60000";
                realGas = (60000.0 * self.host.gasPrice.doubleValue) / 10000000000000000.0;
                if ([txChain isEqualToString:@"BNB"]) {
                    realGas = realGas > 0.001 ? 0.00 : realGas;
                }
                NSString *allowanceDisplay = amount.length > 0 ? amount : @"";
                paramArray = @[@{@"name":L(@"支付信息"),
                                  @"info":L(@"代币授权")},
                                @{@"name":L(@"代币合约"),
                                  @"info":conAddr ?: @""},
                                @{@"name":L(@"授权给"),
                                  @"info":toAddr},
                                @{@"name":L(@"授权额度"),
                                  @"info":allowanceDisplay},
                                @{@"name":L(@"付款地址"),
                                  @"info":from},
                                @{@"name":L(@"矿工费"),
                                  @"info":@(realGas)}];
            } else {
                realGas = (21000.0 * self.host.gasPrice.doubleValue) / 10000000000000000.0;
                if ([txChain isEqualToString:@"BNB"]) {
                    realGas = realGas > 0.001 ? 0.00 : realGas;
                }
                if (isSwap) {
                    // swap 交易使用更高的 gas limit
                    gasStr = @"200000";
                    realGas = (200000.0 * self.host.gasPrice.doubleValue) / 10000000000000000.0;
                    if ([txChain isEqualToString:@"BNB"]) {
                        realGas = realGas > 0.001 ? 0.00 : realGas;
                    }
                    // 构建 swap 显示信息
                    NSMutableArray *mutableParamArray = [NSMutableArray arrayWithArray:@[
                        @{@"name":L(@"支付信息"), @"info":L(@"兑换")},
                        @{@"name":L(@"调用合约"), @"info":toAddr},
                        @{@"name":L(@"付款地址"), @"info":from},
                        @{@"name":L(@"矿工费"), @"info":@(realGas)}
                    ]];
                    // ETH swap: 显示当前主链币 -> Token
                    if (isETHSwap) {
                        [mutableParamArray insertObject:@{@"name":L(@"兑入代币"), @"info":swapTokenOut} atIndex:2];
                        [mutableParamArray insertObject:@{@"name":L(@"支付币种"), @"info":txChain} atIndex:2];
                    } else {
                        // Token swap: 显示 TokenIn -> TokenOut
                        [mutableParamArray insertObject:@{@"name":L(@"兑出代币"), @"info":swapTokenOut} atIndex:2];
                        [mutableParamArray insertObject:@{@"name":L(@"兑入代币"), @"info":swapTokenIn} atIndex:2];
                    }
                    paramArray = [mutableParamArray copy];
                } else if (isWithdraw) {
                    gasStr = @"100000";
                    realGas = (100000.0 * self.host.gasPrice.doubleValue) / 10000000000000000.0;
                    if ([txChain isEqualToString:@"BNB"]) {
                        realGas = realGas > 0.001 ? 0.00 : realGas;
                    }
                    NSString *withdrawDisplay = [self tanxinHumanReadableAmountFromWeiDecimalString:(amount.length > 0 ? amount : @"0") maximumFractionDigits:18];
                    paramArray = @[@{@"name":L(@"支付信息"),
                                      @"info":L(@"提现")},
                                    @{@"name":L(@"合约地址"),
                                      @"info":toAddr},
                                    @{@"name":L(@"转账金额"),
                                      @"info":withdrawDisplay},
                                    @{@"name":L(@"付款地址"),
                                      @"info":from},
                                    @{@"name":L(@"矿工费"),
                                      @"info":@(realGas)}];
                } else if (fromInCall.length > 0) {
                    paramArray = @[@{@"name":L(@"支付信息"),
                                      @"info":L(@"转账")},
                                    @{@"name":L(@"收款地址"),
                                      @"info":toAddr},
                                    @{@"name":L(@"转出地址"),
                                      @"info":fromInCall},
                                    @{@"name":L(@"付款地址"),
                                      @"info":from},
                                    @{@"name":L(@"矿工费"),
                                      @"info":@(realGas)}];
                } else {
                    paramArray = @[@{@"name":L(@"支付信息"),
                                      @"info":L(@"转账")},
                                    @{@"name":L(@"收款地址"),
                                      @"info":toAddr},
                                    @{@"name":L(@"付款地址"),
                                      @"info":from},
                                    @{@"name":L(@"矿工费"),
                                      @"info":@(realGas)}];
                }
            }
            dict = @{@"name":[self tanxinResolvedChainDisplayNameFromTxObj:obj],
                     @"url":self.host.webUrl,
                     @"icon_url":@"",
                     @"paramArray":paramArray,
                     @"value":value,
                     @"gas":gasStr,
                     @"gasPrice":self.host.gasPrice};
            
            NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
            if (isETHSwap || isRouterTokenSwapNoCoinGate) {
                /// Router swap：`to` 为路由合约；ETH 类 path 首项常为 WETH，Token-Token 类不应按 Router 或 path 强绑「已添加合约币」
                self.host.localCoin = nil;
                for (LocalCoin *coin in coinArray) {
                    if ([txChain isEqualToString:@"BTY"]) {
                        if ([coin.coin_type isEqualToString:@"BTY"] && [coin.coin_chain isEqualToString:@"ETH"]) {
                            self.host.localCoin = coin;
                            break;
                        }
                    } else {
                        if ([coin.coin_type isEqualToString:txChain] && [coin.coin_chain isEqualToString:txChain]) {
                            self.host.localCoin = coin;
                            break;
                        }
                    }
                }
            } else {
                self.host.localCoin = [self tanxinLocalCoinForContractAddress:conAddr inCoins:coinArray coinChain:txChain];
                NSString *normContract = [self tanxinNormalizedHexAddress:conAddr];
                if (!self.host.localCoin && normContract.length == 42) {
                    NSString *chainLine = [self tanxinResolvedChainDisplayNameFromTxObj:obj];
                    [self tanxinPresentMissingContractTokenAlertWithContractAddress:normContract
                                                                   chainDisplayName:chainLine
                                                                          requestId:requestId
                                                                             method:method
                                                                         callbackId:0
                                                                 useExecuteCallback:NO];
                    return;
                }
            }
        }
    }else{
        // BTY ETH
        NSString *from = obj[@"from"];
        NSString *to = obj[@"to"];
        NSString *value = [self.host sixteenToTen:obj[@"value"]]; // 需要把16进制转为10进制
        NSString *gas = @"21000"; // 需要把16进制转为10进制
        double realGas = (gas.doubleValue * self.host.gasPrice.doubleValue) / 1000000000000000000.0;
        
        NSArray *paramArray = @[@{@"name":L(@"支付信息"),
                                  @"info":L(@"转账")},
                                @{@"name":L(@"收款地址"),
                                  @"info":to},
                                @{@"name":L(@"付款地址"),
                                  @"info":from},
                                @{@"name":L(@"矿工费"),
                                  @"info":@(realGas)}];
        
       
        dict = @{@"name":[self tanxinResolvedChainDisplayNameFromTxObj:obj],
                 @"url":self.host.webUrl,
                 @"icon_url":@"",
                 @"paramArray":paramArray,
                 @"value":value,
                 @"gas":gas,
                 @"gasPrice":self.host.gasPrice};
        
        NSArray *coinArray = [[PWDataBaseManager shared] queryCoinArrayBasedOnSelectedWalletID];
        NSString *txChainPlain = [self tanxinResolvedCoinChainKeyFromTxObj:obj];
        for (LocalCoin *coin in coinArray) {
            
            if ([txChainPlain isEqualToString:@"BTY"]) {
                if ([coin.coin_type isEqualToString:@"BTY"] && [coin.coin_chain isEqualToString:@"ETH"]) {
                    self.host.localCoin = coin;
                    break;
                }
            }
            else{
                if ([coin.coin_type isEqualToString:txChainPlain]&& [coin.coin_chain isEqualToString:txChainPlain]) {
                    //bty
                    self.host.localCoin = coin;
                    break;
                }
            }
        }
    }
    if(self.host.localCoin == nil){
        [self.host showCustomMessage:L(@"暂不支持") hideAfterDelay:2.f];
        return;
    }
    
    DappAlertSheetView *sheetView = [[DappAlertSheetView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)
                                                                     withType:DappAlertSheetTypePay
                                                                     withData:dict
                                                                     withCoin:self.host.localCoin];
    sheetView.dappBlock = ^(NSString * _Nonnull passwdStr,NSString * _Nonnull selectedGas,NSString * _Nonnull selectedGasPrice) {
        if(passwdStr.length == 0){
            [self.host showCustomMessage:L(@"请输入密聊密码") hideAfterDelay:2.f];
            return;
        }else if ([passwdStr isEqualToString:L(@"取消")]){
            NSDictionary *error = @{@"code": @4001, @"message": @"User rejected the transaction"};
            [self.host sendResponseToJS:requestId result:nil error:error method:method];
            return;
        }else{
            LocalWallet *wallet = [[PWDataBaseManager shared] queryWalletIsSelected];
            NSString *remebercode = [GoFunction deckey:wallet.wallet_remembercode password:passwdStr];
            WalletapiHDWallet *hdWallet = WalletapiNewWalletFromMnemonic_v2(@"ETH",[self.host remv:remebercode],nil );
            if (hdWallet == nil) {
                [self.host showCustomMessage:L(@"密码错误")  hideAfterDelay:2.f];
                return;
            }
            NSString *prikey = [[hdWallet newKeyPriv:0 error:nil] hexString];
            self.host.priKey = prikey;
            
            [self metaMaskEthSendTransaction:prikey obj:obj requestId:requestId gas:selectedGas gasPrice:selectedGasPrice method:method];
        }
    };
    self.host.sheetView = sheetView;
    [self.host.sheetView showWithView:self.host.view];

}

/// Sheet 确认后根据是否有 `data` 分支：approve 走 raw 签名广播；有 calldata 时走 `CreateRawTransaction`+签名+`eth_sendRawTransaction`；否则纯 value 转账构造。
- (void)metaMaskEthSendTransaction:(NSString *)prikey
                               obj:(NSDictionary *)obj
                         requestId:(nullable NSString *)requestId
                               gas:(nullable NSString *)selectedGas
                          gasPrice:(nullable NSString *)selectedGasPrice
                            method:(nullable NSString *)method
{
    NSDictionary *resultJson = nil;
    
    if (obj[@"data"] != nil) {
        id dataRaw = obj[@"data"];
        if ([dataRaw isKindOfClass:[NSString class]] && [self tanxinIsERC20ApproveCalldata:(NSString *)dataRaw]) {
            WEAKSELF
            [self tanxinSignAndBroadcastRawEthTransactionWithPrikey:prikey obj:obj selectedGas:selectedGas selectedGasPrice:selectedGasPrice enforceApproveMinGas:YES completion:^(NSString *txHash, NSDictionary *rpcJsError, NSString *toastOrNet) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                if (txHash.length > 0) {
                    [strongSelf.host sendResponseToJS:requestId result:txHash error:nil method:method];
                    return;
                }
                if (rpcJsError) {
                    if (toastOrNet.length) {
                        [strongSelf.host showCustomMessage:toastOrNet hideAfterDelay:2.f];
                    }
                    [strongSelf.host sendResponseToJS:requestId result:nil error:rpcJsError method:method];
                    return;
                }
                if (toastOrNet.length) {
                    [strongSelf.host showCustomMessage:toastOrNet hideAfterDelay:2.f];
                }
            }];
            return;
        }
        NSDictionary *dataDict = [ETHInputParser parseInputData:obj[@"data"]];
        NSString *fn = dataDict[@"function_name"];
        if ([fn isEqualToString:@"deposit()"] || [fn isEqualToString:@"withdraw(uint256)"]) {
            NSString *from = obj[@"from"];
            NSString *to = obj[@"to"];
            NSString *data = obj[@"data"];
            NSString *value = [self.host sixteenToTen:obj[@"value"]]; // 需要把16进制转为10进制
            NSString *gas = (selectedGas == nil || selectedGas.integerValue == 0) ? [self.host sixteenToTen:obj[@"gas"]] : selectedGas; //先判断是不是修改过矿工费，如果修改过了，就用修改的，如果没有就用前端返回的 前端返回的需要把16进制转为10进制。
            if (gas.integerValue == 0) {
                NSString *gl = [self.host sixteenToTen:obj[@"gasLimit"]];
                if (gl.integerValue > 0) {
                    gas = gl;
                }
            }
            // deposit / withdraw：合约调用，gas 不低于安全下限（DApp 可估更大 gas）
            NSInteger minGas = [fn isEqualToString:@"deposit()"] ? 60000 : 100000;
            if (gas.integerValue < minGas) {
                gas = [NSString stringWithFormat:@"%ld", (long)minGas];
            }
            NSString *gasPriceWeiStr = [self tanxinWeiStringGasPriceForSignTx:obj selectedSheetGasPrice:selectedGasPrice];
            
            NSString *inputData64 = @"";
            if (data == nil || data.length == 0) {
                
            }else{
                NSString *inputData = [data stringByReplacingOccurrencesOfString:@"0x" withString:@""];
                inputData64 = [self.host base64Encoding:inputData];
            }
            
            resultJson = @{@"from":from,
                           @"gas":@(gas.integerValue),
                           @"gasPrice":[NSDecimalNumber decimalNumberWithString:gasPriceWeiStr],
                           @"input":inputData64,
                           @"nonce":@([self tanxinResolvedNonceForSigningTransaction:obj]),
                           @"to":to,
                           @"value":[NSDecimalNumber decimalNumberWithString:value]};
            NSData *resultJsonData = [NSJSONSerialization dataWithJSONObject:resultJson options:NSJSONWritingFragmentsAllowed error:nil];
            NSString *resultJsonStr = [[NSString alloc] initWithData:resultJsonData encoding:NSUTF8StringEncoding];
            NSLog(@"构造的数据是----->%@",resultJson);
            NSError *error;
            NSData *txData = WalletapiStringTobyte(resultJsonStr, &error);
            
            WalletapiSignData *signData = [[WalletapiSignData alloc] init];
            if ([self.host.selectedChain isEqualToString:@"BTY"]) {
                signData.cointype = @"BTYETH";
            }else{
                signData.cointype = self.host.selectedChain;
            }
            if (self.host.selectedChainID > 0) {
                signData.chainID = (int32_t)self.host.selectedChainID;
            }
            signData.data = txData;
            signData.privKey = prikey;
            signData.addressID = 2;

            NSString *signTx = WalletapiSignRawTransaction(signData, &error);
            if(error){
                [self.host showCustomMessage:L(@"操作失败，请稍后再试") hideAfterDelay:2.f];
                return;
            }
            [self.host.sheetView dismiss];
            NSDictionary *params = @{@"id":@1,
                                     @"jsonrpc":@"2.0",
                                     @"method":@"eth_sendRawTransaction",
                                     @"params":@[signTx]};
            [self.host showProgressMessage:@"" hideAfterDelay:2.f];
            [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                                serverUrl:self.host.selectedRpcUlr
                                                  apiPath:@""
                                               parameters:params
                                                 progress:nil
                                                  success:^(BOOL isSuccess, id  _Nullable responseObject) {
                
                NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
                NSLog(@"eth_sendRawTransaction response is %@",jsonData);
                NSString *result = jsonData[@"result"];
                
                if(result == nil || result.length == 0){
                    NSDictionary *dict = jsonData[@"error"];
                    NSString *message = dict[@"message"];
                    if (message == nil || message.length == 0) {
                        [self.host showCustomMessage:L(@"操作失败，请稍后再试")  hideAfterDelay:2.f];
                    }else{
                        [self.host showCustomMessage:message  hideAfterDelay:2.f];
                    }
                    NSDictionary *error = @{@"code": @-32010, @"message": @"response error"};
                    [self.host sendResponseToJS:requestId result:nil error:error method:method];
                   
                    return;
                }
                
                [self.host sendResponseToJS:requestId result:result error:nil method:method];
            } failure:^(NSString * _Nullable errorMessage) {
                [self.host showCustomMessage:errorMessage hideAfterDelay:2.f];
            }];
        }else{
            NSLog(@"data str %@",dataDict);
            NSString *sendSelectorHex = dataDict[@"function_selector"] ?: @"";
            BOOL isSwap = TanxinSelectorHexIsDexSwap(sendSelectorHex);
            BOOL sendIsETHSwap = TanxinSelectorHexIsEthInputDexSwap(sendSelectorHex);
            NSDictionary *peerAmt = [self tanxinErc20PeerAndAmountFromParseResult:dataDict];
            NSString *toAddr;
            NSString *extendDataHex = nil;
            if (isSwap) {
                toAddr = [self tanxinTxToAddressString:obj];
                extendDataHex = [self tanxinNonEmptyDataHexForExtend:obj[@"data"]];
            } else {
                toAddr = peerAmt[@"peer"] ?: @"";
            }
            NSString *from = obj[@"from"];
            NSString *valueWeiDecimal;
            if (sendIsETHSwap) {
                // ETH swap: value 是交易的 ETH 金额
                valueWeiDecimal = [self.host sixteenToTen:obj[@"value"]];
            } else if (isSwap) {
                // Token swap: value 为 0，amount 从 calldata 取
                valueWeiDecimal = [self.host sixteenToTen:obj[@"value"]];
                if (valueWeiDecimal.doubleValue == 0) {
                    valueWeiDecimal = @"0";
                }
            } else {
                id amtObj = peerAmt[@"amount"];
                valueWeiDecimal = amtObj ? [NSString stringWithFormat:@"%@", amtObj] : @"";
            }
            NSString *tokenAddrForRaw = isSwap ? @"" : [self tanxinTokenContractAddressForDisplayAndCoinMatch:obj parsed:dataDict];
            // swap 交易使用更高的 gas limit
            NSString *defaultGas = isSwap ? @"200000" : @"21000";
            NSString *gas = (selectedGas == nil || selectedGas.integerValue == 0) ? defaultGas : selectedGas;
            double gasPrice = (selectedGasPrice == nil || selectedGasPrice.integerValue == 0) ? self.host.gasPrice.integerValue : selectedGasPrice.doubleValue * 10000000000;
            double fee = gas.integerValue * gasPrice / 1000000000000000000.0;
            BOOL isApproveCalldata = [obj[@"data"] isKindOfClass:[NSString class]] && [self tanxinIsERC20ApproveCalldata:(NSString *)obj[@"data"]];
            NSString *inputHexForPatch = extendDataHex;
            if (inputHexForPatch.length == 0 && isApproveCalldata) {
                inputHexForPatch = [self tanxinNonEmptyDataHexForExtend:obj[@"data"]];
            }
            BOOL shouldPatchCreateRawInput = (isSwap || isApproveCalldata) && inputHexForPatch.length > 0;
            [PWContractRequest createRawTranscationWithCoinType:self.host.localCoin.coin_chain
                                                    tokensymbol:self.host.localCoin.coin_type
                                                       fromAddr:from
                                                         toAddr:toAddr
                                                         amount:(valueWeiDecimal.doubleValue / 1000000000000000000.0)
                                                            fee:fee
                                                      tokenAddr:tokenAddrForRaw
                                                  extendDataHex:extendDataHex
                                                        success:^(id  _Nonnull object) {
                NSError *error;
                NSDictionary *resultJsonData = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingAllowFragments error:&error];
                [self.host hideProgress];
                if (resultJsonData[@"result"] == nil || [resultJsonData[@"result"] isEqual:[NSNull null]]) {
                    NSLog(@"resultDic==%@",resultJsonData);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.host showCustomMessage:L(@"支付失败")  hideAfterDelay:2.0];
                    });
                }else{
                    NSString *resultJsonStr = [self tanxinCreateRawResultJsonStringForSignFromParsedResponse:resultJsonData extendDataHex:inputHexForPatch shouldPatchInput:shouldPatchCreateRawInput];
                    if (resultJsonStr.length == 0) {
                        id rawRes = resultJsonData[@"result"];
                        if ([rawRes isKindOfClass:[NSData class]]) {
                            resultJsonStr = [[NSString alloc] initWithData:(NSData *)rawRes encoding:NSUTF8StringEncoding];
                        } else if ([rawRes isKindOfClass:[NSDictionary class]]) {
                            NSData *d = [NSJSONSerialization dataWithJSONObject:rawRes options:NSJSONWritingPrettyPrinted error:nil];
                            resultJsonStr = d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"";
                        }
                    }
                    
                    NSData *txData = WalletapiStringTobyte(resultJsonStr, &error);
                    
                    WalletapiSignData *signData = [[WalletapiSignData alloc] init];
                    if ([self.host.selectedChain isEqualToString:@"BTY"]) {
                        signData.cointype = @"BTYETH";
                    } else {
                        signData.cointype = self.host.selectedChain;
                    }
                    signData.data = txData;
                    signData.privKey = prikey;
                    signData.addressID = 2;
                    if (self.host.selectedChainID > 0) {
                        signData.chainID = (int32_t)self.host.selectedChainID;
                    }
                   

                    NSString *signTx = WalletapiSignRawTransaction(signData, &error);
                    if(error != nil){
                        [self.host showCustomMessage:L(@"签名失败，请稍后再试") hideAfterDelay:2.f];
                        return;
                    }
                    [self.host.sheetView dismiss];
                    NSDictionary *params = @{@"id":@1,
                                             @"jsonrpc":@"2.0",
                                             @"method":@"eth_sendRawTransaction",
                                             @"params":@[signTx]};
                    [self.host showProgressMessage:@"" hideAfterDelay:2.f];
                    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                                        serverUrl:self.host.selectedRpcUlr
                                                          apiPath:@""
                                                       parameters:params
                                                         progress:nil
                                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
                        
                        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
                        NSLog(@"eth_sendRawTransaction response is %@",jsonData);
                        NSString *result = jsonData[@"result"];
                        if(result == nil || result.length == 0){
                            NSDictionary *dict = jsonData[@"error"];
                            NSString *message = dict[@"message"];
                            if (message == nil || message.length == 0) {
                                [self.host showCustomMessage:L(@"支付失败，请稍后再试")  hideAfterDelay:2.f];
                            }else{
                                [self.host showCustomMessage:message  hideAfterDelay:2.f];
                            }
                            NSDictionary *error = @{@"code": @-32010, @"message": @"response error"};
                            [self.host sendResponseToJS:requestId result:nil error:error method:method];
                           
                            return;
                        }
                        [self.host sendResponseToJS:requestId result:result error:nil method:method];
                    } failure:^(NSString * _Nullable errorMessage) {
                        [self.host showCustomMessage:errorMessage hideAfterDelay:2.f];
                    }];
                }
            } failure:^(NSString * _Nonnull errorMsg) {
                [self.host showCustomMessage:errorMsg hideAfterDelay:2.f];
            }];
        }
       

    }else{
        NSString *from = obj[@"from"];
        NSString *to = obj[@"to"];
        NSString *data = obj[@"data"];
        NSString *value = [self.host sixteenToTen:obj[@"value"]]; // 需要把16进制转为10进制
        NSString *gas = (selectedGas == nil || selectedGas.integerValue == 0) ? [self.host sixteenToTen:obj[@"gas"]] : selectedGas; //先判断是不是修改过矿工费，如果修改过了，就用修改的，如果没有就用前端返回的 前端返回的需要把16进制转为10进制。
        if (gas.integerValue == 0) {
            NSString *gl = [self.host sixteenToTen:obj[@"gasLimit"]];
            if (gl.integerValue > 0) {
                gas = gl;
            }
        }
        NSString *gasPriceWeiStr = [self tanxinWeiStringGasPriceForSignTx:obj selectedSheetGasPrice:selectedGasPrice];
        
        NSString *inputData64 = @"";
        if (data == nil || data.length == 0) {
            
        }else{
            NSString *inputData = [data stringByReplacingOccurrencesOfString:@"0x" withString:@""];
            inputData64 = [self.host base64Encoding:inputData];
        }
        
        resultJson = @{@"from":from,
                       @"gas":@(gas.integerValue),
                       @"gasPrice":[NSDecimalNumber decimalNumberWithString:gasPriceWeiStr],
                       @"input":inputData64,
                       @"nonce":@([self tanxinResolvedNonceForSigningTransaction:obj]),
                       @"to":to,
                       @"value":[NSDecimalNumber decimalNumberWithString:value]};
        NSData *resultJsonData = [NSJSONSerialization dataWithJSONObject:resultJson options:NSJSONWritingFragmentsAllowed error:nil];
        NSString *resultJsonStr = [[NSString alloc] initWithData:resultJsonData encoding:NSUTF8StringEncoding];
        NSLog(@"构造的数据是----->%@",resultJson);
        NSError *error;
        NSData *txData = WalletapiStringTobyte(resultJsonStr, &error);
        
        WalletapiSignData *signData = [[WalletapiSignData alloc] init];
        if ([self.host.selectedChain isEqualToString:@"BTY"]) {
            signData.cointype = @"BTYETH";
        }else{
            signData.cointype = self.host.selectedChain;
        }
        if (self.host.selectedChainID > 0) {
            signData.chainID = (int32_t)self.host.selectedChainID;
        }
        signData.data = txData;
        signData.privKey = prikey;
        signData.addressID = 2;

        NSString *signTx = WalletapiSignRawTransaction(signData, &error);
        if(error){
            [self.host showCustomMessage:L(@"操作失败，请稍后再试") hideAfterDelay:2.f];
            return;
        }
        [self.host.sheetView dismiss];
        NSDictionary *params = @{@"id":@1,
                                 @"jsonrpc":@"2.0",
                                 @"method":@"eth_sendRawTransaction",
                                 @"params":@[signTx]};
        [self.host showProgressMessage:@"" hideAfterDelay:2.f];
        [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                            serverUrl:self.host.selectedRpcUlr
                                              apiPath:@""
                                           parameters:params
                                             progress:nil
                                              success:^(BOOL isSuccess, id  _Nullable responseObject) {
            
            NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
            NSLog(@"eth_sendRawTransaction response is %@",jsonData);
            NSString *result = jsonData[@"result"];
            
            if(result == nil || result.length == 0){
                NSDictionary *dict = jsonData[@"error"];
                NSString *message = dict[@"message"];
                if (message == nil || message.length == 0) {
                    [self.host showCustomMessage:L(@"操作失败，请稍后再试")  hideAfterDelay:2.f];
                }else{
                    [self.host showCustomMessage:message  hideAfterDelay:2.f];
                }
                NSDictionary *error = @{@"code": @-32010, @"message": @"response error"};
                [self.host sendResponseToJS:requestId result:nil error:error method:method];
               
                return;
            }
            
            [self.host sendResponseToJS:requestId result:result error:nil method:method];
        } failure:^(NSString * _Nullable errorMessage) {
            [self.host showCustomMessage:errorMessage hideAfterDelay:2.f];
        }];
    }
    
}

#pragma mark EIP-712 与 eth_call

/// 🚫 `eth_sign` 已禁用：它签的是**任意 32 字节哈希**，攻击者可让这个哈希恰好等于一笔转账交易的哈希
/// ⇒ 用户以为在「签名验证」，实际签掉了一笔转账。主流钱包（MetaMask / Ledger 等）均已禁用。
/// 旧实现是把参数转成 `personal_sign` 后再签（EIP-191 前缀），对真正的 eth_sign 请求方来说签名本来就是错的。
/// dApp 如需签名请用 personal_sign / eth_signTypedData。
- (void)handleEthSign:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method {
    [self.host sendResponseToJS:requestId
                         result:nil
                          error:@{@"code": @-32601,
                                  @"message": L(@"出于安全考虑，已禁用 eth_sign（原始数据签名），请使用 personal_sign")}
                         method:method];
}

/// 旧版 `eth_signTypedData`，参数与 v4 一致时走同一套 EIP-712 弹窗（占位签名）。
- (void)handleEthSignTypedData:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method {
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    [self handleEthSignTypedDataV4:requestId params:params method:method];
}

/// 处理 `eth_signTypedData_v4`：解析 JSON、弹窗展示 domain/message，拒绝或确认后回包（确认时签名为占位）。
- (void)handleEthSignTypedDataV4:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method{
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    if (params.count < 2) return;
    
    NSString *address = params[0];
    NSString *typedDataJson = params[1]; // 这是一个 JSON 字符串
    
    // 1. 将 JSON 字符串解析为字典
    NSError *error;
    NSData *jsonData = [typedDataJson dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *typedData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if (error || !typedData) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @-32602, @"message": @"Invalid JSON"} method:method];
        return;
    }

    // 2. 提取 DApp 信息和待签名的消息内容
    NSDictionary *domain = typedData[@"domain"];
    NSDictionary *message = typedData[@"message"];
    NSString *dappName = domain[@"name"] ?: L(@"未知 DApp");
    
    // 假设消息里有 "contents" 或 "amount" 等字段，我们动态提取
    NSMutableString *displayMessage = [NSMutableString stringWithFormat:L(@"来自: %@\n\n"), dappName];
    [message enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [displayMessage appendFormat:@"%@: %@\n", key, obj];
    }];

    // 3. 弹出原生确认框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"签名请求 (EIP-712)")
                                                                   message:displayMessage
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:L(@"拒绝") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @4001, @"message": @"User rejected signing"} method:method];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:L(@"确认签名") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 🚫 这里以前返回空串（@""）当签名 —— dApp 会拿到一个无效签名且无从排查。
        // 旧 OC 浏览器（WebViewController）暂未接入 EIP-712 哈希与签名，明确报错让它走兜底；
        // 新版 DApp 浏览器（chat/dapp/DAppBrowser.swift）已完整实现，请用新版打开。
        [self.host sendResponseToJS:requestId
                             result:nil
                              error:@{@"code": @-32601,
                                      @"message": L(@"当前浏览器暂不支持结构化签名，请用新版 DApp 浏览器打开")}
                             method:method];
    }]];

    [self.host presentViewController:alert animated:YES completion:nil];
}

/// eth_call 的 transaction 里 from 为可选；DApp 常不传。缺省时用当前选中链对应的钱包地址，避免 RPC/合约按 msg.sender 读状态时异常。
- (NSString *)resolvedEthCallFromAddress:(nullable id)fromValue {
    if (fromValue == nil || [fromValue isKindOfClass:[NSNull class]]) {
        return [GameGoFunction queryAddressByChain:self.host.selectedChain] ?: @"";
    }
    if ([fromValue isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)fromValue;
        if (s.length == 0) {
            return [GameGoFunction queryAddressByChain:self.host.selectedChain] ?: @"";
        }
        return s;
    }
    NSString *s = [NSString stringWithFormat:@"%@", fromValue];
    if (s.length == 0 || [s isEqualToString:@"(null)"]) {
        return [GameGoFunction queryAddressByChain:self.host.selectedChain] ?: @"";
    }
    return s;
}

/// eth_call 回包注入前等待（仅 tanxinSendEthCallJsResponseDelayed 使用）
static const NSTimeInterval kEthCallJsResponseDelay = 1.0;


/// 主线程上延迟 kEthCallJsResponseDelay 再注入 JS，缓解 _onResponse 与回调注册的竞态
- (void)tanxinSendEthCallJsResponseDelayed:(nullable NSString *)requestId result:(nullable id)result error:(nullable id)error method:(nullable NSString *)method {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kEthCallJsResponseDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.host sendResponseToJS:requestId result:result error:error method:method];
        });
    });
}

/// 异步派发 `tanxinProcessEthCallItem`，避免阻塞调用线程。
- (void)handleEthCall:(NSString *)requestId params:(NSArray *)params method:(NSString *)method {
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    if (params.count == 0) {
        return;
    }
    NSDictionary *item = @{
        @"requestId": requestId ?: @"",
        @"params": [params copy] ?: @[],
        @"method": method ?: @"eth_call"
    };
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [weakSelf tanxinProcessEthCallItem:item];
    });
}

/// 主线程快照 `from`/`to`/`data`/区块标签与 RPC URL，经 `web3ProviderHandler` POST eth_call，结果规范化后延迟回包。
- (void)tanxinProcessEthCallItem:(NSDictionary *)item {
    NSString *requestId = item[@"requestId"];
    NSString *method = item[@"method"];
    NSArray *params = item[@"params"];

    __block NSString *from = nil;
    __block NSString *to = nil;
    __block NSString *data = nil;
    __block NSString *blockTag = @"latest";
    __block NSString *rpcURL = nil;
    void (^snapshotFromMain)(void) = ^{
        NSDictionary *callData = (params.count > 0 && [params[0] isKindOfClass:[NSDictionary class]]) ? params[0] : @{};
        if (params.count >= 2 && params[1] != nil && ![params[1] isKindOfClass:[NSNull class]]) {
            blockTag = [NSString stringWithFormat:@"%@", params[1]];
        }
        from = [self resolvedEthCallFromAddress:callData[@"from"]];
        to = callData[@"to"] ?: @"";
        data = callData[@"data"] ?: @"";
        rpcURL = [self.host.selectedRpcUlr copy];
    };
    if ([NSThread isMainThread]) {
        snapshotFromMain();
    } else {
        dispatch_sync(dispatch_get_main_queue(), snapshotFromMain);
    }

    __weak typeof(self) weakSelf = self;

    NSDictionary *paramss = @{@"from": from ?: @"", @"to": to ?: @"", @"data": data ?: @""};
    NSDictionary *param = @{@"id": @1, @"jsonrpc": @"2.0", @"method": @"eth_call", @"params": @[paramss, blockTag ?: @"latest"]};

    __strong typeof(self) strongSelf = weakSelf;
    if (!strongSelf) {
        return;
    }

    NSString *version = [NSString stringWithFormat:@"V%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    NSString *deviceiNFO = [NSString stringWithFormat:@"%@%@%@%@", [UIDevice currentDevice].name, [UIDevice currentDevice].model, [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion];
    NSDictionary *httpHeaders = @{
        @"Content-Type": @"application/json",
        @"FZM-PLATFORM-ID": @"1",
        @"version": version,
        @"device": deviceiNFO
    };

    NSString *rpcURLCopy = [rpcURL copy];
    NSString *requestIdCopy = [requestId copy];
    NSString *methodCopy = [method copy];

    [[strongSelf.host web3ProviderHandler] enqueueJsonRpcPostWithURL:rpcURLCopy jsonRpcBody:param httpHeaders:httpHeaders completion:^(NSDictionary *jsonData, NSError *rpcErr) {
        __strong typeof(weakSelf) innerSelf = weakSelf;
        if (!innerSelf) {
            return;
        }
        if (rpcErr) {
            NSLog(@"eth_call error: %@", rpcErr.localizedDescription);
            NSDictionary *err = @{@"code": @(-32603), @"message": rpcErr.localizedDescription ?: @"RPC request failed"};
            [innerSelf tanxinSendEthCallJsResponseDelayed:requestIdCopy result:nil error:err method:methodCopy];
            return;
        }

        id rpcJsonErr = jsonData[@"error"];
        if (rpcJsonErr) {
            NSDictionary *err = [rpcJsonErr isKindOfClass:[NSDictionary class]] ? (NSDictionary *)rpcJsonErr : @{@"code": @(-32603), @"message": [NSString stringWithFormat:@"%@", rpcJsonErr]};
            [innerSelf tanxinSendEthCallJsResponseDelayed:requestIdCopy result:nil error:err method:methodCopy];
            return;
        }

        id rawResult = jsonData[@"result"];
        NSString *result = [innerSelf tanxinNormalizeEthCallResult:rawResult];
        [innerSelf tanxinSendEthCallJsResponseDelayed:requestIdCopy result:result error:nil method:methodCopy];
    }];
}

#pragma mark - 钱包权限、切链、估算 gas

/// 将 App 当前网络切到 targetChainId（BTY / ETH / BNB）
- (void)applySwitchToChainId:(NSString *)targetChainId {
    NSString *l = [[targetChainId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if ([l isEqualToString:@"0x38"]) {
        [[PWAppsettings instance] setAPPNetType:NetBNB];
        self.host.selectedChain = @"BNB";
        self.host.selectedRpcUlr = BNBRPCUrl;
        self.host.selectedChainID = 56;
        self.host.selectedChainName = @"BNB Smart Chain";
    } else if ([l isEqualToString:@"0xbb7"]) {
        [[PWAppsettings instance] setAPPNetType:NetBTY];
        self.host.selectedChain = @"BTY";
        self.host.selectedRpcUlr = BTYRPCUrl;
        self.host.selectedChainID = 2999;
        self.host.selectedChainName = @"BitYuan Mainnet";
    }else if ([l isEqualToString:@"0x1"]) {
        [[PWAppsettings instance] setAPPNetType:NetETH];
        self.host.selectedChain = @"ETH";
        self.host.selectedRpcUlr = ETHRPCUrl;
        self.host.selectedChainID = 1;
        self.host.selectedChainName = @"Ethereum Mainnet";
    }
}

/// `wallet_getPermissions`：无账户返回 `[]`，否则返回 `eth_accounts` 权限描述数组。
- (void)handleWalletGetPermissions:(nullable NSString *)requestId method:(nullable NSString *)method {
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    NSString *addr = [self addressForEthRequestAccounts];
    if (!addr.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.host sendResponseToJS:requestId result:@[] error:nil method:method];
            });
        });
        return;
    }
    NSDictionary *perm = @{@"parentCapability": @"eth_accounts", @"caveats": @[]};
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.host sendResponseToJS:requestId result:@[perm] error:nil method:method];
        });
    });
}

/// `wallet_requestPermissions`：无账户返回 4001；有账户则授予并返回权限数组。
- (void)handleWalletRequestPermissions:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method {
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    NSString *addr = [self addressForEthRequestAccounts];
    if (!addr.length) {
        NSDictionary *err = @{@"code": @4001, @"message": @"No account for current chain"};
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.host sendResponseToJS:requestId result:nil error:err method:method];
            });
        });
        return;
    }
    NSDictionary *perm = @{@"parentCapability": @"eth_accounts", @"caveats": @[]};
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.host sendResponseToJS:requestId result:@[perm] error:nil method:method];
        });
    });
}

/// `web3_clientVersion`：返回 `Tanxin/<CFBundleShortVersionString>`。
- (void)handleWeb3ClientVersion:(nullable NSString *)requestId method:(nullable NSString *)method {
    NSString *ver = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: @"1";
    NSString *client = [NSString stringWithFormat:@"Tanxin/%@", ver];
    [self.host sendResponseToJS:requestId result:client error:nil method:method];
}

/// EIP-3085：添加链；已支持的网络走与切换相同的确认流程，成功返回 null
- (void)handleWalletAddEthereumChain:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method {
    if (params.count == 0) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @-32602, @"message": @"Invalid params"} method:method];
        return;
    }
    NSDictionary *chainParams = [params[0] isKindOfClass:[NSDictionary class]] ? params[0] : @{};
    NSInteger targetDecimal = WebViewMetaMaskDecimalChainIdFromParam(chainParams[@"chainId"], self.host);
    if (targetDecimal == NSNotFound) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @-32602, @"message": @"Invalid chainId"} method:method];
        return;
    }
    if (targetDecimal == self.host.selectedChainID) {
        [self.host sendResponseToJS:requestId result:nil error:nil method:method];
        return;
    }
    NSString *norm = [[self.host tenToSixteen:targetDecimal isUppercase:NO] lowercaseString];
    NSDictionary *supportedChains = @{
        @"0x38": @"BNB Smart Chain",
        @"0x1": @"Ethereum Mainnet",
        @"0xbb7": @"BitYuan Mainnet",
    };
    if (!supportedChains[norm]) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @-32603, @"message": @"Only BitYuan (0xbb7), Ethereum (0x1), and BNB Smart Chain (0x38) are supported"} method:method];
        return;
    }
    NSString *chainName = supportedChains[norm] ?: norm;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"添加网络")
                                                                   message:[NSString stringWithFormat:L(@"允许此站点添加并使用网络 %@ (%@) 吗？"), chainName, norm]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    WEAKSELF
    [alert addAction:[UIAlertAction actionWithTitle:L(@"取消") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf.host sendResponseToJS:requestId result:nil error:@{@"code": @4001, @"message": @"User rejected"} method:method];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"确认") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf applySwitchToChainId:norm];
        [weakSelf.host sendResponseToJS:requestId result:nil error:nil method:method];
        [weakSelf.host notifyChainChanged:norm];
    }]];
    [self.host presentViewController:alert animated:YES completion:nil];
}

/// `wallet_switchEthereumChain`：已在目标链则回包并 `notifyChainChanged`；否则弹窗确认后 `applySwitchToChainId` 再回包。
- (void)handleSwitchEthereumChain:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method {
    if (params.count == 0) return;
    NSDictionary *chainParams = [params[0] isKindOfClass:[NSDictionary class]] ? params[0] : @{};
    NSInteger targetDecimal = WebViewMetaMaskDecimalChainIdFromParam(chainParams[@"chainId"], self.host);
    if (targetDecimal == NSNotFound) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @-32602, @"message": @"Invalid chainId"} method:method];
        return;
    }
    if (!WebViewMetaMaskSupportedNumericChainId(targetDecimal)) {
        [self.host sendResponseToJS:requestId result:nil error:@{@"code": @4902, @"message": @"Only BitYuan (2999), Ethereum (1), and BNB Smart Chain (56) are supported"} method:method];
        return;
    }
    NSString *canonical = [[self.host tenToSixteen:targetDecimal isUppercase:NO] lowercaseString];
    if (targetDecimal == self.host.selectedChainID) {
        [self.host sendResponseToJS:requestId result:canonical error:nil method:method];
        // 5. 【进阶】通知网页端链已改变，以便 DApp 刷新界面
        [self.host notifyChainChanged:canonical];
        
        return;
    }
    NSDictionary *supportedChains = @{
        @"0x38": @"BNB Smart Chain",
        @"0x1": @"Ethereum Mainnet",
        @"0xbb7": @"BitYuan Mainnet",
    };
    NSString *chainName = supportedChains[canonical] ?: L(@"未知网络");
    
    // 2. 弹出确认框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"切换网络")
                                                                   message:[NSString stringWithFormat:L(@"允许此站点切换网络到 %@ (%@) 吗？"), chainName, canonical]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    WEAKSELF
    [alert addAction:[UIAlertAction actionWithTitle:L(@"取消") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:L(@"切换网络") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf applySwitchToChainId:canonical];
        [weakSelf.host sendResponseToJS:requestId result:canonical error:nil method:method];
        [weakSelf.host notifyChainChanged:canonical];
    }]];
    
    [self.host presentViewController:alert animated:YES completion:nil];
}

/// `eth_estimateGas`：补全 `from` 后对当前 RPC POST，失败则回 RPC 错误。
- (void)handleEthEstimateGas:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method{
    if ([self tanxinRejectIfUnsupportedSelectedChainWithRequestId:requestId method:method]) {
        return;
    }
    NSMutableDictionary *txParams = params.count > 0 ? [params[0] mutableCopy] : [NSMutableDictionary dictionary];
    if (!txParams[@"from"] || [(NSString *)txParams[@"from"] length] == 0) {
        txParams[@"from"] = [self resolvedEthCallFromAddress:nil];
    }
    NSDictionary *rpc = @{@"id": @1, @"jsonrpc": @"2.0", @"method": @"eth_estimateGas", @"params": @[txParams]};
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:self.host.selectedRpcUlr
                                          apiPath:@""
                                       parameters:rpc
                                         progress:nil
                                          success:^(BOOL isSuccess, id _Nullable responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
        NSString *gasHex = json[@"result"];
        id err = json[@"error"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err) {
                [self.host sendResponseToJS:requestId result:nil error:err method:method];
            } else {
                [self.host sendResponseToJS:requestId result:gasHex ?: @"0x5208" error:nil method:method];
            }
        });
    } failure:^(NSString * _Nullable errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.host sendResponseToJS:requestId result:nil error:@{@"code": @(-32603), @"message": errorMessage ?: @"RPC failed"} method:method];
        });
    }];
}

/// eth_call 的 JSON-RPC result 规范为 0x 前缀十六进制字符串；部分节点返回无 0x 或大写，统一后再给 DApp，避免合约读状态异常
- (nullable NSString *)tanxinNormalizeEthCallResult:(nullable id)raw {
    if (raw == nil || raw == [NSNull null]) {
        return nil;
    }
    if (![raw isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"%@", raw];
    }
    NSString *s = [(NSString *)raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) {
        return @"0x";
    }
    if (![s hasPrefix:@"0x"] && ![s hasPrefix:@"0X"]) {
        s = [@"0x" stringByAppendingString:s];
    }
    return [s lowercaseString];
}

@end
