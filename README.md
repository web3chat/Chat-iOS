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
BackupURL 主域名
TeamH5Url 组织架构（可为空）
OKRH5Url OKR（可为空）
APP_URL 分享地址，用于加好友等操作，需与安卓端保持一致
USER_SERVER_AGREEMENT_URL 用户协议地址 
WalletURL 钱包域名
GoNodeUrl go包节点
BlockchainPriKey 代扣地址 需要配置，很重要
