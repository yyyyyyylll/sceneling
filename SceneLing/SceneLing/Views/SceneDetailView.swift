import SwiftUI
import SwiftData
import UIKit

struct SceneDetailView: View {
    let scene: LocalScene
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var showRoleSelection = false
    @State private var showChat = false
    @State private var selectedUserRole: Role?
    @State private var selectedAIRole: Role?
    @State private var isSavedToLibrary: Bool
    @State private var isSaving = false
    @State private var pendingChatNavigation = false
    @State private var chatStartTime: Date?  // 对话开始时间

    init(scene: LocalScene) {
        self.scene = scene
        self._isSavedToLibrary = State(initialValue: scene.isSavedToLibrary)
    }

    // 从 LocalScene 转换为 SceneAnalyzeResponse 用于 ChatView
    private var sceneContext: SceneAnalyzeResponse {
        SceneAnalyzeResponse(
            sceneTag: scene.sceneTag,
            sceneTagCn: scene.sceneTagCn,
            objectTags: scene.objectTags,
            description: Description(en: scene.descriptionEn, cn: scene.descriptionCn),
            expressions: scene.expressions,
            category: scene.category
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Photo with category badge
                    ZStack(alignment: .topLeading) {
                        if let photoData = scene.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: AppTheme.Colors.cardShadow, radius: 6, y: 4)
                        }

                        // Category badge
                        Text(scene.category)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Capsule())
                            .padding(12)
                    }
                    .padding(.horizontal)

                    // Tab Selector
                    ContentTabSelector(selectedTab: $selectedTab)
                        .padding(.top, 16)

                    // Content
                    TabView(selection: $selectedTab) {
                        VocabularyCard(objectTags: scene.objectTags, sceneId: scene.id)
                            .tag(0)
                        DescriptionCard(description: Description(
                            en: scene.descriptionEn,
                            cn: scene.descriptionCn
                        ))
                            .tag(1)
                        ExpressionCard(expressions: scene.expressions, sceneId: scene.id)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(minHeight: 350)
                }
            }

            // Bottom Buttons
            HStack(spacing: 12) {
                // Save Button - 可切换保存/取消保存状态
                Button {
                    Task {
                        if isSavedToLibrary {
                            await unsaveScene()
                        } else {
                            await saveScene()
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

                // AI对话按钮
                Button {
                    showRoleSelection = true
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("AI对话")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .navigationTitle("场景详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showRoleSelection) {
            RoleSelectionView(
                roles: scene.expressions.roles,
                onConfirm: { userRole, aiRole in
                    selectedUserRole = userRole
                    selectedAIRole = aiRole
                    pendingChatNavigation = true
                },
                sceneTag: scene.sceneTag,
                sceneTagCn: scene.sceneTagCn,
                category: scene.category,
                photoData: scene.photoData,
                createdAt: scene.createdAt
            )
        }
        .onChange(of: showRoleSelection) { oldValue, newValue in
            // When RoleSelectionView dismisses and we have pending navigation
            if oldValue == true && newValue == false && pendingChatNavigation {
                pendingChatNavigation = false
                // Small delay to ensure the dismiss animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showChat = true
                }
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            if let userRole = selectedUserRole, let aiRole = selectedAIRole {
                ChatView(sceneContext: sceneContext, userRole: userRole, aiRole: aiRole, photoData: scene.photoData, isPresented: $showChat)
                    .onAppear {
                        chatStartTime = Date()
                    }
            } else {
                // Fallback - should not happen, but prevents blank screen
                Text("加载中...")
                    .onAppear {
                        // If no roles selected, dismiss
                        if selectedUserRole == nil || selectedAIRole == nil {
                            showChat = false
                        }
                    }
            }
        }
        .onChange(of: showChat) { oldValue, newValue in
            // 对话结束时记录时长和对话次数
            if oldValue == true && newValue == false {
                if let startTime = chatStartTime {
                    let duration = Int(Date().timeIntervalSince(startTime))
                    scene.addDialogueDuration(duration)
                    scene.incrementDialogueCount()
                    try? modelContext.save()
                    chatStartTime = nil
                }
            }
        }
    }

    /// 保存到场景库
    private func saveScene() async {
        isSaving = true
        scene.isSavedToLibrary = true
        do {
            try modelContext.save()
            isSavedToLibrary = true
        } catch {
            print("保存失败：\(error.localizedDescription)")
        }
        isSaving = false
    }

    /// 从场景库取消保存
    private func unsaveScene() async {
        isSaving = true
        scene.isSavedToLibrary = false
        do {
            try modelContext.save()
            isSavedToLibrary = false
        } catch {
            print("取消保存失败：\(error.localizedDescription)")
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        SceneDetailView(scene: LocalScene(
            localPhotoId: "test",
            sceneTag: "Coffee Shop",
            sceneTagCn: "咖啡店",
            objectTags: [
                ObjectTag(en: "Coffee", cn: "咖啡", phonetic: "/ˈkɔːfi/", pos: "n.")
            ],
            descriptionEn: "A cozy coffee shop",
            descriptionCn: "一家温馨的咖啡店",
            expressions: Expressions(roles: []),
            category: "生活"
        ))
    }
}
