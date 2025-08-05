//
//  FZMEditHeadImageVC.swift
//  Chat33
//
//  Created by 吴文拼 on 2018/10/14.
//  Copyright © 2018年 吴文拼. All rights reserved.
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "头像"
        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: Color_Theme]
        self.view.backgroundColor = .black
        self.xls_navigationBarBackgroundColor = .black
        self.xls_navigationBarTintColor = Color_Theme
        let backItem = UIBarButtonItem(image: #imageLiteral(resourceName: "nav_back_blue"), style: .plain, target: self, action: #selector(backClick))
        self.navigationItem.leftBarButtonItem = backItem
        let moreItem = UIBarButtonItem(image: #imageLiteral(resourceName: "cell_right_dot"), style: .plain, target: self, action: #selector(moreItemClick))
        self.navigationItem.rightBarButtonItem = moreItem
        setNavBackgroundColor()
        self.createUI()
    }
    
    func setNavBackgroundColor() {
        if #available(iOS 15.0, *) {   ///  standardAppearance 这个api其实是 13以上就可以使用的 ，这里写 15 其实主要是iOS15上出现的这个死样子
            let naba = UINavigationBarAppearance.init()
            naba.configureWithOpaqueBackground()
            naba.backgroundColor = .black
            naba.shadowColor = UIColor.lightGray
            self.navigationController?.navigationBar.standardAppearance = naba
            self.navigationController?.navigationBar.scrollEdgeAppearance = naba
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
                                        FZMBottomOption(title: "保存图片", block: {
                                            guard let img = self.headImageView.image else { return }
                                            UIImageWriteToSavedPhotosAlbum(img, self, #selector(FZMEditHeadImageVC.image(image:didFinishSavingWithError:contextInfo:)), nil)
                                        }),FZMBottomOption(title: "从相册选择", block: {
                                            block(true)
                                        }),FZMBottomOption(title: "拍照", block: {
                                            block(false)
                                        })])
        case .showGroupAvatar, .showPersonAvatar:
            FZMBottomSelectView.show(with: "", arr: [
                                        FZMBottomOption(title: "保存图片", block: {
                                            guard let img = self.headImageView.image else { return }
                                            UIImageWriteToSavedPhotosAlbum(img, self, #selector(FZMEditHeadImageVC.image(image:didFinishSavingWithError:contextInfo:)), nil)
                                        })])
        }
    }
    
    private func chooseImages() {
        let picker = ImagePickerController.init(withSelectOne: true, maxSelectCount: 1, allowEditing: true, showVideo: false)
        picker.imagePickerControllerDidCancelHandle = {
            self.setStatusBarHiddenAction(false)
        }
        picker.didFinishPickingPhotosHandle = {[weak self] (photos, _, _) in
            guard let self = self, let images = photos  else { return }
            images.forEach { (image) in
                self.changeImage(image)
            }
            
            self.setStatusBarHiddenAction(false)
        }
        setStatusBarHiddenAction(true)
        self.present(picker, animated: true, completion: nil)
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
            strongSelf.showToast("上传图片出错，请重新操作")
            
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
                
                strongSelf.showToast("头像修改成功，请耐心等待，稍后查看结果...")
                
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
                strongSelf.showToast("群头像修改成功")
            } failureBlock: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.hideProgress()
                strongSelf.showToast("群头像修改失败")
            }
        case .showPersonAvatar, .showGroupAvatar:
            return
        }
        
    }
    
    @objc private func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = "图片保存失败"
        }else{
            showMessage = "图片已保存"
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
