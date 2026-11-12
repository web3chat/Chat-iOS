# 待编写...
# Chat
- Glass中的Main存放各个模块。包括首页、聊天、商城、账户。
- Network封装网络请求，配置接口以及参数。ServerContext中切换测试环境和生产环境。
- Base中配置基础VC，统一处理。
- Tools中封装各个模块中用到的工具及View。
- LanuchSettings处理app加载时页面的切换(已弃用)。app加载页面切换挪到ChatUIMediator的中。参考

```
func enterMain(showLogin: Bool = false)

```
- Singleton单例，APPContext保存app运行时的信息。

## 参考 App

- TestFlight 体验（参考版本）：<https://testflight.apple.com/join/eTPe37rR>

## 代码编辑规则

- 创建VC的时候，需遵守协议ViewControllerProtocol，比如

```
class SquareVC: UIViewController, ViewControllerProtocol {

}

```
- 改造首页，如果用原来的首页，为SquareVC；

```
static let getUserInfo = WebViewScriptFunction(name: "getUserInfo")

```
- 登录的检查及调用在LoginManager中封装。全局搜索LoginManager查看调用示例。
- 图片、音频的上传参考GMOSSManager。其中buket分开，OSS_Chat_Buket存放聊天相关内容，OSS_Data_Buket存放除聊天以外的内容，OSS_Auth_Buket存放实名认证的内容。
- 登录模块不要随意改动，改动要通知全员Review。
- 聊天模块不要随意改动，改动要通知全员Review。
- 钱包模块不要随意改动，改动要通知全员Review。
- 不要乱发通知，用代理，block，信号订阅基本上能代替通知。

##  手动修复pods bug

- 手动修复Bug libwebp 文件夹前往到 /Users/***/.cocoapods/repos/master/Specs/1/9/2/libwebp 修改libwebp.podspec.json line 12 git地址 原文：https://chromium.googlesource.com/webm/libwebp 改为：https://github.com/webmproject/libwebp.git

- 手动修复Bug WCDB -> WCDBTokenize.swift line 165
[https://github.com/Tencent/wcdb/issues/367](https://github.com/Tencent/wcdb/issues/367)

- 手动修复Bug WCDB -> final class TimedQueue<Key: Hashable> line 45, 56
**list.remove(at: map[index].value)**
**增加 if map[index].value < list.count && map[index].value > 0 {} 判断**

##  代码注意事项
- 用rx监听自身属性的时候用observeWeakly，避免内存无法释放。

```
self.rx
    .observeWeakly(String.self, "title")
    .subscribe(onNext: { [weak self] (x) in
        guard let title = x else {return}
        guard let wself = self else {return}
        wself.delegate?.webView?(wself, setTitle: title)
}).disposed(by: disposeBag)

```

- 导航栏适配iOS 15（导航栏变黑问题）。

```
//适配iOS15Navigationbar背景色
    func setNavigataionBar(barColor: UIColor = UIColor.white, titleColor: UIColor = UIColor.black) {
        if #available(iOS 13.0, *) {//  standardAppearance 这个api其实是 13以上就可以使用的 ，这里可以写 15 其实主要是iOS15上出现的这个死样子
            let app = UINavigationBarAppearance()//
            app.configureWithOpaqueBackground() // 重置背景和阴影颜色
            app.titleTextAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18),
                NSAttributedString.Key.foregroundColor: titleColor
            ]
            app.backgroundColor = barColor // 设置导航栏背景色
            app.shadowColor = .clear
            app.backgroundEffect = nil
            self.navigationController?.navigationBar.scrollEdgeAppearance = app // 带scroll滑动的页面
            self.navigationController?.navigationBar.standardAppearance = app // 常规页面。描述导航栏以标准高度
        } else {
            self.navigationController?.navigationBar.barTintColor = barColor //Colors.baseColor
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: titleColor]
        }
    }
```

## 用户名显示规则
* user、member、staffinfo的contactname
- 普通用户详情页： 备注>昵称>地址(显示前后各四位)
- 从群进入用户详情页： 备注>群昵称>昵称>地址(显示前后各四位)
- 列表显示： 备注>团队姓名>昵称>地址(显示前后各四位)

## 本地保存文件
文件类型消息：
- 自己发的文件保存在路径Documents/File/“cacheKey”；
- 接收到的文件url下载后转存到路径Documents/File/“cacheKey”；

语音类型消息：
- 播放的语音是wav格式；
- 录制的是wav格式，转为amr格式上传；
- 接收到的url下载后格式为amr，需转为wav格式保存；
- amr保存的路径为“Documents/Voice/AmrFile/20220128111053258.amr”；
- wav保存的路径为“Documents/Voice/WavFile/20220128111053258.wav”；

## 打包报错可能原因
- pod的所有库的target改为12；

## .proto 生成swift文件
- Cd 到当前目录下，然后执行下面的命令，其中msg.proto为文件名
protoc msg.proto --swift_out="./"


## 服务器地址配置

> 代码中所有自有服务器地址默认都是空字符串（`""`）。首次部署 / 联调前必须按下表补齐；
> 未配置时相关功能会直接请求失败（属预期行为，不会因空 URL 崩溃）。

### 业务服务端

| 配置项 | 代码位置 | 需要的功能 | 说明 / 示例 |
| --- | --- | --- | --- |
| `BackupURL` | `chat/BusinessTool/Network/SeverContext.swift` | 中心化服务主域名 | 登录/验证码、好友、群组、系统配置、备份/账号绑定、OSS Token；`TokenAPI` / `SystemAPI` / `CodeAPI` / `DiscoveryAPI` / `BackupAPI` / `GroupAPI` / `XLSTargetType` 的默认 baseURL。示例：`https://chat.example.com` |
| `TeamH5Url` | 同上 | 组织架构 H5 | 创建/加入团队、团队入口、团队管理、成员选择（派生 `TeamCreateURL` 等）。示例：`https://example.com/oa` |
| `OKRH5Url` | 同上 | OKR H5 | OKR 页面。示例：`https://example.com/okr` |
| `VoiceRoomBaseURL` | 同上 | 语音房 H5 | `POST /api/v1/room/create` 建房并拼接进房链接；可被 `VoiceRoomSiteURL`（UserDefaults / Info.plist）覆盖。示例：`https://voice.example.com` |
| `APP_URL` | 同上 | 分享 / 邀请下载页 | 加好友等分享，派生 `APP_DOWNLOAD_URL` / `ShareURL`，需与 Android 端一致。示例：`https://example.com` |
| `USER_SERVER_AGREEMENT_URL` | 同上 | 用户服务协议 | 注册/登录页协议入口。示例：`https://example.com/license` |
| `SquareBaseURL` | 同上 | 广场（Square）后端 | 广场信息流、发布、评论、点赞等 `/square/*` 接口。示例：`https://example.com` |
| `ScanLoginBaseURL` | 同上 | PC 网页版扫码登录 | `/app/qr-login/*` 的 confirm / cancel。示例：`https://qr.example.com` |
| `WalletURL` | `chat/Views/MyDao/OCDepend/Depend.h` | 钱包后端 | 币种搜索、资产/交易记录、行情、探索 Banner、推荐币种、手续费推荐等 `/interface/*`、`/goapi/*` |
| `GoNodeUrl` | 同上 | 区块链 Go 节点 | Walletapi SDK `setNode`，签名/广播/查询 |
| `SLGNFTURL` | 同上 | NFT 服务 | `PWNFTRequest` 的 NFT 列表/详情 |
| `UPDATEJSON` | 同上 | App 版本更新 | 版本更新提示 JSON 地址 |
| `S1BackUpAPI.baseURL` | `chat/BusinessTool/Network/API/S1BackUpAPI.swift` | 手机号备份 / 账号绑定 | 验证码、分片密钥备份/恢复/重置/注销、手机号/微信/小红书/抖音绑定与查询 |
| `PWAlertController` 手续费推荐 | `chat/Views/MyDao/Tool/PWAlertController.m` | 矿工费推荐 | `/goapi/interface/fees/recommended` |
| `SquarePostShareCard.downloadLink` | `chat/Square/V/SquarePostShareCard.swift` | 分享卡片下载页 | 分享卡片底部下载链接 |
| `AICustomerConfig.defaultSiteURLString` | `chat/AI/M/AICustomerModels.swift` | AI 智能客服 H5 | 可被 `AICustomerServiceSiteURL`（UserDefaults / Info.plist）覆盖 |

### 服务端下发的地址（无需硬编码）

| 配置项 | 说明 |
| --- | --- |
| `TeamOAServerUrl` | 企业 OA 服务器，登录后由服务端下发；默认空字符串 |
| `WalletServerUrl` | 钱包服务器，登录后由服务端下发；默认空字符串 |
| `IMChatServerInUse` | 当前 IM 聊天服务器，来自服务端服务器列表 / 用户选择 |
| `BlockchainServerInUse` | 当前区块链 Go 节点，来自服务端节点列表 / 用户选择 |
| `OfficialChatServers` / `OfficialBlockchainServers` | 官方服务器列表；发现接口失败时的兜底地址已置空 |

### 说明

- 派生地址（`TeamCreateURL`、`BackUpOSSURL`、`OSS_AUTH_SERVER`、`OBS_AUTH_SERVER`、`APP_DOWNLOAD_URL` 等）都由上表主域名拼接；主域名为空时派生地址不完整。
- 链上 RPC / 区块浏览器（`mainnet.bityuan.com`、`etherscan.io`、`bscscan.com`、`publicnode` 等）以及只读第三方 API（GoPlus、GeckoTerminal、Blockscout、DApp 站点）不属于自有服务器，保持原值。
- 服务器地址为空时，`baseURL` 回退到 `UNCONFIGURED_SERVER_URL`（`URL(fileURLWithPath: "")`），请求失败但不会崩溃。

## 第三方配置需求

> 第三方密钥/凭证默认都是空字符串（`""`），需自行申请后填入；未配置时对应能力不可用。

| 第三方服务 | 配置项 | 代码位置 | 需要的功能 | 不配置的后果 |
| --- | --- | --- | --- | --- |
| 友盟+（UMeng） | `UMAPPKEY` | `chat/BusinessTool/Network/SeverContext.swift` | 推送（U-Push）与统计初始化 | 收不到推送、统计数据缺失 |
| 腾讯 Bugly | `BUGLYID` | 同上 | 崩溃上报 | 无崩溃数据 |
| 华为云 OBS | `OBS_Access_Key` / `OBS_Access_Secret` | 同上 | 备用对象存储上传（**当前未使用**，见下方说明） | — |
| 华为云 OBS | `OBS_EDN_POINT` / `OBS_BUCKET_NAME` | 同上 | OBS 服务地址与桶名（非密钥，保持默认；**当前未使用**） | — |
| 阿里云 OSS | `OSS_End_Point` / `OSS_Buket` | 同上 | 图片/语音/文件存储地址与桶名（非密钥，保持默认）；**上传未使用**，endpoint/bucket 仍用于广场图片 URL 拼接（见下方说明） | — |
| Walletapi SDK | `APPKEY` | `chat/Views/MyDao/OCDepend/Depend.h` | `WalletapiSetAppKey`，生成本地钱包会话 SessionId | 钱包 SDK 初始化失败 |
| 代扣 / 免手续费交易 | `BlockchainPriKey` | `chat/BusinessTool/Network/SeverContext.swift` | 代扣地址私钥（`createNoBalanceTransaction`） | 代扣/免手续费交易不可用；⚠️ 生产环境应由服务端保管，勿提交真实私钥 |
| Apple App Store | `APPSTORE_DOWNLOAD_URL` | 同上 | 应用下载地址 | 分享/更新跳转失效（保持现有值即可） |
| Apple TestFlight | `TESTFLIGHT_DOWNLOAD_URL` | 同上 | 分享邀请页的 TestFlight 参与链接 | TestFlight 邀请失效（保持现有值即可） |
| Apple Push（APNs） | `aps-environment`（Xcode Signing & Capabilities） | `chat/chat.entitlements` | 远程推送（与友盟 U-Push 配合） | 收不到远程推送；需在 Apple Developer 配置 App ID 的 Push Notifications 与证书/Key |
| Mixpanel | `Mixpanel-swift`（Podfile） | — | 埋点（当前代码未使用） | 无影响 |
| 蒲公英 / Fir | `shell.sh` 中的 `_api_key`（已注释） | `shell.sh` | 内测分发上传 | 内测上传不可用 |

### 云存储代码使用情况（阿里云 OSS / 华为云 OBS）

> 结论：当前版本**没有使用**阿里云 OSS / 华为云 OBS 的上传能力；华为云 OBS 代码完全未调用，阿里云 OSS 仅保留启动初始化和广场图片 URL 拼接。

| 云服务 | 代码位置 | 使用情况 |
| --- | --- | --- |
| 阿里云 OSS | `chat/BusinessTool/Network/OSS.swift`、`chat/ProjectBase/OSSClient/IMOSSClient.swift` | `OSS.launchClient()` 在 App 启动时调用，会尝试通过 `TokenAPI.OSSToken` 获取 STS；但 `uploadImage` / `uploadVoice` / `uploadFile` / `download` 的业务调用点均已注释或不存在。`IMOSSClient` 无任何调用。`OSS_End_Point` / `OSS_Buket` 仍被 `SquareModels` 用于拼接广场图片公共地址。 |
| 华为云 OBS | `chat/BusinessTool/Network/OBS.swift` | 类定义与 `OBS.framework` 仍在工程中，但没有任何 `OBS.shared()` / `OBS.launchClient()` 调用，上传/下载方法也未被使用；`TokenAPI.OBSToken` 不会实际触发，`OBS_AUTH_SERVER` / `OBS_Access_Key` / `OBS_Access_Secret` 也无有效引用。 |

- 因此 `OBS_Access_Key` / `OBS_Access_Secret` 目前无需填写；即使填写也不会生效。
- 如需彻底清理，可删除 `OSS.swift`、`OBS.swift`、`IMOSSClient.swift`、`OBS.framework` 及 `AliyunOSSiOS` Pod，并移除相应的 `OSS_*` / `OBS_*` 常量。
- 注意：`OSS_End_Point` / `OSS_Buket` 仍用于广场图片 URL 拼接，清理前需确认服务端返回的图片地址形态。

### 建议一并迁移的接口凭证

| 配置项 | 代码位置 | 用途 |
| --- | --- | --- |
| `X-App-Token` | `chat/BusinessTool/Network/XLSTargetType.swift` | 服务端接口鉴权请求头 |
| `DESKeyForGame` / `DESKey` | `chat/Views/MyDao/C/web3/WebViewController.m`、`chat/Views/MyDao/C/TransferViewController.m` | 钱包相关请求参数 DES 加密 |
