import SwiftUI
import SwiftData
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

@main
struct FinariaApp: App {
    // SwiftData LOCAL (sin CloudKit)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Category.self, TransactionItem.self, Budget.self, ExchangeRate.self])
        let configuration = ModelConfiguration(schema: schema) // <<< SIN cloudKitDatabase
        return try! ModelContainer(for: schema, configurations: configuration)
    }()

    init() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.jurgenschmidt.finaria.daily", using: nil) { task in
            Task { await BackgroundJobs.handleDaily(task: task) }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    #if canImport(BackgroundTasks)
                    BackgroundJobs.scheduleDaily()
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
