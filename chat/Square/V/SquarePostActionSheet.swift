//
//  SquarePostActionSheet.swift
//  chat
//
//  我的帖子操作面板（列表右下角三个点 / 详情页共用）：
//  个人帖 = 删除；公众号帖额外提供「关闭/开启评论」（接口目前仅这两个能力）。
//

import Foundation
import UIKit

enum SquarePostActionSheet {

    /// 展示操作面板
    /// - Parameter sourceView: iPad / 大屏上的气泡锚点，传触发按钮
    /// - Parameter onEdited: 二次编辑提交后回调（帖会重新走审核，调用方最好整体刷新）
    static func present(from viewController: UIViewController,
                        post: SquarePost,
                        sourceView: UIView? = nil,
                        onUpdated: ((SquarePost) -> Void)? = nil,
                        onDeleted: ((Int) -> Void)? = nil,
                        onEdited: (() -> Void)? = nil) {
        guard post.id > 0 else { return }

        let sheet = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
        // 二次编辑（《App增量-置顶与二次编辑》§3）：过期后服务端会回 -20415，入口也随之隐藏
        if post.canEdit() {
            sheet.addAction(UIAlertAction.init(title: L("编辑"), style: .default, handler: { _ in
                openEditor(post: post, from: viewController, onEdited: onEdited)
            }))
        }
        if post.isOfficialPost {
            sheet.addAction(UIAlertAction.init(title: post.commentsEnabled ? L("关闭评论") : L("开启评论"),
                                               style: .default,
                                               handler: { _ in
                setCommentsEnabled(!post.commentsEnabled, post: post, from: viewController, onUpdated: onUpdated)
            }))
        }
        sheet.addAction(UIAlertAction.init(title: L("删除帖子"), style: .destructive, handler: { _ in
            confirmDelete(postId: post.id, from: viewController, onDeleted: onDeleted)
        }))
        sheet.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView ?? viewController.view
            if let sourceView = sourceView {
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceRect = CGRect.init(x: k_ScreenWidth - 30, y: k_StatusNavigationBarHeight, width: 1, height: 1)
            }
        }
        viewController.present(sheet, animated: true)
    }

    /// 进行二次编辑（预填正文与已发布图片，提交走 `PUT /square/app/posts/:id`）
    private static func openEditor(post: SquarePost,
                                   from viewController: UIViewController,
                                   onEdited: (() -> Void)?) {
        let vc = SquareCreatePostVC.edit(with: post)
        vc.hidesBottomBarWhenPushed = true
        vc.onPosted = onEdited
        viewController.navigationController?.pushViewController(vc, animated: true)
    }

    /// 删除前二次确认
    private static func confirmDelete(postId: Int, from viewController: UIViewController, onDeleted: ((Int) -> Void)?) {
        let alert = UIAlertController.init(title: L("删除帖子"),
                                           message: L("删除后不可恢复，确定删除？"),
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L("取消"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction.init(title: L("确定"), style: .destructive, handler: { _ in
            SquareService.shared.deletePost(id: postId, success: { deletedId in
                viewController.showToast(with: L("删除成功"))
                onDeleted?(deletedId)
            }, failure: { failure in
                viewController.showToast(with: failure.message)
            })
        }))
        viewController.present(alert, animated: true)
    }

    private static func setCommentsEnabled(_ enabled: Bool,
                                           post: SquarePost,
                                           from viewController: UIViewController,
                                           onUpdated: ((SquarePost) -> Void)?) {
        SquareService.shared.setCommentsEnabled(postId: post.id, enabled: enabled, success: { result in
            viewController.showToast(with: result.enabled ? L("已开启评论") : L("已关闭评论"))
            // 服务端只回 enabled，这里补一份最新帖子对象给列表刷新
            var updated = post
            updated.commentsEnabled = result.enabled
            onUpdated?(updated)
        }, failure: { failure in
            viewController.showToast(with: failure.message)
        })
    }
}


