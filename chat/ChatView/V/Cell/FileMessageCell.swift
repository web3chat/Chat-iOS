//
//  FileMessageCell.swift
//  chat
//
//  Created by 王俊豪 on 2021/4/26.
//

import UIKit
import SnapKit

class FileMessageCell: MessageContentCell {
    
    lazy var contentImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.layer.cornerRadius = 5
        v.clipsToBounds = true
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.image = #imageLiteral(resourceName: "chat_fileBg")
        return v
    }()
    
    lazy var fileIconImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        return v
    }()
    
    var downloadOrUploadProgressView = SectorProgress.init(frame: CGRect.init(x: 0, y: 0, width: 40, height: 40))

    
    let fileNameLab : UILabel = {
        let lab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .center, text: "")
        lab.numberOfLines = 0
        lab.textAlignment = .left
        return lab
    }()
    
    let fileSizeLab = UILabel.getLab(font: UIFont.regularFont(12), textColor: Color_8A97A5, textAlignment: .left, text: "")
    
    let line = UIView.getNormalLineView()
    
    override func setupViews() {
        super.setupViews()
        IMNotifyCenter.shared().addReceiver(receiver: self, type: .download)
        self.messageContainerView.addSubview(self.contentImageView)
        self.contentImageView.addSubview(self.fileIconImageView)
        self.contentImageView.addSubview(self.fileNameLab)
        self.contentImageView.addSubview(self.line)
        self.contentImageView.addSubview(self.fileSizeLab)
        self.fileIconImageView.addSubview(self.downloadOrUploadProgressView)

        
        
//        self.admireView.snp.makeConstraints { (m) in
//            m.bottom.equalTo(contentImageView.snp.bottom).offset(-15)
//            m.left.equalTo(contentImageView.snp.right).offset(-5)
//        }
//
        
//        let longPress = UILongPressGestureRecognizer()
//        longPress.rx.event.subscribe {[weak self] (event) in
//            guard case .next(let press) = event else { return }
//            if press.state == .began {
//                guard let view = press.view else { return }
//                self?.showMenu(in: view)
//            }
//        }.disposed(by: disposeBag)
//        contentImageView.addGestureRecognizer(longPress)
//        let tap = UITapGestureRecognizer()
//        tap.rx.event.subscribe {[weak self] (event) in
//            guard let strongSelf = self else { return }
//            strongSelf.contentImageViewTap(msgId: strongSelf.vm.msgId)
//            }.disposed(by: disposeBag)
//        contentImageView.addGestureRecognizer(tap)
        
    }
    
    
    
    
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        
        self.contentImageView.frame = self.messageContainerView.bounds
//        self.contentImageView.snp.makeConstraints { make in
//            make.size.equalTo(CGSize.init(width: 260, height: 120))
//            make.top.equalTo(avatarView.snp.top).offset(2)
//            make.left.equalTo(statusView.snp.right)
//            make.bottom.equalToSuperview().offset(-15)
//            make.right.equalTo(avatarView.snp.left)
//        }
        fileIconImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 50, height: 50))
            m.left.equalToSuperview().offset(12)
            m.top.equalToSuperview().offset(10)
        }
        fileNameLab.numberOfLines = 0
        fileNameLab.textAlignment = .left
        fileNameLab.snp.makeConstraints { (m) in
            m.top.equalTo(self.fileIconImageView)
            m.left.equalTo(self.fileIconImageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-20)
            m.height.equalTo(50)
        }
        line.snp.makeConstraints { (m) in
            m.height.equalTo(0.5)
            m.left.right.equalToSuperview()
            m.top.equalTo(self.fileIconImageView.snp.bottom).offset(10)
        }
        self.contentImageView.addSubview(fileSizeLab)
        fileSizeLab.snp.makeConstraints { (m) in
            m.left.equalTo(self.fileIconImageView)
            m.right.equalToSuperview().offset(-12)
            m.height.equalTo(30)
            m.bottom.equalToSuperview()
        }
        
        downloadOrUploadProgressView.isHidden = true
        downloadOrUploadProgressView.alpha = 0.6
        downloadOrUploadProgressView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 40, height: 40))
        }
    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        super.configure(with: message, at: indexPath, and: messageCollectionView)
//        guard messageCollectionView.messagesDisplayDelegate != nil else {
//            fatalError("nilMessagesDisplayDelegate")
//        }
        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessageDisplayDelegate")
        }
        switch message.kind {
        case .file(let fileItem):
            let filename = fileItem.fileName ?? ""
            self.fileNameLab.text = filename
            
            let imageName = filename.pathExtension.matchingFileType()
            
            self.fileIconImageView.image = UIImage(named: imageName as String)
            
            let size = fileItem.fileSize ?? 0
            var sizeString = (size / 1024) > 0 ? "\(size / 1024 )K" : "\(size)B"
            if (size / 1024) > 1024 {
                sizeString = "\(size / 1024 / 1024)M"
            }
            self.fileSizeLab.text = sizeString
//            let filePath = fileItem.localFilePath ?? ""
            
//            self.downloadOrUploadProgressView.isHidden = !filePath.isEmpty
//            self.downloadOrUploadProgressView.progress = 0
            
            
        default:
            break
        }
        displayDelegate.configureMediaMessageImageView(self.contentImageView, for: message, at: indexPath, in: messageCollectionView)
    }
    
    // 更新下载进度
    func updateDownLoadProcress(proress : CGFloat){
        if proress < 1 {
            self.downloadOrUploadProgressView.isHidden = false
            self.downloadOrUploadProgressView.progress = proress
        }else{
            self.downloadOrUploadProgressView.isHidden = true
            self.downloadOrUploadProgressView.progress = 0
        }
    }
    
    
    
    func contentImageViewTap(msgId: String) {
//        guard let vm = self.vm as? Message else { return }
//        if vm.message.body.localFilePath.count == 0 {
//            vm.downloadFile()
//        } else {
//            self.actionDelegate?.openFile(msgId: msgId, filePath:vm.message.body.localFilePath, fileName: vm.fileName)
//        }
    }
    
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        // Initialization code
//    }
//
//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//    }
    

}

extension FileMessageCell: DownloadDelegate {
    func downloadProgress(_ sendMsgID: String, _ progress: Float) {
        /*
        guard let data = self.vm as? Message,sendMsgID == data.fileDownloadID  else {
            return
        }
        self.downloadOrUploadProgressView.isHidden = false
        self.downloadOrUploadProgressView.progress = CGFloat(progress)

        if progress == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.downloadOrUploadProgressView.isHidden = true
                self.downloadOrUploadProgressView.progress = 0
            }
        }
         */
    }
}


class MineFileMessageCell: FileMessageCell {
    
    override func setupViews() {
        IMNotifyCenter.shared().addReceiver(receiver: self, type: .upload)
        super.setupViews()
        
        /*
        self.changeMineConstraints()
        contentImageView.snp.remakeConstraints { (m) in
            m.top.equalTo(userNameLbl.snp.bottom).offset(2)
            m.right.equalTo(headerImageView.snp.left)
            m.size.equalTo(CGSize.init(width: 260, height: 120))
            m.bottom.equalToSuperview().offset(-15)
        }
        sendingView.snp.remakeConstraints { (m) in
            m.centerY.equalTo(contentImageView)
            m.right.equalTo(contentImageView.snp.left).offset(-5)
            m.size.equalTo(CGSize(width: 15, height: 15))
        }
        self.admireView.snp.remakeConstraints { (m) in
            m.bottom.equalTo(contentImageView.snp.bottom).offset(-15)
            m.right.equalTo(contentImageView.snp.left).offset(5)
        }
  */
    }
    /*
    override func configure(with data: Message) {
        super.configure(with: data)
        self.sendingView.transform = CGAffineTransform.init(scaleX: 0, y: 0)
        guard let data = data as? Message else { return }
    }
    */
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        // Initialization code
//
//    }
//
//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//    }
    
}

extension MineFileMessageCell: UploadDelegate {
    func uploadProgress(_ sendMsgID: String, _ progress: Float) {
        /*
        guard sendMsgID == self.vm.sendMsgId  else {
            return
        }
        
        self.downloadOrUploadProgressView.isHidden = false
        self.downloadOrUploadProgressView.progress = CGFloat(progress)
        
        if progress == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.downloadOrUploadProgressView.isHidden = true
                self.downloadOrUploadProgressView.progress = 0
                self.sendingView.transform = CGAffineTransform.identity
            }
        }
 */
    }
}
