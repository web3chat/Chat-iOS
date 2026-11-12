//
//  FZMUnreadCountButton.swift
//  IMSDK
//
//  Created by fzm on 2019/1/23.
//

import UIKit

class FZMUnreadCountButton: UIButton {

    /// 尺寸账本：左内边距 / 图标边长 / 图文间距 / 右内边距 / 字号
    private enum Metric {
        static let leading: CGFloat = 15
        static let iconSide: CGFloat = 10
        static let gap: CGFloat = 5
        static let trailing: CGFloat = 15
        static let fontSize: CGFloat = 14
    }

    /// 顶部那条「从屏幕右侧滑出」的胶囊只圆左边两个角；
    /// 宽度会随文案变化，所以 mask 要能重算（见 `applyLeftRoundedMaskIfNeeded`）
    var roundsLeftCornersOnly = false {
        didSet { setNeedsLayout() }
    }

    private let arrowIcon = UIImageView()
    private var maskedSize: CGSize = .zero

    init(with image:UIImage?,frame:CGRect) {
        super.init(frame: frame)
        self.setBackgroundColor(color: Color_Auxiliary, state: .normal)
        self.setBackgroundColor(color: Color_Auxiliary, state: .highlighted)

        arrowIcon.image = image
        arrowIcon.contentMode = UIView.ContentMode.scaleAspectFit
        self.addSubview(arrowIcon)

        self.setTitleColor(Color_Theme, for: .normal)
        self.titleLabel?.font = UIFont.systemFont(ofSize: Metric.fontSize)
        self.titleLabel?.numberOfLines = 1
        self.titleLabel?.lineBreakMode = .byClipping
        // 标题位置由 layoutSubviews 自己算；这里必须归零，
        // 否则「标题居中 + 左偏 15」的旧做法会让长文案（英文 / 日文 / 韩文）压到图标上
        self.titleEdgeInsets = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 当前文案 + 图标所需的最小宽度（中文短文案 == minWidth，观感不变；
    /// 英文 / 日文 / 韩文更长时自动加宽，避免文字压到图标或右边缘）
    func fittedWidth(minWidth: CGFloat) -> CGFloat {
        let font = titleLabel?.font ?? UIFont.systemFont(ofSize: Metric.fontSize)
        let text = title(for: .normal) ?? ""
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let contentWidth = Metric.leading + Metric.iconSide + Metric.gap + textWidth + Metric.trailing
        return max(minWidth, ceil(contentWidth))
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        arrowIcon.frame = CGRect(
            x: Metric.leading,
            y: (bounds.height - Metric.iconSide) / 2,
            width: Metric.iconSide,
            height: Metric.iconSide)

        if let label = titleLabel {
            label.sizeToFit()
            // 标题左边缘**锚在图标右侧**（在「图标右侧 ~ 右内边距」之间居中）：
            // 无论文案多长都不会盖住图标；宽度实在不够时截断，不会重叠
            let available = bounds.width - Metric.leading - Metric.iconSide - Metric.gap - Metric.trailing
            let textWidth = max(0, min(label.frame.width, available))
            label.frame = CGRect(
                x: Metric.leading + Metric.iconSide + Metric.gap + max(0, (available - textWidth) / 2),
                y: (bounds.height - label.frame.height) / 2,
                width: textWidth,
                height: label.frame.height)
        }

        applyLeftRoundedMaskIfNeeded()
    }

    /// 只圆左上 / 左下两个角（顶部胶囊），尺寸变化时重算
    private func applyLeftRoundedMaskIfNeeded() {
        guard roundsLeftCornersOnly, bounds.width > 0, bounds.height > 0,
              maskedSize != bounds.size else { return }
        maskedSize = bounds.size
        let radius = bounds.height * 0.5
        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [UIRectCorner.topLeft, UIRectCorner.bottomLeft],
            cornerRadii: CGSize(width: radius, height: radius))
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        self.layer.mask = maskLayer
    }

}
