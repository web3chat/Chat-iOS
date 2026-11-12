//
//  WebViewMetaMaskCoordinator.h
//  MetaMask / EIP-1193（原 WebViewController #pragma mark - MetaMask）
//

#import <Foundation/Foundation.h>

@class WebViewController;
@class LocalCoin;

NS_ASSUME_NONNULL_BEGIN

/// 托管在 WebViewController 上的 MetaMask / EIP-1193 注入与 RPC 处理协调器。
@interface WebViewMetaMaskCoordinator : NSObject

/// 宿主 Web 容器，用于访问 WebView、链配置、回包给 JS 等。
@property (nonatomic, weak, readonly, nullable) WebViewController *host;

/// 使用宿主 VC 初始化协调器。
- (instancetype)initWithHost:(nonnull WebViewController *)host;

/// 生成在页面内触发 `connect` 与 `accountsChanged` 的 JS 片段（同步 chainId / networkVersion 后 emit）。
- (NSString *)tanxinJsForEmitConnectAndAccountsChanged:(NSArray *)accounts;
/// 在 WebView 中执行上述 emit JS，完成后调用 completion（可为 nil，直接返回）。
- (void)tanxinEvaluateEmitConnectAndAccountsChanged:(NSArray *)accounts completion:(void (^ _Nullable)(void))completion;
/// `eth_requestAccounts` 两步投递：先 emit 事件，间隔后再把账户数组 resolve 给 DApp（兼容 Revoke.cash 等依赖事件顺序的场景）。
- (void)deliverEthRequestAccountsTwoStep:(nullable NSString *)requestId accounts:(NSArray *)accounts method:(nullable NSString *)method;
/// 解析当前选中链下的钱包地址（0x 格式），供 `eth_requestAccounts` / 权限等使用。
- (nullable NSString *)addressForEthRequestAccounts;
/// 处理 `eth_requestAccounts` / `eth_accounts`：校验地址、按方法决定延迟与两步投递，并通过 `sendResponseToJS` 回包。
- (void)handleEthRequestAccounts:(nullable NSString *)requestId method:(nullable NSString *)method;
/// 处理 `eth_chainId`：返回小写十六进制链 ID，带短延迟后回包。
- (void)handleEthChainId:(nullable NSString *)requestId method:(nullable NSString *)method;
/// 通用 JSON-RPC 透传：将请求发到当前选中 RPC（如 eth_getBalance、eth_gasPrice、eth_blockNumber 等），结果写回 JS。
- (void)handleGenericRpc:(nullable NSString *)requestId method:(nullable NSString *)method params:(nullable NSArray *)params;
/// 处理 `net_version`：返回当前链 ID 的十进制字符串。
- (void)handleNetVersion:(nullable NSString *)requestId method:(nullable NSString *)method;
/// 查询当前选中链对应的 `LocalCoin`（数据库）。
- (nullable LocalCoin *)localCoinForSelectedChain;
/// 处理 `personal_sign`：解析十六进制消息、展示签名确认 Sheet，用户确认后签名并回包。
- (void)handlePersonalSign:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// 处理 `eth_sign`（EIP-1193 参数顺序 `[address, data]`）：**已禁用**，直接回错误给 dApp。
/// 原因：eth_sign 签的是任意 32 字节哈希，可被构造成一笔转账交易的哈希；
/// 且旧实现把参数转成 personal_sign 后签名（EIP-191 前缀），对 eth_sign 请求方而言签名本身就是错的。
- (void)handleEthSign:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// 处理旧版 `eth_signTypedData`，参数与 v4 一致时转交 `handleEthSignTypedData_v4`。
- (void)handleEthSignTypedData:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// 将十六进制字符串转为可读 UTF-8 文本（用于 personal_sign 展示）。
- (NSString *)stringFromHexString:(NSString *)hexString;
/// 处理 `eth_sendTransaction`：解析首参交易对象，弹出支付确认 Sheet（`showAlert`）。
- (void)handleEthSendTransaction:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;

/// 判断 calldata 是否为 ERC-20 `approve(address,uint256)`（函数选择器 0x095ea7b3）。
- (BOOL)tanxinIsERC20ApproveCalldata:(NSString *)dataHex;
/// 将地址统一为 `0x` + 40 位小写 hex，便于与 DApp / 库内币种比对。
- (NSString *)tanxinNormalizedHexAddress:(nullable id)addrOrNil;
/// 从交易对象解析十进制链 ID（EIP-155）；无 `chainId` 时用当前宿主选中链 ID。
- (NSInteger)tanxinResolvedChainNumericIdFromTxObj:(NSDictionary *)obj;
/// 将交易中的链 ID 映射为钱包 `coin_chain` 键（如 1→ETH、56→BNB）；缺省为当前选中链。
- (NSString *)tanxinResolvedCoinChainKeyFromTxObj:(NSDictionary *)obj;
/// 解析用于弹窗展示的网络名称（主网名或当前链名）。
- (NSString *)tanxinResolvedChainDisplayNameFromTxObj:(NSDictionary *)obj;
/// 在币种列表中按合约地址（NFT 类型代币的 `coin_pubkey`）匹配 `LocalCoin`。
- (nullable LocalCoin *)tanxinLocalCoinForContractAddress:(NSString *)contractAddr inCoins:(NSArray *)coinArray coinChain:(NSString *)coinChain;
/// 未添加对应合约代币时：向 JS 报错、弹出提示并可复制合约地址（支持 `executeCallback` 路径）。
- (void)tanxinPresentMissingContractTokenAlertWithContractAddress:(NSString *)contractAddress
                                                 chainDisplayName:(NSString *)chainDisplayName
                                                        requestId:(nullable NSString *)requestId
                                                           method:(nullable NSString *)method
                                                       callbackId:(NSInteger)callbackId
                                               useExecuteCallback:(BOOL)useExecuteCallback;
/// 从交易与解析结果取用于钱包匹配的合约地址：swap 优先 `swap_token_in`；DEX Router 方法勿回退用交易 `to`（路由地址）。
- (NSString *)tanxinTokenContractAddressForDisplayAndCoinMatch:(NSDictionary *)obj parsed:(NSDictionary *)dataDict;
/// 取交易对象的 `to` 字段字符串（DApp 传入的合约 / Router 地址）。
- (NSString *)tanxinTxToAddressString:(NSDictionary *)obj;
/// 校验 `data` 非空后返回十六进制字符串，空则返回 nil（不写 extend）。
- (nullable NSString *)tanxinNonEmptyDataHexForExtend:(nullable id)dataRaw;
/// 将十六进制 calldata 转为 JSON 数字字节数组，供构造 raw 交易的 `input`。
- (NSArray<NSNumber *> *)tanxinJsonByteArrayFromHexDataString:(NSString *)hexString;
/// 将 `CreateRawTransaction` 返回的 result 转为签名用 JSON 字符串；必要时用本地 calldata 覆盖 `input`。
- (nullable NSString *)tanxinCreateRawResultJsonStringForSignFromParsedResponse:(NSDictionary *)resultJsonData
                                                           extendDataHex:(NSString *)extendDataHex
                                                      shouldPatchInput:(BOOL)shouldPatchInput;
/// 从 ETHInputParser 结果中提取对手方地址、数量等（approve / transfer / swap 等分支）。
- (NSDictionary *)tanxinErc20PeerAndAmountFromParseResult:(NSDictionary *)dataDict;
/// 计算签名用的 gasPrice（wei 十进制字符串）：优先 Sheet 所选 Gwei，其次交易字段与 `host.gasPrice`。
- (NSString *)tanxinWeiStringGasPriceForSignTx:(NSDictionary *)obj selectedSheetGasPrice:(nullable NSString *)selectedGasPrice;
/// 使用私钥对本地组装的 raw 交易签名并 `eth_sendRawTransaction` 广播（用于 approve 等需链上 data 的路径）。
- (void)tanxinSignAndBroadcastRawEthTransactionWithPrikey:(NSString *)prikey
                                                        obj:(NSDictionary *)obj
                                                selectedGas:(nullable NSString *)selectedGas
                                           selectedGasPrice:(nullable NSString *)selectedGasPrice
                                     enforceApproveMinGas:(BOOL)enforceApproveMinGas
                                                 completion:(void (^ _Nullable)(NSString * _Nullable txHash, NSDictionary * _Nullable rpcJsError, NSString * _Nullable signFailToast))completion;

/// 解析交易并展示 `DappAlertSheetView` 支付确认；用户确认后派生私钥并调用 `metaMaskEthSendTransaction`。
- (void)showAlert:(NSDictionary *)obj requestId:(nullable NSString *)requestId method:(nullable NSString *)method;
/// 在用户输入密码并选择 gas 后执行实际广播：approve 走 raw 签名，其余走 `CreateRawTransaction` / `eth_sendRawTransaction` 等分支。
- (void)metaMaskEthSendTransaction:(NSString *)prikey
                               obj:(NSDictionary *)obj
                         requestId:(nullable NSString *)requestId
                               gas:(nullable NSString *)selectedGas
                          gasPrice:(nullable NSString *)selectedGasPrice
                            method:(nullable NSString *)method;

/// 处理 `eth_signTypedData_v4`：展示 EIP-712 摘要 Alert，确认或拒绝后回包（当前签名为占位实现）。
- (void)handleEthSignTypedDataV4:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// 解析 `eth_call` 中 transaction 的 `from`：缺省时用当前链钱包地址。
- (NSString *)resolvedEthCallFromAddress:(nullable id)fromValue;
/// 主线程延迟后再 `sendResponseToJS`，缓解 eth_call 与页面回调注册的竞态。
- (void)tanxinSendEthCallJsResponseDelayed:(nullable NSString *)requestId result:(nullable id)result error:(nullable id)error method:(nullable NSString *)method;
/// 处理 `eth_call`：将任务派到后台执行 `tanxinProcessEthCallItem`。
- (void)handleEthCall:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// 组装 JSON-RPC `eth_call` 请求，经 `web3ProviderHandler` 发往 RPC，规范化结果后延迟回包。
- (void)tanxinProcessEthCallItem:(NSDictionary *)item;
/// 将 App 内选中网络、RPC、链名等切换到指定 `chainId`（十六进制，如 0x38）。
- (void)applySwitchToChainId:(NSString *)targetChainId;
/// 处理 `wallet_getPermissions`：返回当前已授予的 `eth_accounts` 能力描述或空数组。
- (void)handleWalletGetPermissions:(nullable NSString *)requestId method:(nullable NSString *)method;
/// 处理 `wallet_requestPermissions`：有地址则授予 `eth_accounts` 能力并回包，否则报错。
- (void)handleWalletRequestPermissions:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// 处理 `web3_clientVersion`：返回带 App 版本号的客户端标识字符串。
- (void)handleWeb3ClientVersion:(nullable NSString *)requestId method:(nullable NSString *)method;
/// EIP-3085 `wallet_addEthereumChain`：校验参数、对支持的网络弹窗确认后切换并通知链变更。
- (void)handleWalletAddEthereumChain:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// `wallet_switchEthereumChain`：已在此链则直接回包并通知；否则弹窗确认后切换网络。
- (void)handleSwitchEthereumChain:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;
/// 处理 `eth_estimateGas`：补全 `from` 后向节点请求估算 gas，失败时回传错误。
- (void)handleEthEstimateGas:(nullable NSString *)requestId params:(nullable NSArray *)params method:(nullable NSString *)method;

/// 将 `eth_call` 返回的 result 规范为带 `0x` 前缀的小写十六进制字符串。
- (nullable NSString *)tanxinNormalizeEthCallResult:(nullable id)raw;

@end

NS_ASSUME_NONNULL_END
