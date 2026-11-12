//
//  MessageExtraBlock.swift
//  chat
//
//  气泡下方的「译文 / 转写」卡片的**数据与尺寸**。
//
//  ⚠️ 尺寸只有这一份：`MessageSizeCalculator`（算行高）和 `MessageExtraBlockView`（摆视图）
//     必须调同一个 `height(for:width:)`，否则要么卡片压住气泡、要么下面多留一块空白
//     —— 引用条（`QuoteBlockMetrics`）那边踩过同样的坑。
//  ⚠️ 正文高度留了 2pt 余量：多行 UILabel 的最后一行容易因为取整被裁掉半个字。
//

import UIKit

/// 卡片种类
enum MessageExtraBlockKind: Equatable {
    case translation// 文本消息译文
    case transcript// 语音消息转写

    /// 卡片左上角的小标题
    var title: String {
        switch self {
        case .translation: return L("译文")
        case .transcript: return L("转写")
        }
    }
}

/// 一条消息要在气泡下方显示的附加卡片
struct MessageExtraBlock: Equatable {
    let kind: MessageExtraBlockKind
    let text: String

    /// 卡片最底部的说明文字（前面会带一个小图标）；nil = 不显示
    /// 译文标注来源，避免用户误以为原文/译文是我们自己翻译的
    var footer: String? {
        switch self.kind {
        case .translation:
            return L("由系统翻译支持")
        case .transcript:
            return nil
        }
    }
}

/// 卡片尺寸常量（视图布局与行高计算共用这一份）
enum MessageExtraBlockMetrics {

    /// 与气泡 / 引用条之间的间距
    static let gap: CGFloat = 4

    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 8

    /// 小标题行高
    static let headerHeight: CGFloat = 14
    /// 小标题与正文的间距
    static let headerBodyGap: CGFloat = 4

    /// 底部说明行（「由系统翻译支持」）
    static let footerGap: CGFloat = 6
    static let footerHeight: CGFloat = 16
    static let footerIconSize: CGFloat = 12
    static let footerIconSpacing: CGFloat = 4

    static let cornerRadius: CGFloat = 6

    static let headerFont = UIFont.systemFont(ofSize: 11)
    static let bodyFont = UIFont.systemFont(ofSize: 14)
    static let footerFont = UIFont.systemFont(ofSize: 11)

    /// 卡片总高度
    static func height(for block: MessageExtraBlock, width: CGFloat) -> CGFloat {
        let bodyHeight = self.bodyHeight(for: block, width: width)
        let footer: CGFloat = block.footer == nil ? 0 : (footerGap + footerHeight)
        return ceil(bodyHeight) + headerHeight + headerBodyGap + footer + verticalPadding * 2
    }

    /// 正文（多行）高度
    static func bodyHeight(for block: MessageExtraBlock, width: CGFloat) -> CGFloat {
        let textWidth = max(width - horizontalPadding * 2, 1)
        let rect = (block.text as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: bodyFont],
            context: nil
        )
        // 至少一行；+2 是留给取整/行高差导致的最后一行裁切
        return max(ceil(rect.height) + 2, ceil(bodyFont.lineHeight) + 2)
    }
}
