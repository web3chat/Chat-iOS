//
//  FZMVideoListCell.swift
//  chat
//
//  Created by 王俊豪 on 2022/2/28.
//

import Foundation
import RxSwift
import SnapKit
import Kingfisher
import TZImagePickerController
import UIKit
import SwiftUI

class FZMVideoListCell: UICollectionViewCell {
    let disposeBag = DisposeBag()
    var vm: FZMMessageBaseVM?
    var selectBlock: ((FZMMessageBaseVM,UIImageView)->())?
    private var curImage: UIImage?
    private var curGifData: Data?
    
    lazy var contentImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.clipsToBounds = true
        return v
    }()
    
    lazy var playOrDownloadImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    lazy var videoTimeLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_Auxiliary, textAlignment: .right, text: "")
        return lab
    }()
    
    lazy var selectBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "tool2_disselect"), for: .normal)
        btn.setImage(#imageLiteral(resourceName: "tool2_select"), for: .selected)
        btn.enlargeClickEdge(15, 15, 15, 15)
        btn.isHidden = true
        return btn
    }()
    var isShowSelect: Bool = false {
        didSet{
            selectBtn.isHidden = !isShowSelect
        }
    }
    
    var downloadProgressView = SectorProgress.init(frame: CGRect.init(x: 0, y: 0, width: 35, height: 35))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.initView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
     func initView() {
        IMNotifyCenter.shared().addReceiver(receiver: self, type: .download)
        
        self.contentView.addSubview(self.contentImageView)
        self.contentImageView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.contentView.addSubview(playOrDownloadImageView)
        playOrDownloadImageView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 35, height: 35))
        }
        self.contentView.addSubview(videoTimeLab)
        videoTimeLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-4)
            m.bottom.equalToSuperview().offset(-2)
        }
        
        self.contentView.addSubview(downloadProgressView)
        downloadProgressView.isHidden = true
        downloadProgressView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 35, height: 35))
        }
        self.contentView.addSubview(selectBtn)
        selectBtn.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(8)
            m.right.equalToSuperview().offset(-8)
            m.size.equalTo(CGSize(width: 25, height: 25))
        }
        
        let tap = UITapGestureRecognizer()
        tap.rx.event.subscribe {[weak self] (event) in
            guard let strongSelf = self,let vm = self?.vm else { return }
            strongSelf.contentImageViewTap(from: strongSelf.contentImageView, msgId: vm.message.msgId)
            }.disposed(by: disposeBag)
        self.contentView.addGestureRecognizer(tap)
        
        selectBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.selectBtn.isSelected = !strongSelf.selectBtn.isSelected
            strongSelf.vm?.selected = strongSelf.selectBtn.isSelected
            }.disposed(by: disposeBag)
    }
    
    override func prepareForReuse() {
        self.contentImageView.image = nil
        
//        if let vm = self.vm {
//            switch vm.message.kind {
//            case .video(let mediaItem):
//                mediaItem.imageAsync { (image) in
//                    if let image = image {
//                        self.curImage = image
//                        self.contentImageView.image = image
//                    } else if let url = mediaItem.url {
//                        self.contentImageView.kf.setImage(with: URL.init(string: url))
//                    }
//                }
//            case .photo(let mediaItem):
//                mediaItem.imageAsync { (image) in
//                    if let image = image {// 本地已有缓存则显示缓存图片
//
//                        // 判断是否为gif图
//                        if let gifData = vm.message.gifData {
//                            self.curGifData = gifData
//                            self.contentImageView.image = UIImage.sd_tz_animatedGIF(with: gifData)
//                        } else {
//                            self.curImage = image
//                            self.contentImageView.image = image
//                        }
//                    } else if let url = mediaItem.url {
//                        self.contentImageView.kf.indicatorType = .activity// 加载菊花-使用系统菊花
//                        self.contentImageView.kf.setImage(with: URL.init(string: url))
//                    }
//                }
//            default:
//                break
//            }
//        }
        
        
//        if let image = self.curImage {
//            self.contentImageView.image = image
//        } else if let gifData = self.curGifData {
//            self.contentImageView.image = UIImage.sd_tz_animatedGIF(with: gifData)
//        } else {
//            self.contentImageView.image = nil
//        }
    }
    
    func configure(with vmData: FZMMessageBaseVM, isShowSelect: Bool = false) {
        self.vm = vmData
        self.isShowSelect = isShowSelect
        self.selectBtn.isSelected = self.vm?.selected ?? false
        playOrDownloadImageView.isHidden = true
        self.downloadProgressView.progress = 0
        switch vmData.message.kind {
        case .video(let mediaItem):
            playOrDownloadImageView.isHidden = false
            videoTimeLab.isHidden = false
            
            if vmData.isLocalFileExist {// 是否已缓存本地
                self.playOrDownloadImageView.image = #imageLiteral(resourceName: "icon_video_play")
            } else {
                self.playOrDownloadImageView.image = #imageLiteral(resourceName: "icon_video_download")
            }
            
            mediaItem.imageAsync { (image) in
                if let image = image {
                    self.curImage = image
                    self.contentImageView.image = image
                } else if let url = mediaItem.url {
                    self.contentImageView.kf.setImage(with: URL.init(string: url))
                }
            }
            
            self.videoTimeLab.text = String.transToHourMinSec(time: mediaItem.duration ?? 0)
            
            vmData.fileDownloadFailedSubject.subscribe { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.playOrDownloadImageView.image = #imageLiteral(resourceName: "icon_video_download")
                strongSelf.downloadProgressView.isHidden = true
                strongSelf.downloadProgressView.progress = 0
            }.disposed(by: disposeBag)
            
            vmData.fileDownloadSucceedSubject.subscribe { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.updateSatus()
            }.disposed(by: disposeBag)
                       
        case .photo(let mediaItem):
            playOrDownloadImageView.isHidden = true
            downloadProgressView.isHidden = true
            videoTimeLab.isHidden = true
            mediaItem.imageAsync { (image) in
                if let image = image {// 本地已有缓存则显示缓存图片
                    
                    // 判断是否为gif图
                    if let gifData = vmData.message.gifData {
                        self.curGifData = gifData
                        self.contentImageView.image = UIImage.sd_tz_animatedGIF(with: gifData)
                    } else {
                        self.curImage = image
                        self.contentImageView.image = image
                    }
                } else if let url = mediaItem.url {
                    self.contentImageView.kf.indicatorType = .activity// 加载菊花-使用系统菊花
                    self.contentImageView.kf.setImage(with: URL.init(string: url))
                }
            }
        default:
            break
        }
    }
    
    //下载完视频 更新状态
    func updateSatus() {
        DispatchQueue.main.async {
            self.playOrDownloadImageView.image = UIImage.init(named: "icon_video_play")
            
            ImageCache.default.retrieveImage(forKey: self.vm?.message.msgType.cachekey ?? "") { (result) in
                guard case .success(let cache) = result,
                      let image = cache.image else {
                    return
                }
                self.curImage = image
                self.contentImageView.image = image
            }
        }
    }
    
    func contentImageViewTap(from imageView: UIImageView, msgId: String) {
        guard let vm = self.vm else { return }
        self.selectBlock?(vm,self.contentImageView)
//        switch vm.message.msgType {
//        case .video:
//            if vm.isLocalFileExist {
//                self.selectBlock?(vm,self.contentImageView)
//            } else {
//                vm.downloadData()
//                self.playOrDownloadImageView.image = #imageLiteral(resourceName: "icon_video_play")
//            }
//        case .image:
//            self.selectBlock?(vm,self.contentImageView)
//        default:
//            break
//        }
    }
    
    // 更新下载进度
    func updateDownLoadProcress(proress : CGFloat){
        if proress < 1 {
            self.downloadProgressView.isHidden = false
            self.downloadProgressView.progress = proress
        }else{
            self.downloadProgressView.isHidden = true
            self.downloadProgressView.progress = 0
        }
    }
}
