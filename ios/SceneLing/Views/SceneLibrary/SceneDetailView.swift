import SwiftUI

struct SceneDetailView: View {
    let scene: LocalScene
    @State private var selectedTab = 0

    var body: some View {
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
                Group {
                    switch selectedTab {
                    case 0:
                        VocabularyCard(objectTags: scene.objectTags)
                    case 1:
                        DescriptionCard(description: Description(
                            en: scene.descriptionEn,
                            cn: scene.descriptionCn
                        ))
                    case 2:
                        ExpressionCard(expressions: scene.expressions)
                    default:
                        EmptyView()
                    }
                }
                .frame(minHeight: 300)

                // AI Dialog Button (V1.1 预告)
                Button {
                    // V1.1 功能
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("AI 对话")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(true)
                .padding()

                Text("AI 对话功能即将上线")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
        }
        .navigationTitle("场景详情")
        .navigationBarTitleDisplayMode(.inline)
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
