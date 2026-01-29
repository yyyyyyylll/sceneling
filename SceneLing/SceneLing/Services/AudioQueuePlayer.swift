import Foundation
import AVFoundation
import Combine

class AudioQueuePlayer: ObservableObject {
    static let shared = AudioQueuePlayer()

    @Published var isPlaying = false

    private var player: AVQueuePlayer?
    private var playerItems: [AVPlayerItem] = []
    private var finishObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 使用 .playback 类别确保在静音模式下也能播放
            // 添加 .duckOthers 选项，在播放时降低其他音频的音量
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("[AudioQueuePlayer] Audio session configured successfully")
        } catch {
            print("[AudioQueuePlayer] Failed to setup audio session: \(error)")
        }
    }

    func enqueue(dataURL: String) {
        print("[AudioQueuePlayer] enqueue dataURL, length: \(dataURL.count)")

        guard let (audioData, fileExtension) = decodeDataURL(dataURL) else {
            print("[AudioQueuePlayer] Failed to decode data URL")
            print("[AudioQueuePlayer] URL prefix: \(String(dataURL.prefix(100)))")
            return
        }

        print("[AudioQueuePlayer] Decoded audio: \(audioData.count) bytes, format: \(fileExtension)")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try audioData.write(to: tempURL)
            print("[AudioQueuePlayer] Saved to: \(tempURL)")
            enqueue(url: tempURL)
        } catch {
            print("[AudioQueuePlayer] Failed to save temp audio: \(error)")
        }
    }

    /// 停止当前播放，立即播放新的音频
    func playNow(dataURL: String) {
        print("[AudioQueuePlayer] playNow dataURL, length: \(dataURL.count)")

        // 先停止当前播放
        stop()

        guard let (audioData, fileExtension) = decodeDataURL(dataURL) else {
            print("[AudioQueuePlayer] Failed to decode data URL")
            return
        }

        print("[AudioQueuePlayer] Decoded audio: \(audioData.count) bytes, format: \(fileExtension)")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try audioData.write(to: tempURL)
            print("[AudioQueuePlayer] Saved to: \(tempURL)")
            playNow(url: tempURL)
        } catch {
            print("[AudioQueuePlayer] Failed to save temp audio: \(error)")
        }
    }

    /// 停止当前播放，立即播放新的音频
    func playNow(url: URL) {
        print("[AudioQueuePlayer] playNow URL: \(url)")

        // 先停止当前播放
        stop()

        // 配置音频会话
        setupAudioSession()

        let item = AVPlayerItem(url: url)
        playerItems.append(item)

        player = AVQueuePlayer(items: [item])
        setupFinishObserver()

        player?.play()
        isPlaying = true
        print("[AudioQueuePlayer] Started playing (playNow)")
    }

    func enqueue(url: URL) {
        print("[AudioQueuePlayer] enqueue URL: \(url)")

        // 每次播放前确保音频会话是活跃的
        setupAudioSession()

        let item = AVPlayerItem(url: url)
        playerItems.append(item)

        // 检查 player 是否存在且正在播放（rate > 0）
        // 如果 player 存在但已停止，需要重新创建
        let shouldCreateNewPlayer = player == nil || (player?.rate == 0 && player?.items().isEmpty == true)

        if shouldCreateNewPlayer {
            print("[AudioQueuePlayer] Creating new player (player nil: \(player == nil), rate: \(player?.rate ?? -1))")

            // 清理旧的 player
            if player != nil {
                stop()
                // 重新添加 item（因为 stop 会清空 playerItems）
                playerItems.append(item)
            }

            // 确保移除旧的观察者后再添加新的
            if let observer = finishObserver {
                NotificationCenter.default.removeObserver(observer)
                finishObserver = nil
            }

            player = AVQueuePlayer(items: [item])
            setupFinishObserver()

            player?.play()
            isPlaying = true
            print("[AudioQueuePlayer] Started playing, player created")
        } else {
            player?.insert(item, after: player?.items().last)
            print("[AudioQueuePlayer] Added to queue, items count: \(player?.items().count ?? 0)")
        }
    }

    func stop() {
        player?.pause()
        player?.removeAllItems()
        playerItems.removeAll()
        player = nil
        isPlaying = false

        // 移除观察者
        if let observer = finishObserver {
            NotificationCenter.default.removeObserver(observer)
            finishObserver = nil
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
    }

    // MARK: - Private

    private func setupFinishObserver() {
        print("[AudioQueuePlayer] Setting up finish observer")
        finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let finishedItem = notification.object as? AVPlayerItem else { return }

            print("[AudioQueuePlayer] Item finished playing")

            // 删除临时文件
            if let asset = finishedItem.asset as? AVURLAsset {
                let url = asset.url
                if url.path.contains(FileManager.default.temporaryDirectory.path) {
                    try? FileManager.default.removeItem(at: url)
                }
            }

            // 从队列中移除
            if let index = self.playerItems.firstIndex(of: finishedItem) {
                self.playerItems.remove(at: index)
            }

            // 检查是否播放完毕
            if self.playerItems.isEmpty {
                print("[AudioQueuePlayer] Queue empty, cleaning up")
                self.isPlaying = false
                self.player = nil
                // 移除观察者
                if let observer = self.finishObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self.finishObserver = nil
                }
            }
        }
    }

    private func decodeDataURL(_ dataURL: String) -> (Data, String)? {
        guard dataURL.hasPrefix("data:") else { return nil }

        let parts = dataURL.components(separatedBy: ",")
        guard parts.count == 2 else { return nil }
        let header = parts[0]
        let base64 = parts[1]

        let fileExtension: String
        if header.contains("audio/wav") {
            fileExtension = "wav"
        } else if header.contains("audio/mp3") || header.contains("audio/mpeg") {
            fileExtension = "mp3"
        } else if header.contains("audio/opus") {
            fileExtension = "opus"
        } else {
            fileExtension = "dat"
        }

        guard let data = Data(base64Encoded: base64) else { return nil }
        return (data, fileExtension)
    }

    deinit {
        if let observer = finishObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
