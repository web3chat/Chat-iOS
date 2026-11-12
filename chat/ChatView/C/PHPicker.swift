//
//  PHPicker.swift
//  chat
//
//  Created by 郑晨 on 2026/3/18.
//

import UIKit
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct PickerResult {
    var image: UIImage?
    var gifData: Data?
    var videoURL: URL?
    var asset: PHAsset?        // <<< 新增：保存对应的 PHAsset 属性
    
    enum MediaType {
        case image, gif, video, unknown
    }
    var mediaType: MediaType = .unknown
}

@objc class SystemMediaPicker: NSObject {
    
    static let shared = SystemMediaPicker()
    private var completionHandler: (([PickerResult]) -> Void)?
    
    // MARK: - 主入口
    /// - Parameter imagesOnly: true 时只展示图片（广场发帖用）；false 时与聊天一致（图片 + 视频）
    func present(from viewController: UIViewController, maxCount: Int = 9, imagesOnly: Bool = false, completion: @escaping ([PickerResult]) -> Void) {
        self.completionHandler = completion
        
        // 关键点：传入 photoLibrary 才能在结果中拿到 assetIdentifier
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = maxCount
        configuration.filter = imagesOnly ? .images : .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    // MARK: - 全 App 统一的「选图 → 识别二维码」（扫一扫）

    /// 给 Swift / OC 两个扫一扫页面共用的唯一入口：选一张图并识别其中的二维码。
    /// 用系统 PHPicker ⇒ **不需要相册权限**，也不会因为用户只授权「部分照片」而只看到几张。
    /// - Parameters:
    ///   - viewController: 发起选择的控制器
    ///   - completion: `cancelled == true` 表示用户取消；`code == nil` 表示选了图但没识别到
    @objc static func pickQRCode(from viewController: UIViewController,
                                 completion: @escaping (Bool, String?) -> Void) {
        shared.present(from: viewController, maxCount: 1, imagesOnly: true) { results in
            guard let first = results.first else {
                completion(true, nil)
                return
            }
            let picked = first.image ?? first.gifData.flatMap { UIImage(data: $0) }
            guard let image = picked else {
                completion(false, nil)
                return
            }
            // 相册图里的二维码往往很小 / 只占一角：多档兜底识别，识别是同步重活，放后台
            DispatchQueue.global(qos: .userInitiated).async {
                let value = QRCodeGenerator.robustQRCodes(in: image).first?.value
                    ?? QRCodeGenerator.detectorQRCode(with: image)
                DispatchQueue.main.async {
                    completion(false, value)
                }
            }
        }
    }
}

// MARK: - 相册「部分照片」（受限访问）提示

/// iOS 14+ 用户可以选择「允许访问部分照片」。
/// 所有打开相册的入口统一走 `preparePhotoAccess(from:limitedMessage:onProceed:)`：
/// · 未决定 → 请求授权（系统弹框）
/// · 已授权 → 直接继续
/// · 部分照片 → 提示一次，并提供「选择更多照片」入口
/// · 拒绝 / 系统限制 → 引导去设置
@objc final class PhotoLibraryAccess: NSObject {

    /// 当前是否只授权了「部分照片」
    @objc static var isLimited: Bool {
        return fzm_isLimited(currentStatus())
    }

    /// 本次启动是否已经提示过「部分照片」（避免每次点相册都弹）
    private static var promptedLimitedThisLaunch = false

    private static func currentStatus() -> PHAuthorizationStatus {
        if #available(iOS 14, *) {
            return PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
        return PHPhotoLibrary.authorizationStatus()
    }

    private static func fzm_isLimited(_ status: PHAuthorizationStatus) -> Bool {
        if #available(iOS 14, *) {
            return status == .limited
        }
        return false
    }

    /// 打开系统相册前的统一权限处理。
    /// - Parameters:
    ///   - viewController: 弹框宿主
    ///   - limitedMessage: 「部分照片」时的入口专属说明；`nil` 用默认文案
    ///   - onProceed: 权限就绪（或用户确认继续）后执行 —— 真正打开选择器
    @objc(preparePhotoAccessFrom:limitedMessage:onProceed:)
    static func preparePhotoAccess(from viewController: UIViewController,
                                   limitedMessage: String?,
                                   onProceed: @escaping () -> Void) {
        func handle(_ status: PHAuthorizationStatus) {
            if status == .authorized {
                onProceed()
                return
            }
            if fzm_isLimited(status) {
                if promptedLimitedThisLaunch {
                    onProceed()
                    return
                }
                promptedLimitedThisLaunch = true
                showLimitedAlert(from: viewController, message: limitedMessage, onProceed: onProceed)
                return
            }
            showDeniedAlert(from: viewController)
        }

        let status = currentStatus()
        if status == .notDetermined {
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    DispatchQueue.main.async { handle(newStatus) }
                }
            } else {
                PHPhotoLibrary.requestAuthorization { newStatus in
                    DispatchQueue.main.async { handle(newStatus) }
                }
            }
        } else {
            handle(status)
        }
    }

    private static func showLimitedAlert(from viewController: UIViewController,
                                         message: String?,
                                         onProceed: @escaping () -> Void) {
        let alert = UIAlertController(
            title: L("提示"),
            message: message ?? L("你当前只允许访问「部分照片」，因此部分页面只能看到已授权的照片。"),
            preferredStyle: .alert
        )
        if #available(iOS 14, *) {
            alert.addAction(UIAlertAction(title: L("选择更多照片"), style: .default) { _ in
                // 等 alert 收起再 present，否则会报 “already presenting”
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
                }
            })
        }
        alert.addAction(UIAlertAction(title: L("确定"), style: .default) { _ in
            onProceed()
        })
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        viewController.present(alert, animated: true)
    }

    private static func showDeniedAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: L("提示"),
            message: L("系统相册权限未打开，请设置"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("去设置"), style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        viewController.present(alert, animated: true)
    }
}

extension SystemMediaPicker: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard !results.isEmpty else {
            self.completionHandler?([])
            return
        }
        
        // 1. 提取所有选中的 localIdentifiers
        let identifiers = results.compactMap { $0.assetIdentifier }
        
        // 2. 通过 PHAsset 批量获取属性 (保持原始索引)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetMap = [String: PHAsset]()
        fetchResult.enumerateObjects { (asset, _, _) in
            assetMap[asset.localIdentifier] = asset
        }
        
        let dispatchGroup = DispatchGroup()
        var finalResults = [PickerResult]()
        let resultsLock = NSLock()// 保护 finalResults 并发写（provider 回调线程不保证串行）
        
        // 3. 遍历结果并匹配 Asset
        for result in results {
            dispatchGroup.enter()
            var pickerResult = PickerResult()
            
            // 匹配对应的 PHAsset
            if let id = result.assetIdentifier {
                pickerResult.asset = assetMap[id]
            }
            
            let provider = result.itemProvider
            
            // --- 视频处理 ---
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                pickerResult.mediaType = .video
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { (url, _) in
                    if let sourceURL = url {
                        let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
                        try? FileManager.default.copyItem(at: sourceURL, to: targetURL)
                        pickerResult.videoURL = targetURL
                    }
                    resultsLock.lock()
                    finalResults.append(pickerResult)
                    resultsLock.unlock()
                    dispatchGroup.leave()
                }
            }
            // --- GIF 处理 ---
            else if provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
                pickerResult.mediaType = .gif
                provider.loadDataRepresentation(forTypeIdentifier: UTType.gif.identifier) { (data, _) in
                    pickerResult.gifData = data
                    resultsLock.lock()
                    finalResults.append(pickerResult)
                    resultsLock.unlock()
                    dispatchGroup.leave()
                }
            }
            // --- 图片处理 ---
            else {
                pickerResult.mediaType = .image
                provider.loadObject(ofClass: UIImage.self) { (img, _) in
                    pickerResult.image = img as? UIImage
                    resultsLock.lock()
                    finalResults.append(pickerResult)
                    resultsLock.unlock()
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.completionHandler?(finalResults)
        }
    }
}

class VideoThumbnailLoader {
    
    /// 从 PHAsset 获取视频缩略图 (异步)
    /// - Parameters:
    ///   - asset: 视频的 PHAsset 对象
    ///   - size: 想要的缩略图尺寸 (例如：CGSize(width: 300, height: 300))
    ///   - completion: 结果回调 (已在主线程)
    static func loadThumbnail(from asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        
        // 1. 确保是视频类型
        guard asset.mediaType == .video else {
            completion(nil)
            return
        }
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        
        // 配置选项
        options.isNetworkAccessAllowed = true // 允许从 iCloud 下载缩略图
        options.deliveryMode = .highQualityFormat // 想要高质量图
        options.isSynchronous = false // 异步请求
        
        // 2. 请求图片
        imageManager.requestImage(for: asset,
                                 targetSize: size,
                                 contentMode: .aspectFill,
                                 options: options) { (image, info) in
            
            // 3. 回调结果 (PhotoKit 自动处理线程，这里通常在主线程)
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}

