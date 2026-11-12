# 谈信 App 功能与接口文档

> 自动梳理自当前工作区分支（`谈信翻译版本`）的代码，仅描述**代码中真实存在**的实现。
> 标注：`[S]` = Swift，`[OC]` = Objective-C。路径均相对仓库根目录。
> 本文档为「现状快照」，不含需求设计；接口以代码里的 path / method / 参数为准。

---

## 目录

- [一、项目概览](#一项目概览)
- [二、App 功能地图](#二app-功能地图)
  - [2.1 根结构与 5 个 Tab](#21-根结构与-5-个-tab)
  - [2.2 功能总开关](#22-功能总开关)
  - [2.3 聊天模块](#23-聊天模块)
  - [2.4 消息会话列表（消息 Tab）](#24-消息会话列表消息-tab)
  - [2.5 通讯录](#25-通讯录)
  - [2.6 广场](#26-广场)
  - [2.7 钱包 / 资产 / 链 / DApp](#27-钱包--资产--链--dapp)
  - [2.8 发现 Tab](#28-发现-tab)
  - [2.9 我的 / 设置](#29-我的--设置)
  - [2.10 登录与账号体系](#210-登录与账号体系)
  - [2.11 AI 客服（H5 免登录）](#211-ai-客服h5-免登录)
  - [2.12 基础能力](#212-基础能力)
- [三、接口文档](#三接口文档)
  - [3.1 网络层架构与公共约定](#31-网络层架构与公共约定)
  - [3.2 服务地址总表](#32-服务地址总表)
  - [3.3 REST 接口明细](#33-rest-接口明细)
  - [3.4 钱包服务（Objective-C）接口](#34-钱包服务objective-c接口)
  - [3.5 文件上传（OSS / OBS）](#35-文件上传oss--obs)
  - [3.6 长连接（Socket）协议](#36-长连接socket协议)
- [四、数据存储](#四数据存储)
- [五、已知缺口与注意事项](#五已知缺口与注意事项)

---

## 一、项目概览

| 项 | 值 |
|---|---|
| App 名称 | 谈信（TanXin），`APPNAME = L("谈信民众版")` |
| AppID | `dtalk` |
| 平台 | iOS（UIKit，无 SwiftUI） |
| 最低版本 | iOS 15.0 |
| 语言 | Swift + Objective-C 混编（钱包模块主体是 OC，通过 `chat/chat-Bridging-Header.h` 桥接） |
| 构建 | CocoaPods（`Podfile`）+ Xcode，`use_frameworks!` |
| 网络 | Moya + 自定义 `XLSTargetType`（HTTP/JSON）；Starscream（WebSocket） |
| 存储 | WCDB.swift（消息/会话/用户/群/员工）+ FTS 全文搜索库；Keychain（密钥/密码） |
| 路由 | `FZMUIMediator`（`chat/BusinessTool/UIManager/FZMUIMediator.swift`） |
| 实时 | `MultipleSocketManager`（多聊天服务器长连接，心跳 + 重连退避） |
| 加密 | 自研应用层 E2E（私聊 ECDH 会话密钥、群聊群密钥 AES）+ Go 桥 `Walletapi.framework` |
| 主要依赖 | Moya / Alamofire / RxSwift / WCDB.swift / Starscream / SnapKit / MJRefresh / Kingfisher / SDWebImage / web3swift / BigInt / CryptoSwift / KeychainAccess / Mixpanel / Bugly / UMeng Push / AliyunOSSiOS |

---

## 二、App 功能地图

### 2.1 根结构与 5 个 Tab

装配位置：`chat/AppDelegate/AppDelegate+UI.swift` → `getRootVC()`，导航栈由 `FZMUIMediator.getXxxNavigationController()` 提供。

| # | Tab | 根页面 | 语言 | 文件 |
|---|---|---|---|---|
| 0 | 消息 | `SessionVC` | [S] | `chat/Views/Session/C/SessionVC.swift` |
| 1 | 通讯录 | `FriendListVC` | [S] | `chat/Views/Contacts/C/FriendListVC.swift` |
| 2 | 发现 | `ExploreSearchViewController` | [OC] | `chat/Views/MyDao/C/web3/ExploreSearchViewController.m` |
| 3 | 资产 | `PWNewsHomeViewController` | [OC] | `chat/Views/MyDao/C/PWNewsHomeViewController.m` |
| 4 | 我的 | `MineVC` | [S] | `chat/Views/Mine/C/MineVC.swift` |

Tab 容器：`chat/ProjectBase/Base/FZMTabBarController.swift`
- 再次点击当前 Tab → 回到顶部（`FZMTabBarReselectHandler` 协议，`SessionVC` 实现）。
- Tab 栏中间的 AI 客服入口 → `AICustomerLauncher.push(...)`（`FZMTabBarController.swift:57-62`）。

启动流程：`AppDelegate` → 初始化 GKNavigationBar / IQKeyboardManager / 数据库 / Socket → `AppDelegate+UI.getRootVC()`。
登录态判定：有历史账号 → `UserLoginVC`，否则 → `ChooseAccountVC`。
核心单例（`AppDelegate+Launch`）：`APP.shared()` / `DBManager.shared()` / `SessionManager.shared()` / `UserManager.shared()` / `GroupManager.shared()` / `TeamManager.shared()` / `MultipleSocketManager.shared()` / `LoginUser.shared()`。

### 2.2 功能总开关

位置：`chat/BusinessTool/Common/CommonTools.swift`（该文件同时集中定义所有 `FZM_Notify_*` 通知名）。

| 常量 | 默认值 | 含义 |
|---|---|---|
| `FZM_EnableChatDeleteFeature` | `false` | 聊天记录删除新功能（定时删除 + 双方同步删除），入口全关 |
| `FZM_EnableMultiLanguage` | `true` | 设置中心「多语言」入口 |
| `FZM_EnableBiometricUnlock` | `true` | 面容/指纹替代密聊密码 |
| `FZM_EnableEnterpriseFeature` | `false` | 企业号 / 团队 / 员工总开关（关闭后团队 UI 隐藏、`TeamAPI` 请求不发） |

### 2.3 聊天模块

代码位置：`chat/ChatView/`（C=控制器 / M=模型 / V=视图 / VM=虚拟机 / P=协议 / Layout=布局计算 / Audio=语音 / RedBag=红包）。

#### 支持的消息类型

协议定义：`chat/BusinessTool/Proto/msg.proto` → `enum MsgType`
Swift 映射：`chat/ChatView/M/Message+MsgType.swift`；展示层：`chat/ChatView/M/MessageKind.swift`

| MsgType | 值 | 客户端支持 | Cell / 处理器 |
|---|---|---|---|
| System | 0 | ✅ | `SystemMessageCell` |
| Text | 1 | ✅ | `TextMessageCell` |
| Audio | 2 | ✅ | `AudioMessageCell` + `AudioMessageManager` |
| Image | 3 | ✅ | `MediaMessageCell` |
| Video | 4 | ✅ | `MediaMessageCell` |
| File | 5 | ✅ | `FileMessageCell` / `MineFileMessageCell` |
| Card | 6 | ❌（客户端忽略，服务端自用） | — |
| Notification | 7 | ✅ | `SystemMessageCell`（群内灰色通知）+ `Message+AlertMsgType.swift` |
| Forward | 8 | ✅ | 合并转发卡片 + `FZMForwardBar` |
| RTCCall | 9 | ⚠️ 枚举存在 | 语音/视频通话未启用（语音房走 H5，见本节「消息内链接与 App 内嵌浏览器」） |
| Transfer | 10 | ✅ | `TransferMessageCell` |
| Collect | 11 | ⚠️ 已注释 | — |
| RedPacket | 12 | ✅ | `RedPacketMessageCell` |
| ContactCard | 13 | ✅ | `ContactCardMessageCell` |

> ⚠️ **没有独立的「位置消息」类型**（全仓只有 `CoreLocation` 系统扩展）。

#### 会话 / 通道类型
- 协议只有 **私聊 = 0 / 群聊 = 1**（`chat/ChatView/M/Message+ChannelType.swift`）。
- 「官方号」不属于会话类型，走广场模块；AI 客服是会话列表里的**虚拟行「小Y」**（不写库）。

#### 聊天页与输入区
| 功能 | 关键类 / 文件 |
|---|---|
| 聊天主页面 | `ChatVC`（`chat/ChatView/C/ChatVC.swift`，约 4000 行）+ 基类 `MessageVC` |
| 输入条 / 表情 / 更多面板 | `InputBarView`、`ChatInputBarView`、`InputBarView+Keyboard`、`FZMMoreItemBar`、`CustomEmojiView.m` [OC] |
| 语音房（发起） | 「+」面板第 2 行第 3 格（项名「语音聊天」，2026-10-16 由「视频聊天」改名）→ `ChatVC.sendVoiceRoom()` → 弹模式选择（见本节「语音房」） |
| 录音与语音播放 | `AudioMessageManager`、`VoiceMessagePlayerManager`、`IMRecordTipHub` |
| 媒体选择 | `PHPicker.swift`（`SystemMediaPicker` / `VideoThumbnailLoader`） |
| 消息下载 | `FZMMessageBaseVM`、`DownloadManager`、`MultipleDownloadManager` |

#### 消息操作
| 功能 | 实现 |
|---|---|
| 撤回 | `ChatManager.revoke(message:chatServerUrl:)` / `handleRevokeInDB` / `setRevokeObserver()`（`ChatManager.swift:758-833`）；信令 `PbMsg_ActionRevoke` |
| 撤回后「重新编辑」 | `ChatVC.reEditRevokedMsg` + `InputBarView`（原文存 `Message.MsgType.revokedContent`） |
| 删除（本地 / 多端同步） | `ChatHistoryAPI`（`chat/ChatView/ChatHistoryAPI.swift`）、`ChatManager.delete(messsages:)` / `deleteSessionMsgs` / `handleDeleteMessagesInDB` |
| 定时 / 自动删除 | `chat/ChatView/ChatManager+AutoDelete.swift`（受 `FZM_EnableChatDeleteFeature` 控制） |
| 转发（逐条 / 合并） | `FZMForwardBar` + `ChoiceContactCardVC`；暂存待发图 `ChatManager.setPendingShareImage/consumePendingShareImage` |
| 多选 | `ChatVC.showSelect` + `FZMForwardBar` |
| @提醒 | `TextMsg.mention`（proto）/ `Message.mentionIds`；选人页 `FZMAtPeopleVC` |
| 消息引用 | `Message+Reference.swift`（`Reference{ref,topic}`）；UI `ChatVC.referenceMsg` |
| 发送状态 / 送达回执 | `Message+Status.swift`（`delivered=3` 对方已接收）；信令 `ActionType.Received` |
| 语音未读 → 已读 | `VoiceMessagePlayerManager.swift:77-88`、`ChatManager.update(mes:isRead:)` |

#### 加解密与安全
| 能力 | 实现 |
|---|---|
| 消息 / 文件加解密 | `chat/ChatView/ChatManager+Encryption.swift`：`encryptMsgData` / `decryptMsgData` / `encryptUploadData` / `decryptUploadData`，密文标志 `$ENC$` |
| 密钥策略 | 私聊：**对端公钥 + ECDH 会话密钥**；群聊：**群密钥 AES** |
| 算法实现 | `chat/BusinessTool/Encrypt/EncryptManager.swift`：`generateDHSessionKey` / `encryptSymmetric` / `encryptGroupName` / `sign` / `publicKeyToAddress`，底层 Go 桥 `chat/ThirdParty/Walletapi.framework` |
| 助记词 / 分片 | `chat/BusinessTool/Encrypt/SeedManager.swift`（`createSeed` / `spliteMnemonic` / `recoverMnemonic`，分片 S2 存 Keychain） |
| 密码 / 生物识别 | `chat/BusinessTool/Security/`：`WalletPrivateKeyStore`、`BiometricAuthManager`、`BiometricPasswordStore`、`ChatPasswordGate` |
| 传输 | HTTPS + WSS（**未见自定义 TLS 层**，加密为应用层自研，非 Signal 协议） |

#### 聊天内红包 / 转账 / 名片
- 红包：`chat/ChatView/RedBag/`（发 `FZMCreateLuckyBagVC`、开/详情 `FZMRedBagInfoVC`、记录 `FZMRedBagRecordVC`、专属红包 `FZMExclusiveRedBagMemberVC`、链上交互 `Extesion/RedPacketWeb3Integration.swift`、合约文档 `README_RedPacketContract.md`）
- 转账：`ChatVC.swift:2099` → [OC] `chat/Views/MyDao/C/TransferViewController.m`；交易详情 `TradeDetailViewController.m`
- 名片：`ContactCardMessageCell` + `ChoiceContactCardVC`

#### 消息内链接

| 环节 | 实现 |
|---|---|
| 链接提取 | `ChatVC.firstLink(in:)` 用 `NSDataDetector` 从**整条文本**里挑第一段 http/https 链接（消息气泡是整条文本一起响应点击，`MessageLabel.handleGesture` 恒返回 false）；挑不出时退回原有「含 `www` → 系统 Safari」行为 |
| 链接样式 | `MessageLabel.underlineLinks(in:)` 把链接区间标成**主题色 + 下划线**。因自己发的气泡背景是浅蓝 `#C1E9FF`，主题色 `#32B2F7` 在其上对比度只有 ~1.85:1（看不清、反而失去暗示），所以自己发的气泡改用同色系压暗一档的 `MessageLabel.outgoingLinkColor`（`#0A7BC4`：浅蓝上 3.55:1 / 白底 4.56:1）；收发由 `TextMessageCell` 在 `configure` **之前**写入 `messageLabel.linkColor` |
| 分发 | `ChatVC.openUrl(urlStr:)`：带 `room` 参数的**语音房**链接 → `VoiceRoomLauncher.open(url:from:)`（走 DApp 浏览器）；**其它链接仍交给系统浏览器**，行为未变 |

> 点击仍是**整条气泡**响应（`MessageLabel.handleGesture` 恒返回 false），所以一条消息里有多个链接时只会打开第一段（`ChatVC.firstLink`）。

> ⚠️ 自签证书：`VoiceRoomWebSupport.handleChallenge(_:completionHandler:)` 会**只对 `VoiceRoomService.siteURL` 的那个 host** 放行自签证书（开关 `VoiceRoomService.trustsSelfSignedCertificate`，当前 `true`，对应内网联调）。**换成正式域名 + 正式证书后请把开关改回 `false`。** 注意 `NSAllowsArbitraryLoads`（ATS）**不管证书链校验**，必须自己放行。另：访问 `192.168.x.x` 会触发 iOS 14+ 本地网络权限，`NSLocalNetworkUsageDescription` 已加。

#### 语音房

模块目录 `chat/voice/`（按 MVC；**无新增 View** —— 入口 View 在现有 `FZMMoreItemBar`，浏览器用现有的 DApp 浏览器）：

| 层 | 文件 |
|---|---|
| C | `chat/voice/C/VoiceRoomLauncher.swift`（语音房入口 + 登录闸门，内部打开 `DAppBrowserViewController`） |
| M | `chat/voice/M/VoiceRoomService.swift`（站点配置 + 建房接口 + 链接模板）、`chat/voice/M/VoiceRoomWebSupport.swift`（媒体配置 / 地址桥 / 麦克风 / 音频会话 / 自签证书 / 自动登录）、`chat/voice/M/WebMediaPermission.swift`（麦克风权限） |
| V | `chat/voice/V/VoiceRoomModeSheet.swift`（发起前的模式选择弹窗，微信风格；**当前只列「语音聊天」** —— 「视频聊天」选项已于 2026-10-16 按用户要求去掉）；「+」面板项仍复用 `chat/ChatView/V/InputBar/FZMMoreItemBar.swift` |

| 功能 | 关键类 / 文件 |
|---|---|
| 入口 | 聊天页输入栏「+」面板第 2 行第 3 格（`FZMMoreItemBar.voiceRoomView`）；私聊/群聊两种面板布局由 `layoutVoiceRoom(isPrivateChat:)` 重排 |
| 发起流程 | 点「+」面板的「语音聊天」项 → `ChatVC.sendVoiceRoom()` 共弹**模式选择**（`VoiceRoomModeSheet`：语音聊天 / 取消）→ 选中后 `createVoiceRoom(mode:)` 建房 → 发一条**文本消息**，内容 = 邀请文案 + 换行 + 房间链接（照 `sendTransferMsg` 构造，不带引用/@提醒）→ `VoiceRoomLauncher.open` 进房。<br>邀请文案按 **模式（语音 / 视频）× 会话类型（私聊 / 群聊）** 区分（`VoiceRoomService.inviteText(mode:isPrivateChat:name:)`，共 4 条）：群聊 = `<称呼> 发起了群语音，点击链接一起语音聊天吧` / `<称呼> 发起了群视频，点击链接一起视频聊天吧`；私聊 = `<称呼> 发起了语音，点击链接加入语音聊天吧` / `<称呼> 发起了视频聊天，点击链接加入视频聊天吧`。<br>称呼取 `LoginUser.shared().contactsName`：**昵称优先，没有昵称才回落到 `address.shortAddress`**（该方法还会优先企业姓名，是全 App 统一的「我的显示名」）。<br>⚠️ **链接必须留在正文里**：气泡是「整条文本」响应点击、取第一段 http/https 链接（`ChatVC.firstLink`），只发文案就没有可点的链接了 |
| 模式选择弹窗 | `chat/voice/V/VoiceRoomModeSheet.swift`：微信风格（选项白卡 + 8pt 间隙 + 独立「取消」白卡；行高 56 / 圆角 12 / 0.5pt 分割线 / 遮罩 50% 黑），回调 `nil` = 取消。<br>**没复用 `FZMBottomSelectView`** —— 那个的「取消」是和选项同一张卡片里的最后一行（不是微信的分离卡片），且已被「更换头像」在用 |
| 模式 | `VoiceRoomMode`（`chat/voice/M/VoiceRoomService.swift`）：`voice` = 服务端强制仅麦克风（页面不显示摄像头按钮）；`video` = 音视频。`createRoom` / `roomLink` 都收这个枚举，默认 `voice` |
| @所有人 | **群聊**的邀请消息正文前会拼 `@所有人` —— 本工程**任何人都能 @所有人**（`FZMAtPeopleVC.headerView` 里「普通群成员不能 @所有人」的判断已被注释掉）。<br>⚠️ 这个 `@` 只是**正文文字**（不置 `mentionIds`）⇒ **不会**触发「有人@我」红点（那个红点由 `SessionManager` 读 `mentionIds` 决定）；若要带红点提醒，得额外给消息置 `mentionIds = ["ALL"]` |
| 打开方式 | 页面本体是 **DApp 浏览器**（`DAppBrowserViewController`，音视频能力由 `VoiceRoomWebSupport` 挂载、**只在 `initialURL` 就是语音房链接时启用**）；但语音房**不进导航栈**，而是装进通话容器 `chat/voice/V/VoiceRoomCallContainerVC.swift`（**直接挂到 key window 上**）。<br>原因：悬浮框要能浮在 App 之上、且通话期间不能有返回按钮 / 侧滑返回 —— push 做不到这两条；<br>⚠️ **不能挂 window 而是用模态**：模态外面还有 `UIPresentationController.containerView`，它铺满整屏且参与 hit-test ⇒ 就算根视图在胶囊外返回 false，触摸也会被吃掉，用户缩小后什么都点不了（用户反馈过）。<br>⚠️ **同一时刻只允许一个通话**：再点其它房间的链接 → 提示「先挂断当前的语音或视频聊天再进行操作」；点的就是当前这一间 → 直接把悬浮框还原成全屏 |
| 通话界面（全屏 ↔ 悬浮框） | 全屏：容器铺满，页面黑底 + 自绘「缩小」按钮（图标 `voiceRoom_minimize`）。<br>按钮位置 = **与房间号同一列、顶栏下方**：`x = 12`、`y = 页面自报的顶栏高度 + 8`（`VoiceRoomWebSupport.headerHeightWatcherJS` 实测上报，取不到才用 `k_StatusBarHeight + 44` 兜底）。<br>⚠️ 上报值要**双向夹紧在 `状态栏 + 24 ~ + 80`**：页面里很容易量到「安全区占位」那种空白容器（bottom 只有状态栏那么高），用它会把按钮**顶进顶栏、压住房间号**（2026-09-30 看录屏定位到的，现已用「元素必须有文字」+ 原生夹紧两层兜底）。<br>点缩小：`callArea` 缩成 **50×50 蓝色正方形**（`Color_Theme` + 白色「语音中 / 视频中」，字号 11、留白 4，照 `AICustomerFloatView`；文字自己换行适配多语言），根视图 `VoiceRoomCallRootView.interactiveFrame` 设为方块（⚠️ **这个值必须统一由 `applyModeLayout()` 维护、拖动时逐帧跟着气泡更新** —— 只在 `setBubble` 里设一次的话，气泡被拖走后就跑出了可交互区 ⇒ 点不动，用户反馈过的 bug）⇒ **方块内接触摸、框外穿透给下面 App**；同时把页面 `isUserInteractionEnabled = false`，否则拖不动。方块盖在页面上（页面缩到方块那么大继续跑，避免被 WebKit 节流）。<br>拖 = 方块上的 pan；点一下 = 回全屏。<br>⚠️ 悬浮框**只能浮在 App 内** —— 想浮在其它 App 之上，iOS 只允许「画中画 + AVPlayerLayer」，WKWebView 做不到 |
| 通话界面（全屏 ↔ 悬浮框） | 全屏：容器铺满，页面黑底 + 顶部自绘「缩小」按钮（图标 `voiceRoom_minimize`）。<br>点缩小：`callArea` 缩成小框（宽 = 屏宽 0.34、高宽比 1.35），根视图 `VoiceRoomCallRootView.interactiveFrame` 设为小框 ⇒ **框内接触摸、框外穿透给下面的 App**（这是用模态做悬浮窗的关键）；同时把页面 `isUserInteractionEnabled = false`，否则拖不动。<br>拖 = `bubbleOverlay` 上的 pan；点一下 = 回全屏。<br>⚠️ 悬浮框**只能浮在 App 内** —— 想浮在其它 App 之上，iOS 只允许「画中画 + AVPlayerLayer」，WKWebView 做不到 |
| 加载失败 → 返回 | 页面加载失败时，顶部那个按钮从「缩放」变成「返回」（图标换成项目现成的 `nav_back_white`），点它直接退出通话界面。失败判定 = `DAppBrowserViewController.isVoiceRoomLoadFailed`（`didFail` / `didFailProvisionalNavigation` 上报，`onVoiceRoomLoadFailureChanged` 回调容器）。<br>⚠️ 必须**滤掉**「被取消 / 被新导航顶掉」（`NSURLErrorCancelled`、`WebKitErrorDomain 102`）—— 我们在 `decidePolicyFor` 里会主动 `.cancel`，不滤按钮会乱闪。<br>⚠️ 超时不等系统默认的 **60 秒**：`DAppBrowserViewController` 自起 **10 秒看门狗**（`voiceRoomLoadTimeout`，每次 `didStartProvisionalNavigation` 重新起表）⇒ 10 秒还没 `didFinish` 就先当失败、按钮先变「返回」（用户 2026-09-30 要求从 1 分钟改成 10 秒）；页面如果只是慢、10 秒后才加载完，`didFinish` 会把状态改回正常（按钮自己变回「缩放」） |
| 后台也能聊 | `Info.plist` 的 `UIBackgroundModes` 含 `audio`；全程不主动改 / 不提前释放音频会话（悬浮框只是把窗口缩小，不进后台）。⚠️ iOS **后台不给摄像头** —— 视频通话退后台后对端只能听到声音（画面停住），这是系统限制 |
| 建房接口 | `POST {VoiceRoomBaseURL}/api/v1/room/create`（`VoiceRoomService`，`URLSession` 直连；body `{mode:"voice"\|"video", owner:"0x…"}`；响应 `{code, room, pin, mode}`）。⚠️ 模式在**建房时定死**并存进服务端 Redis ⇒ 请求体与链接必须带**同一个**模式 |
| 链接模板 | `VoiceRoomService.roomLink(room:pin:mode:)` → `{host}/?room=xxxxxx&pin=1234&mode=voice#/`（`mode` 取 `voice` / `video`；全仓唯一拼链接处） |
| 进房链接补 `name` | 真正加载的 URL 会由 `VoiceRoomService.link(_:addingName:)` 补上 `name=<当前用户显示名>`（`LoginUser.contactsName` = 昵称 → 短地址 → 企业姓名）。<br>⚠️ 必需：H5 侧 `index-*.js` 读 `window.location.search` 的 `room`/`pin`/`name`，**三者齐全才会自动加入房间**（缺 name 要用户手填）。<br>⚠️ 名字**按人、在打开时**补 —— 消息里分享的链接**不带**名字，否则收链接的人会顶着**发起人的名字**进房。补在 `DAppBrowserViewController.voiceRoomEntryURL`（`initialURL` 保持原样，标题与去重都用它） |
| 音频输出 | **语音 / 视频两种模式都是「进来就外放」**（与模式无关）：只做 `overrideOutputAudioPort(.speaker)`，**绝不主动 `setCategory` / `setActive`**（见下方提示）。看门狗前 20 秒 0.5s 一次、之后 2s 一次、最多 ~4 分钟，**确认到扬声器立即自停**（之后用户手动切听筒 / 蓝牙不会被抢回）；耳机 / 蓝牙在场时一律不抢 |
| 退出即挂断 | 挂断信号 = **页面里那个「挂断」按钮被点击**：`VoiceRoomWebSupport` 注入的 `callEndedWatcherJS` 用事件委托监听（`class` 含 `ctrl-btn` 且文案含「挂断」）后 `postMessage({action:'hangup'})` ⇒ 宿主调 `VoiceRoomCallContainerVC.finish()` ⇒ 销毁整个通话界面（页面一起没、**不留悬浮框**）。<br>⚠️ 为什么靠「偷听」：H5 是另一侧维护的，**实测它没有给原生任何桥**（bundle 里完全没用 `window.webkit.*`），点挂断也不改 URL、不跳转 ⇒ 原生没有别的信号。以后 H5 加正式桥（同 action）时，把脚本删掉即可（消息处理已支持）。<br>`VoiceRoomWebSupport.hangUp()` 本身 = 停加载 + 把文档导航到 `about:blank`（销毁文档 ⇒ 轨道 stop + LiveKit 断连）+ 释放音频会话 |
| 图标 | `inputBar_videoRoom`（自绘：180×180、圆角 30、浅青底 `#E4F8F8` + 实心青绿摄像机 `#2FC6C4`，风格对齐 InputBar 其余 6 个图标；找不到时自动回退 `inputBar_voice`） |

> 建房时只传 `owner`，**不传 `user_addr`** ⇒ 不绑定进房者身份，凭 room + PIN 谁都能进（适配「把链接发给对方一起聊」）。

> **DApp 浏览器上挂的音视频能力**（`VoiceRoomWebSupport`）：`allowsInlineMediaPlayback = true`、`mediaTypesRequiringUserActionForPlayback = []`、`uiDelegate` 实现 `requestMediaCapturePermissionFor → .grant` 与 `createWebViewWith`、注入 `window.H5Wallet.getAddress()`（handler 名 `h5Wallet`）、麦克风权限（iOS 17+ 用 `AVAudioApplication`，15/16 用 `AVAudioSession`）、**音频会话不主动接管** —— WKWebView 里的 WebRTC 由 WebKit 自己配 `.playAndRecord`，App 抢先 `setCategory`/`setActive` 会让 WebKit 的音频单元起不来（表现为「页面正常但一点声音都没有」）；只观察 `routeChangeNotification` / `interruptionNotification` / `mediaServicesWereResetNotification`，并在「会话已是 `.playAndRecord` 且当前输出是**听筒**」时 `overrideOutputAudioPort(.speaker)`（耳机 / 蓝牙在场时**不抢**），出房清掉 override 并 `setActive(false, options: .notifyOthersOnDeactivation)`。这些代理都写在 `DAppBrowserViewController` 末尾的 `// MARK: - 语音房：媒体授权 / 自签证书` 扩展里。

> **自动登录**：进房页需要钱包地址才能加入，而它**只在按钮点击 / 点「加入房间」时**才去取地址（挂载不会自己取）。所以 `VoiceRoomWebSupport.didFinish(in:)` 在页面加载完后**替用户点一次**页面自己的「登录获取钱包地址」按钮（按按钮文案匹配，幂等）。地址桥按 README 约定在**注入时**就带上地址并**立即 resolve**（早期「每次调用都 postMessage + 共用单个 resolver」的写法有竞态，会让第一个 Promise 永不 resolve）。

> **页内跳转**：在 DApp 浏览器里点到语音房链接时，`decidePolicyForNavigationAction` 会 `.cancel` 并**另开一个语音房浏览器** —— 媒体配置只在 `setupWebView()` 里按 `initialURL` **一次性**生效，就地加载拿不到麦克风。发现页本来就直接打开 DApp 浏览器，无需改道。

### 2.4 消息会话列表（消息 Tab）

| 功能 | 关键类 / 文件 |
|---|---|
| 三段 Tab：广场 / 私聊 / 群聊 | `FZMScrollPageView`；`SquareFeedPageView` / `FZMPrivateChatListView` / `FZMGroupChatListView` |
| 列表与 cell | `SessionListView`（基类，含置顶排序 + 免打扰）、`SessionColletionView`、`SessionCollectionViewCell`、`ChatHeadSegment`、`UnreadCountView` |
| 未读统计 | `SessionManager.refreshAllUnreadCount / refreshPrivateUnreadCount / refreshGroupUnreadCount`、`clearUnreadCount(session:)` |
| 会话操作 | `SessionManager`：`updateLatestInfo` / `updateLastMsgInfo` / `deleteSession` / `updateAutoDeleteDays` / `updateSessionName` |
| 长按菜单 | 置顶 / 取消置顶、免打扰 / 取消、删除聊天（「小Y」虚拟行只允许置顶） |
| 搜索 | `CustomBarView` → `FZMFullTextSearchVC`（`FZMFullTextSearchType` = friend / group / chatRecord / all） |
| 扫一扫 / 加号 | `SessionListDownQRCodeView` + `CustomBarView.addFriendBtnClick` |
| 服务端记录拉取 / 重装恢复 | `ChatManager+RecordPull.swift`：日常预取（`prefetchPrivateRecords`，最近 10 个会话）、重装后自动恢复（`autoRecoverPrivateRecordsIfFreshInstall`，按好友列表拉回私聊历史并补建会话行）、手动恢复（`recoverPrivateRecordsFromServer`） |

### 2.5 通讯录

| 功能 | 关键类 / 文件 |
|---|---|
| 好友 / 群 / 团队三视图 | `FZMContactListView`、`FZMFriendContactListView`、`FZMGroupContactListView`（`chat/Views/Contacts/V/ContactListView.swift`，含字母索引） |
| 好友详情 | `FriendInfoVC` + `FriendInfoCell`（黑名单 / 服务器 / 设置 / 团队 Cell） |
| 添加 / 搜索用户 | `SearchUserVC`（按地址搜索、扫码入口） |
| 黑名单 | `BlackListVC` + `UserManager.getBlackList / addShieldUser / deleteShieldUser` |
| 群二级页 | `chat/Views/Group/`：`FZMAddGroupVC`、`FZMGroupDetailInfoVC`、`FZMGroupMemberListVC`、`FZMGroupApplyListVC` 等 |
| 数据层 | `chat/User/`：`User` / `UserManager` / `Group` / `GroupManager`（群密钥） / `TeamManager` |

> ⚠️ **不存在**独立的「新的朋友 / 好友申请」页面（加好友直接调 `UserManager.addFriend`）；也**没有**标签 / 星标 / 分组管理。

### 2.6 广场

目录 `chat/Square/`：`C/`（控制器）、`V/`（视图与 Cell）、`M/`（模型与状态缓存）、`Network/`（接口层）。

| 功能 | 关键类 / 文件 |
|---|---|
| 广场主列表（消息 Tab 第一段） | `chat/Square/V/SquareFeedPageView.swift` |
| 一级筛选：全部 / 个人 / 公众号 / 公告 / 新闻 / 活动；二级：最新 / 热门 / 关注 | `SquareFeedCategory` / `SquareFeedTab`（`chat/Square/M/SquareModels.swift:283,327`） |
| 帖子 Cell（九宫格 / 点赞 / 评论 / 阅读 / 关注） | `SquarePostCell`、`SquareImageGridView` |
| 帖子详情 + 评论 | `SquarePostDetailVC`、`SquareCommentCell`、`SquareCommentInputBar` |
| 发帖 / 二次编辑 / 删帖 | `SquareCreatePostVC`（正文 2000 字 + 图 ≤9 张先传 OSS，支持 `@` 与 `#话题`） |
| 作者页 | `SquareAuthorVC`（`SquareAuthorInfoCell` / `SquareAuthorTabBar`） |
| 我的帖子 | `SquareMyPostsVC` + `SquareMyPostStore`（含本机待审快照） |
| 关注 / 粉丝列表 | `SquareFollowListVC` + `SquareFollowCell` |
| 公众号（金标） | `SquareOfficialVC`、`SquareGoldWallView`、`SquareOfficialDirectoryStore`；申请与资料修改见 `SquareOfficialAPI` |
| 举报 | `SquareReportVC`；原因 `SquareReportReason`（spam / porn / scam / abuse / other） |
| 点赞 | `SquareService.like / unlike / toggleLike`（乐观更新，无独立「收藏」功能） |
| 话题 / @提及 | `SquareRichText.swift`（`SquareRichTap` = mention / topic / link） |
| 分享 | `SquarePostShareCard`（画成图片）+ `SquarePostSharePresenter`（分享到聊天） |
| 大图浏览 / 骨架屏 / 红点 | `SquarePhotoPresenter`、`SquareFeedSkeletonView`、`SquareUnreadStore` |
| 头像解析（接口只回 authorAddr） | `SquareAvatarResolver.swift` |

### 2.7 钱包 / 资产 / 链 / DApp

> **关键结论：`chat/WalletConnect/` 是空目录，WalletConnect 未实现。**
> 2026-10-29 评估后**决定不接入**：① Project ID 依赖官方 relay，上架审核不通过时功能直接作废；② 历史接入经验出现过运行期闪退。
> 外部 dApp 连接统一走内置 EIP-1193 浏览器（见下「DApp 浏览器与签名」）。

#### 钱包页面（资产 Tab，主体 Objective-C）
| 功能 | 文件 |
|---|---|
| 我的资产（列表 / 行情 / 授权入口 / 删币 / 快捷转账） | `chat/Views/MyDao/C/PWNewsHomeViewController.m` |
| 币种详情（行情 + 转账 / 收款分段） | `CoinDetailViewController.m` / `_new.m` |
| 转账（多链、矿工费、密码校验） | `TransferViewController.m` / `_new.m` |
| 交易详情 | `TradeDetailViewController.m` / `_new.m` |
| 二维码收款（通用 / 指定金额） | `PWNesReceiptMoneyViewController.m` / `_new.m` |
| 合约页 | `PWContractVC.m` |
| 币种搜索 / 添加 | `chat/Views/MyDao/C/searchadd/*` |
| 单币种交易记录 / 手续费选择 | `PWSingelCoinTransListViewController.m`、`PWChoiceFeeSheetView.m` + `M/Fee.h` |
| 授权列表（Token Approve） | `chat/Views/MyDao/C/web3/TokenApproveListVC.swift` + `TokenApproveService.swift` |

#### 钱包数据 / 工具层
- 模型（OC）：`chat/Views/MyDao/M/`：`LocalWallet` / `LocalCoin` / `CoinPrice` / `Fee` / `OrderModel` / `PreCoin` / `PWAppsettings` / `PWContractRequest` / `PWNFTRequest`
- 本地库（OC）：`chat/Views/MyDao/OCDepend/PWDataBaseManager.m`（行情表等）+ `PWDataBaseSQLCollection.h`
- Go 钱包桥（OC）：`GoFunction.h`（`goCreateHDWallet:rememberCode:`、`enckey/deckey/checkPassword`）、`GameGoFunction.h`、`PWUtils.h`、`PWNetworkingTool.h`、`SGNetWork.h`
- Go 框架（bin）：`chat/ThirdParty/Walletapi.framework`（`WalletapiHDWallet`、`WalletapiNewWalletFromMnemonic_v2`、paracross 跨链、红包 `WalletapiBackRedPacket`）
- Swift 链上 helper：`chat/BusinessTool/Network/Helper/BlockchainHelper.swift`

#### 支持的链
| 链 | chainID | RPC |
|---|---|---|
| BTY（比原） | 2999 | `https://mainnet.bityuan.com/eth` |
| ETH | 1 | `https://rpc.flashbots.net` |
| BNB | 56 | `https://bsc-dataseed.bnbchain.org/` |

定义：`chat/dapp/DAppBrowser.swift:19-70`（`AppExploreWebRPC` / `BlockchainRPC.current` / `currentChainID`）；OC 侧链常量 `chat/Views/MyDao/C/web3/WebViewController_Private.h`、`chat/Views/MyDao/M/PWAppsettings.h`（`NetType{NetBTY, NetETH, NetBNB}`）；默认币 `COINDEFAULT @"ETH,BTY,YCC"`（`Depend.h:145`）。

#### DApp 浏览器与签名
| 实现 | 文件 |
|---|---|
| **Swift EIP-1193 浏览器（新）** | `chat/dapp/DAppBrowser.swift`：`DAppBrowserViewController`、`DAppWeb3Bridge`、`DAppBrowserConfiguration` |
| Swift 旧 H5 兼容通道 | `chat/dapp/DAppWVJBLegacyHandlers.m` [OC]、`chat/dapp/MessageSigner.swift` |
| Swift 授权 / 矿工费 UI | `chat/dapp/DappAuthSheetView.swift`、`DappChoiceFeeSheetView.swift` |
| **EIP-712 结构化签名**（2026-10-29 新增） | `chat/dapp/EIP712TypedData.swift`：`eth_signTypedData` / `_v3` / `_v4`（解析 / 摘要 / 签名 / 弹窗展示；支持嵌套结构体、定长与动态数组、`int`/`bytes`/`bytes32`） |
| **Objective-C 老浏览器** | `chat/Views/MyDao/C/web3/WebViewController.m`、`WebViewMetaMaskCoordinator.m`、`Web3ProviderHandler.m`、`provider.js` |
| DApp 探索 / 分类 | `chat/Views/MyDao/探索/`（`AppsTableVC`、`PWApplication.h`、`RecentlyUsedAppTool`、`ExploreAlertTool`） |

支持的 EIP-1193 方法：`eth_accounts` / `eth_requestAccounts` / `eth_coinbase` / `eth_chainId` / `net_version` / `eth_mining` / `eth_hashrate` / `wallet_getPermissions` / `wallet_requestPermissions` / `personal_sign` / `eth_signTypedData(_v3/_v4)` / `eth_sendTransaction` / `wallet_switchEthereumChain` / `wallet_addEthereumChain`；其余方法转发给当前链 RPC。
`eth_sign` 因安全原因**主动拒绝**（可签任意 32 字节哈希，等同可签走一笔转账）。

> ⚠️ **旧的 OC 浏览器（`WebViewMetaMaskCoordinator`）没有实现 EIP-712**：以前确认签名后返回空串（dApp 拿到无效签名且无从排查），2026-10-29 已改为明确回 `-32601`。新站点请用 Swift DApp 浏览器打开。

#### 红包合约能力（Swift）
- `chat/ChatView/RedBag/Extesion/RedPacketWeb3Integration.swift` → `RedPacketWeb3Service`：`createRedPacket` / `claimRedPacket` / `withdrawRedPacket` / `getRedPacketInfo(WithRecords)` / `getClaimRecordsWithTime` / `getMyRedPacketInfos` / `pollRedPacketProgress` / `startRedPacketClaimWatch`
- 钱包数据源：`chat/ChatView/RedBag/M/RedPacketWalletDataSource.swift`（`getSupportedTokens` / `getTokenBalance` / `getCurrentWalletAddress` / `getContractAddress` / `isContractERC20Coin`）
- 合约接口文档：`chat/ChatView/RedBag/README_RedPacketContract.md`、`Extesion/contract-api22.md`

### 2.8 发现 Tab

根页面 `ExploreSearchViewController` [OC]（`chat/Views/MyDao/C/web3/ExploreSearchViewController.m`，`FZMUIMediator.getSearchNavigationController()` 唯一入口）。

| 功能 | 说明 |
|---|---|
| 导航栏 | 输入框（进页不自动弹键盘）+ 左「切换网络」+ 右「搜索」 |
| 搜索历史段 | `PWAppsettings getEWebsite / saveEWebsite / deleteEWebsite`，左滑删除（二次确认） |
| 常用网站段 | 写死 `BitYuan → https://bityuan.com`，图标取站点 favicon |
| 打开 DApp | `openDAppWithText:` → `openDAppWithURL:title:`（先判免责）→ `pushDAppBrowserWithURL:` |
| 免责声明 | `ExploreAlertTool` + `RecentlyUsedAppTool`（Key `DAppDisclaimerConfirmedHosts`） |
| 二级页 | `PWLanguageViewController`（切换网络）、`AppsTableVC` |

> ⚠️ `chat/Views/MyDao/探索/ExploreVC.m`（banner + 热门专题）**全仓无实例化**，是死代码，勿在其上加需求。

### 2.9 我的 / 设置

| 功能 | 关键类 / 文件 |
|---|---|
| 个人信息（头像 / 昵称 / 二维码名片 / 切换账号） | `MineVC`、`EditNicknameVC`、`ImageEditVC` |
| 二维码名片（me / group / team / customer） | `QRCodeVC`（`FZMQRCodeVCShowType`） |
| 通用设置 | `SettingVC`：离线通知、面容/指纹验证、多语言（cell = `SettingTextCell` / `SettingSwitchCell`）、修复聊天记录（「恢复私聊记录」/「重新同步」） |
| 安全管理 | `SecurityVC`：导出助记词、导出第二段分片、账号绑定（手机/微信/小红书/抖音）、密聊密码 |
| 绑定手机 / 邮箱、密聊密码 | `BindSeedVC`、`SetChatPwdVC` |
| 切换 / 删除账号 | `SwitchAccountVC` |
| 服务器 / 节点管理 | `chat/Views/Mine/Server/`：`ServerListVC`（chatServer / chainServer）、`AddServerVC`、`SetServerVC`、`ChooseServerVC` |
| 隐私清单 | `chat/PrivacyInfo.xcprivacy` + 根目录 `verify_privacy_manifest.sh` |

> ⚠️ **不存在**实名认证页、独立的「关于/版本号」页、独立「清理缓存」页。

### 2.10 登录与账号体系

| 功能 | 关键类 / 文件 |
|---|---|
| 账号选择登录（列出已登录账号） | `UserLoginVC`（`chat/Views/Login/UserLogin/UserLogin.swift`） |
| 新设备入口：创建 / 导入助记词、手机号登录 | `ChooseAccountVC` |
| 手机号 + 验证码登录 | `LoginViewController`（`chat/Views/Login/Phone/`） |
| 重置助记词登录、S1+S2 分片登录、S2 发手机 | `ResetMnemonicLoginViewController`、`S2LoginViewController`、`SendS2ToPhoneViewController` |
| 分片备份展示 / 校验 | `ShardBackupDisplayViewController`、`ShardBackupVerifyViewController` |
| 助记词创建 / 导入 / 备份 | `chat/Views/Login/Seed/C/`：`CreateSeedPreVC`、`CreateSeedVC`、`ImportSeedVC`、`BackupSeedVC` |
| 扫码登录（PC 网页版） | `chat/Views/Login/scanLogin/`：`ScanLoginRouter` / `ScanLoginService` / `ScanLoginConfirmVC` / `ScanLoginAPI` / `ScanLoginCrypto`（v2 / ECDH 协商密钥 + 本地 AES-GCM 加密私钥；旧版 v1 已停用） |
| 创建 / 加入团队（企业号） | `CreateOrJoinTeamVC` |
| 切换 / 删除账号 | `SwitchAccountVC` |
| 登录状态与登出 | `LoginUser.shared()`（`login(seed:)` / `login()` / `logout()`），`UserManager` / `SeedManager` 配合 |

> ⚠️ **不存在**：一键登录 / 运营商本机号码登录、微信 / Apple 第三方**登录**（只有 `LoginUser.bindWechat` 等账号绑定）、独立的「多设备登录管理」页面（多端仅通过 Socket `EndpointLogin` 信令踢下线）。

### 2.11 AI 客服（H5 免登录）

模块 `chat/AI/`：

| 角色 | 文件 |
|---|---|
| 站点配置 / 凭证模型 / 错误 | `chat/AI/M/AICustomerModels.swift` |
| 免登录编排（SIWE 三步） | `chat/AI/M/AICustomerAPI.swift` |
| EIP-191 签名 / 地址工具 | `chat/AI/M/AICustomerSigner.swift` |
| 会话 / 置顶状态存储 | `chat/AI/M/AICustomerStore.swift` |
| 入口 | `chat/AI/C/AICustomerLauncher.swift`（Tab 中间 + 私聊列表「小Y」行） |
| H5 容器 | `chat/AI/C/AICustomerServiceWebVC.swift` |
| 浮动入口 | `chat/AI/V/AICustomerFloatView.swift` |

流程：`GET /api/auth/nonce` → 本地 EIP-191 签名 → `POST /api/auth/login/user`；
私钥从 `WalletPrivateKeyStore` 内存缓存取（首次弹一次密聊密码）；`nonce` 过期（400）只重签一次；401 时静默自愈（`allowPasswordPrompt: false`）。
站点默认未配置（空字符串），可用 UserDefaults / Info.plist 键 `AICustomerServiceSiteURL` 覆盖。

> ⚠️ 仓库记忆里提到的 `chat/BusinessTool/Network/AIAPIManager.swift`、`ChatManager+AI.swift` **在本分支不存在**，不要按记忆引用。

### 2.12 基础能力

| 能力 | 关键文件 |
|---|---|
| 文本搜索 | `chat/Views/FullTextSearch/`（`FZMFullTextSearchVC` + `IMFullTextSearchVM`） |
| 会话文件管理 | `chat/Views/File/`（`FZMFileViewController`、`FZMFileSearchController`、`FZMVideoListView`） |
| H5 容器 | `chat/Views/Web/`（`WebViewVC`、`OKRH5WebViewVC`、`TeamH5WebViewVC`）；**语音房 = `chat/voice/` 模块 + DApp 浏览器**（见 §2.3） |
| 扫码 | `chat/BusinessTool/QRCodeScan/`、[OC] `SGQRCode/*` |
| 文件上传 | `chat/ProjectBase/OSSClient/IMOSSClient.swift`、`chat/BusinessTool/Network/OSS.swift` / `OBS.swift` |
| 推送 | 友盟（`UMAPPKEY`）+ Bugly（`BUGLYID`），Token 存 `APPDeviceToken` |
| 版本更新 | `SystemAPI.update(versionCode:)` + `VersionCheck.swift` |
| 多语言 | 21 个 `.lproj`（`zh-Hans` / `zh-HK` / `en` / `ja` / `ko` / `de` / `fr` / `es` / `it` / `nl` / `pl` / `pt-PT` / `ru` / `uk` / `vi` / `id` / `ms` / `th` / `tr` / `lo` / `my`），源文件在 `chat/Localizations/<lang>.lproj/Localizable.strings`，打包后落在 `<bundle>/<lang>.lproj/`。映射在 `LanguageManager`（App 内切换，存 `UserDefaults "AppSelectedLanguage"`，默认 `zh-Hans`）；`L(key)` 从 `Bundle.main/<lang>.lproj` 取。⚠️ **key 就是中文原文，缺 key 时原样返回中文** ⇒ 漏加 key 会在其它语言界面漏出中文 |
| 权限文案本地化 | `chat/Localizations/<lang>.lproj/InfoPlist.strings`（21 份，key 用 Info.plist 的**键名**如 `NSCameraUsageDescription`，不是文案本身）。⚠️ iOS **只认 `InfoPlist.strings` 这个名字**。⚠️ 弹窗语言 = 系统 / 「设置 → 谈信 → 语言」，**App 内那个切换改不了它** |
| 埋点 | Mixpanel |

## 三、接口文档

### 3.1 网络层架构与公共约定

```
[业务页面 / Manager]
        │
        ▼
Provider.request(target:successBlock:failureBlock:)        chat/BusinessTool/Network/Provider.swift
        │   MoyaProvider<MultiTarget>（callbackQueue = .main）
        ▼
XLSTargetType（协议）                                       chat/BusinessTool/Network/XLSTargetType.swift
   - baseURL / path / method / parameters / headers / validation
        │
        ▼
各 API 枚举（enum XxxAPI: XLSTargetType）                    chat/BusinessTool/Network/API/、chat/Square/Network/、
                                                            chat/Views/Login/scanLogin/、chat/ChatView/ChatHistoryAPI.swift
```

**默认编码**：`Task.requestParameters(parameters, encoding: JSONEncoding.default)`（即 JSON body；**默认 method = POST**）。

**公共请求头**（`XLSTargetType.headers`）：

| Header | 值 |
|---|---|
| `FZM-SIGNATURE` | `LoginUser.shared().signature` |
| `FZM-VERSION` | `CFBundleShortVersionString` |
| `FZM-UUID` | 每次请求新生成的 UUID |
| `FZM-DEVICE` | `iOS` |
| `FZM-DEVICE-NAME` | `k_DeviceName` |
| `X-App-Id` | `ios_txchatapp` |
| `X-App-Token` | `6514b255dd0234ec4ec919b75defa633` |

**统一响应约定**（`XLSTargetType.validation`）：
- HTTP 非 200 → 失败（`NSError`，取 `response.description`）；
- `result` / `code` == `0` → 成功，回调返回 `json["data"]`；
- `code == 13001` → 特殊放行（团队未绑定，直接回 `result`）；
- 其它 → 失败，错误信息取 `message`，为空时取 `msg`；
- 网络异常 → 统一文案「无网络，请检查网络连接 / 请求超时，请检查网络连接 / 网络连接错误，请稍后再试」（`L()` 本地化）。

**不复用基类 validation 的模块**（自行判定整个响应信封）：
- `SquareAPI`（`chat/Square/Network/SquareAPI.swift`）：广场 HTTP **恒为 200**，业务结果看 body 的 `result`，由 `SquareService` 判定；
- `ScanLoginAPI`（`chat/Views/Login/scanLogin/ScanLoginAPI.swift`）：需区分 HTTP 401（鉴权失败）与 `result = -1`（会话失效）；
- `BlockchainAPI`（`chat/BusinessTool/Network/API/BlockchainAPI.swift`）：JSON-RPC 2.0，直接取 `json["result"]`。

### 3.2 服务地址总表

定义集中在 `chat/BusinessTool/Network/SeverContext.swift`（另有 OC 侧在 `chat/Views/MyDao/OCDepend/Depend.h`）。

| 名称 | 变量 / 宏 | 值 | 用途 |
|---|---|---|---|
| IM 中心服务器（可切换） | `IMChatServerInUse` | 服务端下发（默认空） | `XLSTargetType` 默认 baseURL |
| 备份/账号服务器 | `BackupURL` | 未配置（空字符串） | `/backup/*`、`/oss/*`、`/disc/*`、`/app/*` |
| 区块链节点（可切换） | `BlockchainServerInUse` | 服务端下发（默认空） | `BlockchainAPI` JSON-RPC |
| 企业 OA 服务器 | `TeamOAServerUrl` | 用户可配，默认空 | `TeamAPI` |
| 钱包服务器（OC） | `WalletURL` | 未配置（空字符串） | 钱包 `/interface/*`、`/goapi/*` |
| Go 节点 | `GoNodeUrl` | 未配置（空字符串） | 钱包节点 |
| 广场 | `SquareBaseURL` | 未配置（空字符串） | `/square/*` |
| 扫码登录 | `ScanLoginBaseURL` | 未配置（空字符串） | `/app/qr-login/*` |
| S1 分片备份 | `S1BackUpAPI.baseURL` | 未配置（空字符串） | `/api/v1/*` |
| AI 客服站点 | `AICustomerConfig.siteURL` | 未配置（空字符串），可用 `AICustomerServiceSiteURL` 覆盖 | `/api/auth/*` |
| 团队 H5 | `TeamH5Url` | 未配置（空字符串） | `TeamCreateURL` / `TeamJoinURL` / `TeamListURL` / `TeamManagerURL` / `TeamSelectorURL` |
| OKR H5 | `OKRH5Url` | 未配置（空字符串） | OKR 页面 |
| 语音房 H5 | `VoiceRoomBaseURL` | 未配置（空字符串），可用 `VoiceRoomSiteURL` 覆盖 | `POST /api/v1/room/create` 建房 + 拼进房链接 |
| 阿里云 OSS | `OSS_End_Point` | `https://oss-cn-shanghai.aliyuncs.com`，bucket `dld-test` | 文件上传 |
| 华为云 OBS | `OBS_EDN_POINT` | `https://obs.cn-east-3.myhuaweicloud.com`，bucket `ccccchy-test` | 文件上传 |
| 用户协议 | `USER_SERVER_AGREEMENT_URL` | 未配置（空字符串） | — |
| App Store | `APPSTORE_DOWNLOAD_URL` | `itms-apps://itunes.apple.com/app/id1563350901` | — |

### 3.3 REST 接口明细

> 除特别说明外，全部 `POST`，body 为 JSON，baseURL 见上表。

#### 3.3.1 `TokenAPI` — 云端存储临时凭证（`chat/BusinessTool/Network/API/TokenAPI.swift`）

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `OSSToken` | POST | `/oss/get-token` | — |
| 2 | `OBSToken` | POST | `/oss/get-huaweiyun-token` | — |

#### 3.3.2 `CodeAPI` — 验证码（`API/CodeAPI.swift`）

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `phoneSend` | POST | `/backup/phone-send` | `area`, `phone` |
| 2 | `emailSend` | POST | `/backup/email-send` | `email` |

#### 3.3.3 `BackupAPI` — 账号备份与找回（`API/BackupAPI.swift`）

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `phoneQuery` | POST | `/backup/phone-query` | `area`, `phone` |
| 2 | `emailQuery` | POST | `/backup/email-query` | `email` |
| 3 | `phoneBinding` | POST | `/backup/phone-binding` | `area`, `phone`, `code`, `mnemonic` |
| 4 | `emailBinding` | POST | `/backup/email-binding` | `email`, `code`, `mnemonic` |
| 5 | `editMnemonic` | POST | `/backup/edit-mnemonic` | `mnemonic` |
| 6 | `phoneRetrieve` | POST | `/backup/phone-retrieve` | `area`, `phone`, `code` |
| 7 | `emailRetrieve` | POST | `/backup/email-retrieve` | `email`, `code` |
| 8 | `addressRetrieve` | POST | `/backup/address-retrieve` | `address` |
| 9 | `getAddress` | POST | `/backup/get-address` | `query`（手机号或邮箱） |

#### 3.3.4 `S1BackUpAPI` — 分片密钥与账号绑定（`API/S1BackUpAPI.swift`，baseURL 未配置时为空字符串）

| # | case | 方法 | 路径 | 参数 / 说明 |
|---|---|---|---|---|
| 1 | `s1phoneSend` | POST | `/api/v1/send-code` | `phone`, `purpose`（backup / reset / get / delete） |
| 2 | `storeShard` | POST | `/api/v1/store-shard` | `phone`, `code`, `chataddress`, `shard_key` |
| 3 | `getShard` | POST | `/api/v1/get-shard` | `phone`, `code`（本地存储） |
| 4 | `getShardBySms` | POST | `/api/v1/get-shard-by-sms` | `phone`, `code`（短信下发） |
| 5 | `checkShardExists` | POST | `/api/v1/check-shard-exists` | `phone` |
| 6 | `resetShard` | POST | `/api/v1/reset-shard` | `phone`, `code`, `chataddress`, `shard_key` |
| 7 | `deleteShard` | POST | `/api/v1/delete-shard` | `phone`, `code` |
| 8 | `bindAccount` | POST | `/api/v1/bind-account` | `phone`, `wechat_id`, `xiaohongshu_id`, `douyin_id`, `chataddress` |
| 9 | `queryChatAddress` | POST | `/api/v1/query-chataddress` | `phone`, `wechat_id`, `xiaohongshu_id`, `douyin_id` |
| 10 | `queryAccounts` | POST | `/api/v1/query-accounts` | `chataddress` |

#### 3.3.5 `DiscoveryAPI` — 服务器/节点发现（`API/DiscoveryAPI.swift`）

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `disc` | POST | `/disc/nodes` | — |

#### 3.3.6 `SystemAPI` — 系统能力（`API/SystemAPI.swift`）

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `update` | POST | `/app/version/check` | `versionCode` |
| 2 | `getModules` | POST | `/app/modules/all` | — |

#### 3.3.7 `TeamAPI` — 企业/团队（`API/TeamAPI.swift`，baseURL = `TeamOAServerUrl`）

| # | case | 方法 | 路径 | 参数 | 说明 |
|---|---|---|---|---|---|
| 1 | `getServer` | POST | `/v1/common/get-server` | — | 默认 IM / 区块链服务器 |
| 2 | `enterpriseInfo` | POST | `/v1/enterprise/info` | `id`（teamId） | 企业信息 |
| 3 | `getStaff` | POST | `/v1/staff/get-staff` | `id`（address） | 员工信息 |
| 4 | `getBind` | POST | `/v1/account/get-bind` | `id`（address） | 绑定信息 |

> 受 `FZM_EnableEnterpriseFeature` 总开关控制（当前 `false`，请求入口全部被 guard）。

#### 3.3.8 `GroupAPI` — 群（`API/GroupAPI.swift`，baseURL = 群自己的 `chatServerUrl`，前缀 `/group/app`）

**群信息 / 设置**

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `groupInfo` | POST | `/group/app/group-info` | `id` |
| 2 | `groupList` | POST | `/group/app/group-list` | — |
| 3 | `groupPubInfo` | POST | `/group/app/group-pub-info` | `id` |
| 4 | `updataGroupAvatar` | POST | `/group/app/avatar` | `id`, `avatar` |
| 5 | `updateGroupName` | POST | `/group/app/name` | `id`, `name`, `publicName` |
| 6 | `updateJoinType` | POST | `/group/app/joinType` | `id`, `joinType`（0 无需审批 / 1 禁止 / 2 需审核） |
| 7 | `updateFriendType` | POST | `/group/app/friendType` | `id`, `friendType`（0 可加 / 1 禁加） |
| 8 | `updateMuteType` | POST | `/group/app/muteType` | `id`, `muteType`（0 全员可发言 / 1 全员禁言） |

**群动作**

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 9 | `groupCreate` | POST | `/group/app/create-group` | `name`, `avatar`, `introduce`, `memberIds` |
| 10 | `groupDisband` | POST | `/group/app/group-disband` | `id` |
| 11 | `groupExit` | POST | `/group/app/group-exit` | `id` |
| 12 | `groupRemove` | POST | `/group/app/group-remove` | `id`, `memberIds` |
| 13 | `groupInviteMembers` | POST | `/group/app/invite-group-members` | `id`, `newMemberIds` |
| 14 | `groupChangeOwner` | POST | `/group/app/change-owner` | `id`, `memberId` |
| 15 | `joinGroup` | POST | `/group/app/join-group` | `id`, `inviterId` |

**群成员 / 禁言**

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 16 | `groupMemberInfo` | POST | `/group/app/group-member-info` | `id`, `memberId` |
| 17 | `groupMemberList` | POST | `/group/app/group-member-list` | `id` |
| 18 | `updateMemberName` | POST | `/group/app/member/name` | `id`, `memberName` |
| 19 | `updateMemberType` | POST | `/group/app/member/type` | `id`, `memberId`, `memberType`（0 群员 / 1 管理员） |
| 20 | `updateMemberMuteTime` | POST | `/group/app/member/muteTime` | `id`, `memberIds`, `muteTime` |
| 21 | `groupMuteMemberList` | POST | `/group/app/mute-list` | `id` |

**入群申请（joinType == 2）**

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 22 | `createGroupApply` | POST | `/group/app/create-group-apply` | `id`, `idStr`（**均为 string 类型**），`applyNote` |
| 23 | `groupApplyList` | POST | `/group/app/get-group-applys` | `id`, `idStr`, `count`, `offset` |
| 24 | `acceptGroupApply` | POST | `/group/app/accept-group-apply` | `id`, `idStr`, `applyId` |
| 25 | `rejectGroupApply` | POST | `/group/app/reject-group-apply` | `id`, `idStr`, `applyId`, `rejectReason` |

**其它**

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 26 | `revoke` | POST | `app/record/revoke` ⚠️ | `type`（0 私聊 / 1 群聊）, `logId` |

> ⚠️ 注意第 26 项的 path **缺少前导 `/`**（`"app/record/revoke"`），与其它群接口（`/group/app/...`）不同前缀；且 `revoke(type:logId:)` 的参数用的是 `logId`，而 `GroupAPI` 其它接口用 `id`。改动前先确认服务端口径。

#### 3.3.9 `BlockchainAPI` — 链上 JSON-RPC（`API/BlockchainAPI.swift`，baseURL = `BlockchainServerInUse`）

统一 `POST`，path = `""`，body 为 JSON-RPC 2.0（`{"jsonrpc":"2.0","id":1,"method":...,"params":[...]}`）。

| # | case | RPC method | 说明 |
|---|---|---|---|
| 1 | `createNoBalanceTransaction` | `Chain33.CreateNoBalanceTransaction` | 构造并发送不收手续费交易（代扣） |
| 2 | `sign` | `Chain33.SignRawTx` | 签名交易（`expire` 2h45m） |
| 3 | `sendTransaction` | `Chain33.SendTransaction` | 发送交易 |
| 4 | `updateFriends` | `chat.CreateRawUpdateFriendTx` | 好友上链 |
| 5 | `getFriends` | `Chain33.Query` / execer `chat` / `GetFriends` | 查好友（签名查询） |
| 6 | `updateBlackList` | `chat.CreateRawUpdateBlackTx` | 黑名单上链 |
| 7 | `getBlackList` | `Chain33.Query` / `GetBlackList` | 查黑名单 |
| 8 | `getUser` | `Chain33.Query` / `GetUser` | 按地址批量取用户信息 |
| 9 | `getServerGroup` | `Chain33.Query` / `GetServerGroup` | 查服务器分组 |
| 10 | `updateServerGroup` | `chat.CreateRawUpdateServerGroupTx` | 更新分组（type 1 新增 / 2 删除 / 3 修改） |
| 11 | `updateUser` | `chat.CreateRawUpdateUserTx` | 更新用户资料（`UpdateUserInfo`：nickname / phone / pubKey / avatar / chain.ETH / chain.BNB / chain.BTY / chain.POL；level：private / protect / public） |
| 12 | `getBalance` | `Chain33.GetBalance` | 查地址余额（execer `coins`） |

Swift 封装：`chat/BusinessTool/Network/Helper/BlockchainHelper.swift`；`User+Net.swift` 提供 `User.updateUserNickname / updateUserPublickKey / updateUserAvatar / updateUserChainAddress`。

#### 3.3.10 `ChatHistoryAPI` — 聊天记录删除同步（`chat/ChatView/ChatHistoryAPI.swift`）

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `syncDelete` | POST | `/chat/history/delete` | `sessionId`, `msgIds?`, `before?`, `clearAll?`, `channelType`, `fromId`, `targetId` |

> ⚠️ 该接口为**占位实现**，代码注释明确「服务端接口文档尚未提供，待确认后补充 path / 字段」。
> 静态入口：`ChatHistoryAPI.syncDelete(_:successBlock:failureBlock:)`。

#### 3.3.11 `SquareAPI` / `SquareOfficialAPI` — 广场（`chat/Square/Network/SquareAPI.swift`）

baseURL = `SquareBaseURL`（`https://3syxin.com`）。**HTTP 恒 200，业务码在 body 的 `result`**。

| # | case | 方法 | 路径 | 参数 / 说明 |
|---|---|---|---|---|
| 1 | `healthz` | GET | `/square/healthz` | 探活，无需签名 |
| 2 | `feed` | GET | `/square/app/posts` | `page`, `pageSize`, `feed?`（排序口径）, `kind?`, `tag?`, `authorAddr?` |
| 3 | `postDetail` | GET | `/square/app/posts/{id}` | — |
| 4 | `createPost` | POST | `/square/app/posts` | `content`, `nickname?`, `mediaUrls`, `commentsEnabled?` |
| 5 | `updatePost` | PUT | `/square/app/posts/{id}` | 二次编辑（同上字段） |
| 6 | `deletePost` | DELETE | `/square/app/posts/{id}` | — |
| 7 | `like` | POST | `/square/app/posts/{id}/like` | — |
| 8 | `unlike` | DELETE | `/square/app/posts/{id}/like` | — |
| 9 | `comments` | GET | `/square/app/posts/{postId}/comments` | `page`, `pageSize`, `thread?`（传 1 只返回楼，带 `replies` / `replyCount` / `commentCount`） |
| 10 | `createComment` | POST | `/square/app/posts/{postId}/comments` | `content`, `nickname?`, `replyToId?`（> 0 = 回复某条可见评论） |
| 11 | `deleteComment` | DELETE | `/square/app/comments/{id}` | — |
| 12 | `setCommentsEnabled` | PUT | `/square/app/posts/{postId}/comments-enabled` | `enabled`（仅公众号作者） |
| 13 | `officialMe` | GET | `/square/app/official/me` | — |
| 14 | `officialApply` | POST | `/square/app/official/apply` | `name`, `avatar?`, `intro?` |
| 15 | `officialUpdate` | PUT | `/square/app/official` | `name?`, `avatar?`（`supportProfileUpdate = true`；封禁 `-20405`、未开号 `-20404`） |
| 16 | `status` | GET | `/square/app/status` | `canRead` / `canPost` |
| 17 | `officials` | GET | `/square/app/officials` | `gold?`（nil 全部 / true 仅金标）, `page`, `pageSize` |
| 18 | `myPosts` | GET | `/square/app/me/posts` | `page`, `pageSize`（含流量汇总） |
| 19 | `follow` | POST | `/square/app/follows` | `targetAddr` |
| 20 | `followList` | GET | `/square/app/follows` | `page`, `pageSize` |
| 21 | `unfollow` | DELETE | `/square/app/follows/{addr}` | — |
| 22 | `followerList` | GET | `/square/app/followers` | `page`, `pageSize` |
| 23 | `report` | POST | `/square/app/posts/{postId}/report` | `reason`, `detail` |
| 24 | `uploadImages` | — | OSS 上传 | `SquareService.shared.uploadImages` |
| 25 | `commentReplies` | GET | `/square/app/posts/{postId}/comments/{commentId}/replies` | `page`, `pageSize`（某楼回复分页；`commentId` 必须是该帖一级评论） |
| 26 | `replyInbox` | GET | `/square/app/replies` | `read?`（nil 全部 / 0 未读 / 1 已读）, `page`, `pageSize`；响应含 `unreadCount` |
| 27 | `markRepliesRead` | POST | `/square/app/replies/read` | `ids: [Int]` 或 `all: true`；响应 `unreadCount` |

评论回复（《App增量-评论回复》）：回复统一挂在一条一级评论下；发回复带 `replyToId`（回复一条回复时服务端把 `parentId` 提到一级评论）。评论列表传 `thread=1` 时 `total` 是楼数、`commentCount` 是含回复的可见评论数，每楼 `replies` 最多 2 条。错误码 `-20418` = 不能回复该评论（不可见 / 已删 / 不属于该帖）。

数据门面 `SquareService`（`chat/Square/Network/SquareService.swift`），专用签名 `SquareSignature.swift`，模型与错误码 `chat/Square/M/SquareModels.swift`（`SquareResultCode`、`SquareFailure`、`SquarePage<T>`）。

#### 3.3.12 `ScanLoginAPI` — 扫码登录（`chat/Views/Login/scanLogin/ScanLoginAPI.swift`）

baseURL = `ScanLoginBaseURL`（未配置时为空字符串）。

二维码**只支持 v2（`type = "qr-login-v2"`，ECDH）**：二维码里只有 PC 临时公钥 `pubKey`，App 本地生成临时密钥对，用 `SHA256(ECDH 共享点 x)` 作为 AES 密钥加密私钥。旧版 `qr-login`（二维码里带对称 `key` / `iv`）已停用：扫到只提示「该二维码为旧版登录码，请在电脑端刷新后重试」，不再解析、不再发起登录。

| # | case | 方法 | 路径 | 参数 |
|---|---|---|---|---|
| 1 | `confirm` | POST | `/app/qr-login/confirm` | `sessionId`、`address`、`encryptedPrivateKey`（AES-GCM 密文 hex = `iv(12) ‖ 密文 ‖ authTag(16)`）、`phonePubKey`（App 临时公钥，33 字节压缩 hex）、`signature`（请求头 `FZM-SIGNATURE`） |
| 2 | `cancel` | POST | `/app/qr-login/cancel` | `sessionId`、`signature`（请求头 `FZM-SIGNATURE`） |

#### 3.3.13 AI 客服免登录（`chat/AI/M/AICustomerAPI.swift`，baseURL = `AICustomerConfig.siteURL`，默认未配置）

| # | 方法 | 路径 | 说明 |
|---|---|---|---|
| 1 | GET | `/api/auth/nonce?address=<0x…>` | 取 SIWE 原文（10s 超时） |
| 2 | POST | `/api/auth/login/user` | 提交 `address` + `signature`（EIP-191），返回 `token` / `uid` / `eth_address` / `role` / `session_id` / `livekit_token` / `room_name` |
| 3 | — | `/api/auth/refresh-livekit` | 页面刷新会话时使用（不计入登录限流），页面侧调用 |

错误约定：`400` = 原文过期/已用（**只重签一次**）；`401` = 鉴权失败（页面触发一次静默自愈）；`429` = 限流，直接失败不重试。

#### 3.3.14 语音房 H5（`chat/voice/M/VoiceRoomService.swift`，baseURL = `VoiceRoomBaseURL`）

不走 Moya（第三方 H5 后端，无项目签名/鉴权约定），用 `URLSession` 直连；host 三级回退：UserDefaults → Info.plist → `SeverContext.VoiceRoomBaseURL`。

| # | 方法 | 路径 | 参数 | 响应 |
|---|---|---|---|---|
| 1 | POST | `/api/v1/room/create` | `mode`（`voice` / `video`）、`owner`（房主 0x 地址） | `{code:0, room, pin, mode, owner}`；失败 `{code:1, error}` |

- 房间号 6 位（字符集去掉易混淆的 `0/1/o/i/l`）、PIN 4 位数字；服务的校验、撞号重试、PIN 限流都在服务端
- `user_addr` 为可选项：传了则进房者必须提供一致地址，**本项目不传**（不绑定身份）
- 其余接口（`/api/v1/token`、`/api/v1/room/owners`、`/api/v1/room/pin-status`）由 H5 页面自己调用，App 不参与

#### 3.3.15 `PriChatRecordAPI` / `ChatRecordAPI` — 聊天记录拉取与删除（`chat/BusinessTool/Network/API/`）

`PriChatRecordAPI`：服务端 `store` 服务的**私聊历史**接口，也是重装 / 换机后恢复消息的唯一数据源。

| # | 方法 | 路径 | 参数 | 说明 |
|---|---|---|---|---|
| 1 | POST | `store/app/pri-chat-record` | `targetId`（对端地址）、`count`、`logId`（分页游标，上一页最小 logId；不传=从最新开始） | 返回 `{record_count, records[]}`；消息体是 DH 密文，用对端公钥解密（`Message.serverRecords`） |

`ChatRecordAPI`：记录删除 / 阅后即焚（前缀 `app/record`），见 `ChatRecordAPI.swift` 注释。

- `app/record/clean-private`（`targetId` + `dateOpt`，自定义时加 `startTime` / `endTime`）
- `app/record/auto-delete/set`、`app/record/auto-delete/get`（`targetId` + `option`）
- `app/record/burn-confirm`（`targetId` + `logId`）

> ⚠️ **没有**群聊历史接口。群聊消息只能靠 socket `SyncMsg` 的**待投递队列**（断点 = 本地库该服务器最大 logId）补，重装后本地断点为 0，已投递过的群消息找不回来。

### 3.4 钱包服务（Objective-C）接口

baseURL = `WalletURL`（未配置时为空字符串），路径宏定义在 `chat/Views/MyDao/OCDepend/Depend.h`，请求走 `SGNetWork defaultManager`。

| 路径 | 方法 | 说明 |
|---|---|---|
| `/interface/banner` | GET | 首页 banner（`PWallet_Banners`） |
| `/interface/explore` | GET | DApp 探索列表（`Explore_Apps`） |
| `/interface/explore/banner` | GET | 探索 banner |
| `/interface/explore/search` | GET | 按 ID 查应用（`Explore_AppsByIDs`） |
| `/interface/explore/category` | GET | 应用分类（`Explore_Category`） |
| `/interface/application/cate-app-info` | GET | 分类应用信息 |
| `/interface/supported-chain` | GET | 钱包支持的链 |
| `/interface/recommend-coin/top` | GET | 首页推荐币种 |
| `/interface/recommend-coin` | GET | 推荐币种 |
| `/interface/coin/coin-index` | GET | 币种/NFT 详情索引 |
| `/interface/wallet-coin/search` | POST | 按链与平台搜币 |
| `/interface/coin/search-coin-by-name` | POST | 按币名搜币 |
| `/interface/coin/get-with-hold` | GET | 带持仓的币种信息（转账/浏览器用） |
| `/interface/notice/list` | GET | 公告列表 |
| `/interface/notice/detail` | GET | 公告详情 |
| `/goapi/interface/tokenview/explore?platform=` | GET | 单币种交易浏览（`TRADEGETBROWER`） |
| `/goapi/interface/fees/recommended` | GET | 推荐矿工费（也可走 `https://www.bitfeel.cn`） |
| `/v1/data/download-info` | GET | 钱包数据下载信息（`WalletInfo`） |

其它地址：
- `UPDATEJSON` = `https://mydao.s3.ap-northeast-2.amazonaws.com/Mydao/mydaoios.json`
- `SLGNFTURL` = `https://183.129.226.77:8083`
- 应用下载/版本检查（OC）：`https://m.bitfeel.cn`（见 `Depend.h` 与钱包工具类）

### 3.5 文件上传（OSS / OBS）

| 步骤 | 说明 | 文件 |
|---|---|---|
| 1. 取凭证 | `TokenAPI.OSSToken` → `/oss/get-token`；`TokenAPI.OBSToken` → `/oss/get-huaweiyun-token` | `API/TokenAPI.swift` |
| 2. 上传 | 阿里云 OSS（`OSS.swift`）/ 华为云 OBS（`OBS.swift`）、`chat/ProjectBase/OSSClient/IMOSSClient.swift` | — |
| 3. 聊天媒体 | 上传前用 `ChatManager+Encryption.encryptUploadData` 加密，路径带 `$ENC$` 标志 | `ChatManager+Network.swift` |
| 4. 视频压缩 | 发送前用 `ChatVideoCompressor` 按**目标码率**转码（H.264/AAC，长边 ≤720p、1.2Mbps）：`AVAssetExportSession` 的预设只按画质调，压不住体积（127s 的 4K 源会导出 ~159MB，服务端拒收）；转码失败时退回系统预设 | `ChatView/VM/ChatVideoCompressor.swift`、`ChatVC.swift` |
| 备用入口 | `BackUpOSSURL` = `BackupURL + "/oss/upload"`；`OSS_AUTH_SERVER` = `BackupURL + "/oss/get-token"` | `SeverContext.swift` |

### 3.6 长连接（Socket）协议

实现：`chat/BusinessTool/Socket/`（`MultipleSocketManager` 管理多聊天服务器连接、心跳与重连；`SocketManager` 为单连接核心）。

协议定义（Protobuf）：
- `chat/BusinessTool/Proto/socket.proto` — 传输层信封 `Skt{ver, op, seq, ack, body}`
- `chat/BusinessTool/Proto/msg.proto` — 业务层 `event` / `msg` / 通知与信令
- 生成代码：`msg.pb.swift`、`socket.pb.swift`；桥接：`PbMsg_msg+Message.swift`、`PbMsg_event+Message.swift`

#### 操作码 `Op`（socket.proto）

| Op | 值 | 说明 |
|---|---|---|
| Undefined | 0 | — |
| Auth / AuthReply | 1 / 2 | 鉴权（`AuthMsg{appId, token, ext}`） |
| Heartbeat / HeartbeatReply | 3 / 4 | 心跳 |
| Disconnect / DisconnectReply | 5 / 6 | 断开 |
| SendMsg / SendMsgReply | 7 / 8 | 发消息 / 回执（`SendMsgAck`） |
| ReceiveMsg / ReceiveMsgReply | 9 / 10 | 收消息 / 回执 |
| ProtoReady / ProtoFinish | 11 / 12 | 协议就绪 |
| Raw | 13 | 透传 |
| SyncMsgReq / SyncMsgReply | 14 / 15 | 离线消息同步 |
| RePush | 16 | 重推 |

登录消息：`Login{device, username, deviceToken, connType(Connect/Reconnect), uuid, deviceName}`；`Device` 枚举：Android 0 / **IOS 1** / Windows 2 / Linux 3 / MacOS 4 / Web 5。

#### 事件类型 `EventType`
`message = 0`（普通消息）、`messageAck = 1`（消息回复）、`notice = 2`（通知信令）。

#### 业务信令 `ActionType`（`NotifyMsg{action, body, sid, reliable}`）

| 值 | 名称 | 说明 |
|---|---|---|
| 0 | Received | 送达回执（`ActionReceived{logs}`） |
| 1 | Revoke | 撤回 |
| 2 | DeleteMessages | 删除聊天记录多端同步（`ActionDeleteMessages`） |
| 10 / 11 / 12 | SignInGroup / SignOutGroup / DeleteGroup | 加群 / 退群 / 删群 |
| 13 | FocusMessage | 关注消息 |
| 14 | EndpointLogin | 多端登录（异地登录踢下线，`ActionEndpointLogin{uuid, device, deviceName, datetime}`） |
| 20 | UpdateGroupJoinType | 更新加群权限 |
| 21 | UpdateGroupFriendType | 更新群加好友权限 |
| 22 | UpdateGroupMuteType | 更新群禁言类型 |
| 23 | UpdateGroupMemberType | 更新群成员角色 |
| 24 | UpdateGroupMemberMuteTime | 更新禁言列表 |
| 25 / 26 | UpdateGroupName / UpdateGroupAvatar | 更新群名 / 群头像 |
| 31 / 32 / 33 | StartCall / AcceptCall / StopCall | 通话信令（`StopCallType`：Busy 0 / Timeout 1 / Reject 2 / Hangup 3 / Cancel 4） |

#### 群内灰色通知 `NotificationType`

`0` 修改群名、`1` 加群、`2` 退群、`3` 踢群、`4` 删群、`5` 群禁言模式变更、`6` 禁言名单变更、`7` 更换群主、`8` `MsgRevoked`（撤回，客户端占用）。

#### 业务消息体（`msg.proto` 主要 message）

| 消息类型 | 结构 |
|---|---|
| Text | `TextMsg{content, mention[]}`（`mention` = @谁） |
| Audio | `AudioMsg{mediaUrl, time}` |
| Image | `ImageMsg{mediaUrl, height, width}` |
| Video | `VideoMsg{mediaUrl, time, height, width}` |
| File | `FileMsg{mediaUrl, name, md5, size}` |
| Notification | `NotificationMsg{type, body}` |
| Forward | `ForwardMsg{items[]}` → `ForwardItem{avatar, name, msgType, msg, datetime}` |
| Transfer | `TransferMsg{txHash, coinName}` |
| RedPacket | `RedPacketMsg{txHash, coinName, exec, packetType(RandomAmount/IdenticalAmount), privateKey, remark, expire}` |
| ContactCard | `ContactCardMsg{type(Undefined/Personal), id, name, avatar}` |
| 信封 | `msg{channelType, logId, msgId, from, target, msgType, msg, datetime, source, reference}` |
| 引用 | `Reference{topic, ref}` |

Socket 发送入口：`SocketManager+Msg.send(msg:publickey:)`；多服务器/HTTP 兜底：`MultipleSocketManager.send(msg:chatServerUrl:publickey:)`。

---

## 四、数据存储

| 存储 | 位置 / 说明 |
|---|---|
| WCDB 表定义 | `chat/BusinessTool/Database/sql/Table/`：`MessageDB`、`SessionDB`、`UserDB`、`GroupDB`、`GroupMemberDB`、`StaffInfoDB`、`EnterpriseDB`、`VirtualMessageDB` |
| DB 管理与约束 | `chat/BusinessTool/Database/sql/DBManager.swift`、`Constraint.swift` |
| 全文搜索 | 独立的 virtualFTS 库（`chat/Views/FullTextSearch/`） |
| Keychain | `KeychainAccess`：助记词分片 S2、私钥缓存（`WalletPrivateKeyStore`）、密码（`BiometricPasswordStore`） |
| 钱包本地库（OC） | `chat/Views/MyDao/OCDepend/PWDataBaseManager.m`（钱包、币种、行情 `CoinPrice`、订单） |
| UserDefaults | 服务器地址、链选择（`PWAPPLocalizableNetType`）、AI 客服站点、设备 Token 等 |

---

## 五、已知缺口与注意事项

### 代码中明确不存在的能力
| 项 | 状态 |
|---|---|
| WalletConnect | `chat/WalletConnect/` 为空目录；**2026-10-29 评估后决定不接入**（Project ID 依赖官方 relay + 上架审核风险 + 历史接入经验有运行期闪退） |
| 位置消息 | `MsgType` 无位置项，无位置 Cell |
| 好友申请 / 新的朋友 | 无独立页面（加好友直接调 `UserManager.addFriend`） |
| 好友标签 / 星标 / 分组 | 无实现 |
| 独立行情页 / 自选列表 | 无（价格内嵌在资产列表与币种详情） |
| NFT 独立页面 | 无（只有 `PWNFTRequest.h` 模型与交易页编号输入） |
| 实名认证页 / 关于页 / 清缓存页 | 无 |
| 一键登录 / 微信·Apple 登录 | 无（只有账号绑定） |
| 多设备登录管理页 | 无（仅 Socket 踢下线） |
| 广场「收藏」 | 无（只有点赞 / 关注） |
| 语音·视频通话 | `RTCCall` 枚举与信令存在，**原生信令仍未启用**；语音 / 视频聊天走 H5 —— `chat/voice/` 模块 + DApp 浏览器内嵌 LiveKit 页面，无原生通话页 / 来电页 / 独立悬浮窗（悬浮框只能浮在 App 内）。⚠️ 2026-10-16 起入口项名改「语音聊天」、发起弹窗只保留语音选项（H5 与建房接口仍支持 `mode=video`） |

### 需要注意的实现细节
1. **`ChatHistoryAPI` 是占位实现**：path `/chat/history/delete` 与字段待服务端确认。
2. **`GroupAPI.revoke` 的 path 是 `app/record/revoke`（无前导 `/`）**，与同枚举其它接口前缀不一致。
3. **广场响应 HTTP 恒 200**，必须看 body 的 `result`；`SquareAPI` / `ScanLoginAPI` / `BlockchainAPI` 都**覆盖了基类 validation**，不要用「HTTP 200 = 成功」判断。
4. **广场基址就是 `https://3syxin.com`**（`http://47.79.39.101:18100` 是后端测试环境），不要为「试增量接口」改客户端基址。
5. **`ExploreVC.m`（`chat/Views/MyDao/探索/`）是死代码**，全仓无实例化；发现 Tab 的根是 `ExploreSearchViewController`。
6. 仓库历史记忆中的 `AIAPIManager.swift` / `ChatManager+AI.swift`（聊天内 AI 助手）**在本分支不存在**，本分支只有 `chat/AI/` 的 H5 免登录客服。
7. 会话列表的「小Y」是**渲染层虚拟行**，不写库、不允许删除，只允许置顶。
8. `TeamAPI` 与所有团队入口受 `FZM_EnableEnterpriseFeature = false` 控制，涉及团队的功能点当前均隐藏/不请求。
9. `S1BackUpAPI` 的 baseURL 已改为空字符串（未配置时请求失败），环境切换时需在代码中补齐。
10. OC 钱包侧接口路径多为 `#define` 宏（`Depend.h`），改动时注意宏与调用点两处。
11. **EIP-712（`eth_signTypedData` / `_v3` / `_v4`）已在 Swift DApp 浏览器实现**（`chat/dapp/EIP712TypedData.swift`，2026-10-29）；**旧 OC 浏览器未实现**，确认签名后回 `-32601`（不再返回空串）。
12. **兑换（DEX Swap）功能已下线**：`chat/exchange` 模块、发现页入口及相关本地化均已删除；授权管理页保留，链配置见 `TokenApproveService.swift` 的 `TokenChainConfig`。
13. 兑换功能下线后，DApp 浏览器内的第三方 Swap 仍会展示「兑换」交易信息（`WebViewMetaMaskCoordinator`），与已删除的 App 内兑换功能无关。

---

*文档生成时间：2026-09-30 ｜ 最后更新：2026-11-12（下线兑换模块、服务器/第三方配置置空）｜ 依据：当前工作区分支的源码*
