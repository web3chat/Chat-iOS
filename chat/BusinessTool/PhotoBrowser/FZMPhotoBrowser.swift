//
//  FZMPhotoBrowser.swift
//  IMSDK
//
//  Created by 陈健 on 2019/2/11.
//

import UIKit
import IDMPhotoBrowser
import RxSwift


class FZMPhotoBrowser: IDMPhotoBrowser {
//    fileprivate var burnProgressView :FZMBurnProgressView?
    fileprivate let disposeBag = DisposeBag()
    fileprivate var idmPhotoIndex = -1
    
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
    
    override init!(photos photosArray: [Any]!, animatedFrom view: UIView!) {
        super.init(photos: photosArray, animatedFrom: view)
        self.delegate = self
        if let imageView = view as? UIImageView {
            self.scaleImage = imageView.image
        }
        self.displayToolbar = false
        self.displayDoneButton = false
        self.dismissOnTouch = true
        self.modalPresentationStyle = .overCurrentContext
    }
    
    convenience init(url: String, from imageView:UIImageView) {
        var photos = [Any]()
        if let url = URL.init(string: url), let photo = IDMPhoto.init(url: url) {
            photos.append(photo)
        } else if let photo = IDMPhoto.init(image: imageView.image) {
            photos.append(photo)
        }
        self.init(photos: photos, animatedFrom: imageView)
    }

    convenience init(msg:Message ,msgList:[Message], from imageView:UIImageView) {
        var photos = [Any]()
        var currentIndex = 0
        for i in 0..<msgList.count {
            let message = msgList[i]
            if let url = URL.init(string: message.msgType.url), let photo = IDMPhoto.init(url: url) {
                photos.append(photo)
                if !msg.msgId.isEmpty && !message.msgId.isEmpty {
                    if msg.msgId == message.msgId {
                        currentIndex = i
                    }
                } else if !msg.msgId.isEmpty && !message.msgId.isEmpty {
                    if message.msgId == msg.msgId {
                        currentIndex = i
                    }
                } else if msg.datetime == message.datetime {
                    currentIndex = i
                }
                
            } else {
                message.msgType.imageAsync { (image) in
                    if let image = image, let photo = IDMPhoto.init(image: image){
                        photos.append(photo)
                        if message.msgId == msg.msgId {
                            currentIndex = i
                        }
                    }
                }
            }
        }
        
        if currentIndex >= photos.count {
            photos.removeAll()
            if let url = URL.init(string: msg.msgType.url), let photo = IDMPhoto.init(url: url) {
                photos.append(photo)
                currentIndex = 0
            } else {
                msg.msgType.imageAsync { (image) in
                    if let image = image, let photo = IDMPhoto.init(image: image){
                        photos.append(photo)
                        currentIndex = 0
                    }
                }
            }
        }
        
        if photos.isEmpty, let photo = IDMPhoto.init(image: UIImage.imageWithColor(with: .black, size: CGSize.init(width: k_ScreenWidth, height: k_ScreenHeight))) {
            photos.append(photo)
        }
        self.init(photos: photos, animatedFrom: imageView)
        if photos.count > currentIndex {
            (photos[currentIndex] as? IDMPhoto)?.placeholderImage = imageView.image
            self.setInitialPageIndex(UInt(currentIndex))
        }
    }
   
//    convenience init(msg:SocketMessage, conversationType:SocketChannelType,conversationID:String, from imageView:UIImageView) {
//        let msgList = SocketMessage.getAllMsg(with: conversationType, conversationId: conversationID, msgType: .image)
//        self.init(msg: msg, msgList: msgList, from: imageView)
//    }
//
//    convenience init(msg:SocketMessage, conversation:SocketConversationModel, from imageView:UIImageView) {
//        self.init(msg: msg, conversationType: conversation.type, conversationID: conversation.conversationId, from: imageView)
//    }
//
//    init(burnBrowserWith msg:SocketMessage, from imageView:UIImageView) {
//        let distance = (msg.snapTime - Date.timestamp)/1000
//        var photos = [IDMPhoto]()
//
//        if let imageURl = URL.init(string: msg.body.imageUrl),
//            let photo = IDMPhoto.init(url: imageURl) {
//            photo.placeholderImage = imageView.image
//            photos = [photo]
//        }
//
//        super.init(photos: photos, animatedFrom: imageView)
//        self.delegate = self
//        self.scaleImage = imageView.image
//        self.displayToolbar = false
//        self.displayDoneButton = false
//        self.dismissOnTouch = true
//
//        let burnProgressView = FZMBurnProgressView(endTime: distance)
//        burnProgressView.countDownCompleteBlock = {[weak self, weak burnProgressView] in
//            burnProgressView?.removeFromSuperview()
//            self?.dismiss(animated: true, completion: nil)
//        }
//        UIApplication.shared.keyWindow?.addSubview(burnProgressView)
//        self.burnProgressView = burnProgressView
//
//    }
    
//    func viewDidLongPressed() {
//        guard idmPhotoIndex >= 0,
//            let img = (self.photo(at: UInt(self.idmPhotoIndex)) as? IDMPhoto)?.value(forKey: "underlyingImage") as? UIImage else { return }
//        VoiceMessagePlayerManager.shared().vibrateAction()
//        if let str = FZMQRCodeGenerator.detectorQRCode(with: img) {
//            FZMBottomSelectView.show(with: [
//                FZMBottomOption(title: "转发图片", block: {
//                    FZMUIMediator.shared().pushVC(.multipleSendMsg(type: .image(image: img)))
//                }),FZMBottomOption(title: "保存图片", block: {[weak self] in
//                    self?.saveBtnClick(img: img)
//                }),FZMBottomOption(title: "识别图中二维码", block: {[weak self] in
//                    self?.dismiss(animated: false, completion: {
//                        FZMUIMediator.shared().parsingUrl(with: str)
//                    })
//                })])
//        }else {
//            FZMBottomSelectView.show(with: [
//                FZMBottomOption(title: "转发图片", block: {
//                    FZMUIMediator.shared().pushVC(.multipleSendMsg(type: .image(image: img)))
//                }),FZMBottomOption(title: "保存图片", block: {[weak self] in
//                    self?.saveBtnClick(img: img)
//                })])
//        }
//    }
    
//    func saveBtnClick(img:UIImage) {
    func saveBtnClick() {
        guard idmPhotoIndex >= 0,
              let img = (self.photo(at: UInt(self.idmPhotoIndex)) as? IDMPhoto)?.value(forKey: "underlyingImage") as? UIImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
    }
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = "图片保存失败"
        }else{
            showMessage = "图片已保存"
            
        }
        APP.shared().showToast(showMessage)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameorNil:String?,bundle nibBundleOrNil:Bundle?){
        super.init(nibName:nibNameorNil,bundle:nibBundleOrNil)
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(downloadBtn)
        downloadBtn.frame = CGRect.init(x: k_ScreenWidth - 45, y: k_ScreenHeight - 60, width: 30, height: 30)
        
//        let longPress = UILongPressGestureRecognizer()
//        longPress.rx.event.subscribe {[weak self] (event) in
//            guard case .next(let ges) = event else { return }
//            if ges.state == .began {
//                self?.viewDidLongPressed()
//            }
//            }.disposed(by: disposeBag)
//        self.view.addGestureRecognizer(longPress)
    }

}


extension FZMPhotoBrowser: IDMPhotoBrowserDelegate {
    func willDisappear(_ photoBrowser: IDMPhotoBrowser!) {
        self.idmPhotoIndex = -1
//        self.burnProgressView?.removeFromSuperview()
    }
    func photoBrowser(_ photoBrowser: IDMPhotoBrowser!, didShowPhotoAt index: UInt) {
        self.idmPhotoIndex = Int(index)
    }
}
