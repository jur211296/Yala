//
//  ErrorReportingService.swift
//  Yala
//
//  Avisos de errores y caídas en Sentry (proyecto `yala-ios`).
//
//  El DSN llega de `Secrets.xcconfig` → `Info.plist` (`SENTRY_DSN`). Sin DSN, en unit tests, en XCUITest y en las
//  previews de Xcode el SDK no arranca y la app se comporta exactamente igual que antes. Lo que sale pasa por `ErrorReportScrubLogic`: sin datos
//  del usuario, sin cuerpos ni queries de red, sin capturas de pantalla ni grabación de sesión.
//

import Foundation
import Sentry
import UIKit

nonisolated enum ErrorReportingService {

    /// Arranca el SDK. Va lo primero de `didFinishLaunching` para que una caída del arranque también avise.
    static func start() {
        guard shouldStart(
            isRunningTests: SwiftDataConfiguration.isRunningTests,
            isUITest: UITestHooks.isActive,
            environment: ProcessInfo.processInfo.environment
        ) else { return }
        guard let dsn = ErrorReportScrubLogic.usableDSN(
            Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String
        ) else { return }

        let environment = currentEnvironment
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.sendDefaultPii = false
            // Ni capturas de pantalla, ni jerarquía de vistas, ni grabación de sesión: enseñarían importes y nombres.
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.sessionReplay.sessionSampleRate = 0
            options.sessionReplay.onErrorSampleRate = 0
            // Solo errores y caídas: sin trazas de rendimiento, que llevan URLs y nombres de pantallas por petición.
            options.tracesSampleRate = 0
            options.enableAutoPerformanceTracing = false
            options.enableNetworkTracking = false
            options.enableFileIOTracing = false
            options.enableCoreDataTracing = false
            options.enableUserInteractionTracing = false
            // Un fallo HTTP no es una caída; y su captura llevaría la petición.
            options.enableCaptureFailedRequests = false
            options.enableLogs = false
            // Memoria agotada y cuelgues: App Store y TestFlight (ver `ErrorReportContextLogic.tracksHangsAndWatchdog`).
            let tracksHangs = ErrorReportContextLogic.tracksHangsAndWatchdog(environment: environment)
                || forcesHangTrackingForTest
            options.enableWatchdogTerminationTracking = tracksHangs
            options.enableAppHangTracking = tracksHangs
            options.beforeSend = { event in scrub(event) }
            options.beforeBreadcrumb = { crumb in scrub(crumb) }
        }
        // «Usuarios afectados»: un id aleatorio de esta instalación, nada de la persona (ver `installID`).
        SentrySDK.setUser(User(userId: anonymousInstallID))
        // Memoria, avisos de memoria baja y pestaña: lo que un cierre por memoria necesita traer (YALA-IOS-B).
        Task { @MainActor in MemoryDiagnostics.shared.start() }

        #if DEV_BUILD
        // `-sentry-test-error`: manda el error de prueba al arrancar, para comprobarlo sin navegar hasta el botón.
        if ProcessInfo.processInfo.arguments.contains("-sentry-test-error") { _ = sendTestError() }
        // `-sentry-test-memory-warning`: un aviso de memoria baja a los 3 s, para ver en Sentry el evento, el contexto
        // `memory` y los rastros sin esperar a que iOS lo mande (el simulador no tiene cómo pedirlo por línea de comandos).
        if ProcessInfo.processInfo.arguments.contains("-sentry-test-memory-warning") {
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
                NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
            }
        }
        // `-sentry-test-hang`: bloquea el hilo principal 4 s a los 5 s del arranque, con el seguimiento de cuelgues
        // encendido, para comprobar en Sentry el título con los segundos, el usuario, el entorno y la huella.
        if forcesHangTrackingForTest {
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                blockMainThreadForSentryTest()
            }
        }
        #endif
    }

    #if DEV_BUILD
    /// Un cuelgue de verdad: el hilo principal no atiende nada durante 4 s. Lleva nombre propio para que la regla de
    /// huella del proyecto lo agrupe aparte («prueba de Sentry»).
    @MainActor
    private static func blockMainThreadForSentryTest() {
        Thread.sleep(forTimeInterval: 4)
    }
    #endif

    private static var forcesHangTrackingForTest: Bool {
        #if DEV_BUILD
        return ProcessInfo.processInfo.arguments.contains("-sentry-test-hang")
        #else
        return false
        #endif
    }

    /// Ni en unit tests, ni en XCUITest, ni dentro de una preview de Xcode. Una preview corre la app de desarrollo en el
    /// simulador, y sus caídas —las de un fixture a medio escribir— llegaban a Sentry como caídas de la app
    /// (YALA-IOS-3 y YALA-IOS-4, 2026-11-02: doce arranques en dos minutos de las previews de «Tu parte»).
    static func shouldStart(isRunningTests: Bool, isUITest: Bool, environment: [String: String]) -> Bool {
        guard !isRunningTests, !isUITest else { return false }
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    }

    /// Error de prueba (Ajustes › Almacenamiento › panel de Modo Nube, o `-sentry-test-error`; solo DEV_BUILD). El mensaje lleva un correo y un importe FALSOS: en
    /// Sentry tienen que verse como `[email]` y `[monto]`.
    static func sendTestError() -> Bool {
        guard SentrySDK.isEnabled else { return false }
        let error = NSError(
            domain: "com.jurgenschmidt.yala.sentry-test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Prueba de Sentry de la app: prueba@example.com pagó S/ 123.45"]
        )
        SentrySDK.capture(error: error)
        return true
    }

    private static var currentEnvironment: String {
        #if DEV_BUILD
        let flavor = ErrorReportContextLogic.BuildFlavor.development
        #elseif DEBUG
        let flavor = ErrorReportContextLogic.BuildFlavor.debug
        #else
        let flavor = ErrorReportContextLogic.BuildFlavor.release
        #endif
        return ErrorReportContextLogic.environment(
            flavor: flavor,
            receiptFileName: (Bundle.main as AppStoreReceiptLocating).appStoreReceiptURL?.lastPathComponent
        )
    }

    /// El id anónimo de esta instalación, creado la primera vez que hace falta.
    private static var anonymousInstallID: String {
        let defaults = UserDefaults.standard
        let resolved = ErrorReportContextLogic.installID(
            stored: defaults.string(forKey: ErrorReportContextLogic.installIDKey)
        )
        if resolved.isNew { defaults.set(resolved.id, forKey: ErrorReportContextLogic.installIDKey) }
        return resolved.id
    }

    // MARK: - Limpieza

    private static func scrub(_ event: Event) -> Event? {
        // Del usuario solo viaja el id anónimo de la instalación: ni IP, ni correo, ni nombre, ni geolocalización.
        let installID = event.user?.userId
        event.user = installID.map { User(userId: $0) }
        event.request = nil
        event.extra = nil
        event.serverName = nil
        if let formatted = event.message?.formatted {
            event.message = SentryMessage(formatted: ErrorReportScrubLogic.scrubText(formatted))
        }
        for exception in event.exceptions ?? [] {
            if let value = exception.value { exception.value = ErrorReportScrubLogic.scrubText(value) }
            // El mecanismo de un NSError repite su descripción y copia el `userInfo` entero (medido en el primer
            // evento). La señal y el código de una caída viajan en `meta`, que se queda.
            if let mechanism = exception.mechanism {
                if let desc = mechanism.desc { mechanism.desc = ErrorReportScrubLogic.scrubText(desc) }
                mechanism.data = nil
            }
        }
        // El nombre del teléfono suele ser el de su dueño («iPhone de Ana»).
        if var device = event.context?["device"] {
            device.removeValue(forKey: "name")
            event.context?["device"] = device
        }
        // El `userInfo` de un NSError viaja como contexto «user info» sin pasar por ningún filtro: medido, llevaba
        // el correo y el importe del error de prueba tal cual. Su texto ya va (limpio) en la excepción.
        event.context?.removeValue(forKey: "user info")
        // Sin esto Sentry toma la IP de quien envía el evento y la geolocaliza (medido: «Lima» en el primer evento).
        var sdk = event.sdk ?? [:]
        sdk["settings"] = ["infer_ip": "never"]
        event.sdk = sdk
        event.breadcrumbs = event.breadcrumbs?.compactMap { scrub($0) }
        return event
    }

    private static func scrub(_ crumb: Breadcrumb) -> Breadcrumb? {
        if let message = crumb.message { crumb.message = ErrorReportScrubLogic.scrubText(message) }
        // Clave a clave: el setter de `data` está obsoleto. Lo que la limpieza no conserva se borra (valor `nil`).
        let kept = ErrorReportScrubLogic.breadcrumbData(category: crumb.category, type: crumb.type, data: crumb.data)
        for key in crumb.data?.keys.map({ $0 }) ?? [] {
            crumb.setData(value: kept?[key], key: key)
        }
        return crumb
    }
}

/// `Bundle.appStoreReceiptURL` está obsoleto desde iOS 18 pero sigue siendo la única forma síncrona de saber si la app
/// viene de TestFlight, y el propio SDK de Sentry la usa para su `build_type`. Leída a través de este requisito no
/// suma un warning de API obsoleta en cada build.
nonisolated private protocol AppStoreReceiptLocating {
    var appStoreReceiptURL: URL? { get }
}

nonisolated extension Bundle: AppStoreReceiptLocating {}
