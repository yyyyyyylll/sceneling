import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalScene.createdAt, order: .reverse) private var recentScenes: [LocalScene]

    @State private var showCamera = false
    @State private var stats = UserStats(totalScenes: 0, totalDialogues: 0, learningDays: 0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Camera Button
                    cameraButton

                    // Stats
                    statsSection

                    // Recent Scenes
                    if !recentScenes.isEmpty {
                        recentScenesSection
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("SceneLing")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
            .task {
                await loadStats()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("生活随手拍")
                .font(.title2)
                .fontWeight(.semibold)
            Text("地道学英语")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var cameraButton: some View {
        Button {
            showCamera = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                Text("拍照学习")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(width: 160, height: 160)
            .background(
                Circle()
                    .fill(.blue.gradient)
            )
            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
        }
        .padding(.vertical, 20)
    }

    private var statsSection: some View {
        HStack(spacing: 0) {
            StatItem(value: "\(stats.totalScenes)", label: "场景")
            Divider().frame(height: 40)
            StatItem(value: "\(stats.totalDialogues)", label: "对话")
            Divider().frame(height: 40)
            StatItem(value: "\(stats.learningDays)", label: "天数")
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recentScenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近学习")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(recentScenes.prefix(4)) { scene in
                    SceneCard(scene: scene)
                }
            }
        }
    }

    private func loadStats() async {
        do {
            stats = try await APIService.shared.getUserStats()
        } catch {
            // 使用本地数据计算
            let dialogueCount = recentScenes.reduce(0) { $0 + $1.expressions.roles.count }
            stats = UserStats(
                totalScenes: recentScenes.count,
                totalDialogues: dialogueCount,
                learningDays: 1
            )
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SceneCard: View {
    let scene: LocalScene

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let photoData = scene.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 100)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            Text(scene.sceneTag)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(scene.sceneTagCn)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
}
