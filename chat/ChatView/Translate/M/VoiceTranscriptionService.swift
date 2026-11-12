//
//  VoiceTranscriptionService.swift
//  chat
//
//  语音消息转文字：只用 `SFSpeechRecognizer` 的**离线**识别。
//  ⚠️ 聊天的语音是端到端加密的，转写绝不把音频送去任何服务端：
//     识别器不支持离线（`supportsOnDeviceRecognition == false`）时直接给提示，不做联网兜底。
//  ⚠️ 依赖 Info.plist 的 `NSSpeechRecognitionUsageDescription`（缺了会在请求授权时崩）。
//

import Foundation
import Speech

final class VoiceTranscriptionService {

    static let shared = VoiceTranscriptionService()

    enum TranscriptionError: Error, LocalizedError {
        /// 本地没有 wav 文件（语音还没下载过）
        case fileMissing
        /// 用户没给语音识别权限
        case permissionDenied
        /// 当前语言 / 设备不支持离线识别
        case onDeviceUnsupported
        /// 识别失败
        case failed

        var errorDescription: String? {
            switch self {
            case .fileMissing:
                return L("语音还没下载，请先播放一次")
            case .permissionDenied:
                return L("没有语音识别权限，请在系统设置中开启后重试")
            case .onDeviceUnsupported:
                return L("当前语言暂不支持离线转写")
            case .failed:
                return L("语音转写失败，请稍后再试")
            }
        }
    }

    /// 每次识别的状态（超时、取消、只回调一次）
    private final class Attempt {
        var completed = false
        var task: SFSpeechRecognitionTask?
        var timeout: DispatchWorkItem?

        func cancel() {
            self.timeout?.cancel()
            self.timeout = nil
            self.task?.cancel()
            self.task = nil
        }
    }

    private init() {}

    /// 把本地语音文件转成文字
    /// - Parameters:
    ///   - audioURL: 本地 wav（`Documents/Voice/WavFile/{cacheKey}.wav`）
    ///   - languageCode: App 当前语言 code（`LanguageManager.currentLanguageCode`）
    ///   - completion: 主线程回调
    func transcribe(
        audioURL: URL,
        languageCode: String,
        completion: @escaping (Result<String, TranscriptionError>) -> Void
    ) {
        DispatchQueue.main.async {
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                completion(.failure(.fileMissing))
                return
            }

            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        completion(.failure(.permissionDenied))
                        return
                    }
                    let locales = VoiceTranscriptionService.localeCandidates(for: languageCode)
                    self.run(locales: locales, index: 0, audioURL: audioURL, completion: completion)
                }
            }
        }
    }

    // MARK: - 识别

    /// 按候选语言依次尝试（App 语言 → 系统语言 → 英文）。
    /// 前一种语言「没识别出内容」时才换下一种，避免把中文语音硬按英文识别出一个错误结果。
    private func run(
        locales: [Locale],
        index: Int,
        audioURL: URL,
        completion: @escaping (Result<String, TranscriptionError>) -> Void
    ) {
        guard index < locales.count else {
            completion(.failure(.onDeviceUnsupported))
            return
        }

        let locale = locales[index]
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            self.run(locales: locales, index: index + 1, audioURL: audioURL, completion: completion)
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        let attempt = Attempt()

        let finish: (Result<String, TranscriptionError>) -> Void = { result in
            guard !attempt.completed else { return }
            attempt.completed = true
            attempt.cancel()
            completion(result)
        }

        attempt.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self, !attempt.completed else { return }

                if let error = error {
                    FZMLog("语音转写失败 locale=\(locale.identifier) error=\(error)")
                    self.tryNext(
                        attempt: attempt,
                        locales: locales,
                        index: index,
                        audioURL: audioURL,
                        completion: completion
                    )
                    return
                }

                guard let result = result, result.isFinal else { return }

                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    self.tryNext(
                        attempt: attempt,
                        locales: locales,
                        index: index,
                        audioURL: audioURL,
                        completion: completion
                    )
                    return
                }
                finish(.success(text))
            }
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !attempt.completed else { return }
            FZMLog("语音转写超时 locale=\(locale.identifier)")
            self.tryNext(
                attempt: attempt,
                locales: locales,
                index: index,
                audioURL: audioURL,
                completion: completion
            )
        }
        attempt.timeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: item)
    }

    /// 当前语言没结果 → 试下一个；全部试完 → 失败
    private func tryNext(
        attempt: Attempt,
        locales: [Locale],
        index: Int,
        audioURL: URL,
        completion: @escaping (Result<String, TranscriptionError>) -> Void
    ) {
        guard !attempt.completed else { return }
        attempt.completed = true
        attempt.cancel()

        guard index + 1 < locales.count else {
            completion(.failure(.failed))
            return
        }
        self.run(locales: locales, index: index + 1, audioURL: audioURL, completion: completion)
    }

    // MARK: - 语言

    private static func localeCandidates(for code: String) -> [Locale] {
        var identifiers: [String] = [VoiceTranscriptionService.localeIdentifier(for: code)]
        let system = Locale.current.identifier
        if !identifiers.contains(system) { identifiers.append(system) }
        if !identifiers.contains("en-US") { identifiers.append("en-US") }
        return identifiers.map { Locale(identifier: $0) }
    }

    private static func localeIdentifier(for code: String) -> String {
        switch code {
        case "zh-Hans": return "zh-CN"
        case "zh-HK": return "zh-HK"
        case "en": return "en-US"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "fr": return "fr-FR"
        case "ru": return "ru-RU"
        case "ms": return "ms-MY"
        case "id": return "id-ID"
        case "de": return "de-DE"
        case "es": return "es-ES"
        case "th": return "th-TH"
        case "lo": return "lo-LA"
        case "my": return "my-MM"
        case "pt-PT": return "pt-PT"
        case "uk": return "uk-UA"
        case "vi": return "vi-VN"
        case "it": return "it-IT"
        case "nl": return "nl-NL"
        case "tr": return "tr-TR"
        case "pl": return "pl-PL"
        default: return code
        }
    }
}
