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
    @State private var showChat = false

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
                VocabularyCard(objectTags: result.objectTags)
                    .tag(0)
                DescriptionCard(description: result.description)
                    .tag(1)
                ExpressionCard(expressions: result.expressions)
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
                        Text("保存")
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
                    showChat = true
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
        .sheet(isPresented: $showChat) {
            if let result = analyzeResult {
                ChatView(sceneContext: result)
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
            localPhotoId: UUID().uuidString,
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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(objectTags, id: \.en) { tag in
                    VocabularyItem(tag: tag)
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
}

struct VocabularyItem: View {
    let tag: ObjectTag
    @State private var isSaved = false

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
                    // TODO: 播放发音
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.blue)
                }

                Button {
                    isSaved = true
                    // TODO: 保存到笔记
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(isSaved ? .green : .blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(expressions.roles, id: \.roleEn) { role in
                    RoleSection(role: role)
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
}

struct RoleSection: View {
    let role: Role

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
                SentenceItem(sentence: sentence)
            }
        }
    }
}

struct SentenceItem: View {
    let sentence: Sentence
    @State private var isSaved = false

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
                    // TODO: 播放发音
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.blue)
                }

                Button {
                    isSaved = true
                    // TODO: 保存到笔记
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(isSaved ? .green : .blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ResultView(image: UIImage(systemName: "photo")!)
    }
}
