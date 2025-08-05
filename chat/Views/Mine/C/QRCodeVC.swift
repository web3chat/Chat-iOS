//
//  QRCodeVC.swift
//  chat
//
//  Created by 王俊豪 on 2022/1/18.
//

import Foundation
import SnapKit
import Photos
import Kingfisher
import UIKit

enum FZMQRCodeVCShowType {
    case me     // 自己的二维码
    case group(Group)  // 群二维码
    case team   // 团队二维码
    case customer // 客服二维码
}

class QRCodeVC: UIViewController, ViewControllerProtocol {
    
    private let bag = DisposeBag.init()
    
    private let customer = "1FS8tiVRpjjtYAJuQFbEsKQm3nhzBAfAN1"
    
    let type : FZMQRCodeVCShowType
    
    // 头像
    private lazy var headerImageView : UIImageView = {
        let imV = UIImageView(image: #imageLiteral(resourceName: "avatar_persion"))
        imV.isUserInteractionEnabled = true
        imV.contentMode = .scaleAspectFill
        return imV
    }()
    
    // 名称
    private lazy var nickNameLab: UILabel = {
        let label = UILabel.getLab(font: .boldSystemFont(ofSize: 17), textColor: Color_24374E, textAlignment: .center, text: "")
        label.numberOfLines = 2
        return label
    }()
    
    // 地址
    private lazy var addressLab: UILabel = {
        let label = UILabel.getLab(font: .mediumFont(14), textColor: Color_24374E, textAlignment: .center, text: "")
        return label
    }()
    
    // 二维码视图
    private lazy var qrImageView: UIImageView = {
        let img = UIImageView.init()
        return img
    }()
    
    // 二维码遮罩层
    private lazy var warnLab :UILabel = {
        let lab = UILabel.getLab(font: .regularFont(30), textColor: Color_24374E, textAlignment: .center, text: "此群禁止加群")
        lab.minimumScaleFactor = 0.5
        return lab
    }()
    private lazy var transView: UIView = {
        let v = UIView()
        v.backgroundColor = Color_F6F7F8.withAlphaComponent(0.7)
        
        v.addSubview(warnLab)
        warnLab.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.height.equalTo(30)
            m.center.equalToSuperview()
        }
        v.isHidden = true
        return v
    }()
    
    // 二维码整体视图
    private lazy var qrCodeOverallView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        
        view.addSubview(qrImageView)
        qrImageView.snp.makeConstraints { make in
            make.size.equalTo(170)
            make.center.equalToSuperview()
        }
        
        view.addSubview(transView)
        transView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        return view
    }()
    
    // 扫描加好友lab
    private lazy var tipLab: UILabel = {
        let label = UILabel.getLab(font: .regularFont(14), textColor: Color_8A97A5, textAlignment: .center, text: "扫描二维码加我好友")
        return label
    }()
    
    // 应用下载视图
    // 下载链接lab
    private lazy var downloadUrlLab: UILabel = {
        let label = UILabel.getLab(font: .mediumFont(14), textColor: Color_Theme, textAlignment: .center, text: "应用下载")
        label.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer.init()
        label.addGestureRecognizer(tap)
        tap.rx.event.subscribe(onNext: { (ges) in
            guard ges.state == .ended else { return }
            UIPasteboard.general.string = APP_URL
            self.showToast("应用下载地址已复制")
        }).disposed(by: self.bag)
        return label
    }()
    private lazy var downloadBgView: UIView = {
        let view = UIView()
        view.backgroundColor = Color_F6F7F8
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        
        view.addSubview(downloadUrlLab)
        return view
    }()
    
    // 复制按钮
    private lazy var copyBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.backgroundColor = Color_Auxiliary
        btn.setTitle("复制账号", for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        btn.layer.cornerRadius = 20
        btn.addTarget(self, action: #selector(clickCopyBtnAction), for: .touchUpInside)
        return btn
    }()
    
    // 群二维码提示文字
    private lazy var groupTipLab: UILabel = {
        let label = UILabel.getLab(font: .systemFont(ofSize: 14), textColor: Color_8A97A5, textAlignment: .left, text: "此群属于“团队名”全员群，仅组织内部成员可加入，如果组织外部人员收到此分享，需要先申请加入该组织")
        label.numberOfLines = 0
        return label
    }()
    
    // 群二维码提示文字视图
    private lazy var groupTipView: UIView = {
        let v = UIView()
        v.backgroundColor = Color_F6F7F8
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        v.isHidden = true
        
        return v
    }()
    
    // 发送聊天按钮view
    private lazy var sendBtnView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = true
        v.isHidden = true
        let imgV = UIImageView.init(image: #imageLiteral(resourceName: "sendMsg"))
        v.addSubview(imgV)
        imgV.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(35)
        }
        
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_24374E, textAlignment: .center, text: "发送到聊天")
        v.addSubview(lab)
        lab.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
        }
        let headImgTap = UITapGestureRecognizer()
        headImgTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.clickSendToChat()
        }.disposed(by: bag)
        v.addGestureRecognizer(headImgTap)
        
        return v
    }()
    
    // 保存按钮view
    private lazy var saveBtnView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = true
        v.isHidden = true
        let imgV = UIImageView.init(image: #imageLiteral(resourceName: "save"))
        v.addSubview(imgV)
        imgV.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(35)
        }
        
        let lab = UILabel.getLab(font: .regularFont(14), textColor: Color_24374E, textAlignment: .center, text: "保存")
        v.addSubview(lab)
        lab.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
        }
        
        let headImgTap = UITapGestureRecognizer()
        headImgTap.rx.event.subscribe {[weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.clickSaveQRCode()
        }.disposed(by: bag)
        v.addGestureRecognizer(headImgTap)
        
        return v
    }()
    
    private lazy var whiteBgView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        return v
    }()
    
    private lazy var contentView : UIView = {
        let view = UIView.init(frame: CGRect(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight))
        
        // 顶部主题色背景图
        let bgV = UIView()
        bgV.backgroundColor = Color_Theme
        view.addSubview(bgV)
        bgV.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(130)
        }
        
        // 其余白色背景图
        view.addSubview(whiteBgView)
        whiteBgView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview().offset(105)
            make.bottom.equalTo(k_ScreenHeight)
        }
        
        // 头像
        let headerBgView = UIView()
        headerBgView.backgroundColor = .white
        headerBgView.layer.cornerRadius = 7
        view.addSubview(headerBgView)
        headerBgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(50)
            make.size.equalTo(110)
        }
        headerBgView.addSubview(headerImageView)
        headerImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(100)
        }
        
        // 名称
        view.addSubview(nickNameLab)
        nickNameLab.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.top.equalTo(headerImageView.snp.bottom).offset(15)
        }
        
        // 地址
        view.addSubview(addressLab)
        addressLab.snp.makeConstraints { make in
            make.left.right.equalTo(nickNameLab)
            make.top.equalTo(nickNameLab.snp.bottom).offset(5)
        }
        
        // 二维码视图
        view.addSubview(qrCodeOverallView)
        qrCodeOverallView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(200)//
            make.top.equalTo(addressLab.snp.bottom).offset(30)//
        }
        
//        // 群类型提示视图
//        view.addSubview(groupTipView)
        
        // 扫码lab
        view.addSubview(tipLab)
        tipLab.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(qrCodeOverallView.snp.bottom).offset(5)
            make.height.equalTo(20)
        }
        
        // 下载链接
        view.addSubview(downloadBgView)
        
        // 复制按钮
        view.addSubview(copyBtn)
        copyBtn.snp.makeConstraints { make in
            make.size.equalTo(CGSize.init(width: 150, height: 40))
            make.centerX.equalToSuperview()
            make.top.equalTo(tipLab.snp.bottom).offset(20)
        }
        
        // 发送到聊天
        view.addSubview(sendBtnView)
        sendBtnView.snp.makeConstraints { make in
            make.size.equalTo(CGSize.init(width: 105, height: 60))
            make.top.equalTo(copyBtn.snp.bottom).offset(30)
            make.left.equalToSuperview().offset(80)
        }
        
        // 保存
        view.addSubview(saveBtnView)
        saveBtnView.snp.makeConstraints { make in
            make.size.equalTo(CGSize.init(width: 105, height: 60))
            make.top.equalTo(copyBtn.snp.bottom).offset(30)
            make.right.equalToSuperview().offset(-80)
        }
        
        return view
    }()
    
    private lazy var scrollview: UIScrollView = {
        let view = UIScrollView(frame: CGRect.zero)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.contentSize = CGSize(width: k_ScreenWidth, height: k_ScreenHeight)
        view.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 40, right: 0)
        view.addSubview(contentView)
        contentView.frame = CGRect(x: 0, y: 0, width: k_ScreenWidth, height: k_ScreenHeight)
        return view
    }()
    
    // 下载到相册的视图
    private lazy var saveView: QRCodeView = {
        let v = QRCodeView.init()
        return v
    }()
    
    private lazy var titleLab: UILabel = {
        return UILabel.getLab(font: .boldFont(17), textColor: .white, textAlignment: .center, text: "我的二维码")
    }()
    
    private lazy var navView: UIView = {
        let v = UIView()
        
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "nav_back_white"), for: .normal)
        btn.addTarget(self, action: #selector(clickBackAction), for: .touchUpInside)
        btn.contentHorizontalAlignment = .left
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        v.addSubview(btn)
        btn.snp.makeConstraints { make in
            make.size.equalTo(44)
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(10)
        }
        
        v.addSubview(titleLab)
        titleLab.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        return v
    }()
    
    init(with type: FZMQRCodeVCShowType) {
        self.type = type
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        setContentViewFrame()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = Color_Theme
        self.xls_isNavigationBarHidden = true
        
        self.createUI()
    }
    
    @objc private func clickBackAction() {
        self.navigationController?.popViewController()
    }
    
    private func createUI() {
        self.view.addSubview(navView)
        navView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview().offset(k_StatusBarHeight)
            make.height.equalTo(44)
        }
        
        self.view.addSubview(scrollview)
        scrollview.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(navView.snp.bottom)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.whiteBgView.roundCorners([.topLeft, .topRight], radius: 30)
        }
        
        downloadUrlLab.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(k_ScreenWidth - 60)
        }
        
        downloadBgView.snp.makeConstraints { make in
            make.top.equalTo(tipLab.snp.bottom).offset(15)
            make.centerX.equalToSuperview()
            make.height.equalTo(30)
//            make.width.equalToSuperview().offset(-60)
            make.width.equalTo(downloadUrlLab.snp.width).offset(30)//
        }
        
        var height = k_ScreenHeight
        
        if case .group(let groupInfo) = self.type {// 群二维码
            self.titleLab.text = "群二维码"
            
            let avatar = groupInfo.avatarURLStr
            if avatar.isBlank {
                headerImageView.image = #imageLiteral(resourceName: "avatar_group")
            } else {
                headerImageView.kf.setImage(with: URL.init(string: groupInfo.avatar), placeholder:#imageLiteral(resourceName: "avatar_group") )
            }
            
            var typeImg: UIImage? = nil
            switch groupInfo.groupType {
            case 1:
                typeImg = #imageLiteral(resourceName: "icon_type_quanyuan")
            case 2:
                typeImg = #imageLiteral(resourceName: "icon_type_bumen")
            default:
                break
            }
            
            self.nickNameLab.attributedText = nil
            self.nickNameLab.text = nil
            
            if let typeImg = typeImg {
                self.nickNameLab.attributedText = groupInfo.publicName.jointImage(image: typeImg, rect: CGRect.init(x: 0, y: 0, width: 34, height: 18))
            } else {
                self.nickNameLab.text = groupInfo.publicName
            }
            
            // 群号
            if let markId = groupInfo.markId {
                self.addressLab.text = "群号：\(markId)"
            } else {
                self.addressLab.text = "群ID：\(groupInfo.id)"
            }
            
            copyBtn.setTitle("复制群号", for: .normal)
            
            // 生成二维码
            let time = Date.timestamp.string
            let groupQrCode = APP_DOWNLOAD_URL + "gid=\(groupInfo.id)" + "&server=\(BackupURL.urlEncoded)" + "&inviterId=\(LoginUser.shared().address)" + "&createTime=\(time)"
            self.qrImageView.image = QRCodeGenerator.setupQRCodeImage(groupQrCode, image: #imageLiteral(resourceName: "logo_120"))
            
            //加群方式，0=无需审批（默认），1=禁止加群，群主和管理员邀请加群
            if groupInfo.joinType == 1 {
                self.transView.isHidden = false
                self.tipLab.isHidden = false
                self.downloadBgView.isHidden = true
                self.groupTipView.isHidden = true
                self.copyBtn.isHidden = true
                self.saveBtnView.isHidden = false
                self.sendBtnView.isHidden = false
                
                self.qrCodeOverallView.snp.updateConstraints { make in
                    make.size.equalTo(200)
                    make.top.equalTo(addressLab.snp.bottom).offset(30)
                }
                
                self.tipLab.text = "扫描二维码加入群聊"
                
                self.sendBtnView.snp.remakeConstraints { make in
                    make.top.equalTo(tipLab.snp.bottom).offset(95)
                    make.size.equalTo(CGSize.init(width: 105, height: 60))
                    make.left.equalToSuperview().offset(80)
                }
                self.saveBtnView.snp.remakeConstraints { make in
                    make.top.equalTo(tipLab.snp.bottom).offset(95)
                    make.size.equalTo(CGSize.init(width: 105, height: 60))
                    make.right.equalToSuperview().offset(-80)
                }
            } else {
                self.transView.isHidden = true
                self.downloadBgView.isHidden = true
                self.copyBtn.isHidden = false
                self.saveBtnView.isHidden = false
                self.sendBtnView.isHidden = false
                
                qrCodeOverallView.snp.updateConstraints { make in
                    make.size.equalTo(170)
                    make.top.equalTo(addressLab.snp.bottom).offset(10)
                }
                
                // 群类型 (0: 普通群, 1: 全员群, 2: 部门群)
                if groupInfo.groupType == 1 || groupInfo.groupType == 2 {
                    self.tipLab.isHidden = true
                    self.groupTipView.isHidden = false
                    
                    var tipStr = ""
                    let typeStr = groupInfo.groupType == 1 ? "全员群" : "部门群"
                    if let teamName = LoginUser.shared().myCompanyInfo?.name {
                        tipStr = "此群属于“\(teamName)”\(typeStr)，仅组织内部成员可加入，如果组织外部人员收到此分享，需要先申请加入该组织"
                    } else {
                        tipStr = "此群属于\(typeStr)，仅组织内部成员可加入，如果组织外部人员收到此分享，需要先申请加入该组织"
                    }
                    
                    contentView.addSubview(groupTipView)
                    
                    groupTipView.addSubview(groupTipLab)
                    groupTipLab.snp.makeConstraints { make in
                        make.top.equalToSuperview().offset(10)
                        make.left.equalToSuperview().offset(14)
                        make.right.equalToSuperview().offset(-14)
                    }
                    
                    let heightTip = tipStr.getContentHeight(font: .systemFont(ofSize: 14), width: k_ScreenWidth - 98)
                    
                    groupTipView.snp.makeConstraints { make in
                        make.top.equalTo(qrCodeOverallView.snp.bottom).offset(15)
                        make.left.equalToSuperview().offset(35)
                        make.right.equalToSuperview().offset(-35)
                        make.height.equalTo(heightTip + 20)
                    }
                    
                    copyBtn.snp.remakeConstraints { make in
                        make.size.equalTo(CGSize.init(width: 150, height: 40))
                        make.centerX.equalToSuperview()
                        make.top.equalTo(qrCodeOverallView.snp.bottom).offset(15 + 10 + heightTip + 10 + 20)
                    }
                } else {
                    // 普通群
                    self.tipLab.isHidden = false
                    self.groupTipView.isHidden = true
                    
                    copyBtn.snp.remakeConstraints { make in
                        make.size.equalTo(CGSize.init(width: 150, height: 40))
                        make.centerX.equalToSuperview()
                        make.top.equalTo(tipLab.snp.bottom).offset(20)
                    }
                }
                
                self.sendBtnView.snp.updateConstraints { make in
                    make.top.equalTo(copyBtn.snp.bottom).offset(30)
                }
                self.saveBtnView.snp.updateConstraints { make in
                    make.top.equalTo(copyBtn.snp.bottom).offset(30)
                }
            }
            
            height = self.saveBtnView.frame.maxY
            
            // 保存到相册的二维码视图
            self.view.addSubview(saveView)
            saveView.frame = CGRect.init(x: k_ScreenWidth, y: 0, width: k_ScreenWidth, height: 582)
            saveView.loadData(groupInfo: groupInfo)
        }else if case .customer = type {
            self.transView.isHidden = true
            self.tipLab.isHidden = false
            self.downloadBgView.isHidden = true
            self.groupTipView.isHidden = true
            self.copyBtn.isHidden = false
            self.saveBtnView.isHidden = true
            self.sendBtnView.isHidden = true
            
            self.titleLab.text = "客服二维码"
            
            headerImageView.image = #imageLiteral(resourceName: "avatar_persion")
            
            self.nickNameLab.text = "WW客服"
            
            
            self.addressLab.text = customer
            
            let qrCode = ShareURL + customer
            self.qrImageView.image = QRCodeGenerator.setupQRCodeImage(qrCode, image: #imageLiteral(resourceName: "logo_120"))
            
            self.qrCodeOverallView.snp.updateConstraints { make in
                make.size.equalTo(200)
                make.top.equalTo(addressLab.snp.bottom).offset(30)
            }
            
            self.tipLab.text = "扫描二维码加WW客服好友"
            
//            let downloadStr = "应用下载：" + APP_URL
//            self.downloadUrlLab.attributedText = downloadStr.jointImage(image: #imageLiteral(resourceName: "icon_copy"))
            
            copyBtn.snp.remakeConstraints { make in
                make.size.equalTo(CGSize.init(width: 150, height: 40))
                make.centerX.equalToSuperview()
                make.top.equalTo(downloadBgView.snp.bottom).offset(20)
            }
            
            copyBtn.setTitle("复制账号", for: .normal)
            
            height = self.copyBtn.frame.maxY
        }
        else {// 我的二维码
            self.transView.isHidden = true
            self.tipLab.isHidden = false
            self.downloadBgView.isHidden = true
            self.groupTipView.isHidden = true
            self.copyBtn.isHidden = false
            self.saveBtnView.isHidden = true
            self.sendBtnView.isHidden = true
            
            self.titleLab.text = "我的二维码"
            
            let avatar = LoginUser.shared().avatarUrl
            if avatar.isBlank {
                headerImageView.image = #imageLiteral(resourceName: "avatar_persion")
            } else {
                headerImageView.kf.setImage(with: URL.init(string: avatar), placeholder: #imageLiteral(resourceName: "avatar_persion"))
            }
            
            self.nickNameLab.text = LoginUser.shared().nickName?.value ?? ""
            
            let address = LoginUser.shared().address
            
            self.addressLab.text = address
            
            let qrCode = ShareURL + address
            self.qrImageView.image = QRCodeGenerator.setupQRCodeImage(qrCode, image: #imageLiteral(resourceName: "logo_120"))
            
            self.qrCodeOverallView.snp.updateConstraints { make in
                make.size.equalTo(200)
                make.top.equalTo(addressLab.snp.bottom).offset(30)
            }
            
            self.tipLab.text = "扫描二维码加我\(APPNAME)好友"
            
            let downloadStr = "应用下载：" + APP_URL
            self.downloadUrlLab.attributedText = downloadStr.jointImage(image: #imageLiteral(resourceName: "icon_copy"))
            
            copyBtn.snp.remakeConstraints { make in
                make.size.equalTo(CGSize.init(width: 150, height: 40))
                make.centerX.equalToSuperview()
                make.top.equalTo(downloadBgView.snp.bottom).offset(20)
            }
            
            copyBtn.setTitle("复制账号", for: .normal)
            
            height = self.copyBtn.frame.maxY
        }
        height += 30
        contentView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: height)
        scrollview.contentSize = CGSize(width: k_ScreenWidth, height: height)
    }
    
    private func setContentViewFrame() {
        var height = k_ScreenHeight
        
        if case .group(_) = self.type {// 群二维码
            height = self.saveBtnView.frame.maxY
        } else {
            height = self.copyBtn.frame.maxY
        }
        height += 30
        contentView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: height)
        scrollview.contentSize = CGSize(width: k_ScreenWidth, height: height)
    }
    
    //MARK: -- 点击事件
    
    // 点击复制按钮
    @objc private func clickCopyBtnAction() {
        if case .group(let groupInfo) = self.type {
            var copyStr = String(groupInfo.id)
            if let markId = groupInfo.markId {
                copyStr = markId
            }
            UIPasteboard.general.string = copyStr
            self.showToast("群号已复制")
        } else {
            UIPasteboard.general.string = LoginUser.shared().address
            self.showToast("地址已复制")
        }
    }
    
    // 点击发送到聊天按钮
    @objc private func clickSendToChat() {
        FZMLog("发送到聊天")
        if case .group(let groupInfo) = self.type, groupInfo.joinType == 1 {// 是群二维码，且禁止加群
            self.showToast("此群禁止加群")
            return
        }
    }
    
    // 点击保存按钮
    @objc private func clickSaveQRCode() {
        if case .group(let groupInfo) = self.type, groupInfo.joinType == 1 {// 是群二维码，且禁止加群
            self.showToast("此群禁止加群")
            return
        }
        //截屏
        let image = saveView.asImage(with: saveView.bounds)
        
        //保存相册
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = "图片保存失败"
        }else{
            showMessage = "图片已保存"
        }
        self.showToast(showMessage)
    }
}
