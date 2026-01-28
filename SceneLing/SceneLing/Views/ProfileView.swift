import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Query private var scenes: [LocalScene]
    @Query private var notes: [LocalNote]

    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.nickname ?? "SceneLing 用户")
                                .font(.headline)
                            Text("继续加油！")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Stats Section
                Section("学习统计") {
                    HStack {
                        StatRow(icon: "photo.stack", title: "场景数", value: "\(scenes.count)")
                        Divider()
                        StatRow(icon: "textformat.abc", title: "词汇数", value: "\(vocabularyCount)")
                        Divider()
                        StatRow(icon: "calendar", title: "学习天数", value: "\(learningDays)")
                    }
                    .padding(.vertical, 8)
                }

                // Features Section
                Section("功能") {
                    NavigationLink {
                        NotesView()
                    } label: {
                        Label("我的笔记", systemImage: "note.text")
                    }

                    NavigationLink {
                        // V1.1
                        ComingSoonView(title: "对话记录")
                    } label: {
                        Label("对话记录", systemImage: "bubble.left.and.bubble.right")
                    }
                }

                // Settings Section
                Section("设置") {
                    NavigationLink {
                        ComingSoonView(title: "学习设置")
                    } label: {
                        Label("学习设置", systemImage: "gearshape")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于我们", systemImage: "info.circle")
                    }
                }

                // Logout Section
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("我的")
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
    }

    private var vocabularyCount: Int {
        notes.filter { $0.type == .vocabulary }.count
    }

    private var learningDays: Int {
        let dates = Set(scenes.map { Calendar.current.startOfDay(for: $0.createdAt) })
        return dates.count
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("即将上线")
                .font(.headline)
            Text("敬请期待！")
                .foregroundStyle(.secondary)
        }
        .navigationTitle(title)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Link(destination: URL(string: "https://sceneling.com/privacy")!) {
                    Text("隐私政策")
                }
                Link(destination: URL(string: "https://sceneling.com/terms")!) {
                    Text("用户协议")
                }
            }

            Section {
                VStack(spacing: 8) {
                    Text("SceneLing")
                        .font(.headline)
                    Text("生活随手拍，地道学英语")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationTitle("关于我们")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
