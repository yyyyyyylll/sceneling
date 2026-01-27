import SwiftUI
import SwiftData

struct SceneLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalScene.createdAt, order: .reverse) private var scenes: [LocalScene]

    @State private var selectedCategory = "全部"
    @State private var searchText = ""
    @State private var showCamera = false

    private let categories = ["全部", "学习", "生活", "旅行", "美食", "其他"]

    private var filteredScenes: [LocalScene] {
        var result = scenes

        if selectedCategory != "全部" {
            result = result.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.sceneTag.localizedCaseInsensitiveContains(searchText) ||
                $0.sceneTagCn.contains(searchText)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if scenes.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }

                // Floating Camera Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showCamera = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("场景库")
            .searchable(text: $searchText, prompt: "搜索场景")
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("还没有场景")
                .font(.headline)

            Text("去拍一张吧！")
                .foregroundStyle(.secondary)

            Button {
                showCamera = true
            } label: {
                Text("去拍照")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        CategoryChip(
                            title: category,
                            isSelected: category == selectedCategory
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Scenes Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(filteredScenes) { scene in
                        NavigationLink(destination: SceneDetailView(scene: scene)) {
                            SceneLibraryCard(scene: scene)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct SceneLibraryCard: View {
    let scene: LocalScene

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let photoData = scene.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(scene.sceneTag)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack {
                    Text(scene.sceneTagCn)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(scene.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

#Preview {
    SceneLibraryView()
}
