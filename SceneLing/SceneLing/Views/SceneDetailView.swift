import SwiftUI
import UIKit

struct SceneDetailView: View {
    let scene: LocalScene
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showRoleSelection = false
    @State private var showChat = false
    @State private var selectedUserRole: Role?
    @State private var selectedAIRole: Role?
    @State private var showSaveSuccess = false

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
                    // Photo
                    if let photoData = scene.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 250)
                            .clipped()
                    }

                    // Scene Info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scene.sceneTag)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(scene.sceneTagCn)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(scene.category)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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

            // Bottom Buttons - 与 ResultView 保持一致
            HStack(spacing: 12) {
                // 保存按钮（已保存状态）
                Button {
                    showSaveSuccess = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("保存到场景库")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

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
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("场景详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showRoleSelection) {
            RoleSelectionView(roles: scene.expressions.roles) { userRole, aiRole in
                selectedUserRole = userRole
                selectedAIRole = aiRole
                showChat = true
            }
        }
        .sheet(isPresented: $showChat) {
            if let userRole = selectedUserRole, let aiRole = selectedAIRole {
                ChatView(sceneContext: sceneContext, userRole: userRole, aiRole: aiRole)
            }
        }
        .alert("已保存到场景库", isPresented: $showSaveSuccess) {
            Button("好的") {}
        }
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
