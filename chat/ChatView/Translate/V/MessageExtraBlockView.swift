//
//  MessageExtraBlockView.swift
//  chat
//
//  气泡下方的「译文 / 转写」卡片。
//  只负责画：frame 由 `MessageContentCell.layoutExtraBlockView` 按布局属性的高度给出，
//  点一下整张卡片 = 复制正文。
//  译文卡片最底部会带一行「小图标 + 由系统翻译支持」，标注译文来源。
//

import UIKit

final class MessageExtraBlockView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = MessageExtraBlockMetrics.headerFont
        label.textColor = Color_8A97A5
        label.textAlignment = .left
        label.numberOfLines = 1
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = MessageExtraBlockMetrics.bodyFont
        label.textColor = Color_24374E
        label.textAlignment = .left
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    /// 底部说明的小图标（译文卡片 = 「由系统翻译支持」前面那个）
    private let footerIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = Color_8A97A5
        imageView.image = UIImage(systemName: "character.bubble")?
            .withRenderingMode(.alwaysTemplate)
        return imageView
    }()

    private let footerLabel: UILabel = {
        let label = UILabel()
        label.font = MessageExtraBlockMetrics.footerFont
        label.textColor = Color_8A97A5
        label.textAlignment = .left
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// 当前卡片正文（复制用）
    private var text: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = Color_F6F7F8
        self.layer.cornerRadius = MessageExtraBlockMetrics.cornerRadius
        self.clipsToBounds = true

        self.addSubview(self.titleLabel)
        self.addSubview(self.bodyLabel)
        self.addSubview(self.footerIconView)
        self.addSubview(self.footerLabel)
        self.footerIconView.isHidden = true
        self.footerLabel.isHidden = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.addGestureRecognizer(tap)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with block: MessageExtraBlock) {
        self.text = block.text
        self.titleLabel.text = block.kind.title
        self.bodyLabel.text = block.text

        let footer = block.footer
        self.footerIconView.isHidden = footer == nil
        self.footerLabel.isHidden = footer == nil
        self.footerLabel.text = footer

        self.accessibilityLabel = block.kind.title + "：" + block.text

        // frame 可能和上一张卡片一样大（cell 复用），这时系统不会再调 layoutSubviews；
        // 主动标脏，保证带不带 footer 的两种布局都重摆一次
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let padding = MessageExtraBlockMetrics.horizontalPadding
        let vertical = MessageExtraBlockMetrics.verticalPadding
        let contentWidth = max(self.bounds.width - padding * 2, 0)

        self.titleLabel.frame = CGRect(
            x: padding,
            y: vertical,
            width: contentWidth,
            height: MessageExtraBlockMetrics.headerHeight
        )

        let bodyY = vertical + MessageExtraBlockMetrics.headerHeight + MessageExtraBlockMetrics.headerBodyGap

        if self.footerLabel.isHidden {
            self.bodyLabel.frame = CGRect(
                x: padding,
                y: bodyY,
                width: contentWidth,
                height: max(self.bounds.height - bodyY - vertical, 0)
            )
        } else {
            let footerY = self.bounds.height - vertical - MessageExtraBlockMetrics.footerHeight
            let bodyHeight = max(footerY - MessageExtraBlockMetrics.footerGap - bodyY, 0)
            self.bodyLabel.frame = CGRect(x: padding, y: bodyY, width: contentWidth, height: bodyHeight)

            let iconSize = MessageExtraBlockMetrics.footerIconSize
            self.footerIconView.frame = CGRect(
                x: padding,
                y: footerY + (MessageExtraBlockMetrics.footerHeight - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            let labelX = padding + iconSize + MessageExtraBlockMetrics.footerIconSpacing
            self.footerLabel.frame = CGRect(
                x: labelX,
                y: footerY,
                width: max(self.bounds.width - labelX - padding, 0),
                height: MessageExtraBlockMetrics.footerHeight
            )
        }
    }

    @objc private func handleTap() {
        guard !self.text.isEmpty else { return }
        UIPasteboard.general.string = self.text
        APP.shared().showToast(L("已复制"))
    }
}
