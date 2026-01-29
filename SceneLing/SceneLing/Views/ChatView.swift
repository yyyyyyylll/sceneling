import SwiftUI
import Combine

class LocalChatMessage: Identifiable, ObservableObject {
    let id = UUID()
    @Published var content: String
    let isUser: Bool
    let timestamp = Date()
    var roleName: String = ""
    var cachedAudioURL: String?  // 缓存TTS音频URL (AI消息)
    var recordedAudioData: Data?  // 缓存录音数据 (用户消息)

    init(content: String, isUser: Bool, roleName: String = "", recordedAudioData: Data? = nil) {
        self.content = content
        self.isUser = isUser
        self.roleName = roleName
        self.recordedAudioData = recordedAudioData
    }

    func append(_ text: String) {
        content += text
    }
}

struct ChatView: View {
    let sceneContext: SceneAnalyzeResponse
    let userRole: Role
    let aiRole: Role
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [LocalChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool

    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @StateObject private var speechRecognizer = SpeechRecognizer.shared
    @State private var sseClient: SSEClient?
    @State private var enableTTS = true
    @State private var isVoiceInputMode = true  // 默认语音输入模式

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Scene Preview Card
            scenePreviewCard

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                userRoleName: userRole.roleCn,
                                aiRoleName: aiRole.roleCn
                            )
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
            // Center title
            Text("AI 对话练习")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.04))

            HStack {
                // Back button
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

                // End button (功能待确认)
                Button {
                    // TODO: 待确认功能 - 暂时设为返回
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

    // MARK: - Scene Preview Card
    private var scenePreviewCard: some View {
        ZStack {
            // Placeholder colored background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.50, green: 0.23, blue: 0.27).opacity(0.5),
                            Color(red: 0.68, green: 0.28, blue: 1).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Scene info overlay
            VStack(alignment: .leading, spacing: 4) {
                Text(sceneContext.sceneTagCn)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text("\(userRole.roleCn) vs \(aiRole.roleCn)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 128)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
    }

    // MARK: - Input Area
    private var inputArea: some View {
        HStack(spacing: 8) {
            // 左侧按钮 (功能待定)
            Button {
                // TODO: 功能待定
            } label: {
                Text("英")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.40))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.95, green: 0.96, blue: 0.96))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
            }

            // 中间输入区域
            if isVoiceInputMode {
                // 语音输入模式
                Button {
                    if speechRecognizer.isRecording {
                        // 停止录音并获取最终识别结果（带标点）
                        Task {
                            if let result = await speechRecognizer.stopAndGetFinalTranscript() {
                                await MainActor.run {
                                    sendVoiceMessage(
                                        text: result.text,
                                        audioData: result.audioData
                                    )
                                }
                            } else {
                                print("语音识别结果为空")
                            }
                        }
                    } else {
                        speechRecognizer.startRecording()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if speechRecognizer.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }

                        if speechRecognizer.isProcessing {
                            Text("识别中...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        } else if speechRecognizer.isRecording {
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
                        speechRecognizer.isProcessing ? Color.orange.opacity(0.8) :
                        speechRecognizer.isRecording ? Color.red.opacity(0.8) :
                        Color(red: 0.68, green: 0.27, blue: 1)
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                }
                .disabled(isLoading || speechRecognizer.isProcessing)
            } else {
                // 文本输入模式
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
                    // 切换到文本模式时停止录音
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
        // 防止重复发送初始消息
        guard messages.isEmpty else { return }
        let greeting = generateGreeting()
        let message = LocalChatMessage(content: greeting, isUser: false, roleName: aiRole.roleCn)
        messages.append(message)
    }

    private func generateGreeting() -> String {
        return "已选择角色：你是\(userRole.roleCn)，AI是\(aiRole.roleCn)。开始对话吧！"
    }

    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }

        messages.append(LocalChatMessage(content: userMessage, isUser: true, roleName: userRole.roleCn))
        inputText = ""
        isLoading = true

        let aiMessage = LocalChatMessage(content: "", isUser: false, roleName: aiRole.roleCn)
        messages.append(aiMessage)

        let history = messages.dropLast().map { ($0.content, $0.isUser) }

        sseClient = APIService.shared.chatStream(
            message: userMessage,
            sceneContext: sceneContext,
            userRole: userRole,
            aiRole: aiRole,
            history: Array(history),
            onEvent: { [weak aiMessage] event in
                switch event {
                case .textDelta(let text):
                    aiMessage?.append(text)

                case .textFull(let text):
                    aiMessage?.append(text)

                case .audio(let url, _):
                    // 缓存音频URL到消息对象
                    print("[ChatView] Received audio event, URL length: \(url.count)")
                    aiMessage?.cachedAudioURL = url
                    if self.enableTTS {
                        print("[ChatView] TTS enabled, enqueueing audio")
                        self.audioPlayer.enqueue(dataURL: url)
                    } else {
                        print("[ChatView] TTS disabled, skipping audio")
                    }

                case .done:
                    self.isLoading = false

                case .error(let message):
                    aiMessage?.append("\n[错误: \(message)]")
                    self.isLoading = false
                }
            },
            onComplete: {
                self.isLoading = false
                self.sseClient = nil
            }
        )
    }

    // 发送语音消息（带录音缓存）
    private func sendVoiceMessage(text: String, audioData: Data?) {
        let userMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }

        print("[ChatView] sendVoiceMessage with audioData: \(audioData?.count ?? 0) bytes")

        // 创建用户消息，附带录音数据
        let message = LocalChatMessage(
            content: userMessage,
            isUser: true,
            roleName: userRole.roleCn,
            recordedAudioData: audioData
        )
        messages.append(message)
        isLoading = true

        let aiMessage = LocalChatMessage(content: "", isUser: false, roleName: aiRole.roleCn)
        messages.append(aiMessage)

        let history = messages.dropLast().map { ($0.content, $0.isUser) }

        sseClient = APIService.shared.chatStream(
            message: userMessage,
            sceneContext: sceneContext,
            userRole: userRole,
            aiRole: aiRole,
            history: Array(history),
            onEvent: { [weak aiMessage] event in
                switch event {
                case .textDelta(let text):
                    aiMessage?.append(text)

                case .textFull(let text):
                    aiMessage?.append(text)

                case .audio(let url, _):
                    print("[ChatView] Received audio event (voice), URL length: \(url.count)")
                    aiMessage?.cachedAudioURL = url
                    if self.enableTTS {
                        print("[ChatView] TTS enabled, enqueueing audio (voice)")
                        self.audioPlayer.enqueue(dataURL: url)
                    } else {
                        print("[ChatView] TTS disabled, skipping audio (voice)")
                    }

                case .done:
                    self.isLoading = false

                case .error(let message):
                    aiMessage?.append("\n[错误: \(message)]")
                    self.isLoading = false
                }
            },
            onComplete: {
                self.isLoading = false
                self.sseClient = nil
            }
        )
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    @ObservedObject var message: LocalChatMessage
    var userRoleName: String = ""
    var aiRoleName: String = ""
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

    // AI Avatar
    private var aiAvatar: some View {
        Text("AI")
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color(red: 0.76, green: 0.48, blue: 1))
            .clipShape(Circle())
    }

    // User Avatar
    private var userAvatar: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color(red: 0.32, green: 0.64, blue: 1))
            .clipShape(Circle())
    }

    // AI Message View
    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Role label
            Text(aiRoleName)
                .font(.system(size: 10))
                .tracking(0.12)
                .foregroundStyle(.black)

            // Message bubble
            VStack(alignment: .leading, spacing: 8) {
                Text(message.content.isEmpty ? " " : message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.04))
                    .animation(.easeInOut(duration: 0.1), value: message.content)

                // Action buttons
                HStack(spacing: 8) {
                    // Play audio button (紫色) - 调用通义千问TTS
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

                    // Second button (蓝色) - 功能待确认
                    Button {
                        // TODO: 待确认功能
                    } label: {
                        Image(systemName: "doc.on.doc")
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
        }
        .frame(maxWidth: 260, alignment: .leading)
    }

    // User Message View
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Role label
            Text(userRoleName)
                .font(.system(size: 10))
                .tracking(0.12)
                .foregroundStyle(.black)

            // Message bubble
            VStack(alignment: .leading, spacing: 8) {
                Text(message.content.isEmpty ? " " : message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .animation(.easeInOut(duration: 0.1), value: message.content)

                // Action button (半透明白色) - 调用通义千问TTS
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
        }
        .frame(maxWidth: 220, alignment: .trailing)
    }

    // 播放语音（优先使用缓存，点击时停止之前的播放）
    private func playAudio() {
        // 用户消息：优先使用录音数据
        if message.isUser {
            print("[MessageBubble] Playing user message, recordedAudioData: \(message.recordedAudioData?.count ?? 0) bytes")
            if let audioData = message.recordedAudioData {
                // 转换为data URL格式播放
                let base64 = audioData.base64EncodedString()
                let dataURL = "data:audio/wav;base64,\(base64)"
                print("[MessageBubble] Playing recorded audio")
                audioPlayer.playNow(dataURL: dataURL)
                return
            }
            // 没有录音数据，使用系统TTS
            print("[MessageBubble] No recorded audio, using system TTS")
            audioPlayer.stop()  // 停止之前的播放
            LocalSpeechSynthesizer.shared.speak(message.content)
            return
        }

        // AI消息：使用缓存的TTS URL
        if let cachedURL = message.cachedAudioURL {
            audioPlayer.playNow(dataURL: cachedURL)
            return
        }

        // 没有缓存，调用API获取
        guard !message.content.isEmpty else { return }
        isLoadingAudio = true

        Task {
            do {
                let audioDataURL = try await APIService.shared.textToSpeechDataURL(text: message.content, voice: "en-US-female")
                await MainActor.run {
                    // 缓存并播放
                    message.cachedAudioURL = audioDataURL
                    audioPlayer.enqueue(dataURL: audioDataURL)
                    isLoadingAudio = false
                }
            } catch {
                print("TTS error: \(error)")
                await MainActor.run {
                    isLoadingAudio = false
                    // 失败时回退到系统TTS
                    LocalSpeechSynthesizer.shared.speak(message.content)
                }
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationOffset = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppTheme.Colors.textSecondary)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset == index ? -4 : 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                animationOffset = (animationOffset + 1) % 3
            }
        }
    }
}

#Preview {
    ChatView(sceneContext: SceneAnalyzeResponse(
        sceneTag: "Coffee Shop",
        sceneTagCn: "咖啡店",
        objectTags: [],
        description: Description(en: "A cozy coffee shop", cn: "一家舒适的咖啡店"),
        expressions: Expressions(roles: [
            Role(roleEn: "Barista", roleCn: "咖啡师", sentences: [])
        ]),
        category: "餐饮"
    ), userRole: Role(roleEn: "Customer", roleCn: "顾客", sentences: []),
       aiRole: Role(roleEn: "Barista", roleCn: "咖啡师", sentences: []))
}
