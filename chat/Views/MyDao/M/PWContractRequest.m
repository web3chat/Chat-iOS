//
//  PWContractRequest.m
//  chat
//
//  Created by 郑晨 on 2025/4/18.
//

#import "PWContractRequest.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]

static NSString *gonodeurl = GoNodeUrl;  //@"https://190.92.231.38:58083";

#pragma mark - ETH 合约币余额（公网 RPC 直连）

/**
 ⚠️ 自建 Go 节点（GoNodeUrl）的 `Wallet.GetBalance` 在 ETH 链上**忽略 `extend_info.Execer`**：
 无论传哪个合约地址（甚至 0x000…0）都返回同一个数 —— 就是该地址的**原生 ETH 余额**。
 表现就是「资产页里 ETH 链下所有合约币余额一模一样」。

 所以 ETH 链的合约币改成一件事：直接向公网 RPC 发 `eth_call`
   1. `decimals()`（按合约地址缓存，读不到就按 18 位）
   2. `balanceOf(owner)`，再按 decimals 归一化成人类可读数值
 ⚠️ 不能用 `rpc.flashbots.net`：它只放行交易类方法，`eth_call` 会返回 `rpc method is not whitelisted`。
 */
static NSArray<NSString *> *PWContractETHRPCHosts(void)
{
    return @[@"https://ethereum-rpc.publicnode.com",
             @"https://eth.drpc.org",
             @"https://rpc.mevblocker.io",
             @"https://eth-mainnet.public.blastapi.io"];
}

/// 合约 decimals 缓存（key = 小写合约地址）
static NSMutableDictionary<NSString *, NSNumber *> *PWContractDecimalsCache(void)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });
    return cache;
}

/// 读缓存（资产页会并发刷新多个币，NSMutableDictionary 必须加锁访问）
static NSNumber *PWContractCachedDecimals(NSString *contractKey)
{
    @synchronized (PWContractDecimalsCache()) {
        return PWContractDecimalsCache()[contractKey];
    }
}

static void PWContractStoreDecimals(NSString *contractKey, NSInteger decimals)
{
    @synchronized (PWContractDecimalsCache()) {
        PWContractDecimalsCache()[contractKey] = @(decimals);
    }
}

/// 是否是 0x + 40 位十六进制的地址
static BOOL PWContractIsHexAddress(NSString *value)
{
    if (![value isKindOfClass:[NSString class]] || value.length == 0) {
        return NO;
    }
    NSString *addr = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
    if (addr.length != 42 || ![addr hasPrefix:@"0x"]) {
        return NO;
    }
    NSString *body = [addr substringFromIndex:2];
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    return [body rangeOfCharacterFromSet:hex.invertedSet].location == NSNotFound;
}

/// address 参数编码成 32 字节左补零
static NSString *PWContractAddressWord(NSString *address)
{
    NSString *body = address.lowercaseString;
    if ([body hasPrefix:@"0x"]) {
        body = [body substringFromIndex:2];
    }
    NSMutableString *word = [NSMutableString string];
    for (NSUInteger i = body.length; i < 64; i++) {
        [word appendString:@"0"];
    }
    [word appendString:body];
    return word;
}

/// 十六进制字符串 → NSDecimalNumber（逐位累加，避免 uint256 超过 64 位后溢出）
static NSDecimalNumber *PWContractDecimalFromHex(NSString *hex)
{
    if (![hex isKindOfClass:[NSString class]] || hex.length == 0) {
        return [NSDecimalNumber zero];
    }
    NSString *body = hex.lowercaseString;
    if ([body hasPrefix:@"0x"]) {
        body = [body substringFromIndex:2];
    }
    NSDecimalNumber *value = [NSDecimalNumber zero];
    NSDecimalNumber *sixteen = [NSDecimalNumber decimalNumberWithString:@"16"];
    for (NSUInteger i = 0; i < body.length; i++) {
        unichar c = [body characterAtIndex:i];
        int digit = 0;
        if (c >= '0' && c <= '9') {
            digit = c - '0';
        } else if (c >= 'a' && c <= 'f') {
            digit = c - 'a' + 10;
        } else {
            continue;
        }
        value = [[value decimalNumberByMultiplyingBy:sixteen]
                 decimalNumberByAdding:[NSDecimalNumber decimalNumberWithMantissa:digit exponent:0 isNegative:NO]];
    }
    return value;
}

@interface PWContractRequest ()

/// 依次尝试各公网 RPC 发 `eth_call`，首个返回 result 的赢
+ (void)ethCallData:(NSString *)dataHex
                 to:(NSString *)to
           rpcHosts:(NSArray<NSString *> *)hosts
            success:(void (^)(NSString *resultHex))successBlock
            failure:(requestFailuresBlock)failureBlock;

+ (void)getETHContractBalanceWithContract:(NSString *)contract
                                  address:(NSString *)owner
                                  success:(requestSuccessBlock)successBlock
                                  failure:(requestFailuresBlock)failureBlock;

+ (void)requestETHBalanceOfContract:(NSString *)contract
                            address:(NSString *)owner
                           decimals:(NSInteger)decimals
                            success:(requestSuccessBlock)successBlock
                            failure:(requestFailuresBlock)failureBlock;

@end

@implementation PWContractRequest

+ (void)getContractorInfowithCoinType:(NSString *)coinType address:(NSString *)address execer:(NSString *)execer success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (execer == nil || address == nil || coinType == nil) {
        if (failureBlock) {
            failureBlock(L(@"参数不能为空"));
        }
        return;
    }
    NSDictionary *execerInfo = @{@"Execer":execer};
    NSDictionary *params = @{@"cointype":coinType,
                             @"address":address,
                             @"extend_info":execerInfo};
    NSDictionary *param = @{@"id":@1,
                            @"jsonrpc":@"2.0",
                            @"method":@"Wallet.GetContractorInfo",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
    
}

+ (void)createRawTranscationWithCoinType:(NSString *)coinType tokensymbol:(NSString *)tokensymbol fromAddr:(NSString *)fromAddr toAddr:(NSString *)toAddr amount:(double)amount fee:(double)fee tokenAddr:(NSString *)tokenAddr extendDataHex:(NSString *)extendDataHex success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (coinType == nil || fromAddr == nil || toAddr == nil) {
        if (failureBlock) {
            failureBlock(L(@"参数不能为空"));
        }
        return;
    }
    NSMutableDictionary *extend = [NSMutableDictionary dictionaryWithDictionary:@{@"token_addr": tokenAddr ?: @""}];
    if (extendDataHex.length > 0) {
        extend[@"data"] = extendDataHex;
    }
    NSDictionary *transaction = @{@"from":fromAddr,
                                  @"to":toAddr,
                                  @"amount":@(amount),
                                  @"fee":@(fee),
                                  @"extend":extend};
    NSDictionary *params = @{@"cointype":coinType,
                             @"tokensymbol":tokensymbol,
                             @"transaction":transaction};
    NSDictionary *param = @{@"id":@1,
                            @"jsonrpc":@"2.0",
                            @"method":@"Wallet.CreateRawTransaction",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

+ (void)getBalancewithCoinType:(NSString *)coinType address:(NSString *)address execer:(NSString *)execer success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (execer == nil || address == nil || coinType == nil) {
        if (failureBlock) {
            failureBlock(L(@"参数不能为空"));
        }
        return;
    }

    // ETH 链：自建节点只返回原生 ETH 余额（忽略 Execer，见文件顶部注释）
    // ⇒ 改走公网 RPC 直接读 ERC20 的 balanceOf，否则每个合约币都会显示成同一个 ETH 余额
    if ([coinType caseInsensitiveCompare:@"ETH"] == NSOrderedSame &&
        PWContractIsHexAddress(execer) &&
        PWContractIsHexAddress(address)) {
        [self getETHContractBalanceWithContract:execer
                                        address:address
                                        success:successBlock
                                        failure:failureBlock];
        return;
    }

    NSDictionary *execerInfo = @{@"Execer":execer};
    NSDictionary *params = @{@"cointype":coinType,
                             @"address":address,
                             @"extend_info":execerInfo};
    NSDictionary *param = @{@"id":@1,
                            @"jsonrpc":@"2.0",
                            @"method":@"Wallet.GetBalance",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

#pragma mark - ETH 合约余额实现

+ (void)ethCallData:(NSString *)dataHex
                 to:(NSString *)to
           rpcHosts:(NSArray<NSString *> *)hosts
            success:(void (^)(NSString *resultHex))successBlock
            failure:(requestFailuresBlock)failureBlock
{
    if (hosts.count == 0) {
        if (failureBlock) {
            failureBlock(L(@"网络异常，请稍后重试"));
        }
        return;
    }
    NSString *host = hosts.firstObject;
    NSArray<NSString *> *rest = [hosts subarrayWithRange:NSMakeRange(1, hosts.count - 1)];
    NSDictionary *call = @{@"to":[to lowercaseString],
                           @"data":dataHex};
    NSDictionary *param = @{@"id":@1,
                            @"jsonrpc":@"2.0",
                            @"method":@"eth_call",
                            @"params":@[call, @"latest"]};

    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:host
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        NSDictionary *json = nil;
        if ([responseObject isKindOfClass:[NSData class]]) {
            json = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        } else if ([responseObject isKindOfClass:[NSDictionary class]]) {
            json = responseObject;
        }
        NSString *resultHex = [json[@"result"] isKindOfClass:[NSString class]] ? json[@"result"] : nil;
        // result 存在（含 "0x" 这种空返回）且无 error ⇒ 该节点可用；空返回交给调用方按缺省处理
        if (resultHex != nil && ![json[@"error"] isKindOfClass:[NSDictionary class]]) {
            if (successBlock) {
                successBlock(resultHex);
            }
            return;
        }
        // 当前节点不支持/出错 → 换下一个
        [self ethCallData:dataHex to:to rpcHosts:rest success:successBlock failure:failureBlock];
    } failure:^(NSString * _Nullable errorMessage) {
        [self ethCallData:dataHex to:to rpcHosts:rest success:successBlock failure:failureBlock];
    }];
}

+ (void)getETHContractBalanceWithContract:(NSString *)contract
                                  address:(NSString *)owner
                                  success:(requestSuccessBlock)successBlock
                                  failure:(requestFailuresBlock)failureBlock
{
    NSString *contractKey = [contract lowercaseString];
    NSNumber *cachedDecimals = PWContractCachedDecimals(contractKey);
    if (cachedDecimals != nil) {
        [self requestETHBalanceOfContract:contractKey
                                  address:owner
                                 decimals:cachedDecimals.integerValue
                                  success:successBlock
                                  failure:failureBlock];
        return;
    }

    [self ethCallData:@"0x313ce567" // decimals()
                   to:contractKey
             rpcHosts:PWContractETHRPCHosts()
              success:^(NSString *resultHex) {
        NSInteger decimals = 18;
        NSString *body = [resultHex.lowercaseString hasPrefix:@"0x"] ? [resultHex substringFromIndex:2] : resultHex;
        if (body.length > 0) {
            NSDecimalNumber *value = PWContractDecimalFromHex(resultHex);
            if ([value compare:[NSDecimalNumber zero]] != NSOrderedAscending &&
                [value compare:[NSDecimalNumber decimalNumberWithString:@"37"]] != NSOrderedDescending) {
                decimals = value.integerValue;
            }
        }
        PWContractStoreDecimals(contractKey, decimals);
        [self requestETHBalanceOfContract:contractKey
                                  address:owner
                                 decimals:decimals
                                  success:successBlock
                                  failure:failureBlock];
    } failure:^(NSString *errorMsg) {
        // decimals() 读不到（老合约没实现该方法等）时按 18 位算，至少余额本身是对的
        [self requestETHBalanceOfContract:contractKey
                                  address:owner
                                 decimals:18
                                  success:successBlock
                                  failure:failureBlock];
    }];
}

+ (void)requestETHBalanceOfContract:(NSString *)contract
                            address:(NSString *)owner
                           decimals:(NSInteger)decimals
                            success:(requestSuccessBlock)successBlock
                            failure:(requestFailuresBlock)failureBlock
{
    NSString *dataHex = [@"0x70a08231" stringByAppendingString:PWContractAddressWord(owner)]; // balanceOf(address)
    [self ethCallData:dataHex
                   to:contract
             rpcHosts:PWContractETHRPCHosts()
              success:^(NSString *resultHex) {
        NSDecimalNumber *raw = PWContractDecimalFromHex(resultHex);
        NSDecimalNumber *unit = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:(short)decimals isNegative:NO];
        NSString *balanceText = [[raw decimalNumberByDividingBy:unit] stringValue];

        // 回调格式与节点一致（NSData JSON），三个调用方都按 result.result.balance 取值
        NSDictionary *json = @{@"id":@1,
                               @"jsonrpc":@"2.0",
                               @"result":@{@"address":owner,
                                           @"balance":balanceText},
                               @"error":[NSNull null]};
        NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
        if (successBlock) {
            successBlock(data ?: [NSData data]);
        }
    } failure:failureBlock];
}

+ (void)getBalanceWithChain:(NSString *)chain address:(NSString *)address tokenSymbol:(NSString *)tokensymbol success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (chain == nil || address == nil || tokensymbol == nil) {
        if (failureBlock) {
            failureBlock(L(@"参数不能为空"));
        }
        return;
    }
    NSDictionary *params = @{@"cointype":chain,
                             @"address":address,
                             @"tokensymbol":tokensymbol};
    NSDictionary *param = @{@"id":@1,
                            @"jsonrpc":@"2.0",
                            @"method":@"Wallet.GetBalance",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

+ (void)queryTransactionByAddress:(NSString *)address coinType:(NSString *)coinType contractAddr:(NSString *)contractAddr index:(NSInteger)index count:(NSInteger)count direction:(NSInteger)direction type:(NSInteger)type success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (address == nil || coinType == nil) {
        if (failureBlock) {
            failureBlock(L(@"参数不能为空"));
        }
        return;
    }
    NSDictionary *params = @{@"cointype":coinType,
                             @"address":address,
                             @"contractAddr":contractAddr,
                             @"index":@(index),
                             @"count":@(count),
                             @"direction":@(direction),
                             @"type":@(type)};
    NSDictionary *param =  @{@"id":@1,
                             @"jsonrpc":@"2.0",
                             @"method":@"Wallet.QueryTransactionsByaddress",
                             @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

+ (void)queryTransactionByAddress:(NSString *)address coinType:(NSString *)coinType contractAddr:(NSString *)contractAddr tokenSymbol:(NSString *)tokenSymbol index:(NSInteger)index count:(NSInteger)count direction:(NSInteger)direction type:(NSInteger)type success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (address == nil || coinType == nil) {
        if (failureBlock) {
            failureBlock(L(@"参数不能为空"));
        }
        return;
    }
    NSMutableDictionary *params = [@{@"cointype":coinType,
                                     @"address":address,
                                     @"contractAddr":contractAddr ?: @"",
                                     @"index":@(index),
                                     @"count":@(count),
                                     @"direction":@(direction),
                                     @"type":@(type)} mutableCopy];
    // ⚠️ ETH 链的 `Wallet.QueryTransactionsByaddress` 会**忽略 contractAddr**，
    //    只认 `tokensymbol`；不传就会把合约币账单查成原生 ETH 的转账。
    //    主链币（coin_type == coin_chain，如 ETH）不能传，传了会被当成「同名代币」查不到。
    //    其它链（BNB/BTY）的 contractAddr 过滤本来就有效，保持不变，避免影响老链行为。
    if ([coinType isEqualToString:@"ETH"]
        && tokenSymbol.length > 0
        && ![tokenSymbol isEqualToString:coinType]) {
        params[@"tokensymbol"] = tokenSymbol;
    }
    NSDictionary *param =  @{@"id":@1,
                             @"jsonrpc":@"2.0",
                             @"method":@"Wallet.QueryTransactionsByaddress",
                             @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

#pragma mark - ETH 原生余额（公网 RPC）

/// 公网 ETH RPC 兜底池（与 `TokenChainConfig.ethereum.fallbackRPCs` 保持一致）
static NSArray<NSString *> *LGETHNativeBalanceEndpoints(void) {
    static NSArray<NSString *> *endpoints;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        endpoints = @[
            @"https://ethereum-rpc.publicnode.com",
            @"https://eth.drpc.org",
            @"https://eth-mainnet.public.blastapi.io",
        ];
    });
    return endpoints;
}

/// `0x...`（16 进制 wei）→ ETH 数量。手写累加，避免超过 2^63 时 `strtoull` 溢出。
static double LGETHFromHexWei(NSString *hexWei) {
    NSString *hex = hexWei;
    if ([hex hasPrefix:@"0x"] || [hex hasPrefix:@"0X"]) {
        hex = [hex substringFromIndex:2];
    }
    if (hex.length == 0) { return 0; }
    double value = 0;
    for (NSUInteger i = 0; i < hex.length; i++) {
        unichar c = [hex characterAtIndex:i];
        int digit = -1;
        if (c >= '0' && c <= '9') { digit = c - '0'; }
        else if (c >= 'a' && c <= 'f') { digit = c - 'a' + 10; }
        else if (c >= 'A' && c <= 'F') { digit = c - 'A' + 10; }
        if (digit < 0) { return 0; }
        value = value * 16.0 + (double)digit;
    }
    return value / 1e18;
}

+ (BOOL)getETHNativeBalanceSync:(NSString *)address balance:(double *)balance
{
    if (address.length == 0) { return NO; }
    // 内部是信号量等待，主线程调用会卡死 UI（调用方 `GoFunction goGetBalance:` 已保证后台线程）
    if ([NSThread isMainThread]) { return NO; }

    NSDictionary *body = @{@"jsonrpc":@"2.0",
                           @"id":@1,
                           @"method":@"eth_getBalance",
                           @"params":@[address, @"latest"]};
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (bodyData == nil) { return NO; }

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = 6;
    configuration.timeoutIntervalForResource = 8;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    for (NSString *endpoint in LGETHNativeBalanceEndpoints()) {
        NSURL *url = [NSURL URLWithString:endpoint];
        if (url == nil) { continue; }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = bodyData;

        // 🔴 session **必须每个 endpoint 单独建**！
        //    下面为了尽快释放连接会 `invalidateAndCancel`，而 session 一旦 invalidate 就永久失效：
        //    再用它 `dataTaskWithRequest:` 会让 CFNetwork 直接抛异常
        //    （`-[__NSURLSessionLocal taskForClassInfo:]` → SIGABRT）。
        //    原来 session 建在循环外 ⇒ 「第一个 RPC 失败、换下一个」时**必崩**，
        //    崩溃栈：`getETHNativeBalanceSync` ← `GoFunction goGetBalance:` ← `downRefresh`。
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block NSString *hexResult = nil;
        NSURLSessionDataTask *task = nil;
        @try {
            task = [session dataTaskWithRequest:request
                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error == nil && data.length > 0) {
                    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([json isKindOfClass:[NSDictionary class]]) {
                        id result = json[@"result"];
                        if ([result isKindOfClass:[NSString class]]) {
                            hexResult = result;
                        }
                    }
                }
                dispatch_semaphore_signal(semaphore);
            }];
        } @catch (NSException *exception) {
            // 兜底：哪怕 CFNetwork 因为别的原因（暂停/失效中的 session）抛异常，也只当这个节点失败
            NSLog(@"ETH 原生余额节点异常：%@ %@", endpoint, exception.reason);
        }
        if (task == nil) {
            [session invalidateAndCancel];
            continue;
        }
        [task resume];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)));
        [task cancel];
        [session invalidateAndCancel];

        if (hexResult.length > 0) {
            double eth = LGETHFromHexWei(hexResult);
            if (balance != NULL) { *balance = eth; }
            return YES;
        }
    }
    return NO;
}

+ (void)signwwrwaDataWithForm:(NSString *)from to:(NSString *)to amount:(double)amount fee:(double)fee coinType:(NSString *)coinType tokenSymbol:(NSString *)tokenSymbol tokenAddr:(NSString *)tokenAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (from == nil || to == nil || coinType == nil) {
        if (failureBlock) {
            failureBlock(L(@"参数不能为空"));
        }
        return;
    }
    NSDictionary *extend = @{@"token_addr": tokenAddr ?: @""};
    NSDictionary *transcation = @{@"from":from,
                                  @"to":to,
                                  @"amount":@(amount),
                                  @"fee":@(fee),
                                  @"extend":extend};
    NSDictionary *params = @{@"cointype":coinType,
                             @"tokensymbol":@"",
                             @"transaction":transcation};
    NSDictionary *param = @{@"id":@1,
                            @"method":@"Wallet.CreateRawTransaction",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}


+ (void)queryTranscationByTxid:(NSString *)txid coinType:(NSString *)coinType tokenSymbol:(NSString *)tokenSymbol success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    NSDictionary *params = @{@"cointype":coinType,
                             @"tokensymbol":tokenSymbol,
                             @"txid":txid};
    NSDictionary *param = @{@"id":@1,
                            @"method":@"Wallet.QueryTransactionByTxid",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
    
}

@end
