//
//  FZMFileViewController.swift
//  chat
//
//  Created by 王俊豪 on 2022/2/18.
//

import Foundation
import SnapKit
import RxSwift
import MediaPlayer
import AVKit
import Lantern
import Photos
import Kingfisher

class FZMFileViewController: UIViewController, ViewControllerProtocol {
    
    let disposeBag = DisposeBag.init()
    
    let session: Session
    
    private var videoOrFile : Int = 1// 区分下载的是视频还是文件  视频==1   文件==2  语音==3
    var documentInteractionController:UIDocumentInteractionController!// 浏览文件用
    
    private var curTapVM: FZMMessageBaseVM?// 当前点击的message
    private var curTapImageView: UIImageView?// 当前点击的图片
    
    private var isSelectStatus = false// 当前页面是否是选择状态
    
    private let refreshListLock = NSLock()
    private var currentIndex = 0
    
    var view1: FZMFileListView?// 文件列表视图
    var view2: FZMVideoListView?// 图片/视频列表视图
    
//    var senderNameCanTouch = true
    
//    private var fileMessagArr: [Message]? {
//        get {
//            return self.view1?.fileMessagArr
//        }
//        set {
//            self.view1?.fileMessagArr = newValue ?? [Message]()
//        }
//    }
    private var fileListVMArr: [FZMMessageBaseVM]? {
        get {
            return self.view1?.fileListVMArr
        }
        set {
            self.view1?.fileListVMArr = newValue ?? [FZMMessageBaseVM]()
        }
    }
//    private var videoAndImageMessageArr: [Message]? {
//        get {
//            return self.view2?.videoAndImageMessageArr
//        }
//        set {
//            self.view2?.videoAndImageMessageArr = newValue ?? [Message]()
//        }
//    }
    private var videoListVmArr: [FZMMessageBaseVM]? {
        get {
            return self.view2?.videoListVMArr
        }
        set {
            self.view2?.videoListVMArr = newValue ?? [FZMMessageBaseVM]()
        }
    }
    
    // 下载按钮（保存图片、视频用）
    private lazy var downloadBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "icon_download"), for: .normal)
        btn.backgroundColor = .black
        btn.layer.cornerRadius = 4
        btn.layer.masksToBounds = true
        btn.enlargeClickEdge(10, 10, 10, 10)
        btn.rx.controlEvent(.touchUpInside).subscribe(onNext: {[weak self] (_) in
            guard let self = self else { return }
            self.saveBtnClick()
        }).disposed(by: self.disposeBag)
        return btn
    }()
    
    // 底部下载/删除按钮
    private lazy var forwardBar: FZMForwardBar = {
        let view = FZMForwardBar.init(withDownload: true)
        view.eventBlock = {[weak self] (event) in
            guard let strongSelf = self else { return }
            switch event {
            case .delete:
                let alert = TwoBtnInfoAlertView.init()
                alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
                alert.leftBtnTitle = "取消"
                alert.rightBtnTitle = "删除"
                let str = "删除后将不会出现在你的消息记录中"
                let attStr = NSMutableAttributedString.init(string: str, attributes: [NSAttributedString.Key.foregroundColor: Color_24374E, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
                alert.attributedInfo = attStr
                alert.leftBtnTouchBlock = {}
                alert.rightBtnTouchBlock = {
                    // 删除文件和消息记录
                    strongSelf.deleteSelectMsgs()
                }
                alert.show()
            case .download:
                strongSelf.downloadSelected()
            default: break
            }
        }
        view.isHidden = true
        return view
    }()
    
    lazy var searchBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        let norImage = #imageLiteral(resourceName: "tool_search")
        btn.setImage(norImage.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.setImage(norImage, for: .highlighted)
        btn.tintColor = Color_Theme
        btn.enlargeClickEdge(10, 10, 10, 10)
        btn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            if let strongSelf = self  {
                let vc = FZMFileSearchController.init(session: strongSelf.session)
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        }.disposed(by: disposeBag)
        return btn
    }()
    
    init(session: Session) {
        
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let selectBtn = UIBarButtonItem.init(title: "选择", style: .done, target: self, action: #selector(selectFileOrCancel))
        self.navigationItem.rightBarButtonItems = [selectBtn]
        self.xls_navigationBarTintColor = Color_Theme
        self.xls_navigationBarBackgroundColor = .white
        
        self.title = "聊天文件"
        
        self.view.backgroundColor = .white
        
        self.createUI()
        
        self.view.addSubview(forwardBar)
        forwardBar.snp.makeConstraints { (m) in
            m.left.right.bottom.equalToSuperview()
            m.height.equalTo(70)
        }
    }
    
    func createUI() {
        
        self.view1 = FZMFileListView.init(with: "文件", session: self.session)
//        self.fileMessagArr = self.view1?.fileMessagArr
        self.fileListVMArr = self.view1?.fileListVMArr
        self.view2 = FZMVideoListView.init(with: "图片/视频", session: self.session)
        let param = FZMSegementParam()
        if let view1 = self.view1, let view2 = self.view2 {
            view1.selectBlock = {[weak self] (vm, cell) in
                guard let strongSelf = self else { return }
                strongSelf.curTapVM = vm
                
                strongSelf.openFile(vm: vm)
            }
            view2.selectBlock = {[weak self] (vm,imageview) in
                guard let strongSelf = self else { return }
                strongSelf.curTapVM = vm
                
                if case .image = vm.message.msgType {
                    strongSelf.curTapImageView = imageview
                    strongSelf.showBigImageViewFromView(imageView: imageview, msg: vm.message)
                    return
                } else if case .video = vm.message.msgType {
                    strongSelf.playVideo(vm: vm)
                    return
                }
            }
            let pageView = FZMScrollPageView(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight - k_StatusNavigationBarHeight), dataViews: [view1,view2], param: param)
            pageView.backgroundColor = .white
            pageView.selectBlock = {[weak self] (index) in
                guard let strongSelf = self else { return }
                strongSelf.currentIndex = index
//                strongSelf.forwardBar.disableDelete = (index == 0 ? false : true)
                strongSelf.searchBtn.isHidden = (index == 0 ? false : true)
//                strongSelf.videoListVmArr?.forEach { (vm) in
//                    if vm.selected == true {
//                        strongSelf.forwardBar.disableDelete = true
//                    }
//                }
            }
            self.view.addSubview(pageView)
            
//            view1.senderLabBlock = {[weak self] (vm) in
//                guard let strongSelf = self,strongSelf.isSelect == false else {return}
//                let vc = FZMSenderFileController.init(conversationType: strongSelf.conversationType, conversationID: strongSelf.conversationID, owner: vm.senderUid,ownerName:vm.name)
//                strongSelf.navigationController?.pushViewController(vc, animated: true)
//            }
//            if senderNameCanTouch {
//                view1.senderLabBlock = {[weak self] (vm) in
//                    guard let strongSelf = self,strongSelf.isSelect == false else {return}
//                    let vc = FZMSenderFileController.init(conversationType: strongSelf.conversationType, conversationID: strongSelf.conversationID, owner: vm.senderUid,ownerName:vm.name)
//                    strongSelf.navigationController?.pushViewController(vc, animated: true)
//                }
//            }
            
            self.view.addSubview(searchBtn)
            searchBtn.snp.makeConstraints { (m) in
                m.top.equalTo(pageView).offset(13)
                m.right.equalToSuperview().offset(-14)
                m.width.height.equalTo(26)
            }
        }
    }
    
    // 列表普通/选择状态切换
    @objc func selectFileOrCancel() {
        if let fileArr = self.fileListVMArr,
            let videoArr = self.videoListVmArr,
            fileArr.isEmpty && videoArr.isEmpty {
            self.showToast("当前没有文件")
            return
        }
        if let fileArr = self.fileListVMArr,
            self.view2 == nil && fileArr.isEmpty  {
            return
        }
        
        isSelectStatus = !isSelectStatus
        let titleStr = isSelectStatus ? "取消" : "选择"
        
        self.navigationItem.rightBarButtonItem?.title = titleStr
        
        self.forwardBar.isHidden = !isSelectStatus
        
        if !isSelectStatus {
            self.fileListVMArr?.forEach({ vm in
                vm.selected = false
            })
            
            self.videoListVmArr?.forEach({ vm in
                vm.selected = false
            })
        }
        
        self.view1?.isSelect = isSelectStatus
        self.view1?.edgeInset(isSelectStatus)
        
        self.view2?.isSelect = isSelectStatus
        self.view2?.edgeInset(isSelectStatus)
        
        self.refreshListLock.lock()
        self.view1?.refresh()
        self.view2?.refresh()
        self.refreshListLock.unlock()
    }
    
    // 点击下载按钮
    private func downloadSelected() {
        var noDataDownload = true
        self.fileListVMArr?.forEach { (vm) in
            if vm.selected {
                if !vm.isLocalFileExist {
                    noDataDownload = false
                    vm.downloadData()
                }
            }
        }
        
        self.videoListVmArr?.forEach { (vm) in
            if vm.selected {
                if !vm.isLocalFileExist {
                    noDataDownload = false
                    vm.downloadData()
                }
            }
        }
        
        if noDataDownload {
            self.showToast("请选择下载内容")
        } else {
            self.showToast("已开始下载")
            self.selectFileOrCancel()
        }
    }
    
    // 从本地数据库消息表删除选择的消息以及删除对应的本地文件
    private func deleteSelectMsgs() {
        var allVMArr = [FZMMessageBaseVM]()
        var msgs = [Message]()
        
        // 遍历筛选出已选中的数据
        let fileArr = self.fileListVMArr ?? [FZMMessageBaseVM]()
        allVMArr += fileArr
        
        let videoArr = self.videoListVmArr ?? [FZMMessageBaseVM]()
        allVMArr += videoArr
        
        allVMArr.forEach { (vm) in
            if vm.selected {
                msgs.append(vm.message)
                
                // 删除本地缓存数据
                if case .image = vm.message.msgType {
                    // 清除图片缓存
                    let fileName = "\(vm.message.msgType.cachekey ?? "")"
                    ImageCache.default.removeImage(forKey: fileName)
                } else {
                    // 删除本地文件
                    if vm.isLocalFileExist {
                        let _ = FZMLocalFileClient.shared().deleteFile(atFilePath: vm.localFilePath)
                    }
                }
            }
        }
        
        // 删除文件列表数据
        self.fileListVMArr = fileArr.filter({ $0.selected == false })
        self.videoListVmArr = videoArr.filter({ $0.selected == false })
       
        if msgs.count > 0 {
            // 删除数据库消息数据并更新会话列表
            ChatManager.shared().delete(messsages: msgs)
            
            // 通知聊天页面删除消息记录
            FZM_NotificationCenter.post(name: FZM_Notify_DeleteChatMsgs, object: (self.session.id, msgs))
        }
        
        // 列表普通/选择状态切换
        self.selectFileOrCancel()
    }
    
    //打开文件 url地址保存在UserDefaults(下载使用)，文件沙盒路径：在Document/File/文件名.文件类型
    func openFile(vm: FZMMessageBaseVM){
        
        if vm.isLocalFileExist {
            // 本地有缓存文件
            self.showPDF(url: URL.init(fileURLWithPath: vm.localFilePath))
            
        } else {
            APP.shared().showToast("已开始下载")
            
            vm.downloadData()
            
            vm.fileDownloadSucceedSubject.subscribe { [weak self] (event) in
                guard let strongSelf = self, vm.message.msgId == strongSelf.curTapVM?.message.msgId else { return }
                if case .video = vm.message.msgType {
                    strongSelf.showPDF(url: URL.init(fileURLWithPath: vm.localFilePath))
                }
            }.disposed(by: disposeBag)
        }
    }
    
    // 浏览文件
    func showPDF(url: URL) {
        documentInteractionController = UIDocumentInteractionController(url: url)
        documentInteractionController.delegate = self
        
        DispatchQueue.main.async { [self] in
            
            let canOpen = documentInteractionController.presentPreview(animated: true)
            if !canOpen {
                if var navRect = self.navigationController?.navigationBar.frame {
                    navRect.size = CGSize.init(width: 1500, height: 40)
                    documentInteractionController.presentOpenInMenu(from: navRect, in: self.view, animated: true)
                }
            }
        }
    }
    
    // 点击视频
    func playVideo(vm: FZMMessageBaseVM){
        if vm.isLocalFileExist {
            // 播放视频
            self.playVideoWithUrl(fileUrl: vm.localFilePath)
        } else {
            APP.shared().showToast("已开始下载")
            
            vm.downloadData()
            
            vm.fileDownloadSucceedSubject.subscribe { [weak self] (event) in
                guard let strongSelf = self, vm.message.msgId == strongSelf.curTapVM?.message.msgId else { return }
                if case .video = vm.message.msgType {
                    strongSelf.playVideoWithUrl(fileUrl: vm.localFilePath)
                }
            }.disposed(by: disposeBag)
        }
    }
    
    // 播放视频
    func playVideoWithUrl(fileUrl : String){
        DispatchQueue.main.async {
            try? AVAudioSession.sharedInstance().setCategory(.playback)// 添加此行代码可在静音模式下播放音频
            
            let item = AVPlayerItem(url: URL(fileURLWithPath: fileUrl))
            let play = AVPlayer(playerItem:item)
            let playController = AVPlayerViewController()
            playController.player = play
            self.present(playController, animated: true, completion: {
                playController.view.addSubview(self.downloadBtn)
                playController.view.bringSubviewToFront(self.downloadBtn)
                self.downloadBtn.tag = 2
                self.downloadBtn.frame = CGRect.init(x: k_ScreenWidth - 80, y: k_ScreenHeight - 80, width: 30, height: 30)
            })
        }
    }
    
    // 查看大图
    func showBigImageViewFromView(imageView: UIImageView, msg: Message) {
        
        let lantern = Lantern()
        lantern.numberOfItems = {
            1
        }
        lantern.reloadCellAtIndex = { context in
            let url = msg.msgType.url ?? ""
            let lanternCell = context.cell as? LanternImageCell
            let placeholder = imageView.image
            // Kingfisher
            lanternCell?.imageView.kf.setImage(with: URL.init(string: url), placeholder: placeholder)
        }
        lantern.transitionAnimator = LanternZoomAnimator(previousView: { index -> UIView? in
            return imageView
        })
        lantern.pageIndex = 1
        lantern.view.addSubview(downloadBtn)
        downloadBtn.tag = 1
        downloadBtn.frame = CGRect.init(x: k_ScreenWidth - 45, y: k_ScreenHeight - 60, width: 30, height: 30)
        lantern.show()
    }
    
    // 保存图片和保存视频公用 tag==1 保存图片  tag==2 保存视频
    func saveBtnClick() {
        if self.downloadBtn.tag == 1 {// 保存图片
            let img = curTapImageView?.image
            let imgData = curTapVM?.message.gifData
            if (imgData != nil) {// 保存gif到相册
                PHPhotoLibrary.shared().performChanges({
                    let options =  PHAssetResourceCreationOptions()
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imgData! as Data, options: options)
                    }) { (isSuccess: Bool, error: Error?) in
                        var showMessage = ""
                        if isSuccess {
                            showMessage = "图片已保存"
                        } else{
                            showMessage = "图片保存失败"
                        }
                        DispatchQueue.main.async {
                            APP.shared().showToast(showMessage)
                        }
                    }
            } else if let image = img {//保存普通图片到相册
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                self.showToast("图片保存失败")
            }
        } else {// 保存视频
            guard let filePath = self.curTapVM?.localFilePath else {
                return
            }
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath){
                UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(self.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    // 视频保存结果回调
    @objc func video(videoPath: String, didFinishSavingWithError error: NSError, contextInfo info: AnyObject) {
        var showMessage = ""
        if error.code != 0 {
            showMessage = "视频保存失败"
        } else {
            showMessage = "视频已保存"
        }
        DispatchQueue.main.async {
            APP.shared().showToast(showMessage)
        }
    }
    
    // 图片保存结果回调
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = "图片保存失败"
        }else{
            showMessage = "图片已保存"

        }
        DispatchQueue.main.async {
            APP.shared().showToast(showMessage)
        }
    }
}

// 系统文件预览delegate
extension FZMFileViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
           return self
       }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        print("Dismissed!!!")
        documentInteractionController = nil
    }
}
