//
//  QRCodeReaderVC.swift
//  chat
//
//  Created by 陈健 on 2021/3/3.
//

import UIKit
import SnapKit
import QRCodeReader
import Photos

@objc class QRCodeReaderVC: UIViewController, ViewControllerProtocol {
    
    lazy var scanTitleLab: UILabel  = {
        let lab = UILabel.getLab(font: UIFont.boldSystemFont(ofSize: 17), textColor: Color_Theme, textAlignment: .center, text: "扫一扫")
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
        btn.setTitle("从相册选择", for: .normal)
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
        
        let block = {
            let picker = ImagePickerController.init(withSelectOne: true, maxSelectCount: 1, allowEditing: false, showVideo: false)
            picker.didFinishPickingPhotosHandle = {[weak self] (photos, _, _) in
                guard let self = self, let image = photos?.first  else { return }
                self.reader.stopScanning()
                guard let qrcodeStr = QRCodeGenerator.detectorQRCode(with: image) else {
                    self.showToast("解析失败")
                    self.reader.startScanning()
                    return
                }
                self.backWithBlock(value: qrcodeStr)
//                self.readBlock?(qrcodeStr)
            }
            self.present(picker, animated: true, completion: nil)
        }
        
        if PHPhotoLibrary.authorizationStatus() == .notDetermined {
            PHPhotoLibrary.requestAuthorization { (status) in
                DispatchQueue.main.async {
                    if status == .authorized {
                        block()
                    }else {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
            }
        }else if PHPhotoLibrary.authorizationStatus() == .authorized {
            block()
        }else {
            let alert = InfoAlertView.init()
            alert.attributedTitle = NSAttributedString.init(string: "提示", attributes: [.font : UIFont.systemFont(ofSize: 14), .foregroundColor : Color_8A97A5])
            alert.confirmBtnTitle = "确定"
            alert.attributedInfo = NSAttributedString.init(string: "系统相册权限未打开，请设置", attributes: [.font : UIFont.systemFont(ofSize: 16), .foregroundColor : Color_24374E])
            alert.confirmBlock = {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            alert.show()
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
          alert = UIAlertController(title: "没有相机权限", message: "请打开相机权限", preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "去设置", style: .default, handler: { (_) in
            DispatchQueue.main.async {
              if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, completionHandler: nil)
              }
            }
          }))
          alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        default:
          alert = UIAlertController(title: "", message: "当前设备不支持扫一扫", preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        }
        present(alert, animated: true, completion: nil)
        return false
      }
    }
}
