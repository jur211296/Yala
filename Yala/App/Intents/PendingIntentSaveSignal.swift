//
//  PendingIntentSaveSignal.swift
//  Yala
//
//  Señal cross-launch (App Group UserDefaults) de que un App Intent background
//  (ApplePay / Siri Natural) guardó un `InboxDraft` vía su PROPIO `ModelContainer`
//  sobre el mismo store físico que la app.
//
//  Por qué existe: el intent no notifica a la app tras su `context.save()`. El único
//  canal pasivo es `.NSPersistentStoreRemoteChange`, cuyo observer se registra recién en
//  `AppBootstrapper.bootstrap()` (dentro del `.task` del WindowGroup). Si el intent guardó
//  antes de que ese observer existiera, la notificación se pierde y la UI no refresca al
//  volver a foreground (Inbox vacío / datos stale) hasta un cold launch.
//
//  El intent escribe esta señal SÍNCRONAMENTE tras el save y ANTES de notificar, así que
//  está garantizada presente cuando el usuario abre la app. `AppBootstrapper` la consume en
//  foreground (`handleBecameActive`) y en `bootstrap()` para forzar el refresh vía el
//  mecanismo existente (`markRemoteChangePending` → `applyPendingChangesIfNeeded`).
//  Ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`.
//

import Foundation

/// Flag persistente en el App Group que marca "un intent background guardó datos".
/// Timestamp (no bool): la edad distingue una señal fresca de una huérfana de un proceso
/// que murió, y es un dato de diagnóstico útil (breadcrumb + telemetría por bucket).
/// `nonisolated` — se escribe desde el proceso del intent (no @MainActor).
enum PendingIntentSaveSignal {

    /// Marca que un intent background acaba de guardar. Llamar tras un `save()` exitoso.
    nonisolated static func mark(
        now: Date = .now,
        defaults: UserDefaults? = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    ) {
        defaults?.set(now.timeIntervalSince1970, forKey: AppPreferences.Keys.pendingIntentSaveAt)
    }

    /// Lee y limpia la señal (patrón `checkForPendingControlAction`: removeObject + synchronize
    /// inmediato para no reprocesar). Devuelve la fecha del último save si había señal, o `nil`
    /// si no la había (o el valor almacenado no era numérico — se limpia igual).
    nonisolated static func consume(
        defaults: UserDefaults? = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    ) -> Date? {
        guard let defaults else { return nil }
        // `object(forKey:)`, NO `double(forKey:)`: este último devuelve 0 y no distingue
        // "ausente" de "0" ni de un valor corrupto.
        let stored = defaults.object(forKey: AppPreferences.Keys.pendingIntentSaveAt)
        guard stored != nil else { return nil }
        defaults.removeObject(forKey: AppPreferences.Keys.pendingIntentSaveAt)
        defaults.synchronize()
        guard let raw = stored as? Double else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Bucket de edad para telemetría sin cardinalidad (evita mandar el timestamp crudo).
    nonisolated static func ageBucket(_ seconds: Double) -> String {
        switch seconds {
        case ..<10: return "<10s"
        case ..<300: return "10s-5m"
        default: return ">5m"
        }
    }
}
