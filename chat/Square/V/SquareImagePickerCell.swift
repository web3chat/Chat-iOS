//
//  SquareImagePickerCell.swift
//  chat
//
//  发帖页已选图片格子（右上角带删除按钮）
//

import Foundation
import UIKit
import SnapKit
import Kingfisher

final class SquareImagePickerCell: UICollectionViewCell {

    static let identifier = "SquareImagePickerCell"

    /// 删除回调
    var onDelete: (() -> Void)?

    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 6
        view.backgroundColor = Color_F6F7F8
        return view
    }()

    private lazy var deleteBtn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(UIImage.init(systemName: "xmark.circle.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        btn.tintColor = Color_FFFFFF
        btn.backgroundColor = UIColor.init(white: 0, alpha: 0.4)
        btn.layer.cornerRadius = 9
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(deleteTap), for: .touchUpInside)
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(deleteBtn)

        imageView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
        deleteBtn.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(2)
            m.top.equalToSuperview().offset(-2)
            m.size.equalTo(CGSize(width: 18, height: 18))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(image: UIImage) {
        imageView.image = image
    }

    /// 编辑模式：展示**已发布的远程图片**（走与列表同一套 OSS 方形裁切地址）
    func configure(url: String) {
        guard let link = SquareMediaURLParser.displayURL(from: url, pixelSide: 300) else {
            imageView.image = nil
            return
        }
        imageView.kf.setImage(with: link, placeholder: nil, options: [.keepCurrentImageWhileLoading])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
    }

    @objc private func deleteTap() {
        onDelete?()
    }
}
