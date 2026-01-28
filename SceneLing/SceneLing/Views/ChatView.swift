import SwiftUI
import Combine

class LocalChatMessage: Identifiable, ObservableObject {
    let id = UUID()
    @Published var content: String
    let isUser: Bool
    let timestamp = Date()

    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
    }

    func append(_ text: String) {
        content += text
    }
}

struct ChatView: View {
    let sceneContext: SceneAnalyzeResponse
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [LocalChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool

    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @State private var sseClient: SSEClient?
    @State private var enableTTS = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scene Context Header
                sceneHeader

                Divider()

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
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

                Divider()

                // Input Area
                inputArea
            }
            .navigationTitle("AI对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                sendInitialMessage()
            }
            .onDisappear {
                sseClient?.disconnect()
                audioPlayer.stop()
            }
        }
    }

    private var sceneHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sceneContext.sceneTag)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(sceneContext.sceneTagCn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(sceneContext.category)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var inputArea: some View {
        VStack(spacing: 8) {
            // TTS 控制栏
            HStack {
                Button {
                    enableTTS.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: enableTTS ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        Text(enableTTS ? "语音开" : "语音关")
                            .font(.caption)
                    }
                    .foregroundStyle(enableTTS ? .blue : .gray)
                }

                Spacer()

                if audioPlayer.isPlaying {
                    Button {
                        audioPlayer.stop()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("停止")
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal)

            // 输入框
            HStack(spacing: 12) {
                TextField("输入消息...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func sendInitialMessage() {
        // AI greeting message based on scene
        let greeting = generateGreeting()
        messages.append(LocalChatMessage(content: greeting, isUser: false))
    }

    private func generateGreeting() -> String {
        // Generate a greeting based on scene roles
        if let firstRole = sceneContext.expressions.roles.first {
            return "你好！我是这个场景中的 \(firstRole.roleCn)。基于「\(sceneContext.sceneTagCn)」这个场景，让我们来练习对话吧！你可以用英文或中文跟我交流。"
        }
        return "你好！基于「\(sceneContext.sceneTagCn)」这个场景，让我们来练习对话吧！你可以用英文或中文跟我交流。"
    }

    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }

        messages.append(LocalChatMessage(content: userMessage, isUser: true))
        inputText = ""
        isLoading = true

        // 创建 AI 回复消息（初始为空）
        let aiMessage = LocalChatMessage(content: "", isUser: false)
        messages.append(aiMessage)

        // 获取历史记录（排除刚添加的空消息）
        let history = messages.dropLast().map { ($0.content, $0.isUser) }

        // 使用流式 API
        sseClient = APIService.shared.chatStream(
            message: userMessage,
            sceneContext: sceneContext,
            history: Array(history),
            onEvent: { [weak aiMessage] event in
                switch event {
                case .textDelta(let text):
                    aiMessage?.append(text)

                case .textFull(let text):
                    aiMessage?.append(text)

                case .audio(let url, _):
                    if self.enableTTS {
                        self.audioPlayer.enqueue(dataURL: url)
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

struct MessageBubble: View {
    @ObservedObject var message: LocalChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.content.isEmpty ? " " : message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(message.isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .animation(.easeInOut(duration: 0.1), value: message.content)

            if !message.isUser { Spacer() }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationOffset = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset == index ? -4 : 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
    ))
}
