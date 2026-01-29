import Foundation
import Combine
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    static let shared = SpeechRecognizer()

    @Published var transcript: String = ""           // iOS 原生实时识别结果
    @Published var finalTranscript: String = ""      // 后端 Paraformer 最终识别结果（带标点）
    @Published var isRecording: Bool = false
    @Published var isProcessing: Bool = false        // 是否正在后端处理
    @Published var errorMessage: String?
    @Published var recordedAudioData: Data?          // 录音的音频数据

    private var audioEngine: AVAudioEngine?
    private var audioBuffers: [AVAudioPCMBuffer] = []  // 收集音频buffer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private init() {}

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startRecording() {
        // 检查权限
        requestAuthorization { [weak self] authorized in
            guard let self = self else { return }

            if !authorized {
                self.errorMessage = "需要语音识别权限"
                return
            }

            self.beginRecording()
        }
    }

    private func beginRecording() {
        // 检查语音识别器是否可用
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "语音识别不可用"
            return
        }

        // 停止之前的录音
        stopRecording()

        // 停止正在播放的音频（避免 AVAudioSession 冲突）
        AudioQueuePlayer.shared.stop()

        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "无法配置音频会话"
            return
        }

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "无法创建识别请求"
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // 创建音频引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            errorMessage = "无法创建音频引擎"
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            // 收集音频buffer用于回放
            if let copiedBuffer = buffer.copy() as? AVAudioPCMBuffer {
                self?.audioBuffers.append(copiedBuffer)
            }
        }

        // 开始识别任务
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }

        // 启动音频引擎
        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async {
                self.transcript = ""
                self.isRecording = true
                self.errorMessage = nil
                self.recordedAudioData = nil
                self.audioBuffers.removeAll()
            }
        } catch {
            errorMessage = "无法启动录音"
            stopRecording()
        }
    }

    func stopRecording() {
        // 防止重复调用
        guard audioEngine != nil else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil

        // 把收集的音频buffer转换为WAV数据
        let audioData = convertBuffersToWAV()
        print("[SpeechRecognizer] Converted audio data: \(audioData?.count ?? 0) bytes")

        DispatchQueue.main.async {
            self.isRecording = false
            self.recordedAudioData = audioData
        }

        // 恢复音频会话
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func convertBuffersToWAV() -> Data? {
        guard !audioBuffers.isEmpty,
              let firstBuffer = audioBuffers.first,
              let format = firstBuffer.format as AVAudioFormat? else {
            return nil
        }

        // 计算总帧数
        let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
        guard totalFrames > 0 else { return nil }

        // 创建合并的buffer
        guard let mergedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else {
            return nil
        }

        var currentFrame: AVAudioFrameCount = 0
        for buffer in audioBuffers {
            let framesToCopy = buffer.frameLength
            if let srcData = buffer.floatChannelData,
               let dstData = mergedBuffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    memcpy(dstData[channel].advanced(by: Int(currentFrame)),
                           srcData[channel],
                           Int(framesToCopy) * MemoryLayout<Float>.size)
                }
            }
            currentFrame += framesToCopy
        }
        mergedBuffer.frameLength = currentFrame

        // 转换为WAV数据
        return pcmBufferToWAVData(buffer: mergedBuffer, format: format)
    }

    private func pcmBufferToWAVData(buffer: AVAudioPCMBuffer, format: AVAudioFormat) -> Data? {
        let sampleRate = UInt32(format.sampleRate)
        let channels = UInt16(format.channelCount)
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = bitsPerSample / 8
        let frameCount = Int(buffer.frameLength)

        // 转换float到int16
        var int16Data = [Int16](repeating: 0, count: frameCount * Int(channels))
        if let floatData = buffer.floatChannelData {
            for frame in 0..<frameCount {
                for channel in 0..<Int(channels) {
                    let floatSample = floatData[channel][frame]
                    let clampedSample = max(-1.0, min(1.0, floatSample))
                    int16Data[frame * Int(channels) + channel] = Int16(clampedSample * Float(Int16.max))
                }
            }
        }

        let dataSize = UInt32(int16Data.count * Int(bytesPerSample))

        // 创建WAV header
        var wavData = Data()

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: (36 + dataSize).littleEndian) { Array($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        wavData.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        let byteRate = sampleRate * UInt32(channels) * UInt32(bytesPerSample)
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        let blockAlign = channels * bytesPerSample
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        // audio data
        int16Data.withUnsafeBufferPointer { ptr in
            wavData.append(UnsafeBufferPointer(start: UnsafeRawPointer(ptr.baseAddress)?.assumingMemoryBound(to: UInt8.self),
                                                count: int16Data.count * Int(bytesPerSample)))
        }

        audioBuffers.removeAll()
        return wavData
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Backend ASR (Paraformer)

    /// 使用后端 Paraformer 进行最终识别（带标点分句）
    /// 返回识别结果，同时更新 finalTranscript
    func getFinalTranscript() async -> String? {
        guard let audioData = recordedAudioData, !audioData.isEmpty else {
            print("[SpeechRecognizer] No recorded audio data for final transcription")
            return nil
        }

        await MainActor.run {
            isProcessing = true
        }

        do {
            let result = try await APIService.shared.speechToText(audioData: audioData, language: "en")
            await MainActor.run {
                finalTranscript = result
                isProcessing = false
            }
            print("[SpeechRecognizer] Final transcript: \(result)")
            return result
        } catch {
            print("[SpeechRecognizer] Backend ASR failed: \(error)")
            await MainActor.run {
                isProcessing = false
                // 失败时使用 iOS 原生识别结果
                finalTranscript = transcript
            }
            return transcript.isEmpty ? nil : transcript
        }
    }

    /// 停止录音并获取最终识别结果（带标点）
    /// 这是混合方案的主入口
    func stopAndGetFinalTranscript() async -> (text: String, audioData: Data?)? {
        // 先保存当前的实时识别结果
        let realtimeText = transcript

        // 停止录音
        stopRecording()

        // 等待音频数据准备好
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒

        guard let audioData = recordedAudioData, !audioData.isEmpty else {
            // 没有录音数据，返回实时识别结果
            return realtimeText.isEmpty ? nil : (realtimeText, nil)
        }

        // 调用后端 ASR 获取带标点的结果
        if let finalText = await getFinalTranscript(), !finalText.isEmpty {
            return (finalText, audioData)
        }

        // 后端失败，使用实时识别结果
        return realtimeText.isEmpty ? nil : (realtimeText, audioData)
    }
}
