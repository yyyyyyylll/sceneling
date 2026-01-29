import AVFoundation

final class LocalSpeechSynthesizer: NSObject {
    static let shared = LocalSpeechSynthesizer()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
    }

    func speak(_ text: String, language: String = "en-US") {
        guard !text.isEmpty else { return }
        // 停止之前的播放
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
