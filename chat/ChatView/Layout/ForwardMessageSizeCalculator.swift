//
//  ForwardMessageSizeCalculator.swift
//  chat
//
//  合并转发卡片的尺寸：宽高都按 `ForwardCardMetrics` 常量算，
//  与 `ForwardMessageCell` 的布局共用同一份常量（改一处即可）。
//

import UIKit

class ForwardMessageSizeCalculator: TextMessageSizeCalculator {

    override func messageContainerMaxWidth(for message: Message, at indexPath: IndexPath) -> CGFloat {
        return ForwardCardMetrics.width
    }

    override func messageContainerSize(for message: Message, at indexPath: IndexPath) -> CGSize {
        let total: Int = message.msgType.forwardItems?.count ?? 0
        let count: CGFloat = CGFloat(min(total, ForwardCardMetrics.maxPreviewCount))

        // ⚠️ 逐项拆开并显式标类型：写成一个大表达式时编译器会报
        //   「unable to type-check this expression in reasonable time」
        let verticalPadding: CGFloat = ForwardCardMetrics.paddingV * 2
        let titleHeight: CGFloat = ForwardCardMetrics.titleHeight
        let titleGap: CGFloat = ForwardCardMetrics.titleGap
        let linesHeight: CGFloat = count * ForwardCardMetrics.lineHeight
        let footerGap: CGFloat = ForwardCardMetrics.footerGap
        let footerHeight: CGFloat = ForwardCardMetrics.footerHeight

        let height: CGFloat = verticalPadding + titleHeight + titleGap + linesHeight + footerGap + footerHeight
        return CGSize.init(width: ForwardCardMetrics.width, height: height)
    }
}
