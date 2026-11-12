//
//  Untitled.swift
//  chat
//
//  Created by 郑晨 on 2026/3/18.
//

import Foundation

@objc enum AppLanguage: Int {
    case english, chinese, japanese, korean
    // 2026-10-19 新增（枚举顺序与语言列表无关，持久化只认 code）
    case french, russian, malay, indonesian, german, spanish
    case thai, lao, burmese, portuguese, ukrainian, vietnamese, traditionalChinese
    case italian, dutch, turkish, polish
    
    var code: String {
        switch self {
        case .english:            return "en"
        case .chinese:            return "zh-Hans"
        case .japanese:           return "ja"
        case .korean:             return "ko"
        case .french:             return "fr"
        case .russian:            return "ru"
        case .malay:              return "ms"
        case .indonesian:         return "id"
        case .german:             return "de"
        case .spanish:            return "es"
        case .thai:               return "th"
        case .lao:                return "lo"
        case .burmese:            return "my"
        case .portuguese:         return "pt-PT"
        case .ukrainian:          return "uk"
        case .vietnamese:         return "vi"
        case .traditionalChinese: return "zh-HK"
        case .italian:            return "it"
        case .dutch:              return "nl"
        case .turkish:            return "tr"
        case .polish:             return "pl"
        }
    }
}

@objc class LanguageManager: NSObject {
    @objc static let shared = LanguageManager()
    
    private let userDefaultsKey = "AppSelectedLanguage"
    private var bundle: Bundle = .main
    /// 英文语言包：新语言缺 key 时兜底，避免界面显示中文原文
    private var englishBundle: Bundle?
    
    @objc static let LanguageChangedNotification = NSNotification.Name("AppLanguageChangedNotification")

    private override init() {
        super.init()
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj") {
            englishBundle = Bundle(path: path)
        }
        var savedLang = UserDefaults.standard.string(forKey: userDefaultsKey) ?? "zh-Hans"
        updateBundle(langCode: savedLang)
    }

    @objc func setLanguage(_ language: AppLanguage) {
        let code = language.code
        UserDefaults.standard.set(code, forKey: userDefaultsKey)
        updateBundle(langCode: code)
        // 语言切换监听里会更新 TabBar / 列表标题等 UI，必须在主线程投递，否则易触发 Swift/UI 运行时陷阱。
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: LanguageManager.LanguageChangedNotification, object: nil)
        }
    }

    // MARK: - 语言列表（设置页 / 语言选择页共用）

    /// 显示语言列表：简体中文置顶，其余按中文名拼音首字母排序。
    /// 每项 name 是**常量**（本地名 + 中文意义），不随界面语言变化；括号里始终显示中文。
    @objc static let languageOptions: [[String: String]] = [
        ["code": "zh-Hans", "name": "简体中文"],
        ["code": "pl",      "name": "Polski(波兰语)"],
        ["code": "de",      "name": "Deutsch(德语)"],
        ["code": "ru",      "name": "Русский(俄语)"],
        ["code": "zh-HK",   "name": "繁體中文(繁体中文)"],
        ["code": "fr",      "name": "Français(法语)"],
        ["code": "ko",      "name": "한국어(韩语)"],
        ["code": "nl",      "name": "Nederlands(荷兰语)"],
        ["code": "lo",      "name": "ລາວ(老挝语)"],
        ["code": "ms",      "name": "Bahasa Melayu(马来语)"],
        ["code": "my",      "name": "မြန်မာ(缅甸语)"],
        ["code": "pt-PT",   "name": "Português(葡萄牙语)"],
        ["code": "ja",      "name": "日本語(日语)"],
        ["code": "th",      "name": "ไทย(泰语)"],
        ["code": "tr",      "name": "Türkçe(土耳其语)"],
        ["code": "uk",      "name": "Українська(乌克兰语)"],
        ["code": "es",      "name": "Español(西班牙语)"],
        ["code": "en",      "name": "English(英语)"],
        ["code": "id",      "name": "Bahasa Indonesia(印度尼西亚语)"],
        ["code": "it",      "name": "Italiano(意大利语)"],
        ["code": "vi",      "name": "Tiếng Việt(越南语)"]
    ]

    /// code → 枚举（未知 code 返回 nil）
    static func language(forCode code: String) -> AppLanguage? {
        switch code {
        case "en":      return .english
        case "zh-Hans": return .chinese
        case "ja":      return .japanese
        case "ko":      return .korean
        case "fr":      return .french
        case "ru":      return .russian
        case "ms":      return .malay
        case "id":      return .indonesian
        case "de":      return .german
        case "es":      return .spanish
        case "th":      return .thai
        case "lo":      return .lao
        case "my":      return .burmese
        case "pt-PT":   return .portuguese
        case "uk":      return .ukrainian
        case "vi":      return .vietnamese
        case "zh-HK":   return .traditionalChinese
        case "it":      return .italian
        case "nl":      return .dutch
        case "tr":      return .turkish
        case "pl":      return .polish
        default:        return nil
        }
    }

    @objc func displayName(forCode code: String) -> String {
        for item in LanguageManager.languageOptions where item["code"] == code {
            return item["name"] ?? code
        }
        return code
    }

    @objc var currentLanguageDisplayName: String {
        return displayName(forCode: currentLanguageCode)
    }

    /// 按 code 切换（ObjC 语言页调用；未知 code 忽略）
    @objc func setLanguage(withCode code: String) {
        guard let language = LanguageManager.language(forCode: code) else { return }
        setLanguage(language)
    }

    // MARK: - 当前语言判断（Swift）
    var currentLanguageCode: String {
        UserDefaults.standard.string(forKey: userDefaultsKey) ?? "zh-Hans"
    }

    var currentLanguage: AppLanguage {
        return LanguageManager.language(forCode: currentLanguageCode) ?? .chinese
    }

    var isEnglish: Bool { currentLanguage == .english }
    /// 中文：简体 + 繁体（zh-HK 的日期格式 / 字号 / 紧凑布局都和简体一致）
    var isChinese: Bool { currentLanguage == .chinese || currentLanguage == .traditionalChinese }
    var isSimplifiedChinese: Bool { currentLanguage == .chinese }
    var isJapanese: Bool { currentLanguage == .japanese }
    var isKorean: Bool { currentLanguage == .korean }

    /// 数字进位单位是否按「万」(÷10000)：中/繁/日/韩；其它语言用 K(÷1000)
    var usesMyriadUnit: Bool {
        switch currentLanguage {
        case .chinese, .traditionalChinese, .japanese, .korean: return true
        default: return false
        }
    }

    private func updateBundle(langCode: String) {
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            self.bundle = langBundle
        } else {
            self.bundle = .main
        }
    }

    /// key 缺失时 bundle 会把 key 原样返回；用哨兵区分「真缺失」，再依次兜底：当前语言 → 英文 → 中文 key
    private static let missingValueMarker = "__FZM_L10N_MISSING__"

    @objc func localizedString(forKey key: String) -> String {
        let marker = LanguageManager.missingValueMarker
        let value = bundle.localizedString(forKey: key, value: marker, table: nil)
        if value != marker { return value }
        if let englishBundle = englishBundle {
            let englishValue = englishBundle.localizedString(forKey: key, value: marker, table: nil)
            if englishValue != marker { return englishValue }
        }
        return key
    }
}

// Swift 全局简便函数
func L(_ key: String) -> String {
    return LanguageManager.shared.localizedString(forKey: key)
}


