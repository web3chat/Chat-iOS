//
//  MediaMessageCell.swift
//  chat
//
//  Created by 陈健 on 2021/3/17.
//

import UIKit
import Kingfisher
import TZImagePickerController

class MediaMessageCell: MessageContentCell {
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 5
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    lazy var playView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage.init(named: "icon_video_play")//icon_video_download
        imageView.size = CGSize.init(width: 50, height: 50)
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var timeLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 16), textColor: Color_Auxiliary, textAlignment: .right, text: "00:00")
        return lab
    }()
    
    var downloadOrUploadProgressView = SectorProgress.init(frame: CGRect.init(x: 0, y: 0, width: 50, height: 50))
    
    
    override func setupViews() {
        super.setupViews()
        self.messageContainerView.addSubview(self.imageView)
        self.messageContainerView.addSubview(self.playView)
        self.messageContainerView.addSubview(self.timeLab)
        
        self.messageContainerView.addSubview(downloadOrUploadProgressView)
        downloadOrUploadProgressView.isHidden = true
        downloadOrUploadProgressView.alpha = 0.6
        downloadOrUploadProgressView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 50, height: 50))
        }
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        self.imageView.frame = self.messageContainerView.bounds
        self.playView.center = self.imageView.center
        self.timeLab.frame = CGRect.init(x: 5, y: self.messageContainerView.bounds.height - 27, width: self.messageContainerView.bounds.width - 10, height: 22)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        self.imageView.kf.cancelDownloadTask()
        self.playView.isHidden = true
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messagesCollectionView: MessageCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        
        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessageDisplayDelegate")
        }
        
        switch message.kind {
        case .photo(let mediaItem):
            self.playView.isHidden = true
            self.timeLab.isHidden = true
            mediaItem.imageAsync { (image) in
                if let image = image {// 本地已有缓存则显示缓存图片
                    
                    // 判断是否为gif图
                    if let gifData = message.gifData {
                        
                        self.imageView.image = UIImage.sd_tz_animatedGIF(with: gifData)
                    } else {
                        self.imageView.image = image
                    }
                } else if let url = mediaItem.url {
                    self.imageView.kf.indicatorType = .activity// 加载菊花-使用系统菊花
                    self.imageView.kf.setImage(with: URL.init(string: url))
                }
            }
        case .video(let mediaItem):
            self.playView.isHidden = false
            self.timeLab.isHidden = false
            self.timeLab.text = String.transToHourMinSec(time: mediaItem.duration ?? 0)
            mediaItem.imageAsync { (image) in
                if let image = image {
                    self.imageView.image = image
                } else if let url = mediaItem.url {
                    self.imageView.kf.setImage(with: URL.init(string: url))
                }
            }
            
            let fileName = "\(message.msgType.cachekey ?? "")"
            let filePath = DocumentPath.appendingPathComponent("Video/\(fileName).MOV")
            if FZMLocalFileClient.shared().isFileExists(atPath: filePath) {
                self.playView.image = UIImage.init(named: "icon_video_play")
            }else{
                self.playView.image = UIImage.init(named: "icon_video_download")
            }
            
        default:
            break
        }
        displayDelegate.configureMediaMessageImageView(self.imageView, for: message, at: indexPath, in: messagesCollectionView)
    }
    
    //下载完视频 更新状态
    func updateSatus(){
        DispatchQueue.main.async {
            self.playView.image = UIImage.init(named: "icon_video_play")
            
            ImageCache.default.retrieveImage(forKey: self.msg?.msgType.cachekey ?? "") { (result) in
                guard case .success(let cache) = result,
                      let image = cache.image else {
                    return
                }
                self.imageView.image = image
            }
        }
    }
    func updateSatusAndImage(_ image: UIImage){
        DispatchQueue.main.async {
            self.imageView.image = image
            self.playView.image = UIImage.init(named: "icon_video_play")
        }
    }
    
    //更新下载进度
    func updateDownLoadProcress(proress : CGFloat){
        if proress < 1 {
            self.downloadOrUploadProgressView.isHidden = false
            self.downloadOrUploadProgressView.progress = proress
        }else{
            self.downloadOrUploadProgressView.isHidden = true
            self.downloadOrUploadProgressView.progress = 0
        }
    }
}
