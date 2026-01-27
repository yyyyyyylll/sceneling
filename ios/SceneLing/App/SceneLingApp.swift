import SwiftUI
import SwiftData

@main
struct SceneLingApp: App {
    @StateObject private var authManager = AuthManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalScene.self,
            LocalNote.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
