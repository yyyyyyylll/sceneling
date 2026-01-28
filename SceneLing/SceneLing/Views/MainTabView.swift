import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

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
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
