//
//  MessageTranslationService.swift
//  chat
//
//  消息翻译的唯一入口：判断系统是否支持，并把系统翻译面板挂到当前页面。
//  ⚠️ 只走系统「翻译」框架（离线），不发服务端、不进消息体，不动 E2E 边界。
//

import UIKit

enum MessageTranslationService {

    /// 系统翻译面板从 iOS 17.4 起才有；低版本不显示「翻译」入口
    static var isAvailable: Bool {
        if #available(iOS 17.4, *) {
            return true
        }
        return false
    }

    /// 调起系统翻译面板
    /// - Parameters:
    ///   - viewController: 当前聊天页（用来 present 透明宿主）
    ///   - text: 要翻译的原文
    ///   - onReplace: 用户在系统面板里点「替换」后回调译文
    /// - Returns: `false` = 当前系统不支持（调用方给提示）
    @discardableResult
    static func present(
        from viewController: UIViewController,
        text: String,
        onReplace: @escaping (String) -> Void
    ) -> Bool {
        guard #available(iOS 17.4, *) else {
            return false
        }
        let host = TranslationHostVC(text: text, onReplace: onReplace)
        viewController.present(host, animated: true, completion: nil)
        return true
    }
}
