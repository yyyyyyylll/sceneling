import SwiftUI
import SwiftData
import UIKit

struct ResultView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var analyzeResult: SceneAnalyzeResponse?
    @State private var selectedTab = 0
    @State private var isSaving = false
    @State private var currentScene: LocalScene?  // 当前保存的场景记录
    @State private var isSavedToLibrary = false  // 是否已保存到场景库
    @State private var showRoleSelection = false
    @State private var showChat = false
    @State private var selectedUserRole: Role?
    @State private var selectedAIRole: Role?
    @State private var pendingSceneId = UUID()
    @State private var pendingChatNavigation = false
    @State private var chatStartTime: Date?  // 对话开始时间

    // 两阶段加载
    @State private var isExpressionsLoading = false
    @State private var sseClient: SSEClient?

    var body: some View {
        VStack(spacing: 0) {
            // Photo Preview with category badge
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.Colors.cardShadow, radius: 6, y: 4)

                // Category badge (show when result is available)
                if let result = analyzeResult {
                    Text(result.category)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let result = analyzeResult {
                contentView(result)
            }
        }
        .background(Color(red: 1, green: 0.97, blue: 0.93))
        .navigationTitle("学习内容")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
        .task {
            await analyzeImage()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("AI 正在理解这个场景...")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("重试") {
                Task {
                    await analyzeImage()
                }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }

    private func contentView(_ result: SceneAnalyzeResponse) -> some View {
        VStack(spacing: 0) {
            // Tab Selector
            ContentTabSelector(selectedTab: $selectedTab)
                .padding(.top, 16)

                    // Content
                    TabView(selection: $selectedTab) {
                        VocabularyCard(objectTags: result.objectTags, sceneId: pendingSceneId)
                            .tag(0)
                        DescriptionCard(description: result.description)
                            .tag(1)
                        ExpressionCard(expressions: result.expressions, sceneId: pendingSceneId, isLoading: isExpressionsLoading)
                            .tag(2)
                    }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Bottom Buttons
            HStack(spacing: 12) {
                // Save Button - 可切换保存/取消保存状态
                Button {
                    Task {
                        if isSavedToLibrary {
                            await unsaveScene()
                        } else {
                            await saveScene(result)
                        }
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else if isSavedToLibrary {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSavedToLibrary ? "已保存场景" : "保存场景")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSavedToLibrary ? AppTheme.Colors.secondary : AppTheme.Colors.secondary.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSaving)

                // AI Chat Button
                Button {
                    showRoleSelection = true
                } label: {
                    HStack {
                        if isExpressionsLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bubble.left.and.bubble.right")
                        }
                        Text(isExpressionsLoading ? "加载中..." : "AI对话")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isExpressionsLoading ? AppTheme.Colors.accent.opacity(0.5) : AppTheme.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isExpressionsLoading)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showRoleSelection) {
            if let result = analyzeResult {
                RoleSelectionView(
                    roles: result.expressions.roles,
                    onConfirm: { userRole, aiRole in
                        selectedUserRole = userRole
                        selectedAIRole = aiRole
                        pendingChatNavigation = true
                    },
                    sceneTag: result.sceneTag,
                    sceneTagCn: result.sceneTagCn,
                    category: result.category,
                    photoData: image.jpegData(compressionQuality: 0.8),
                    createdAt: Date()
                )
            }
        }
        .onChange(of: showRoleSelection) { oldValue, newValue in
            if oldValue == true && newValue == false && pendingChatNavigation {
                pendingChatNavigation = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showChat = true
                }
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            if let result = analyzeResult,
               let userRole = selectedUserRole,
               let aiRole = selectedAIRole {
                ChatView(sceneContext: result, userRole: userRole, aiRole: aiRole, photoData: image.jpegData(compressionQuality: 0.8), isPresented: $showChat)
                    .onAppear {
                        chatStartTime = Date()
                    }
            } else {
                Text("加载中...")
                    .onAppear {
                        if selectedUserRole == nil || selectedAIRole == nil {
                            showChat = false
                        }
                    }
            }
        }
        .onChange(of: showChat) { oldValue, newValue in
            // 对话结束时记录时长和对话次数
            if oldValue == true && newValue == false {
                if let startTime = chatStartTime, let scene = currentScene {
                    let duration = Int(Date().timeIntervalSince(startTime))
                    scene.addDialogueDuration(duration)
                    scene.incrementDialogueCount()
                    try? modelContext.save()
                    chatStartTime = nil
                }
            }
        }
    }

    private func analyzeImage() async {
        isLoading = true
        errorMessage = nil
        isExpressionsLoading = true

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "图片处理失败"
            isLoading = false
            isExpressionsLoading = false
            return
        }

        // 使用流式 API 进行两阶段加载
        sseClient = APIService.shared.analyzeImageStream(
            imageData,
            cefrLevel: "B1",
            onEvent: { event in
                switch event {
                case .sceneBasic(let data):
                    // 第一阶段：收到基础信息，立即显示
                    if let basicResult = SceneAnalyzeBasicResult.fromDict(data) {
                        self.analyzeResult = SceneAnalyzeResponse.fromBasic(basicResult)
                        self.isLoading = false
                        // 自动保存到最近学习
                        self.autoSaveToRecentLearning(SceneAnalyzeResponse.fromBasic(basicResult))
                    }

                case .sceneExpressions(let data):
                    // 第二阶段：收到口语例句，更新结果
                    if let expressionsData = data["expressions"] as? [String: Any],
                       let expressions = Expressions.fromDict(expressionsData) {
                        self.analyzeResult?.expressions = expressions
                        // 更新已保存场景的口语例句
                        self.currentScene?.expressions = expressions
                    }
                    self.isExpressionsLoading = false

                case .done:
                    self.isExpressionsLoading = false

                case .error(let message):
                    if self.analyzeResult == nil {
                        // 如果还没有基础结果，显示错误
                        self.errorMessage = message
                        self.isLoading = false
                    }
                    self.isExpressionsLoading = false

                default:
                    break
                }
            },
            onComplete: {
                self.sseClient = nil
                if self.analyzeResult == nil && self.errorMessage == nil {
                    self.errorMessage = "分析失败，请重试"
                    self.isLoading = false
                }
                self.isExpressionsLoading = false
            }
        )
    }

    /// 自动保存到最近学习（不保存到场景库）
    private func autoSaveToRecentLearning(_ result: SceneAnalyzeResponse) {
        let scene = LocalScene(
            id: pendingSceneId,
            localPhotoId: pendingSceneId.uuidString,
            photoData: image.jpegData(compressionQuality: 0.8),
            sceneTag: result.sceneTag,
            sceneTagCn: result.sceneTagCn,
            objectTags: result.objectTags,
            descriptionEn: result.description.en,
            descriptionCn: result.description.cn,
            expressions: result.expressions,
            category: result.category,
            isSavedToLibrary: false  // 只保存到最近学习，不保存到场景库
        )

        modelContext.insert(scene)
        currentScene = scene

        do {
            try modelContext.save()
        } catch {
            print("自动保存失败：\(error.localizedDescription)")
        }
    }

    /// 保存到场景库
    private func saveScene(_ result: SceneAnalyzeResponse) async {
        isSaving = true

        // 更新已有记录的 isSavedToLibrary 标记
        if let scene = currentScene {
            scene.isSavedToLibrary = true
            do {
                try modelContext.save()
                isSavedToLibrary = true
            } catch {
                errorMessage = "保存失败：\(error.localizedDescription)"
            }
        } else {
            // 如果没有已保存的记录，创建新记录
            let scene = LocalScene(
                id: pendingSceneId,
                localPhotoId: pendingSceneId.uuidString,
                photoData: image.jpegData(compressionQuality: 0.8),
                sceneTag: result.sceneTag,
                sceneTagCn: result.sceneTagCn,
                objectTags: result.objectTags,
                descriptionEn: result.description.en,
                descriptionCn: result.description.cn,
                expressions: result.expressions,
                category: result.category,
                isSavedToLibrary: true
            )

            modelContext.insert(scene)
            currentScene = scene

            do {
                try modelContext.save()
                isSavedToLibrary = true
            } catch {
                errorMessage = "保存失败：\(error.localizedDescription)"
            }
        }

        isSaving = false
    }

    /// 从场景库取消保存
    private func unsaveScene() async {
        isSaving = true

        if let scene = currentScene {
            scene.isSavedToLibrary = false
            do {
                try modelContext.save()
                isSavedToLibrary = false
            } catch {
                errorMessage = "取消保存失败：\(error.localizedDescription)"
            }
        }

        isSaving = false
    }
}

// MARK: - Custom Tab Selector

struct ContentTabSelector: View {
    @Binding var selectedTab: Int
    let tabs = ["核心词汇", "场景描述", "口语表达"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    Text(tabs[index])
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(selectedTab == index ? .white : Color(red: 0.29, green: 0.33, blue: 0.40))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedTab == index ? AppTheme.Colors.secondary : .white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedTab == index ? Color.clear : Color(red: 0.90, green: 0.91, blue: 0.92), lineWidth: 0.5)
                        )
                        .shadow(color: selectedTab == index ? AppTheme.Colors.cardShadow : .clear, radius: 6, y: 4)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Card Views

struct VocabularyCard: View {
    let objectTags: [ObjectTag]
    let sceneId: UUID?

    // Gradient background colors for vocabulary items
    private let cardColors: [Color] = [
        Color(red: 1, green: 0.97, blue: 0.93),
        Color(red: 1, green: 0.98, blue: 0.92),
        Color(red: 1, green: 0.99, blue: 0.91),
        Color(red: 1, green: 0.95, blue: 0.95),
        Color(red: 0.99, green: 0.95, blue: 0.97)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("核心词汇")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal)

                LazyVStack(spacing: 8) {
                    ForEach(Array(objectTags.enumerated()), id: \.element.en) { index, tag in
                        VocabularyItem(tag: tag, sceneId: sceneId, backgroundColor: cardColors[index % cardColors.count])
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
    }
}

struct VocabularyItem: View {
    let tag: ObjectTag
    let sceneId: UUID?
    var backgroundColor: Color = Color(red: 1, green: 0.97, blue: 0.93)
    @State private var isSaved = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @State private var isSpeaking = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tag.en)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if !tag.phonetic.isEmpty {
                        Text(tag.phonetic)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Text(tag.cn)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // Play button
                Button {
                    speak(text: tag.en)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
                }
                .disabled(isSpeaking)

                // Save button
                Button {
                    saveNote()
                } label: {
                    Image(systemName: isSaved ? "checkmark" : "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSaved ? .green : AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
                }
                .accessibilityLabel("保存到笔记本")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(height: 70)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func saveNote() {
        if isSaved { return }
        let note = LocalNote(
            sceneId: sceneId,
            type: .vocabulary,
            contentEn: tag.en,
            contentCn: tag.cn,
            phonetic: tag.phonetic,
            pos: tag.pos,
            role: nil
        )
        modelContext.insert(note)
        isSaved = true
    }

    private func speak(text: String) {
        guard !text.isEmpty else { return }
        // 停止之前的播放
        audioPlayer.stop()
        isSpeaking = true
        LocalSpeechSynthesizer.shared.speak(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isSpeaking = false
        }
    }
}

struct DescriptionCard: View {
    let description: Description
    @State private var isSpeaking = false
    @StateObject private var audioPlayer = AudioQueuePlayer.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("场景描述")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(description.en)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(description.cn)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Button {
                        speak(text: description.en)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(.white)
                            .clipShape(Circle())
                            .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
                    }
                    .disabled(isSpeaking)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(red: 1, green: 0.97, blue: 0.93))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
    }

    private func speak(text: String) {
        guard !text.isEmpty else { return }
        // 停止之前的播放
        audioPlayer.stop()
        isSpeaking = true
        LocalSpeechSynthesizer.shared.speak(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSpeaking = false
        }
    }
}

struct ExpressionCard: View {
    let expressions: Expressions
    let sceneId: UUID?
    var isLoading: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("口语表达")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal)

                if isLoading {
                    // 加载中状态
                    VStack(spacing: 16) {
                        Spacer()
                            .frame(height: 40)
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在生成口语例句...")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if expressions.roles.isEmpty {
                    // 没有内容
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
                        Text("暂无口语例句")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(expressions.roles, id: \.roleEn) { role in
                            RoleSection(role: role, sceneId: sceneId)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
    }
}

struct RoleSection: View {
    let role: Role
    let sceneId: UUID?

    private let cardColors: [Color] = [
        Color(red: 1, green: 0.97, blue: 0.93),
        Color(red: 1, green: 0.98, blue: 0.92),
        Color(red: 1, green: 0.99, blue: 0.91),
        Color(red: 1, green: 0.95, blue: 0.95),
        Color(red: 0.99, green: 0.95, blue: 0.97)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(role.roleEn.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(role.roleCn)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            ForEach(Array(role.sentences.enumerated()), id: \.element.en) { index, sentence in
                SentenceItem(sentence: sentence, role: role.roleCn, sceneId: sceneId, backgroundColor: cardColors[index % cardColors.count])
            }
        }
    }
}

struct SentenceItem: View {
    let sentence: Sentence
    let role: String?
    let sceneId: UUID?
    var backgroundColor: Color = Color(red: 1, green: 0.97, blue: 0.93)
    @State private var isSaved = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @State private var isSpeaking = false

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sentence.en)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(sentence.cn)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    speak(text: sentence.en)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
                }
                .disabled(isSpeaking)

                Button {
                    saveNote()
                } label: {
                    Image(systemName: isSaved ? "checkmark" : "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSaved ? .green : AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
                }
                .accessibilityLabel("保存到笔记本")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 70)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func saveNote() {
        if isSaved { return }
        let note = LocalNote(
            sceneId: sceneId,
            type: .expression,
            contentEn: sentence.en,
            contentCn: sentence.cn,
            phonetic: nil,
            pos: nil,
            role: role
        )
        modelContext.insert(note)
        isSaved = true
    }

    private func speak(text: String) {
        guard !text.isEmpty else { return }
        // 停止之前的播放
        audioPlayer.stop()
        isSpeaking = true
        LocalSpeechSynthesizer.shared.speak(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isSpeaking = false
        }
    }
}

#Preview {
    NavigationStack {
        ResultView(image: UIImage(systemName: "photo")!)
    }
}
