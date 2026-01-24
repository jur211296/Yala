import Foundation
import SwiftData

#if canImport(BackgroundTasks)
    import BackgroundTasks

    enum BackgroundJobs {
        static let dailyId = "com.jurgenschmidt.yala.daily"

        static func scheduleDaily() {
            let request = BGAppRefreshTaskRequest(identifier: dailyId)
            request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            do { try BGTaskScheduler.shared.submit(request) } catch {
                print("BG submit error: " + String(describing: error))
            }
        }

        static func handleDaily(task: BGTask, context: ModelContext) async {
            task.expirationHandler = { task.setTaskCompleted(success: false) }

            // Update exchange rates daily
            await ExchangeRateService.shared.updateTodayIfNeeded(context: context)

            // Budget notifications planned for V1.1 (Phase 9)

            task.setTaskCompleted(success: true)
        }
    }
#endif
