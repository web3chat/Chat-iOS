//
//  WebMediaPermission.swift
//  chat
//
//  麦克风权限（语音房 H5 用）。
//
//  【为什么单独写】本工程原先只有相机权限工具（`PWAuthorizationTool`，OC），
//  全仓没有任何麦克风权限请求代码（grep `requestRecordPermission` / `AVAudioApplication` 均为 0 命中）。
//
//  ⚠️ 部署目标：app target 级是 iOS 15.6（`chat.xcodeproj/project.pbxproj`），所以**必须双分支**：
//     · iOS 17+ 用 `AVAudioApplication`（`AVAudioSession.requestRecordPermission` 在 iOS 17 起标记 deprecated）
//     · iOS 15 / 16 用 `AVAudioSession.requestRecordPermission`
//
//  跳设置的引导形态照 `ScanViewController.m:92-98`（相机版）：
//  `UIApplication.openSettingsURLString` + 「取消 / 确定」两按钮。
//

import AVFoundation
import UIKit

enum WebMediaPermission {

    /// 请求麦克风权限。
    /// - Parameters:
    ///   - granted: 已授权，或本次刚被用户允许
    ///   - denied: 被拒绝 / 受限 —— 调用方负责提示并引导去系统设置
    static func requestMicrophone(granted: @escaping () -> Void, denied: @escaping () -> Void) {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                granted()
            case .denied:
                denied()
            case .undetermined:
                AVAudioApplication.requestRecordPermission { allowed in
                    DispatchQueue.main.async { allowed ? granted() : denied() }
                }
            @unknown default:
                denied()
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                granted()
            case .denied:
                denied()
            case .undetermined:
                session.requestRecordPermission { allowed in
                    DispatchQueue.main.async { allowed ? granted() : denied() }
                }
            @unknown default:
                denied()
            }
        }
    }

    /// 被拒绝时的引导弹窗：去系统设置打开麦克风权限
    static func showDeniedGuide(from host: UIViewController?) {
        guard let host = host else { return }
        let alert = UIAlertController(
            title: L("麦克风"),
            message: L("请前往设置打开麦克风权限"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("确定"), style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        })
        host.present(alert, animated: true)
    }
}
