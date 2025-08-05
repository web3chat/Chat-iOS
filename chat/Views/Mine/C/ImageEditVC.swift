//
//  ImageEditVC.swift
//  chat
//
//  Created by 王俊豪 on 2022/1/21.
//

import Foundation
import UIKit
import Lantern
import SnapKit
import TZImagePickerController
import CryptoSwift

class ImageEditVC: UIViewController, ViewControllerProtocol, UIScrollViewDelegate {
    
    var imageEditBlock: ImageBlock?
    
    private let image: UIImage
    
    let padding = (k_ScreenHeight - k_ScreenWidth) / 2// 截图框上下距离屏幕边的间距
    
    let cropRect = CGRect(x: 0, y: (k_ScreenHeight - k_ScreenWidth) / 2, width: k_ScreenWidth, height: k_ScreenWidth)
    
    private lazy var scrollview: UIScrollView = {
        let scrollview = UIScrollView(frame: cropRect)
        scrollview.isScrollEnabled = true
        scrollview.bounces = true
        scrollview.showsVerticalScrollIndicator = false
        scrollview.showsHorizontalScrollIndicator = false
        scrollview.clipsToBounds = false
        
        // 两个手指拿捏缩放
        scrollview.minimumZoomScale = 1.0
        scrollview.maximumZoomScale = 3.0
        scrollview.delegate = self
        return scrollview
    }()
    
    init(with image: UIImage) {
        self.image = image
        
        super.init(nibName: nil, bundle: nil)
        
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.xls_isNavigationBarHidden = true
        self.view.backgroundColor = .black
    }
    
    private func setupViews() {
        
//        let scrollview = UIScrollView(frame: cropRect)
        self.view.addSubview(scrollview)
//        scrollview.isScrollEnabled = true
//        scrollview.bounces = true
//        scrollview.showsVerticalScrollIndicator = false
//        scrollview.showsHorizontalScrollIndicator = false
//        scrollview.clipsToBounds = false
//
//        // 两个手指拿捏缩放
//        scrollview.minimumZoomScale = 1.0
//        scrollview.maximumZoomScale = 3.0
//        scrollview.delegate = self
        
        let imageView = UIImageView(image: self.image)
        imageView.contentMode = .scaleAspectFill
        scrollview.addSubview(imageView)
        imageView.frame = CGRect.init(x: 0, y: 0, width: k_ScreenWidth, height: (k_ScreenWidth*image.size.height)/image.size.width)
        
        scrollview.contentSize = imageView.bounds.size
        
        if imageView.frame.height > cropRect.height {
            let h = (imageView.frame.height - cropRect.height)/2
            scrollview.contentOffset = CGPoint.init(x: 0, y: h)
        }
        
        let navView = UIView()
        navView.backgroundColor = UIColor.init(hexString: "0x000000", transparency: 0.8)
        self.view.addSubview(navView)
        navView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(k_StatusNavigationBarHeight)
        }
        
        let backBtn = UIButton.init(type: .custom)
        backBtn.setImage(#imageLiteral(resourceName: "nav_back_white"), for: .normal)
        backBtn.addTarget(self, action: #selector(clickBack), for: .touchUpInside)
        navView.addSubview(backBtn)
        backBtn.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(10)
            make.size.equalTo(44)
            make.bottom.equalToSuperview()
        }
        
        let okBtn = UIButton.init(type: .custom)
        okBtn.setTitle("确定", for: .normal)
        okBtn.setTitleColor(.white, for: .normal)
        okBtn.titleLabel?.font = .regularFont(16)
        okBtn.addTarget(self, action: #selector(clickOkBtn), for: .touchUpInside)
        navView.addSubview(okBtn)
        okBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-10)
            make.size.equalTo(44)
            make.bottom.equalToSuperview()
        }
        
        let cropBgView = UIView()
        cropBgView.backgroundColor = .clear
        cropBgView.isUserInteractionEnabled = false
        self.view.addSubview(cropBgView)
        cropBgView.frame = self.view.frame
        
        // 裁剪框背景的处理
        TZImageCropManager.overlayClipping(with: cropBgView, cropRect: cropRect, containerView: self.view, needCircleCrop: false)
        
        let cropView = UIView()
        cropView.isUserInteractionEnabled = false
        cropView.frame = cropRect
        cropView.backgroundColor = .clear
        cropView.layer.borderColor = UIColor.white.cgColor
        cropView.layer.borderWidth = 1
        self.view.addSubview(cropView)
    }
    
    @objc private func clickBack() {
        self.navigationController?.popViewController()
    }
    
    @objc private func clickOkBtn() {
        
        let image = self.view.asImage(with: CGRect.init(x: cropRect.origin.x + 1, y: cropRect.origin.y + 1, width: cropRect.size.width - 2, height: cropRect.size.height - 2))
        
        self.imageEditBlock?(image)
        
        self.clickBack()
    }
}

extension ImageEditVC {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        for imagev in scrollView.subviews {
            if imagev is UIImageView {
                return imagev
            }
        }
        return nil
    }
}
