//
//  GroupsIdentityPurgeIntent.swift
//  Yala
//
//  El intent DURABLE de «hay que purgar el dominio Grupos porque cambió el Apple ID del OS».
//
//  Por qué existe, y por qué NO basta con el flag en memoria que había antes
//  (`SplitSyncManager.deferredClearAllRequested`): esa purga se AUTO-DIFIERE en la ventana export-only
//  (`deferMainContextWork` — un `save()` sobre el `mainContext` compartido mientras el store personal se
//  importa a medias dispara el `_assertionFailure` interno de SwiftData, crash-loop en cada cold launch,
//  builds 29-32), y el único drenaje del flag vivía en `enableAutoSync()`. O sea: la purga solo ocurría si
//  el proceso sobrevivía hasta la promoción. Si el usuario —o iOS— mataba la app antes, la purga NO
//  ocurría JAMÁS, porque el evento de cuenta del OS llega UNA sola vez (guard de re-entrada en
//  `SplitSyncManager.identityCleanupInFlight`) y nadie lo re-entrega: no es un evento de CloudKit, que
//  CKSyncEngine sí re-entregaría desde su cola persistida. El humano NUEVO del dispositivo se quedaba con
//  los grupos del anterior y con sus credenciales de re-join intactas.
//
//  Patrón vigente del repo para esto, escrito en `.claude/rules/swiftdata-cloudkit.md`: «acción que
//  depende de estado que puede no haber llegado = intent PERSISTENTE reconciliable, nunca one-shot».
//  Molde `PendingJoinStore` (UserDefaults + `defaults` inyectable) y `GroupBatchLeaveStore`; el
//  reconciliador es el paso 16.4.4 de `AppBootstrapper`, que retoma tras la QUIESCENCIA del import
//  personal (`awaitPersonalStoreReady`) — el mismo gate que los otros ocho boot-saves.
//
//  **SIN TTL, a diferencia de `PendingJoinStore` (7 días), y es deliberado.** Aquel caduca porque una
//  unión que nadie reconcilió en una semana probablemente ya no interesa, y el coste de olvidarla es que
//  el usuario vuelva a tocar el enlace. Aquí caducar significa NO purgar: los datos del humano anterior se
//  quedan en el dispositivo del nuevo. La dirección segura es persistir hasta cumplirse — el intent solo
//  se desarma cuando la purga se completó de verdad (`save()` incluido).
//
//  `armedAt` es DIAGNÓSTICO (breadcrumb: cuántos arranques tardó en retomarse), nunca un criterio de
//  caducidad. Un `Date` suelto, no un JSON: una única purga pendiente por dispositivo — el evento es
//  global al dominio, no por zona, así que no hay nada que coleccionar.
//

import Foundation

@MainActor
enum GroupsIdentityPurgeIntent {

    static let userDefaultsKey = "yala.groups.pendingIdentityPurge"

    /// UserDefaults storage. `nonisolated(unsafe)` para permitir inyección en tests (molde
    /// `PendingJoinStore.defaults`): el host de los unit tests es la propia app, así que su
    /// `UserDefaults.standard` es el del simulador y un intent escrito ahí sobreviviría a la corrida.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    /// Marca que hay una purga de identidad PENDIENTE. Idempotente: re-armar sobre un intent ya armado
    /// CONSERVA el `armedAt` original — el dato interesante es desde cuándo se arrastra, no la última vez
    /// que se reintentó.
    static func arm(at now: Date = .now) {
        guard defaults.object(forKey: userDefaultsKey) == nil else { return }
        defaults.set(now.timeIntervalSince1970, forKey: userDefaultsKey)
    }

    static var isArmed: Bool {
        defaults.object(forKey: userDefaultsKey) != nil
    }

    /// Instante en que se armó, para el breadcrumb del retome. `nil` si no hay intent.
    static var armedAt: Date? {
        guard let raw = defaults.object(forKey: userDefaultsKey) as? Double else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Se llama SOLO cuando la purga se completó de verdad (filas aplicadas Y `save()` OK). Un `catch`,
    /// un contexto ausente o un diferido dejan el intent ARMADO a propósito.
    static func disarm() {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}
