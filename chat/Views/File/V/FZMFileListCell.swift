//
//  FZMFileListCell.swift
//  chat
//
//  Created by 王俊豪 on 2022/2/21.
//

import Foundation
import RxSwift
import SnapKit
import UIKit

class FZMFileListCell: UITableViewCell {
    let disposeBag = DisposeBag()
    var vm: FZMMessageBaseVM?
//    var senderLabBlock: ((Message)->())? {
//        didSet {
//            guard senderLabBlock != nil else {return}
//            senderLab.textColor = Color_Theme
//        }
//    }
    lazy var selectBtn : UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "tool_disselect"), for: .normal)
        btn.setImage(#imageLiteral(resourceName: "tool_select"), for: .selected)
        btn.enlargeClickEdge(15, 15, 15, 15)
        btn.isHidden = true
        return btn
    }()// 选择按钮
    var isShowSelect: Bool = false {
        didSet{
            selectBtn.isHidden = !isShowSelect
            if self.fileIconImageView.superview != nil {
                self.fileIconImageView.snp.updateConstraints { (m) in
                    m.left.equalToSuperview().offset(isShowSelect ? 45 : 15)
                }
            }
        }
    }// 当前是否是选择文件UI flg
    lazy var fileIconImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        return v
    }()// 文件图标
    
    lazy var downloadProgressView: SectorProgress = {
        let view = SectorProgress.init(frame: CGRect.init(x: 0, y: 0, width: 85, height: 85))
        view.isHidden = true
        return view
    }() // 下载进度视图
    
    let fileNameLab = UILabel.getLab(font: UIFont.regularFont(16), textColor: Color_24374E, textAlignment: .center, text: "")// 文件名
    let fileSizeLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")// 文件大小
    let senderLab = UILabel.getLab(font: UIFont.regularFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "")// 上传人备注/昵称
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = .white
        self.clipsToBounds = true
//        IMNotifyCenter.shared().addReceiver(receiver: self, type: .download)
        self.initViews()
    }
    
    func initViews() {
        
        self.contentView.addSubview(selectBtn)
        selectBtn.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
            m.size.equalTo(CGSize(width: 15, height: 15))
        }
        self.contentView.addSubview(fileIconImageView)
        fileIconImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 60, height: 60))
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
        }
        self.fileIconImageView.addSubview(downloadProgressView)
        downloadProgressView.isHidden = true
        downloadProgressView.alpha = 0.6
        downloadProgressView.snp.makeConstraints { (m) in
            m.center.equalToSuperview()
            m.size.equalTo(CGSize.init(width: 85, height: 85))
        }
        fileNameLab.textAlignment = .left
        self.contentView.addSubview(fileNameLab)
        fileNameLab.snp.makeConstraints { (m) in
            m.top.equalTo(self.fileIconImageView)
            m.left.equalTo(self.fileIconImageView.snp.right).offset(10)
            m.right.equalToSuperview().offset(-15)
        }
        fileSizeLab.textAlignment = .left
        self.contentView.addSubview(fileSizeLab)
        fileSizeLab.snp.makeConstraints { (m) in
            m.left.right.equalTo(self.fileNameLab)
            m.centerY.equalTo(self.fileIconImageView)
        }
        senderLab.textAlignment = .left
        self.contentView.addSubview(senderLab)
        senderLab.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 0, bottom: 2, right: 10))
        senderLab.snp.makeConstraints { (m) in
            m.left.equalTo(self.fileNameLab)
            m.right.lessThanOrEqualTo(self.contentView)
            m.bottom.equalTo(self.fileIconImageView)
        }
        
//        let tap = UITapGestureRecognizer.init()
//        tap.rx.event.subscribe { [weak self] (_) in
//            guard let strongSelf = self,let vm = self?.vm else {return}
//            strongSelf.senderLabBlock?(vm)
//            }.disposed(by: disposeBag)
//        senderLab.addGestureRecognizer(tap)
        
        selectBtn.rx.controlEvent(.touchUpInside).subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.selectBtn.isSelected = !strongSelf.selectBtn.isSelected
            strongSelf.vm?.selected = strongSelf.selectBtn.isSelected
        }.disposed(by: disposeBag)
    }
    
    func configure(with data: FZMMessageBaseVM, isShowSelect: Bool = false) {
        self.vm = data
        self.isShowSelect = isShowSelect
        self.selectBtn.isSelected = self.vm?.selected ?? false
        
        let filename = data.message.msgType.fileName ?? ""
        self.fileNameLab.text = filename
        
        let imageName = filename.pathExtension.matchingFileType()
        
        self.fileIconImageView.image = UIImage(named: imageName as String)
        
//        if let haveFile = FZM_UserDefaults.value(forKey: data.fileUrl) as? String, !haveFile.isEmpty {
//            downloadProgressView.isHidden = true
//        } else {
//            downloadProgressView.isHidden = false
//        }
//        self.downloadProgressView.progress = 0
        // 下载失败订阅
        data.fileDownloadFailedSubject.subscribe { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.downloadProgressView.isHidden = false
            strongSelf.downloadProgressView.progress = 0
        }.disposed(by: disposeBag)
        
        // 下载进度订阅
        data.fileDownloadProgressSubject.subscribe { [weak self] (event) in
            guard let strongSelf = self, case .next(let progress) = event else { return }
            strongSelf.downloadProgressView.progress = progress
        }.disposed(by: disposeBag)
        
        let timeStr = String.showTimeString(with: Double(data.message.datetime))
        let size = data.message.msgType.fileSize ?? 0
        var sizeString = (size / 1024) > 0 ? "\(size / 1024 )K" : "\(size)B"
        if (size / 1024) > 1024 {
            sizeString = "\(size / 1024 / 1024)M"
        }
        self.fileSizeLab.text = timeStr + "   " + sizeString
        
        // 发送者昵称/备注
        var nickname = ""
        let senderAdd = data.message.fromId
        if senderAdd == LoginUser.shared().address {// 自己发的
            nickname = LoginUser.shared().contactsName
        } else {// other
            if data.message.channelType == .person {// 私聊
                let user = UserManager.shared().user(by: senderAdd)
                nickname = user?.contactsName ?? senderAdd.shortAddress
            } else {// 群聊
                let member = GroupManager.shared().getDBGroupMember(with: data.message.targetId.intEncoded, memberId: senderAdd)
                nickname = member?.contactsName ?? senderAdd.shortAddress
            }
        }
        self.senderLab.text = nickname
        
//        data.infoSubject.subscribe {[weak self] (event) in
//            guard case .next(let (name,_)) = event else { return }
//            self?.senderLab.text = name
//            }.disposed(by: disposeBag)
        
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
}
