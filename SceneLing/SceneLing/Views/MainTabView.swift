import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white // Solid block
        appearance.shadowColor = .clear // No shadow line
        
        // Default icon colors are handled by the system and .tint modifier
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)

            SceneLibraryView()
                .tabItem {
                    Label("场景库", systemImage: "photo.stack.fill")
                }
                .tag(1)

            CommunityPlaceholderView()
                .tabItem {
                    Label("社区", systemImage: "person.3.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.Colors.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
