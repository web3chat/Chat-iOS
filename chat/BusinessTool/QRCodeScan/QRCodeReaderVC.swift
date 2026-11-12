//
//  QRCodeReaderVC.swift
//  chat
//
//  Created by fzm on 2021/3/3.
//

import UIKit
import SnapKit
import QRCodeReader
import Photos

@objc class QRCodeReaderVC: UIViewController, ViewControllerProtocol {
    
    lazy var scanTitleLab: UILabel  = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 17), textColor: Color_Theme, textAlignment: .center, text: L("扫一扫"))
        return lab
    }()
    
    private lazy var backBtn: UIButton = {
        let btn = UIButton.init()
        btn.setImage(UIImage.init(named: "nav_back")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_Theme
        btn.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10))
        btn.addTarget(self, action: #selector(back), for: .touchUpInside)
        return btn
    }()
    
    private lazy var albumBtn: UIButton = {
        let btn = UIButton.init()
        btn.setTitle(L("从相册选择"), for: .normal)
        btn.setTitleColor(Color_Theme, for: .normal)
        btn.enlargeClickEdge(UIEdgeInsets.init(top: 10, left: 10, bottom: 10, right: 10))
        btn.addTarget(self, action: #selector(albumBtnTouch), for: .touchUpInside)
        return btn
    }()
    
    private lazy var reader: QRCodeReader = {
        let reader = QRCodeReader()
        reader.didFindCode = {[weak self] result in
          print("Completion with result: \(result.value) of type \(result.metadataType)")
            self?.backWithBlock(value: result.value)
//            self?.readBlock?(result.value)
        }
        return reader
    }()
    
    private lazy var previewView: QRCodeReaderView = {
        let v = QRCodeReaderView.init()
        v.setupComponents(with: QRCodeReaderViewControllerBuilder.init(buildBlock: {
            $0.reader                 = reader
            $0.showTorchButton        = false
            $0.showSwitchCameraButton = false
            $0.showCancelButton       = false
            $0.showOverlayView        = false
        }))
        return v
    }()
    
   @objc var readBlock: ((String)->())?
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.xls_isNavigationBarHidden = true
        self.setupViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard checkScanPermissions() else { return }
        self.reader.startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.reader.stopScanning()
    }

    private func setupViews() {
        self.view.addSubview(self.previewView)
        self.previewView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        
        self.view.addSubview(self.backBtn)
        self.backBtn.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 11, height: 20))
            m.left.equalToSuperview().offset(16)
            m.top.equalTo(self.view.safeAreaTop).offset(12)
        }
        
        self.view.addSubview(self.scanTitleLab)
        self.scanTitleLab.snp.makeConstraints { (m) in
            m.centerY.equalTo(self.backBtn)
            m.centerX.equalToSuperview()
        }
        
        self.view.addSubview(self.albumBtn)
        self.albumBtn.snp.makeConstraints { (m) in
            m.bottom.equalToSuperview().offset(-k_SafeBottomInset - 100)
            m.centerX.equalToSuperview()
        }
    }
    
    @objc private func back() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func backWithBlock(value: String) {
        self.dismiss(animated: true) {
            self.readBlock?(value)
        }
    }
    
    @objc private func albumBtnTouch() {
        // 打开系统相册前统一走权限检查（未决定→请求；部分照片→提示；拒绝→去设置）。
        // 注：扫一扫用的是系统 PHPicker，权限只影响其它直接读相册的页面，但产品要求统一提示。
        PhotoLibraryAccess.preparePhotoAccess(
            from: self,
            limitedMessage: L("你当前只允许访问「部分照片」。扫一扫使用的是系统相册选择器，仍可浏览全部照片；如需在其它页面也看到全部照片，请点「选择更多照片」。")
        ) { [weak self] in
            self?.startAlbumPick()
        }
    }

    /// 真正打开相册选择器（权限已就绪）
    private func startAlbumPick() {
        // 与「聊天发送图片 / 广场发帖」复用同一个系统相册选择器（PHPicker）：
        //  · 系统 UI 自带「相簿」入口，能进任意相册、看到全部照片；
        //  · 选图 + 识别的实现统一在 SystemMediaPicker.pickQRCode（钱包侧扫一扫也走同一套）。
        self.reader.stopScanning()

        SystemMediaPicker.pickQRCode(from: self) { [weak self] cancelled, code in
            guard let self = self else { return }
            if let code = code, !code.isEmpty {
                self.backWithBlock(value: code)
                return
            }
            // 取消或没识别到：恢复扫码（没识别到才提示）
            if !cancelled {
                self.showToast(L("解析失败"))
            }
            self.reader.startScanning()
        }
    }
    
}


extension QRCodeReaderVC {
    private func checkScanPermissions() -> Bool {
      do {
        return try QRCodeReader.supportsMetadataObjectTypes()
      } catch let error as NSError {
        let alert: UIAlertController
        switch error.code {
        case -11852:
          alert = UIAlertController(title: L("没有相机权限"), message: L("请打开相机权限"), preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: L("去设置"), style: .default, handler: { (_) in
            DispatchQueue.main.async {
              if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, completionHandler: nil)
              }
            }
          }))
          alert.addAction(UIAlertAction(title: L("取消"), style: .cancel, handler: nil))
        default:
          alert = UIAlertController(title: "", message: L("当前设备不支持扫一扫"), preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        }
        present(alert, animated: true, completion: nil)
        return false
      }
    }
}
