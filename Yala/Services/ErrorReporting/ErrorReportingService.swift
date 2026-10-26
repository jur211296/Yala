//
//  ErrorReportingService.swift
//  Yala
//
//  Avisos de errores y caídas en Sentry (proyecto `yala-ios`).
//
//  El DSN llega de `Secrets.xcconfig` → `Info.plist` (`SENTRY_DSN`). Sin DSN, en unit tests y en XCUITest el SDK no
//  arranca y la app se comporta exactamente igual que antes. Lo que sale pasa por `ErrorReportScrubLogic`: sin datos
//  del usuario, sin cuerpos ni queries de red, sin capturas de pantalla ni grabación de sesión.
//

import Foundation
import Sentry

nonisolated enum ErrorReportingService {

    /// Arranca el SDK. Va lo primero de `didFinishLaunching` para que una caída del arranque también avise.
    static func start() {
        guard !SwiftDataConfiguration.isRunningTests, !UITestHooks.isActive else { return }
        guard let dsn = ErrorReportScrubLogic.usableDSN(
            Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String
        ) else { return }

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
            options.beforeSend = { event in scrub(event) }
            options.beforeBreadcrumb = { crumb in scrub(crumb) }
        }

        #if DEV_BUILD
        // `-sentry-test-error`: manda el error de prueba al arrancar, para comprobarlo sin navegar hasta el botón.
        if ProcessInfo.processInfo.arguments.contains("-sentry-test-error") { _ = sendTestError() }
        #endif
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

    private static var environment: String {
        #if DEV_BUILD
        return "development"
        #elseif DEBUG
        return "debug"
        #else
        return "production"
        #endif
    }

    // MARK: - Limpieza

    private static func scrub(_ event: Event) -> Event? {
        event.user = nil
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
