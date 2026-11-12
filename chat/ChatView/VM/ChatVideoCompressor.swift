//
//  ChatVideoCompressor.swift
//  chat
//
//  聊天视频压缩：H.264 + AAC，长边 ≤ 720p，**按目标码率编码**。
//

import AVFoundation
import Foundation

/// 聊天视频压缩。
///
/// 为什么不用 `AVAssetExportSession` 的预设：预设是按**画质**调的，压不住体积 ——
/// 实测同一段 1080p 源（30s / 44MB）：
/// - `AVAssetExportPreset1280x720` ⇒ 720x1280、7.5Mbps（127s 的视频约 160MB，服务端直接拒收）
/// - `AVAssetExportPresetMediumQuality` ⇒ 320x568、0.7Mbps（直接糊了）
///
/// 所以这里用 `AVAssetReader` + `AVAssetWriter` 自己编码：720p / ~1.5Mbps / 30fps，
/// 2 分钟的视频约 20MB（原来的 159MB → 现在的 1/8），转码也更快。
enum ChatVideoCompressor {

    struct Configuration {
        /// 长边上限（1280 = 720p）
        var maxLongSide: CGFloat = 1280
        /// 视频目标码率（bps）。1.2Mbps / 720p 是聊天场景的常用值
        /// （2 分钟视频约 18MB，再大服务端容易拒收、上传也慢）
        var videoBitrate: Int = 1_200_000
        /// 音频目标码率（bps）
        var audioBitrate: Int = 64_000
    }

    enum CompressError: LocalizedError {
        case noVideoTrack
        case reader(String)
        case writer(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "视频轨道不存在"
            case .reader(let msg): return "读取失败(\(msg))"
            case .writer(let msg): return "写入失败(\(msg))"
            }
        }
    }

    /// 同步转码（调用方自己放到后台线程）。
    /// - Returns: 成功返回 `nil`，失败返回错误（调用方可以兜底）
    static func compress(
        source: URL,
        destination: URL,
        configuration: Configuration = Configuration()
    ) -> Error? {
        let asset = AVURLAsset(
            url: source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return CompressError.noVideoTrack
        }

        // 1) 输出尺寸：先按 `preferredTransform` 算「实际显示尺寸」，再等比缩到长边 ≤ 720p。
        //    偶数是为了满足 H.264 的 4:2:0 采样要求。
        let transform = videoTrack.preferredTransform
        let naturalRect = CGRect(origin: .zero, size: videoTrack.naturalSize)
        let rotatedRect = naturalRect.applying(transform)
        let rotatedSize = CGSize(width: abs(rotatedRect.width), height: abs(rotatedRect.height))
        guard rotatedSize.width > 0, rotatedSize.height > 0 else {
            return CompressError.writer("视频尺寸无效")
        }
        let longSide = max(rotatedSize.width, rotatedSize.height)
        let scale = longSide > configuration.maxLongSide
            ? configuration.maxLongSide / longSide : 1
        func evenPixel(_ value: CGFloat) -> CGFloat { max(2, (value / 2).rounded() * 2) }
        let renderSize = CGSize(
            width: evenPixel(rotatedSize.width * scale),
            height: evenPixel(rotatedSize.height * scale))

        // 2) 帧率：保留源帧率（少于 30fps 的画面更糊），高于 30fps 统一降到 30（码率固定时更清晰）
        var frameDuration = CMTime(value: 1, timescale: 30)
        let sourceFrameDuration = videoTrack.minFrameDuration
        if sourceFrameDuration.isValid, sourceFrameDuration.seconds > 0,
            sourceFrameDuration.seconds >= 1.0 / 30.0 - 0.0001 {
            frameDuration = sourceFrameDuration
        }
        let frameRate = max(1, Int((1.0 / frameDuration.seconds).rounded()))

        // 3) Reader：用 video composition 把「旋转 + 缩放」烘进像素，
        //    输出文件不带旋转标记，任何客户端都能正着播。
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            return CompressError.reader(String(describing: error))
        }

        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        composition.frameDuration = frameDuration
        // 源可能是 HDR（iPhone 默认），这里统一按 SDR/709 渲染，避免导出色偏
        composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        composition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let normalize = CGAffineTransform(
            translationX: -rotatedRect.origin.x, y: -rotatedRect.origin.y)
        let scaleTransform = CGAffineTransform(
            scaleX: renderSize.width / rotatedSize.width,
            y: renderSize.height / rotatedSize.height)
        layerInstruction.setTransform(
            transform.concatenating(normalize).concatenating(scaleTransform), at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [videoTrack],
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ])
        videoOutput.videoComposition = composition
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else {
            return CompressError.reader("无法创建视频读取输出")
        }
        reader.add(videoOutput)

        // 4) 音频：解成 PCM 再编成 AAC 64k（体积可控，也不挑源编码）
        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                ])
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                reader.add(output)
                audioOutput = output
                let input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 2,
                        AVEncoderBitRateKey: configuration.audioBitrate,
                    ])
                input.expectsMediaDataInRealTime = false
                audioInput = input
            }
        }

        // 5) Writer
        try? FileManager.default.removeItem(at: destination)
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        } catch {
            return CompressError.writer(String(describing: error))
        }
        writer.shouldOptimizeForNetworkUse = true

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(renderSize.width),
                AVVideoHeightKey: Int(renderSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: configuration.videoBitrate,
                    AVVideoMaxKeyFrameIntervalKey: frameRate * 2,
                    AVVideoExpectedSourceFrameRateKey: frameRate,
                    AVVideoAllowFrameReorderingKey: true,
                ],
            ])
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else {
            return CompressError.writer("无法创建视频写入输入")
        }
        writer.add(videoInput)

        if let input = audioInput, !writer.canAdd(input) {
            audioInput = nil
        }
        if let input = audioInput {
            writer.add(input)
        }

        guard reader.startReading() else {
            return CompressError.reader(String(describing: reader.error))
        }
        guard writer.startWriting() else {
            reader.cancelReading()
            return CompressError.writer(String(describing: writer.error))
        }
        writer.startSession(atSourceTime: .zero)

        // 6) 双路泵数据（视频 / 音频各自一条串行队列）
        let group = DispatchGroup()
        let lock = NSLock()
        var appendFailed = false
        func markFailed() {
            lock.lock()
            appendFailed = true
            lock.unlock()
        }

        group.enter()
        videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "chat.video.compress.video")) {
            while videoInput.isReadyForMoreMediaData {
                guard let sample = videoOutput.copyNextSampleBuffer() else {
                    videoInput.markAsFinished()
                    group.leave()
                    return
                }
                if !videoInput.append(sample) {
                    markFailed()
                    videoInput.markAsFinished()
                    group.leave()
                    return
                }
            }
        }

        if let audioInput = audioInput, let audioOutput = audioOutput {
            group.enter()
            audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "chat.video.compress.audio")) {
                while audioInput.isReadyForMoreMediaData {
                    guard let sample = audioOutput.copyNextSampleBuffer() else {
                        audioInput.markAsFinished()
                        group.leave()
                        return
                    }
                    if !audioInput.append(sample) {
                        markFailed()
                        audioInput.markAsFinished()
                        group.leave()
                        return
                    }
                }
            }
        }

        group.wait()
        if reader.status == .failed {
            writer.cancelWriting()
            return CompressError.reader(String(describing: reader.error))
        }
        if appendFailed {
            writer.cancelWriting()
            return CompressError.writer("写入样本失败")
        }

        let finishSemaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { finishSemaphore.signal() }
        finishSemaphore.wait()

        guard writer.status == .completed else {
            return CompressError.writer(String(describing: writer.error))
        }
        return nil
    }
}
