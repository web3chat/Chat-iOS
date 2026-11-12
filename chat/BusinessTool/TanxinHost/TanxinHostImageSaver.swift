//
//  TanxinHostImageSaver.swift
//  chat
//
//  H5 宿主桥的「保存图片」落地（对接文档 §5）。
//
//  两条通道：
//  · 单发 `saveImage(base64, filename)`：只在**原图 ≤512KB** 时页面才会调用（文档 §5.1）。
//  · 分片 `saveImageBegin(filename, totalBytes)` → `saveImageChunk(seq, base64Chunk)` × N →
//    `saveImageEnd()`：每片是 **256KB 原图**，`seq` 从 `"0"` 开始、两者都是字符串（文档 §5.2）。
//    ⚠️ 分片必须**严格按序**累加：序号跳号/乱序说明传输出错，本次直接放弃（不要拼出一张坏图）。
//
//  保存用 `PHAssetCreationRequest + addResource(data:)`：与相册里已有的 GIF 保存路径同款写法，
//  **保留原始 PNG 字节**（`UIImageWriteToSavedPhotosAlbum` 会重新编码，透明/像素可能变化）。
//

import UIKit
import Photos

final class TanxinHostImageSaver {

    private var isActive = false
    private var filename = ""
    private var expectedBytes = 0
    private var nextSeq = 0
    private var buffer = Data()
    private var isFailed = false

    // MARK: - 单发

    func saveSingle(base64: String, filename: String, completion: @escaping (Bool) -> Void) {
        guard let data = Self.decode(base64), !data.isEmpty else {
            FZMLog("H5 保存图片：base64 解码失败（\(filename)）")
            completion(false)
            return
        }
        FZMLog("H5 保存图片：单发收到 \(data.count)B（\(filename)）")
        Self.writeToAlbum(data: data, filename: filename, completion: completion)
    }

    // MARK: - 分片

    func begin(filename: String, totalBytes: String) {
        isActive = true
        isFailed = false
        nextSeq = 0
        buffer = Data()
        self.filename = filename
        expectedBytes = Int(totalBytes.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        FZMLog("H5 保存图片：开始分片接收（\(filename)，声明总字节=\(expectedBytes)）")
    }

    func append(seq: String, base64: String) {
        guard isActive, !isFailed else { return }
        guard let index = Int(seq), index == nextSeq else {
            isFailed = true
            FZMLog("H5 保存图片：分片序号异常（期望 \(nextSeq)，收到 \(seq)），放弃本次保存")
            return
        }
        guard let data = Self.decode(base64), !data.isEmpty else {
            isFailed = true
            FZMLog("H5 保存图片：第 \(index) 片解码失败，放弃本次保存")
            return
        }
        buffer.append(data)
        nextSeq += 1
    }

    func finish(completion: @escaping (Bool) -> Void) {
        guard isActive else {
            completion(false)
            return
        }
        isActive = false

        let received = buffer.count
        let isComplete = !isFailed && received > 0 && (expectedBytes <= 0 || received == expectedBytes)
        guard isComplete else {
            FZMLog("H5 保存图片：分片不完整（收到 \(received)/\(expectedBytes) 字节，失败=\(isFailed)）")
            reset()
            completion(false)
            return
        }

        let data = buffer
        let name = filename
        reset()
        FZMLog("H5 保存图片：分片接收完成 \(data.count)B（\(name)），开始写入相册")
        Self.writeToAlbum(data: data, filename: name, completion: completion)
    }

    func cancel() {
        if isActive {
            FZMLog("H5 保存图片：分片会话被中止（已收 \(buffer.count)B）")
        }
        reset()
    }

    // MARK: - 内部

    private func reset() {
        isActive = false
        isFailed = false
        nextSeq = 0
        expectedBytes = 0
        filename = ""
        buffer = Data()
    }

    /// 兼容 `data:image/png;base64,xxxx` 前缀（标准 base64 里没有逗号）。
    private static func decode(_ base64: String) -> Data? {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let payload: String
        if let comma = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: comma)...])
        } else {
            payload = trimmed
        }
        return Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
    }

    private static func writeToAlbum(data: Data, filename: String, completion: @escaping (Bool) -> Void) {
        guard UIImage(data: data) != nil else {
            FZMLog("H5 保存图片：图片解析失败（\(filename)），\(data.count)B")
            completion(false)
            return
        }
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    FZMLog("H5 保存图片：已存入相册（\(filename)）")
                } else {
                    FZMLog("H5 保存图片：写入相册失败 \(error?.localizedDescription ?? "")")
                }
                completion(success)
            }
        })
    }
}
