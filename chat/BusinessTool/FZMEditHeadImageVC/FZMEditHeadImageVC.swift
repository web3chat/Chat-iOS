//
//  FZMEditHeadImageVC.swift
//  Chat33
//
//  Created by fzm on 2018/10/14.
//  Copyright © 2018年 fzm. All rights reserved.
//

import UIKit
import SnapKit
import MobileCoreServices
import Photos
import PhotosUI

enum FZMEditHeadImageType {
    case me
    case group(groupId:Int)
    case showPersonAvatar
    case showGroupAvatar
}

class FZMEditHeadImageVC: UIViewController, ViewControllerProtocol {
    
    init(with type: FZMEditHeadImageType, oldAvatar: String = "") {
        self.type = type
        self.oldAvatar = oldAvatar
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let type : FZMEditHeadImageType
    private var oldAvatar : String
    
    private var isHiddenStatusBar:Bool = false
    
    private let bag = DisposeBag.init()
    
    lazy var headImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "friend_chat_avatar"))
        return imV
    }()

    /// 本页自己的返回按钮（主题色箭头）。
    /// 存成属性是为了在 `setNavBackgroundColor()` 里把左侧 item **收敛成只有这一个**：
    /// 全局拦截器 `ViewControllerIntercepter` 在 iOS 26 上会给每个页面补一个默认返回 item
    /// （深色 `Color_24374E`，黑底上几乎看不见），和这一条同时出现就是「两个返回箭头」。
    private lazy var navBackItem: UIBarButtonItem = {
        // 图标必须按模板渲染，否则原本就是深色的图在黑底上看不见
        let backImage = #imageLiteral(resourceName: "nav_back_blue").withRenderingMode(.alwaysTemplate)
        return UIBarButtonItem(image: backImage, style: .plain, target: self, action: #selector(backClick))
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = L("头像")
        self.view.backgroundColor = .black
        self.xls_navigationBarBackgroundColor = .black
        self.xls_navigationBarTintColor = Color_Theme
        // 图标必须按模板渲染，否则原本就是深色的图在黑底上看不见
        self.navigationItem.leftBarButtonItem = navBackItem
        let moreImage = #imageLiteral(resourceName: "cell_right_dot").withRenderingMode(.alwaysTemplate)
        let moreItem = UIBarButtonItem(image: moreImage, style: .plain, target: self, action: #selector(moreItemClick))
        self.navigationItem.rightBarButtonItem = moreItem
        setNavBackgroundColor()
        self.createUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 「我的」页面把系统导航栏隐藏了（它自绘顶栏）。push 进本页时，
        // 如果等全局拦截器在**转场动画中**用 `animated: true` 把栏显出来，
        // iOS 26 上会出现“栏位就是不出现”（页面顶部直接顶到状态栏）。
        // 这里用 `animated: false` 先把栏位摆好；拦截器随后再设一次同值不会重播动画。
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        setNavBackgroundColor()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // viewWillAppear 里设的外观会被全局拦截器（`ViewControllerIntercepter`）
        // 用 `setBackgroundImage(UIImage())` + `tintColor` 再覆盖一遍，
        // 所以转场结束后再完整应用一次，保证标题/按钮在黑底上可见。
        if self.navigationController?.isNavigationBarHidden == true {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
        setNavBackgroundColor()
    }
    
    func setNavBackgroundColor() {
        guard let nav = self.navigationController else { return }
        let bar = nav.navigationBar
        bar.isTranslucent = false
        // 所有模板图标（含拦截器换上的返回箭头）都走这个色
        bar.tintColor = Color_Theme
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            // 去掉 iOS 26 自动给 bar button 加的玻璃胶囊
            naba.buttonAppearance.normal.backgroundImage = UIImage()
            naba.buttonAppearance.highlighted.backgroundImage = UIImage()
            naba.doneButtonAppearance.normal.backgroundImage = UIImage()
            naba.doneButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backButtonAppearance.normal.backgroundImage = UIImage()
            naba.backButtonAppearance.highlighted.backgroundImage = UIImage()
            naba.backgroundColor = .black
            naba.shadowColor = UIColor.lightGray
            // ⚠️ 背景是纯黑：标题/按钮色必须显式走 appearance 里设，
            //    `navigationBar.titleTextAttributes`、`tintColor` 在设了 standardAppearance 后
            //    对新版系统上的 item 不再生效（会回退成默认的黑色 → 黑底黑字看不见）。
            let titleAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: Color_Theme]
            naba.titleTextAttributes = titleAttrs
            naba.largeTitleTextAttributes = titleAttrs
            naba.buttonAppearance.normal.titleTextAttributes = titleAttrs
            naba.doneButtonAppearance.normal.titleTextAttributes = titleAttrs
            naba.backButtonAppearance.normal.titleTextAttributes = titleAttrs
            bar.standardAppearance = naba
            bar.scrollEdgeAppearance = naba
            // iOS 26：三个 appearance 都要设，缺 compactAppearance 时部分状态会回退系统默认（透明玻璃）
            bar.compactAppearance = naba
        } else {
            bar.barTintColor = .black
        }
        // 再补一份 legacy 写法：全局拦截器会调 `setBackgroundImage(UIImage(), for: .default)`，
        // 一旦它把 bar 拉回 legacy 渲染路径，上面 appearance 里的颜色就不生效，这里兜住。
        bar.titleTextAttributes = [.foregroundColor: Color_Theme]
        self.navigationItem.leftBarButtonItem?.tintColor = Color_Theme
        self.navigationItem.rightBarButtonItem?.tintColor = Color_Theme

        // 左侧只留本页这一条主题色返回箭头（标题「头像」与右上「⋯」不受影响）。
        // 全局拦截器 / GKNavigationBar 可能在 `viewDidLoad` 之后往左侧再挂一个深色返回 item，
        // 于是就会出现两条箭头（其中一条在黑底上看不见、但能点到）。
        // `viewDidLoad` / `viewWillAppear` / `viewDidAppear` 都会走这里 ⇒ 谁后挂上来的都会被清掉。
        let leftItems = self.navigationItem.leftBarButtonItems ?? []
        if leftItems.count != 1 || leftItems[0] !== navBackItem {
            self.navigationItem.leftBarButtonItems = [navBackItem]
        }
    }
    
    @objc private func backClick() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func moreItemClick() {
        let block : (Bool)->() = { isAlbum in
            if isAlbum {
                self.chooseImages()
            }else {
                self.goCamera()
            }
        }
        switch type {
        case .me, .group:
            FZMBottomSelectView.show(with: "", arr: [
                                        FZMBottomOption(title: L("保存图片"), block: {
                                            guard let img = self.headImageView.image else { return }
                                            UIImageWriteToSavedPhotosAlbum(img, self, #selector(FZMEditHeadImageVC.image(image:didFinishSavingWithError:contextInfo:)), nil)
                                        }),FZMBottomOption(title: L("从相册选择"), block: {
                                            block(true)
                                        }),FZMBottomOption(title: L("拍照"), block: {
                                            block(false)
                                        })])
        case .showGroupAvatar, .showPersonAvatar:
            FZMBottomSelectView.show(with: "", arr: [
                                        FZMBottomOption(title: L("保存图片"), block: {
                                            guard let img = self.headImageView.image else { return }
                                            UIImageWriteToSavedPhotosAlbum(img, self, #selector(FZMEditHeadImageVC.image(image:didFinishSavingWithError:contextInfo:)), nil)
                                        })])
        }
    }
    
    private func chooseImages() {
        // 打开系统相册前统一走权限检查（未决定→请求；部分照片→提示；拒绝→去设置）
        PhotoLibraryAccess.preparePhotoAccess(from: self, limitedMessage: nil) { [weak self] in
            guard let self = self else { return }
            self.presentImagePicker()
        }
    }

    /// 真正打开相册选择器（权限已就绪）
    private func presentImagePicker() {
        SystemMediaPicker.shared.present(from: self, maxCount: 1) { results in
            
            if results.isEmpty {
                print("用户取消了选择")
                return
            }
            print("一共选择了 \(results.count) 个媒体")
            // 遍历结果，模拟发送逻辑
            for (index, media) in results.enumerated() {
                print("--- 处理第 \(index+1) 个媒体 ---")
                switch media.mediaType {
                case .image:
                    // 1. 发送静态图片
                    if let img = media.image {
                        print("拿到静态图: \(img.size)")
                        self.changeImage(img)
                    }
                case .gif:
                    // 2. 选择 GIF 动图作为头像
                    if let gifData = media.gifData {
                        print("拿到 GIF Data，大小: \(gifData.count)")
                        // PHPicker 的 GIF 只填充 gifData，image 恒为 nil，不可强制解包
                        if let gifImage = UIImage(data: gifData) {
                            self.changeImage(gifImage)
                        }
                    }
                case .video:
                    // 3. 选择视频封面
                    if let videoURL = media.videoURL, let asset = media.asset {
                        print("拿到视频路径: \(videoURL.path)")
                        // 调用工具方法获取 300x300 的缩略图
                        VideoThumbnailLoader.loadThumbnail(from: asset, size: CGSize(width: 300, height: 300)) { [weak self] (thumbnailImage) in
                            guard let self = self else { return }
                            if let image = thumbnailImage {
                                print("成功拿到视频缩略图: \(image.size)")
                                self.changeImage(image)
                            } else {
                                print("获取视频缩略图失败")
                            }
                        }

                    }
                case .unknown:
                    print("未知媒体类型，跳过")
                }
            }
        }
    }
    
    func goCamera() {
        let picker = UIImagePickerController.init()
        picker.delegate = self
        picker.mediaTypes = [kUTTypeImage as String]
        picker.sourceType = .camera
//        picker.allowsEditing = true
        
        setStatusBarHiddenAction(true)
        self.present(picker, animated: true, completion: nil)
    }
    
    private func createUI() {
        self.view.addSubview(headImageView)
        headImageView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize(width: k_ScreenWidth, height: k_ScreenWidth))
        }
        
        let tap = UILongPressGestureRecognizer()
        tap.rx.event.subscribe {[weak self] (event) in
            guard case .next(let ges) = event else { return }
            if ges.state == .began {
                self?.moreItemClick()
            }
        }.disposed(by: bag)
        self.view.addGestureRecognizer(tap)
        
        self.requestImage()
    }
    
    private func requestImage() {
        switch type {
        case .me:
            headImageView.kf.setImage(with: URL.init(string: LoginUser.shared().avatarUrl), placeholder: #imageLiteral(resourceName: "avatar_persion"))
        case .group:
            headImageView.kf.setImage(with: URL.init(string: oldAvatar), placeholder: #imageLiteral(resourceName: "group_chat_avatar"))
        case .showPersonAvatar:
            headImageView.kf.setImage(with: URL.init(string: oldAvatar), placeholder: #imageLiteral(resourceName: "avatar_persion"))
        case .showGroupAvatar:
            headImageView.kf.setImage(with: URL.init(string: oldAvatar), placeholder: #imageLiteral(resourceName: "group_chat_avatar"))
        }
    }
    
    private func changeImage(_ image : UIImage){
        self.showProgress(with: nil)
        
        let imgData = image.jpegData(compressionQuality: 0.6)!
        ChatManager.shared().uploadRequest(fileData: imgData, type: .image) { [weak self] (url) in
            guard let strongSelf = self else { return }
            strongSelf.sendImageUrl(with: url)
        } failure: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.hideProgress()
            strongSelf.showToast(L("上传图片出错，请重新操作"))
            
        }
//        // 阿里云
//        OSS.shared().uploadImage(file: image.jpegData(compressionQuality: 0.6)!) { (url) in
//            self.sendImageUrl(with: url)
//        } failure: { (error) in
//            self.hideProgress()
//            self.showToast("上传图片出错，请重新操作")
//            FZMLog("OSS上传图片出错-----\(error)")
//        }
    }
    
    func sendImageUrl(with url: String) {
        switch type {
        case .me:
            User.updateUserAvatar(targetAddress: LoginUser.shared().address, avatar: url) { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                
                strongSelf.headImageView.kf.setImage(with: URL.init(string: url), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
                
                // 保存头像
                LoginUser.shared().avatarUrl = url
                LoginUser.shared().save()
                _ = PWDataBaseManager.shared().updateUserInfoAvatar(withAddress: LoginUser.shared().address, avatarurl: url)
                
                strongSelf.showToast(L("头像修改成功，请耐心等待，稍后查看结果..."))
                
            } failureBlock: {[weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                strongSelf.showToast("\(error)")
            }
        case .group(let groupId):
            guard let group = GroupManager.shared().getDBGroup(by: groupId), let serverUrl = group.chatServerUrl else {
                return
            }
            GroupManager.shared().updateGroupAvatar(serverUrl: serverUrl, groupId: groupId, avatar: url) { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                strongSelf.headImageView.kf.setImage(with: URL.init(string: url), placeholder: #imageLiteral(resourceName: "friend_chat_avatar"))
                strongSelf.showToast(L("群头像修改成功"))
            } failureBlock: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                strongSelf.showToast(L("群头像修改失败"))
            }
        case .showPersonAvatar, .showGroupAvatar:
            return
        }
        
    }
    
    @objc private func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = L("图片保存失败")
        }else{
            showMessage = L("图片已保存")
        }
        APP.shared().showToast(showMessage)
    }
}



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}

extension FZMEditHeadImageVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        let mediaType = info[UIImagePickerController.InfoKey.mediaType.rawValue] as? String
        if mediaType == kUTTypeImage as String {// 图片
            DispatchQueue.main.async {
                picker.dismiss(animated: true, completion: { [self] in
                    setStatusBarHiddenAction(false)
                })
                guard let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage else {
                    return
                }
                let newImage = image.fixedImageToUpOrientation2()
                
                self.showImageEditVC(newImage)
            }
        }
    }
    
    private func showImageEditVC(_ image: UIImage) {
        let vc = ImageEditVC.init(with: image)
        vc.imageEditBlock = { [weak self] (image) in
            guard let strongSelf = self else { return }
            strongSelf.changeImage(image)
        }
        self.navigationController?.pushViewController(vc, completion: nil)
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        DispatchQueue.main.async {
            picker.dismiss(animated: true) { [self] in
                setStatusBarHiddenAction(false)
            }
        }
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    override var prefersStatusBarHidden: Bool {
        return isHiddenStatusBar
    }
    
    private func setStatusBarHiddenAction(_ hiddenFlg: Bool) {
        isHiddenStatusBar = hiddenFlg
        UIView.animate(withDuration: 0.5) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
}
