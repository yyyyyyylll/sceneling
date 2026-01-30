import SwiftUI
import Combine

struct FreeChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [LocalChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool

    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @StateObject private var speechRecognizer = SpeechRecognizer.shared
    @State private var sseClient: SSEClient?
    @State private var enableTTS = true
    @State private var isVoiceInputMode = true
    @State private var sessionId = UUID().uuidString

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            FreeMessageBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input Area
            inputArea
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            sendInitialMessage()
        }
        .onDisappear {
            sseClient?.disconnect()
            audioPlayer.stop()
            speechRecognizer.stopRecording()
        }
    }

    // MARK: - Header
    private var chatHeader: some View {
        ZStack {
            Text("AI 自由对话")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.04))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.40))
                        .frame(width: 36, height: 36)
                        .background(Color(red: 0.95, green: 0.96, blue: 0.96))
                        .clipShape(Circle())
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("结束")
                        .font(.system(size: 16))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Color(red: 0.95, green: 0.96, blue: 0.96))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 64)
        .background(Color.white.opacity(0.9))
        .overlay(
            Rectangle()
                .fill(Color(red: 0.90, green: 0.91, blue: 0.92).opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Input Area
    private var inputArea: some View {
        HStack(spacing: 8) {
            // 中间输入区域
            if isVoiceInputMode {
                Button {
                    if speechRecognizer.isRecording {
                        Task {
                            if let result = await speechRecognizer.stopAndGetFinalTranscript() {
                                await MainActor.run {
                                    sendVoiceMessage(
                                        text: result.text,
                                        audioData: result.audioData
                                    )
                                }
                            }
                        }
                    } else {
                        speechRecognizer.startRecording()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)

                        if speechRecognizer.isRecording {
                            Text(speechRecognizer.transcript.isEmpty ? "正在听..." : speechRecognizer.transcript)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        } else {
                            Text("点击说话")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        speechRecognizer.isRecording ? Color.red.opacity(0.8) :
                        Color(red: 0.68, green: 0.27, blue: 1)
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                }
                .disabled(isLoading)
            } else {
                HStack(spacing: 8) {
                    TextField("输入消息...", text: $inputText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .accentColor(.white)
                        .focused($isInputFocused)

                    if !inputText.isEmpty {
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(red: 0.68, green: 0.27, blue: 1))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
            }

            // 右侧按钮 - 切换输入模式
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVoiceInputMode.toggle()
                    if !isVoiceInputMode && speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                    }
                }
            } label: {
                Image(systemName: isVoiceInputMode ? "keyboard" : "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.40))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.95, green: 0.96, blue: 0.96))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 17)
        .background(Color.white.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(Color(red: 0.90, green: 0.91, blue: 0.92).opacity(0.5))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private func sendInitialMessage() {
        guard messages.isEmpty else { return }
        let greeting = "Hi there! I'm your English learning buddy. Feel free to talk to me about anything - your day, your hobbies, or whatever's on your mind. What would you like to chat about today?"
        let message = LocalChatMessage(content: greeting, isUser: false, roleName: "AI")
        messages.append(message)
    }

    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }

        messages.append(LocalChatMessage(content: userMessage, isUser: true, roleName: "Me"))
        inputText = ""
        isLoading = true

        let aiMessage = LocalChatMessage(content: "", isUser: false, roleName: "AI")
        messages.append(aiMessage)

        let history = messages.dropLast().map { ($0.content, $0.isUser) }

        sseClient = APIService.shared.freeChatStream(
            message: userMessage,
            history: Array(history),
            sessionId: sessionId,
            onEvent: { [weak aiMessage] event in
                switch event {
                case .textDelta(let text):
                    aiMessage?.append(text)

                case .textFull(let text):
                    aiMessage?.append(text)

                case .translation(let text):
                    aiMessage?.translation = text

                case .audio(let url, _):
                    aiMessage?.cachedAudioURL = url
                    if self.enableTTS {
                        self.audioPlayer.enqueue(dataURL: url)
                    }

                case .done:
                    self.isLoading = false

                case .error(let message):
                    aiMessage?.append("\n[Error: \(message)]")
                    self.isLoading = false

                case .sceneBasic, .sceneExpressions:
                    // 自由对话不处理场景分析事件
                    break
                }
            },
            onComplete: {
                self.isLoading = false
                self.sseClient = nil
            }
        )
    }

    private func sendVoiceMessage(text: String, audioData: Data?) {
        let userMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }

        let message = LocalChatMessage(
            content: userMessage,
            isUser: true,
            roleName: "Me",
            recordedAudioData: audioData
        )
        messages.append(message)
        isLoading = true

        let aiMessage = LocalChatMessage(content: "", isUser: false, roleName: "AI")
        messages.append(aiMessage)

        let history = messages.dropLast().map { ($0.content, $0.isUser) }

        sseClient = APIService.shared.freeChatStream(
            message: userMessage,
            history: Array(history),
            sessionId: sessionId,
            onEvent: { [weak aiMessage] event in
                switch event {
                case .textDelta(let text):
                    aiMessage?.append(text)

                case .textFull(let text):
                    aiMessage?.append(text)

                case .translation(let text):
                    aiMessage?.translation = text

                case .audio(let url, _):
                    aiMessage?.cachedAudioURL = url
                    if self.enableTTS {
                        self.audioPlayer.enqueue(dataURL: url)
                    }

                case .done:
                    self.isLoading = false

                case .error(let message):
                    aiMessage?.append("\n[Error: \(message)]")
                    self.isLoading = false

                case .sceneBasic, .sceneExpressions:
                    // 自由对话不处理场景分析事件
                    break
                }
            },
            onComplete: {
                self.isLoading = false
                self.sseClient = nil
            }
        )
    }
}

// MARK: - Free Message Bubble

struct FreeMessageBubble: View {
    @ObservedObject var message: LocalChatMessage
    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @State private var isLoadingAudio = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer()
                userMessageView
                userAvatar
            } else {
                aiAvatar
                aiMessageView
                Spacer()
            }
        }
    }

    private var aiAvatar: some View {
        Text("AI")
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color(red: 0.76, green: 0.48, blue: 1))
            .clipShape(Circle())
    }

    private var userAvatar: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color(red: 0.32, green: 0.64, blue: 1))
            .clipShape(Circle())
    }

    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.content.isEmpty ? " " : message.content)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.04))
                .animation(.easeInOut(duration: 0.1), value: message.content)

            if message.showTranslation, let translation = message.translation, !translation.isEmpty {
                Text(translation)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.40))
                    .animation(.easeInOut(duration: 0.1), value: message.showTranslation)
            }

            HStack(spacing: 8) {
                Button {
                    playAudio()
                } label: {
                    if isLoadingAudio {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 0.68, green: 0.28, blue: 1))
                            .frame(width: 24, height: 24)
                            .background(Color(red: 0.95, green: 0.91, blue: 1))
                            .clipShape(Circle())
                    }
                }
                .disabled(isLoadingAudio)

                Button {
                    message.showTranslation.toggle()
                } label: {
                    Image(systemName: "translate")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.32, green: 0.64, blue: 1))
                        .frame(width: 24, height: 24)
                        .background(Color(red: 0.86, green: 0.92, blue: 1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
        .frame(maxWidth: 260, alignment: .leading)
    }

    private var userMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.content.isEmpty ? " " : message.content)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .animation(.easeInOut(duration: 0.1), value: message.content)

            HStack {
                Button {
                    playAudio()
                } label: {
                    if isLoadingAudio {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .disabled(isLoadingAudio)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color(red: 0.68, green: 0.28, blue: 1))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
        .frame(maxWidth: 220, alignment: .trailing)
    }

    private func playAudio() {
        if message.isUser {
            if let audioData = message.recordedAudioData {
                let base64 = audioData.base64EncodedString()
                let dataURL = "data:audio/wav;base64,\(base64)"
                audioPlayer.playNow(dataURL: dataURL)
                return
            }
            audioPlayer.stop()
            LocalSpeechSynthesizer.shared.speak(message.content)
            return
        }

        if let cachedURL = message.cachedAudioURL {
            audioPlayer.playNow(dataURL: cachedURL)
            return
        }

        guard !message.content.isEmpty else { return }
        isLoadingAudio = true

        Task {
            do {
                let audioDataURL = try await APIService.shared.textToSpeechDataURL(text: message.content, voice: "en-US-female")
                await MainActor.run {
                    message.cachedAudioURL = audioDataURL
                    audioPlayer.enqueue(dataURL: audioDataURL)
                    isLoadingAudio = false
                }
            } catch {
                await MainActor.run {
                    isLoadingAudio = false
                    LocalSpeechSynthesizer.shared.speak(message.content)
                }
            }
        }
    }
}

#Preview {
    FreeChatView()
}
