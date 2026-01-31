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
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
            .task {
                await loadStats()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("SceneLing")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("生活随手拍，地道学英语")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 20)
    }

    private var cameraButton: some View {
        Button {
            showCamera = true
        } label: {
            ZStack {
                // Outer pink circle
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 144, height: 144)

                // Inner white area
                VStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text("拍照学习")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .frame(width: 128, height: 128)
                .background(
                    Circle()
                        .fill(Color.white)
                )
            }
            .shadow(color: AppTheme.Colors.buttonShadow, radius: 50, y: 25)
        }
        .padding(.vertical, 30)
    }

    private var statsSection: some View {
        HStack(spacing: 10) {
            statCard(icon: "photo.stack", value: "\(stats.totalScenes)", label: "场景", color: AppTheme.Colors.Pastels.pink)
            statCard(icon: "bubble.left.and.bubble.right.fill", value: "\(stats.totalDialogues)", label: "对话", color: AppTheme.Colors.Pastels.purple)
            statCard(icon: "flame.fill", value: "\(stats.learningDays)", label: "连续天", color: AppTheme.Colors.Pastels.blue)
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(label)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
    }

    private var recentScenesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近学习")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            // Group scenes by date
            ForEach(groupedScenes, id: \.0) { dateLabel, scenes in
                VStack(alignment: .leading, spacing: 8) {
                    // Date label
                    HStack(spacing: 6) {
                        Text(dateLabel)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text("·")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text("\(scenes.count)个场景")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    // Horizontal scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(scenes) { scene in
                                NavigationLink {
                                    SceneDetailView(scene: scene)
                                } label: {
                                    SceneCard(scene: scene)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 只显示7天内的场景
    private var groupedScenes: [(String, [LocalScene])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        var todayScenes: [LocalScene] = []
        var yesterdayScenes: [LocalScene] = []
        var olderScenes: [LocalScene] = []

        // 只显示7天内的场景
        for scene in recentScenes {
            let sceneDate = calendar.startOfDay(for: scene.createdAt)
            // 超过7天的不显示
            guard sceneDate >= sevenDaysAgo else { continue }

            if sceneDate == today {
                todayScenes.append(scene)
            } else if sceneDate == yesterday {
                yesterdayScenes.append(scene)
            } else {
                olderScenes.append(scene)
            }
        }

        var result: [(String, [LocalScene])] = []
        if !todayScenes.isEmpty { result.append(("今天", todayScenes)) }
        if !yesterdayScenes.isEmpty { result.append(("昨天", yesterdayScenes)) }
        if !olderScenes.isEmpty { result.append(("更早", olderScenes)) }
        return result
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

struct SceneCard: View {
    let scene: LocalScene

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let photoData = scene.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.50, green: 0.23, blue: 0.27).opacity(0.50))
                    .frame(width: 92, height: 92)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.6))
                    }
            }

            Text(scene.sceneTag)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: 112)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
}
