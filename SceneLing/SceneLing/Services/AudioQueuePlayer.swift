import Foundation
import AVFoundation
import Combine

class AudioQueuePlayer: ObservableObject {
    static let shared = AudioQueuePlayer()

    @Published var isPlaying = false

    private var player: AVQueuePlayer?
    private var playerItems: [AVPlayerItem] = []
    private var finishObserver: Any?

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func enqueue(dataURL: String) {
        guard let (audioData, fileExtension) = decodeDataURL(dataURL) else {
            print("Failed to decode data URL")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try audioData.write(to: tempURL)
            enqueue(url: tempURL)
        } catch {
            print("Failed to save temp audio: \(error)")
        }
    }

    func enqueue(url: URL) {
        let item = AVPlayerItem(url: url)
        playerItems.append(item)

        if player == nil {
            player = AVQueuePlayer(items: [item])
            setupFinishObserver()
            player?.play()
            isPlaying = true
        } else {
            player?.insert(item, after: player?.items().last)
        }
    }

    func stop() {
        player?.pause()
        player?.removeAllItems()
        playerItems.removeAll()
        player = nil
        isPlaying = false
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
        finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let finishedItem = notification.object as? AVPlayerItem else { return }

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
                self.isPlaying = false
                self.player = nil
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
