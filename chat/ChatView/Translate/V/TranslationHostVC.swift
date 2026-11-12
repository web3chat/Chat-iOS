//
//  TranslationHostVC.swift
//  chat
//
//  系统翻译面板的透明宿主。
//  为什么要有这一层：`translationPresentation` 是 SwiftUI 的修饰器，UIKit 里必须先有
//  一个 SwiftUI 视图；这里用透明、全屏的 `UIHostingController` 承载它。
//  兜底：系统面板万一没弹出来，宿主是全屏透明的，点一下空白处即可撤掉，不会把聊天页卡死。
//
//  ⚠️ `Translation` 框架 iOS 17.4 起才有，所以整个类（含 SwiftUI 视图）都标了
//     `@available(iOS 17.4, *)`；低版本由 `MessageTranslationService.present` 直接返回 false。
//  ⚠️ 本工程最低 15.6，`Translation.framework` 与 SwiftUI 的 cross-import 覆盖模块
//     `_Translation_SwiftUI.framework` 都必须在 Xcode 里**弱链接**（Link Binary With Libraries → Optional），
//     否则 iOS 17.4 以下会在启动时 dyld 找不到库直接崩（Swift 不会因为 #available 自动弱链接）。
//

import SwiftUI
import Translation
import UIKit

@available(iOS 17.4, *)
final class TranslationHostVC: UIViewController {

    private let sourceText: String
    private let onReplace: (String) -> Void

    private var hosting: UIHostingController<TranslationHostView>?
    /// 防止「替换」与「关闭」两条路同时 dismiss
    private var isFinishing = false

    init(text: String, onReplace: @escaping (String) -> Void) {
        self.sourceText = text
        self.onReplace = onReplace
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear

        let root = TranslationHostView(
            text: self.sourceText,
            onReplace: { [weak self] translated in
                guard let self = self else { return }
                self.onReplace(translated)
                self.finish()
            },
            onDismiss: { [weak self] in
                self?.finish()
            }
        )

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        self.addChild(host)
        self.view.addSubview(host.view)
        host.view.frame = self.view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)
        self.hosting = host

        // 兜底出口：系统面板没弹出来时，点空白处关闭宿主
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTap() {
        self.finish()
    }

    private func finish() {
        guard !self.isFinishing else { return }
        self.isFinishing = true
        // 稍等一下：系统翻译面板自己也在收，先把面板收完再撤宿主，避免二次 dismiss 动画打架
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.dismiss(animated: false)
        }
    }
}

@available(iOS 17.4, *)
struct TranslationHostView: View {

    let text: String
    let onReplace: (String) -> Void
    let onDismiss: () -> Void

    @State private var isPresented = true

    var body: some View {
        Color.clear
            .translationPresentation(isPresented: self.$isPresented, text: self.text) { translated in
                self.onReplace(translated)
            }
            .onChange(of: self.isPresented) { _, presented in
                if !presented {
                    self.onDismiss()
                }
            }
    }
}
