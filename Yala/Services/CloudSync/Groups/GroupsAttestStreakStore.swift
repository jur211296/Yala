//
//  GroupsAttestStreakStore.swift
//  Yala
//
//  Dónde vive, entre arranques, la racha de rechazos de App Attest del TELÉFONO. Nació con el canal de Grupos, y desde el
//  2026-09-15 la escribe también el motor personal. La decisión es de `GroupsAttestVerdictLogic`; aquí solo se lee, se
//  escribe y se avisa una vez.
//
//  POR QUÉ `UserDefaults.standard` Y FUERA DE LOS BARRIDOS. La racha describe al TELÉFONO, no a la persona: App Attest va
//  con la instalación y su key, no con la cuenta. Por eso no está en `DataWipeService.removeUserPreferenceKeys` —cerrar
//  sesión no arregla el attest— ni en `PrefSyncKey`, que llevaría a otro dispositivo un hecho de éste
//  (`swiftdata-cloudkit.md`, «pregunta DE QUIÉN es el hecho»). Una racha heredada tampoco bloquea nada por sí sola: el
//  cierre exige además un rechazo del ciclo que lee, y el primer 200 la borra.
//
//  QUIÉN ESCRIBE. Los dos clientes de Grupos, en el borde donde leen la respuesta: `GroupsSyncClient` (push y pull) y
//  `GroupsMembershipClient.call` (RPC), con el 401 `yala_attest_required` como rechazo y un 200 como acierto. Y desde el
//  2026-09-15 la puerta de attest del motor personal (`CloudSyncRuntime.resolveAttest`): nunca manda una subida sin attest,
//  así que cuenta el error con el que no consiguió el token (`AttestSyncGate.countsTowardAttestStreak`) y toma como acierto
//  un token conseguido (ticket `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`). **El 401
//  `yala_attest_required` de las rutas personales NO escribe** (2026-09-16): llega después de esa puerta, con un token que
//  el teléfono sí acuñó, así que no habla del teléfono (ticket `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`).
//  **Una sola racha
//  para los dos canales, a propósito**: describe al teléfono, y con dos un cierre en la nube podía aceptar perder lo
//  personal y quedarse en «inténtalo en un rato» con los cambios de grupos. Sin inyección por construcción, a propósito:
//  la membresía tiene ocho, y quien la construya de nuevo apunta sin tener que acordarse. Los tests aíslan `defaults`,
//  como en `PendingJoinStore`.
//
//  QUIÉN ESCUCHA. Desde el 2026-09-15 el store emite `didChangeNotification` cada vez que la racha cambia en disco,
//  porque el veredicto dejó de leerse solo dentro de un gesto: la pestaña Grupos lo pinta FIJO y una vista no se
//  entera de una escritura en `UserDefaults` (`GroupsAttestTabNoticeLogic`).
//

import Foundation

@MainActor
enum GroupsAttestStreakStore {

    /// Almacén de la racha. `nonisolated(unsafe)` para poder inyectar una suite en tests (molde `PendingJoinStore`).
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static let key = "groupsSync.attestRejectionStreak"

    /// **Se emite cuando la racha CAMBIA en disco**, y solo entonces: al escribir un rechazo que cuenta y al
    /// borrarla con un acierto. Un rechazo que no suma (misma hora) no la emite, porque nada cambió.
    ///
    /// POR QUÉ EXISTE (2026-09-15, ticket `groups-tab-does-not-say-this-phone-cannot-sync-groups`). El veredicto
    /// pasó de leerse solo dentro de un gesto —donde el propio gesto lo pregunta— a pintarse FIJO en la pestaña
    /// Grupos. Una vista no puede enterarse de una escritura en `UserDefaults`: **medido el 2026-09-15**, con la
    /// racha ausente al arrancar y escrita un segundo después, la pestaña se quedaba muda hasta que la persona
    /// salía y volvía. Y eso es justo lo que pasa en producción, donde el 401 llega con el tab delante.
    ///
    /// Avisa el ESCRITOR y no sondea el lector: es el único sitio que sabe que el hecho cambió, y así vale para
    /// los tres canales que lo escriben (push, pull y RPC de Grupos, más la puerta del motor personal).
    static let didChangeNotification = Notification.Name("GroupsAttestStreakStore.didChange")

    /// La racha guardada, o `nil` si no hay ninguna o no se puede leer. **Solo lee**: un valor ilegible lo sobrescribe
    /// el siguiente rechazo, y hasta entonces cuenta como «sin racha», que nunca ofrece perder nada.
    static func current() -> GroupsAttestVerdictLogic.Streak? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(GroupsAttestVerdictLogic.Streak.self, from: data)
        } catch {
            #if DEBUG
            print("GroupsAttestStreakStore: Error: \(error)")
            #endif
            return nil
        }
    }

    /// ¿Este teléfono ya no puede sincronizar grupos?
    static func isTerminal(now: Date = .now) -> Bool {
        GroupsAttestVerdictLogic.isTerminal(current(), now: now)
    }

    /// Un rechazo del attest: el servidor respondió 401 `yala_attest_required` a una ruta de Grupos, o la puerta del motor
    /// personal no consiguió el token por algo que habla del attest. La primera vez que la racha se lee terminal deja rastro
    /// y cuenta el teléfono en el canario, una sola vez por racha.
    static func recordRejection(now: Date = .now) {
        let previous = current()
        var next = GroupsAttestVerdictLogic.recordingRejection(after: previous, now: now)
        let reports = GroupsAttestVerdictLogic.shouldReportTerminal(next, now: now)
        if reports { next.terminalReported = true }
        // Un rechazo de la misma hora que no avisa no cambia nada: no se escribe. Un loop en backoff reintenta cada pocos
        // minutos, y cada escritura sería trabajo sin información.
        guard next != previous else { return }
        guard write(next) else { return }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        guard reports else { return }
        let hours = Int(now.timeIntervalSince(next.firstRejectedAt) / 3600)
        GroupsSyncBreadcrumb.groupsAttestTerminal(rejections: next.rejections, hours: hours)
        MetricsService.canary(.groupsAttestTerminal, detail: "rejections=\(next.rejections) hours=\(hours)")
    }

    /// Un acierto del attest —una ruta de Grupos respondió 200, o la puerta del motor personal consiguió un token— y la
    /// racha se acaba. Si ya era terminal, deja rastro de que el teléfono se recuperó solo.
    static func recordAcceptance() {
        guard defaults.object(forKey: key) != nil else { return }
        let ended = current()
        defaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        if let ended, ended.terminalReported {
            GroupsSyncBreadcrumb.groupsAttestRecovered(rejections: ended.rejections)
        }
    }

    private static func write(_ streak: GroupsAttestVerdictLogic.Streak) -> Bool {
        do {
            defaults.set(try JSONEncoder().encode(streak), forKey: key)
            return true
        } catch {
            #if DEBUG
            print("GroupsAttestStreakStore: Error: \(error)")
            #endif
            return false
        }
    }
}
