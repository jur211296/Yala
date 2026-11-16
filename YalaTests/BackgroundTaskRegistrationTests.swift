//
//  BackgroundTaskRegistrationTests.swift
//  YalaTests
//
//  YALA-IOS-E (2026-11-06): el swap de persona en caliente re-ejecuta el bootstrap en el mismo proceso, y
//  registrar otra vez `com.jurgenschmidt.yala.widget-refresh` en `BGTaskScheduler` lanza
//  `NSInternalInconsistencyException` («Launch handler … has already been registered»). El registro es por
//  PROCESO: el segundo `registerTasks()` no toca el sistema.
//

import BackgroundTasks
import Testing

@testable import Yala

@MainActor
struct BackgroundTaskRegistrationTests {

    /// Registrar falso: anota cada identifier y los que entran dos veces (lo que `BGTaskScheduler` no perdona).
    private final class FakeRegistrar {
        var registered: [String] = []
        var duplicates: [String] = []

        func register(_ identifier: String) {
            if registered.contains(identifier) { duplicates.append(identifier) }
            registered.append(identifier)
        }
    }

    @Test func registerTasks_registersTheThreeIdentifiersOnce() {
        let fake = FakeRegistrar()
        let manager = BackgroundTaskManager(registrar: { identifier, _ in fake.register(identifier) })

        manager.registerTasks()

        #expect(fake.registered == [
            BackgroundTaskManager.widgetRefreshTaskID,
            BackgroundTaskManager.reportNotificationTaskID,
            BackgroundTaskManager.reportBackupTaskID,
        ])
        #expect(manager.tasksRegistered)
    }

    /// El re-bootstrap tras el swap (`AppBootstrapper.rebootstrapAfterSwap`) vuelve a llamar a `registerTasks()`.
    @Test func registerTasks_secondCallInTheSameProcessDoesNotReRegister() {
        let fake = FakeRegistrar()
        let manager = BackgroundTaskManager(registrar: { identifier, _ in fake.register(identifier) })

        manager.registerTasks()
        manager.registerTasks()
        manager.registerTasks()

        #expect(fake.duplicates.isEmpty)
        #expect(fake.registered.count == 3)
    }
}
