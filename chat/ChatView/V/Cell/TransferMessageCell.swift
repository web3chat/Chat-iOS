//
//  TransferMessageCell.swift
//  chat
//
//  Created by 郑晨 on 2025/3/10.
//
import UIKit
import SnapKit

class TransferMessageCell: MessageContentCell{
    
    lazy var coinNameLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 16), textColor: Color_Auxiliary, textAlignment: .left, text: "")
        return lab
    }()
    
    lazy var detailLab: UILabel = {
        let lab = UILabel.getLab(font: .systemFont(ofSize: 10), textColor: Color_Auxiliary, textAlignment: .left, text: "")
        return lab
    }()
    
    lazy var contentImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.layer.cornerRadius = 5
        v.clipsToBounds = true
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.backgroundColor = UIColor.init(hex: 0xEBAE44)
        return v
    }()
    
    lazy var transferIconImageView : UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        v.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        v.isUserInteractionEnabled = true
        v.layer.cornerRadius = 5
        v.layer.masksToBounds = true
        v.image = UIImage.init(named: "inputBar_transfer")
        return v
    }()

    override func setupViews() {
        super.setupViews()
        self.messageContainerView.addSubview(contentImageView)
        self.messageContainerView.addSubview(transferIconImageView)
        self.messageContainerView.addSubview(coinNameLab)
        self.messageContainerView.addSubview(detailLab)
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        self.contentImageView.frame = CGRect.init(x: self.messageContainerView.bounds.origin.x, y: self.messageContainerView.bounds.origin.y, width: self.messageContainerView.bounds.size.width, height: self.messageContainerView.bounds.size.height + 20)
        self.transferIconImageView.snp.makeConstraints { make in
            make.left.equalTo(self.contentImageView).offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(50)
        }
        self.coinNameLab.snp.makeConstraints { make in
            make.left.equalTo(self.transferIconImageView.snp.right).offset(5)
            make.top.equalTo(self.transferIconImageView).offset(-5)
            make.height.equalTo(30)
        }
        
        self.detailLab.snp.makeConstraints { make in
            make.left.equalTo(self.transferIconImageView.snp.right).offset(5)
            make.top.equalTo(self.coinNameLab.snp.bottom).offset(5)
            make.height.equalTo(22)
        }
        
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

    }
    
    override func configure(with message: Message, at indexPath: IndexPath, and messageCollectionView: MessageCollectionView) {
        super.configure(with: message, at: indexPath, and: messageCollectionView)
        
        guard let displayDelegate = messageCollectionView.messagesDisplayDelegate else {
            fatalError("nilMessageDisplayDelegate")
        }
        
        switch message.kind{
        case .transfer(let transferItem):
            let coinName = transferItem.coinName
            if message.isOutgoing {
                // 发送
                self.coinNameLab.textAlignment = .left
                self.detailLab.textAlignment = .left
                self.coinNameLab.text = coinName! + "转账"
                self.detailLab.text = "发起一笔转账，点击查看"
//                self.transferIconImageView.snp.remakeConstraints { make in
//                    make.right.equalTo(self.contentImageView).offset(-10)
//                    make.centerY.equalToSuperview()
//                    make.width.height.equalTo(50)
//                }
//                self.coinNameLab.snp.remakeConstraints { make in
//                    make.right.equalTo(self.transferIconImageView.snp.left).offset(-5)
//                    make.top.equalTo(self.transferIconImageView).offset(-5)
//                    make.height.equalTo(30)
//                }
//                
//                self.detailLab.snp.remakeConstraints { make in
//                    make.right.equalTo(self.coinNameLab)
//                    make.top.equalTo(self.coinNameLab.snp.bottom).offset(5)
//                    make.height.equalTo(22)
//                }
            }else {
                // 接收
                self.coinNameLab.textAlignment = .right
                self.detailLab.textAlignment = .right
                self.coinNameLab.text = coinName! + "收款"
                self.detailLab.text = "你有一笔收款，点击查看"
//                self.transferIconImageView.snp.remakeConstraints { make in
//                    make.left.equalTo(self.contentImageView).offset(10)
//                    make.centerY.equalToSuperview()
//                    make.width.height.equalTo(50)
//                }
//                self.coinNameLab.snp.remakeConstraints { make in
//                    make.left.equalTo(self.transferIconImageView.snp.right).offset(5)
//                    make.top.equalTo(self.transferIconImageView).offset(-5)
//                    make.height.equalTo(30)
//                }
//                
//                self.detailLab.snp.remakeConstraints { make in
//                    make.left.equalTo(self.transferIconImageView.snp.right).offset(5)
//                    make.top.equalTo(self.coinNameLab.snp.bottom).offset(5)
//                    make.height.equalTo(22)
//                }
                
            }
        default:
            break
        }
        
        
    }
    
    
    
}
