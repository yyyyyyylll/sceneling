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
    @State private var showSaveSuccess = false
    @State private var showRoleSelection = false
    @State private var showChat = false
    @State private var selectedUserRole: Role?
    @State private var selectedAIRole: Role?
    @State private var pendingSceneId = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Photo Preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let result = analyzeResult {
                contentView(result)
            }
        }
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
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("好的") {
                dismiss()
            }
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
            // Scene Tag
            HStack {
                Text(result.sceneTag)
                    .font(.headline)
                Text(result.sceneTagCn)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(result.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding()

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("词汇").tag(0)
                Text("描述").tag(1)
                Text("例句").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

                    // Content
                    TabView(selection: $selectedTab) {
                        VocabularyCard(objectTags: result.objectTags, sceneId: pendingSceneId)
                            .tag(0)
                        DescriptionCard(description: result.description)
                            .tag(1)
                        ExpressionCard(expressions: result.expressions, sceneId: pendingSceneId)
                            .tag(2)
                    }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Bottom Buttons
            HStack(spacing: 12) {
                // Save Button
                Button {
                    Task {
                        await saveScene(result)
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("保存到场景库")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSaving)

                // AI Chat Button
                Button {
                    showRoleSelection = true
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("AI对话")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .sheet(isPresented: $showRoleSelection) {
            if let result = analyzeResult {
                RoleSelectionView(roles: result.expressions.roles) { userRole, aiRole in
                    selectedUserRole = userRole
                    selectedAIRole = aiRole
                    showChat = true
                }
            }
        }
        .sheet(isPresented: $showChat) {
            if let result = analyzeResult,
               let userRole = selectedUserRole,
               let aiRole = selectedAIRole {
                ChatView(sceneContext: result, userRole: userRole, aiRole: aiRole)
            }
        }
    }

    private func analyzeImage() async {
        isLoading = true
        errorMessage = nil

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "图片处理失败"
            isLoading = false
            return
        }

        do {
            analyzeResult = try await APIService.shared.analyzeImage(imageData)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveScene(_ result: SceneAnalyzeResponse) async {
        isSaving = true

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
            category: result.category
        )

        modelContext.insert(scene)

        do {
            try modelContext.save()
            showSaveSuccess = true
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }

        isSaving = false
    }
}

// MARK: - Card Views

struct VocabularyCard: View {
    let objectTags: [ObjectTag]
    let sceneId: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(objectTags, id: \.en) { tag in
                    VocabularyItem(tag: tag, sceneId: sceneId)
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
}

struct VocabularyItem: View {
    let tag: ObjectTag
    let sceneId: UUID?
    @State private var isSaved = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @State private var isSpeaking = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(tag.en)
                        .font(.headline)
                    Text(tag.phonetic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tag.pos)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
                Text(tag.cn)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    speak(text: tag.en)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.blue)
                }
                .disabled(isSpeaking)

                Button {
                    saveNote()
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(isSaved ? .green : .blue)
                }
                .accessibilityLabel("保存到笔记本")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        isSpeaking = true
        Task {
            defer { isSpeaking = false }
            do {
                let url = try await APIService.shared.textToSpeech(text: text)
                audioPlayer.enqueue(url: url)
            } catch {
                print("TTS failed: \(error)")
            }
        }
    }
}

struct DescriptionCard: View {
    let description: Description

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("English")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            // TODO: 播放发音
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .foregroundStyle(.blue)
                        }
                    }
                    Text(description.en)
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("中文")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(description.cn)
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
}

struct ExpressionCard: View {
    let expressions: Expressions
    let sceneId: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(expressions.roles, id: \.roleEn) { role in
                    RoleSection(role: role, sceneId: sceneId)
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
}

struct RoleSection: View {
    let role: Role
    let sceneId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(role.roleEn)
                    .font(.headline)
                Text(role.roleCn)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(role.sentences, id: \.en) { sentence in
                SentenceItem(sentence: sentence, role: role.roleCn, sceneId: sceneId)
            }
        }
    }
}

struct SentenceItem: View {
    let sentence: Sentence
    let role: String?
    let sceneId: UUID?
    @State private var isSaved = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioQueuePlayer.shared
    @State private var isSpeaking = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sentence.en)
                    .font(.body)
                Text(sentence.cn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    speak(text: sentence.en)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.blue)
                }
                .disabled(isSpeaking)

                Button {
                    saveNote()
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(isSaved ? .green : .blue)
                }
                .accessibilityLabel("保存到笔记本")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        isSpeaking = true
        Task {
            defer { isSpeaking = false }
            do {
                let url = try await APIService.shared.textToSpeech(text: text)
                audioPlayer.enqueue(url: url)
            } catch {
                print("TTS failed: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResultView(image: UIImage(systemName: "photo")!)
    }
}
