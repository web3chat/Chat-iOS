//
//  SettingVC.swift
//  chat
//
//  Created by 王俊豪 on 2021/4/15.
//

import UIKit
import SnapKit
import SwifterSwift
import RxSwift
import MBProgressHUD

class SettingVC: UIViewController, ViewControllerProtocol {
    
    private lazy var headerView: UIView = {
        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth - 30, height: 15))
        view.backgroundColor = Color_F6F7F8
        return view
    }()
    
    private lazy var listview: UITableView = {
        let view = UITableView.init(frame: CGRect.zero, style: .plain)
        view.backgroundColor = Color_F6F7F8
        view.dataSource = self
        view.delegate = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.separatorStyle = .none
        view.estimatedRowHeight = 50
//        view.estimatedSectionHeaderHeight = 15
        view.register(SettingTextCell.self, forCellReuseIdentifier: "SettingTextCell")
        view.register(SettingSwitchCell.self, forCellReuseIdentifier: "SettingSwitchCell")
        view.tableHeaderView = headerView
        
        return view
    }()
    
    private lazy var offlineNoti: SettingSwitchCellModel = {
        let model = SettingSwitchCellModel.init()
        model.leftString = L("离线通知")
        model.isShowLine = true
        model.switchChangeBlock = { [weak self] isSwitchOn in
            self?.offlineNotiChanged(isOn: isSwitchOn)
        }
        
        return model
    }()
    
    // 多语言
    private lazy var languageModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("多语言")
        model.rightString = self.currentLanguageDisplayName()
        model.isShowLine = true
        model.selectedBlock = { [weak self] in
            self?.goLanguageSetting()
        }
        return model
    }()
    
    // 存储空间（总占用 / 聊天记录 / 缓存，进入二级页）
    private lazy var storageModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("存储空间")
        model.rightString = ""
        model.isShowLine = true
        model.selectedBlock = { [weak self] in
            self?.goStorageSpace()
        }
        return model
    }()

    /// 修复聊天记录：手动把同步断点按天回退，让服务端重推这段时间的消息。
    /// 用于救「自动补拉覆盖不到」的缺口（会话中间缺一条，后面已经有本地消息了）。
    private lazy var repairModel: SettingTextCellModel = {
        let model = SettingTextCellModel.init()
        model.leftString = L("修复聊天记录")
        model.rightString = ""
        model.isShowLine = false
        model.selectedBlock = { [weak self] in
            self?.showRepairRecordsAlert()
        }
        return model
    }()
    
    /// 面容/指纹替代密聊密码（设备不支持或未录入人脸/指纹时不显示该行）
    private lazy var biometricModel: SettingSwitchCellModel = {
        let model = SettingSwitchCellModel.init()
        model.leftString = L("面容/指纹验证")
        model.isShowLine = true
        model.switchChangeBlock = { [weak self] isSwitchOn in
            self?.biometricChanged(isOn: isSwitchOn)
        }
        return model
    }()
    
    private lazy var dataSource: [[SettingCellModel]] = {
        var rows: [SettingCellModel] = [offlineNoti]
        // 面容/指纹入口：总开关打开且当前设备真的可用（已录入人脸/指纹）时才显示
        if FZM_EnableBiometricUnlock && BiometricAuthManager.shared.isDeviceSupported {
            rows.append(biometricModel)
        }
        // 多语言入口开关（FZM_EnableMultiLanguage 打开即显示）
        if FZM_EnableMultiLanguage {
            rows.append(languageModel)
        }
        // 存储空间（始终显示）
        rows.append(storageModel)
        // 修复聊天记录（放在最后）
        rows.append(repairModel)
        return [rows]
    }()
    
    private var unRegisterRemoteNotifi = false// 关闭消息推送
    
    private var languageChangeObserver: NSObjectProtocol?
    
    deinit {
        if let observer = languageChangeObserver {
            FZM_NotificationCenter.removeObserver(observer)
        }
        if let observer = repairSyncObserver {
            FZM_NotificationCenter.removeObserver(observer)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.applyLocalizedStrings()
        
        self.view.backgroundColor = Color_F6F7F8
        self.xls_navigationBarTintColor = Color_24374E
        self.xls_navigationBarBackgroundColor = Color_F6F7F8
//        self.xls_isNavigationBarHidden = false
        
        self.view.addSubview(self.listview)
        listview.snp.makeConstraints { (m) in
            m.top.bottom.equalToSuperview()
            m.left.equalToSuperview().offset(15)
            m.right.equalToSuperview().offset(-15)
        }
        
        // 读取本地存储的友盟推送关闭flg
        let flg = FZM_UserDefaults.bool(forKey: CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY)
        if flg {
            self.unRegisterRemoteNotifi = true
        } else {
            self.unRegisterRemoteNotifi = false
        }
        
        self.offlineNoti.isSwitchOn = !self.unRegisterRemoteNotifi
        
        // 面容/指纹开关状态（按账号存，切换账号后各看各的）
        self.biometricModel.isSwitchOn = BiometricAuthManager.shared.isEnabled
        
        // 语言切换后刷新全部 L() 文案
        languageChangeObserver = FZM_NotificationCenter.addObserver(forName: LanguageManager.LanguageChangedNotification, object: nil, queue: .main) { [weak self] (_) in
            guard let self = self else { return }
            self.applyLocalizedStrings()
            self.listview.reloadData()
        }
        
        listview.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从多语言页面返回时刷新全部文案
        self.applyLocalizedStrings()
        // 系统里的指纹/面容被改动导致绑定作废时，门面会把开关关掉，这里同步显示
        self.biometricModel.isSwitchOn = BiometricAuthManager.shared.isEnabled
        self.listview.reloadData()
    }
    
    // 语言切换后重建全部 L() 文案（标题、cell 文本行）
    private func applyLocalizedStrings() {
        self.title = L("设置中心")
        offlineNoti.leftString = L("离线通知")
        biometricModel.leftString = L("面容/指纹验证")
        languageModel.leftString = L("多语言")
        languageModel.rightString = self.currentLanguageDisplayName()
        storageModel.leftString = L("存储空间")
        repairModel.leftString = L("修复聊天记录")
    }
    
    // 当前语言显示名（与语言选择页完全一致：本地名(中文名)，简体中文不带括号）
    private func currentLanguageDisplayName() -> String {
        return LanguageManager.shared.currentLanguageDisplayName
    }
    
    // 跳转「存储空间」
    private func goStorageSpace() {
        let vc = StorageSpaceVC()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    // 跳转多语言设置页（复用钱包模块的 PWLanguageViewController，ChangeLang 模式）
    private func goLanguageSetting() {
        let vc = PWLanguageViewController(changeType: ChangeLang)
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - 修复聊天记录（手动重新同步离线消息）

    /// 二次确认后选择恢复方式：
    /// - 「恢复私聊记录」：按好友列表从服务端重拉私聊历史（重装 / 换机后消息消失用这个）；
    /// - 「重新同步」：让所有聊天服务器重跑一次离线消息同步。
    ///
    /// ⚠️ 实测结论（2026-11-02）：`syncMsg` 是**服务端待投递队列**的消费协议，不是历史游标 ——
    ///    把 logId 退到 1 天前，服务端只会回一个空的 `syncMsgReply`，一条消息都不重推。
    ///    「重新同步」只能补回「服务器还没投递成功」的消息；
    ///    「恢复私聊记录」走的是 `store/app/pri-chat-record` 记录接口，能整段拉回私聊历史。
    ///    群聊历史服务端没有接口，两种方式都恢复不了。
    private func showRepairRecordsAlert() {
        let alert = UIAlertController(
            title: L("修复聊天记录"),
            message: L("「恢复私聊记录」会按好友列表从服务端重新拉取私聊历史，重装或换设备后消息不见了用这个；「重新同步」只会让服务器重推还没投递成功的离线消息。群聊历史服务端没有接口，无法恢复。"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("恢复私聊记录"), style: .default) { [weak self] _ in
            self?.startRecoverPrivateRecords()
        })
        alert.addAction(UIAlertAction(title: L("重新同步"), style: .default) { [weak self] _ in
            self?.startDeepResync(days: 1)
        })
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel))
        self.present(alert, animated: true)
    }

    /// 手动从服务端恢复私聊记录（后台串行执行，不挡界面）
    private func startRecoverPrivateRecords() {
        self.showToast(L("已开始恢复私聊记录，稍后回到会话列表查看"))
        ChatManager.shared().recoverPrivateRecordsFromServer { [weak self] summary in
            guard let self = self else { return }
            if summary.cancelled {
                self.showToast(L("恢复已中止（账号已切换）"))
                return
            }
            guard summary.totalTargets > 0 else {
                self.showToast(L("本机没有好友或会话，没有可恢复的对象"))
                return
            }
            let text = String(format: L("恢复完成：%@ 个会话 / %@ 条消息"),
                              "\(summary.restoredSessions)", "\(summary.restoredMessages)")
            self.showToast(summary.failedSessions > 0 ? text + L("（部分会话拉取失败，请检查网络后重试）") : text)
        }
    }

    /// 「重新同步」进度状态：服务端一次推送会漏消息，所以整个过程要断开重连好几轮，
    /// 这里把「第几轮」显示出来，全部拉完才收起 HUD。
    private var isRepairSyncing = false
    private var repairSyncRound = 0
    private var repairSyncObserver: NSObjectProtocol?

    private func startDeepResync(days: Int) {
        self.isRepairSyncing = true
        self.repairSyncRound = 0
        self.showProgress(with: L("正在同步…"))
        self.observeRepairSyncIfNeeded()

        // 延后一拍：先让 progress 出来，再开始退断点（socket 线程上发，不阻塞主线程）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let started = MultipleSocketManager.shared().deepResyncAllServers(days: days)
            if !started {
                self.finishRepairSync(showToast: L("当前没有可用的聊天连接，请检查网络后重试"))
            }
            // 兜底：万一因为节流等原因没有触发同步，20 秒后也把 HUD 收掉，别一直转
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self = self, self.isRepairSyncing, self.repairSyncRound == 0 else { return }
                self.finishRepairSync(showToast: L("已开始重新同步，稍后重新进入会话查看"))
            }
        }
    }

    /// 监听离线同步状态：每开始一条链算一轮，全部结束才收 HUD
    private func observeRepairSyncIfNeeded() {
        guard self.repairSyncObserver == nil else { return }
        self.repairSyncObserver = FZM_NotificationCenter.addObserver(
            forName: FZM_Notify_OfflineSyncStateChanged, object: nil, queue: .main
        ) { [weak self] (_) in
            guard let self = self, self.isRepairSyncing else { return }
            if MultipleSocketManager.shared().isAnyOfflineSyncing {
                self.repairSyncRound += 1
                self.updateRepairSyncText()
            } else {
                self.finishRepairSync(showToast: L("已开始重新同步，稍后重新进入会话查看"))
            }
        }
    }

    /// 更新 HUD 文案为「第 N 轮」（直接改 label，避免反复创建 HUD 闪屏）
    private func updateRepairSyncText() {
        let text = String(format: L("正在同步（第 %@ 次）…"), "\(self.repairSyncRound)")
        if let hud = MBProgressHUD.forView(self.view) {
            hud.label.text = text
        } else {
            self.showProgress(with: text)
        }
    }

    private func finishRepairSync(showToast text: String?) {
        self.isRepairSyncing = false
        self.hideProgress()
        if let text = text, !text.isEmpty {
            self.showToast(text)
        }
    }
    
    private func offlineNotiChanged( isOn: Bool ) {
        self.unRegisterRemoteNotifi = !isOn
        // 先落盘开关，再走统一入口同步注册状态（syncPushRegistration 会读这个 flg）
        FZM_UserDefaults.set(self.unRegisterRemoteNotifi, forKey: CHAT33PRO_UNREGISTER_REMOTENOTIFICATION_KEY)
        AppDelegate.shared().syncPushRegistration()
        self.showToast(isOn ? L("离线通知开启") : L("离线通知关闭"))
    }
    
    // MARK: - 面容/指纹验证（替代密聊密码）
    
    /// 开关交互：开启 = 先输密聊密码校验通过 → 再验一次人脸/指纹完成绑定；
    /// 关闭 = 弹窗二次确认后再删除本账号绑定（降级操作不需要验证）
    private func biometricChanged(isOn: Bool) {
        guard isOn else {
            self.confirmDisableBiometric()
            return
        }
        
        let address = LoginUser.shared().address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            self.resetBiometricSwitch()
            self.showToast(L("请先登录"))
            return
        }
        guard BiometricAuthManager.shared.isDeviceSupported else {
            self.resetBiometricSwitch()
            self.showToast(L("当前设备不支持面容/指纹识别"))
            return
        }
        
        // 1. 先输入密聊密码并校验
        self.showBindPasswordAlert(address: address)
    }
    
    /// 关闭前的二次确认：取消 = 开关拨回开启、绑定不动；确定 = 删除本账号绑定
    private func confirmDisableBiometric() {
        let alert = UIAlertController(title: L("提示"),
                                      message: L("确定关闭面容/指纹验证"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: { [weak self] (_) in
            self?.resetBiometricSwitch(isOn: true)
        }))
        alert.addAction(UIAlertAction(title: L("确定"), style: .default, handler: { [weak self] (_) in
            guard let self = self else { return }
            BiometricAuthManager.shared.disable()
            self.resetBiometricSwitch(isOn: false)
            self.showToast(L("已关闭面容/指纹验证"))
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    /// 绑定流程：密聊密码校验通过后，再验证人脸/指纹，两者都过才写入绑定
    private func showBindPasswordAlert(address: String) {
        let alert = InputAlertView()
        alert.title = L("请输入密聊密码")
        alert.textFieldAttributedPlaceholder = NSAttributedString(
            string: L("请输入密码"),
            attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                         NSAttributedString.Key.foregroundColor: Color_8A97A5])
        alert.isSecureTextEntry = true
        // ⚠️ InputAlertView 在「确定」后也会触发 hideBlock，用这个标记区分「提交」与「取消」
        var didConfirm = false
        alert.confirmBlock = { [weak self] password in
            didConfirm = true
            guard let self = self else { return }
            let wallet = PWDataBaseManager.shared().queryWalletIsSelected()
            guard GoFunction.checkPassword(password, hash: wallet?.wallet_password) else {
                self.showToast(L("密码错误"))
                self.resetBiometricSwitch()
                return
            }
            // 2. 密码正确后再验人脸/指纹，通过才写绑定（绑定 = 账号 + 密聊密码 + 本机生物识别）
            BiometricAuthManager.shared.authenticate(reason: L("验证身份以开启面容/指纹验证")) { [weak self] success in
                guard let self = self else { return }
                guard success else {
                    self.resetBiometricSwitch()
                    return
                }
                if BiometricAuthManager.shared.enable(withPassword: password, boundAddress: address) {
                    self.biometricModel.isSwitchOn = true
                    self.listview.reloadData()
                    self.showToast(L("面容/指纹验证已开启"))
                } else {
                    self.showToast(L("开启失败，请稍后再试"))
                    self.resetBiometricSwitch()
                }
            }
        }
        alert.hideBlock = { [weak self] in
            if !didConfirm { self?.resetBiometricSwitch() }
        }
        alert.show()
    }
    
    /// 开启流程中断（取消/失败）时把开关拨回去，避免界面状态与实际不一致
    /// - Parameter isOn: 目标开关状态（默认 false；关闭确认被取消时传 true 拨回开启）
    private func resetBiometricSwitch(isOn: Bool = false) {
        self.biometricModel.isSwitchOn = isOn
        self.listview.reloadData()
    }
}

extension SettingVC: UITableViewDelegate, UITableViewDataSource {
//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let view = UIView.init(frame: CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: 15))
////        view.backgroundColor = self.listview.backgroundColor
//        view.backgroundColor = UIColor.red
//
//        return view
//    }
//
//    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return section == 0 ? 15 : 0
//    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 50 : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell.init()
        
        guard dataSource.count > indexPath.section else {
            return cell
        }
        let sectionData = dataSource[indexPath.section]
        guard sectionData.count > indexPath.row else {
            return cell
        }
        let model = sectionData[indexPath.row]
        
        // 按模型类型区分 switch 行与文本行
        let isSwitchCell = (model as? SettingSwitchCellModel) != nil
        
        if isSwitchCell {
            let switchCell = tableView.dequeueReusableCell(withClass: SettingSwitchCell.self, for: indexPath)
            guard let model = model as? SettingSwitchCellModel else {
                return switchCell
            }
            switchCell.configure(with: model)
            
            cell = switchCell
        } else {
            let textCell = tableView.dequeueReusableCell(withClass: SettingTextCell.self, for: indexPath)
            guard let model = model as? SettingTextCellModel else {
                return textCell
            }
            textCell.configure(with: model)
            
            cell = textCell
        }
        
        if indexPath.section == 0 {
            // 圆角按「首行/末行」判断：行数会随开关变化（多语言、面容/指纹入口）
            let isFirstRow = indexPath.row == 0
            let isLastRow = indexPath.row == sectionData.count - 1
            if isFirstRow && isLastRow {
                DispatchQueue.main.async {
                    cell.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 5)
                }
            } else if isFirstRow {
                DispatchQueue.main.async {
                    cell.roundCorners([.topLeft, .topRight], radius: 5)
                }
            } else if isLastRow {
                DispatchQueue.main.async {
                    cell.roundCorners([.bottomLeft, .bottomRight], radius: 5)
                }
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard dataSource.count > indexPath.section else { return }
        let sectionData = dataSource[indexPath.section]
        guard sectionData.count > indexPath.row else { return }
        sectionData[indexPath.row].selectedBlock?()
    }
}

