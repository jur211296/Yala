//
//  NotificationColdLaunchTapTests.swift
//  YalaTests
//
//  Toque en una notificación con la app cerrada (ticket `notification-delegate-assigned-after-launch`).
//
//  iOS entrega el toque que abre la app (`didReceive`) al delegado del centro de notificaciones, y Apple pide
//  asignarlo ANTES de que termine el lanzamiento. Hasta este ticket lo asignaba el paso 1 de
//  `AppBootstrapper.bootstrap`, en el `.task` de `ContentView`: después de `didFinishLaunching`, así que el toque
//  podía abrir Yala sin llevar a ningún sitio.
//
//  El test recorre el camino entero del arranque en frío: el centro sin delegado (proceso recién lanzado), el
//  `didFinishLaunching` REAL del app delegate, y el toque entregado con el arranque sin terminar. Debe quedar
//  aplazado y salir como `.navigate(destino)` cuando el arranque termina.
//

import Foundation
import Testing
import UIKit
import UserNotifications
@testable import Yala

@Suite("Toque en una notificación con la app cerrada", .serialized)
@MainActor
struct NotificationColdLaunchTapTests {

    /// La clave de `DeferredIntentBuffer.shared` en `.standard`. El buffer compartido es el que usa
    /// `RouterEntryGate`, así que el test lo aparta y lo repone al salir.
    private static let bufferKey = "Yala.RoutingDeferredIntentBuffer.v1"

    @Test("El delegado se asigna al terminar de lanzar y el toque en frío llega a su destino")
    func coldLaunchTap_isReceivedDeferredAndRouted() {
        let center = UNUserNotificationCenter.current()
        let savedDelegate = center.delegate
        let savedReadiness = RouterEntryGate.shared.readinessProvider
        let savedBuffer = UserDefaults.standard.data(forKey: Self.bufferKey)
        defer {
            center.delegate = savedDelegate
            RouterEntryGate.shared.readinessProvider = savedReadiness
            UserDefaults.standard.set(savedBuffer, forKey: Self.bufferKey)
            AppRouter.shared._testReset()
        }
        AppRouter.shared._testReset()
        DeferredIntentBuffer.shared.clear()

        // 1. Proceso recién lanzado: nadie ha asignado el delegado todavía.
        center.delegate = nil
        #expect(center.delegate == nil)

        // 2. El lanzamiento termina. Al volver de `didFinishLaunching`, el delegado tiene que estar puesto.
        let launched = YalaAppDelegate().application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
        #expect(launched)
        #expect(center.delegate === NotificationService.shared,
                "el delegado de notificaciones tiene que asignarse antes de que termine el lanzamiento")

        // 3. iOS entrega el toque con el arranque sin terminar (`isInitialized == false`): se aplaza, no se pierde.
        RouterEntryGate.shared.readinessProvider = { (hasCompletedOnboarding: true, isBootstrapInitialized: false) }
        NotificationService.routeTap(deepLink: "scheduledPayments", targetSessionID: nil)
        #expect(AppRouter.shared.queueSnapshot.isEmpty, "antes del arranque no se presenta nada")
        #expect(!DeferredIntentBuffer.shared.isEmpty, "el toque queda guardado en el buffer de entradas aplazadas")

        // 4. El arranque termina y drena el buffer (paso 20): el toque sale hacia su destino.
        RouterEntryGate.shared.readinessProvider = { (hasCompletedOnboarding: true, isBootstrapInitialized: true) }
        RouterEntryGate.shared.drainDeferredBuffer()
        let routed = AppRouter.shared.queueSnapshot.contains {
            if case .navigate(.scheduledPayments) = $0 { return true }
            return false
        }
        #expect(routed, "el toque tiene que llevar a Pagos planificados")
        #expect(DeferredIntentBuffer.shared.isEmpty)
    }

    /// `UNNotificationResponse` no se puede construir en un test, así que el tramo `didReceive → routeTap` se fija
    /// por source-scan: el cuerpo ENTERO del delegado, normalizado (sin comentarios ni sangría). Quitar la llamada,
    /// cambiar el `deepLink` que se lee o dejar de reenviar la ventana lo pone rojo.
    @Test("didReceive reenvía el toque a routeTap con su destino y su ventana")
    func didReceive_forwardsTheTapToRouteTap() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // YalaTests/
            .deletingLastPathComponent()      // raíz del repo
            .appendingPathComponent("Yala/Services/NotificationService.swift")
        let source = try String(contentsOf: path, encoding: .utf8)
        let start = try #require(source.range(of: "didReceive response: UNNotificationResponse,"))
        let end = try #require(source.range(of: "static func routeTap(", range: start.upperBound..<source.endIndex))
        let body = source[start.lowerBound..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("@MainActor") }

        #expect(body == [
            "didReceive response: UNNotificationResponse,",
            "withCompletionHandler completionHandler: @escaping () -> Void",
            ") {",
            "let userInfo = response.notification.request.content.userInfo",
            "let targetSessionID = response.targetScene?.session.persistentIdentifier",
            "if let destination = userInfo[\"deepLink\"] as? String {",
            "Task { @MainActor in",
            "Self.routeTap(deepLink: destination, targetSessionID: targetSessionID)",
            "}",
            "}",
            "completionHandler()",
            "}",
        ])
    }
}
