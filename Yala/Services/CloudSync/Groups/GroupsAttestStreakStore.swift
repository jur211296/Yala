//
//  GroupsAttestStreakStore.swift
//  Yala
//
//  Dónde vive, entre arranques, la racha de rechazos de App Attest del canal de Grupos. La decisión es de
//  `GroupsAttestVerdictLogic`; aquí solo se lee, se escribe y se avisa una vez.
//
//  POR QUÉ `UserDefaults.standard` Y FUERA DE LOS BARRIDOS. La racha describe al TELÉFONO, no a la persona: App Attest va
//  con la instalación y su key, no con la cuenta. Por eso no está en `DataWipeService.removeUserPreferenceKeys` —cerrar
//  sesión no arregla el attest— ni en `PrefSyncKey`, que llevaría a otro dispositivo un hecho de éste
//  (`swiftdata-cloudkit.md`, «pregunta DE QUIÉN es el hecho»). Una racha heredada tampoco bloquea nada por sí sola: el
//  cierre exige además un rechazo del ciclo que lee, y el primer 200 la borra.
//
//  QUIÉN ESCRIBE. Los dos clientes de Grupos, en el borde donde leen la respuesta: `GroupsSyncClient` (push y pull) y
//  `GroupsMembershipClient.call` (RPC). Sin inyección por construcción, a propósito: la membresía tiene ocho, y quien la
//  construya de nuevo apunta sin tener que acordarse. Los tests aíslan `defaults`, como en `PendingJoinStore`.
//

import Foundation

@MainActor
enum GroupsAttestStreakStore {

    /// Almacén de la racha. `nonisolated(unsafe)` para poder inyectar una suite en tests (molde `PendingJoinStore`).
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static let key = "groupsSync.attestRejectionStreak"

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

    /// El servidor respondió 401 `yala_attest_required` a una ruta de Grupos. La primera vez que la racha se lee
    /// terminal deja rastro y cuenta el teléfono en el canario, una sola vez por racha.
    static func recordRejection(now: Date = .now) {
        let previous = current()
        var next = GroupsAttestVerdictLogic.recordingRejection(after: previous, now: now)
        let reports = GroupsAttestVerdictLogic.shouldReportTerminal(next, now: now)
        if reports { next.terminalReported = true }
        // Un rechazo de la misma hora que no avisa no cambia nada: no se escribe. Un loop en backoff reintenta cada pocos
        // minutos, y cada escritura sería trabajo sin información.
        guard next != previous else { return }
        guard write(next), reports else { return }
        let hours = Int(now.timeIntervalSince(next.firstRejectedAt) / 3600)
        GroupsSyncBreadcrumb.groupsAttestTerminal(rejections: next.rejections, hours: hours)
        MetricsService.canary(.groupsAttestTerminal, detail: "rejections=\(next.rejections) hours=\(hours)")
    }

    /// Una ruta de Grupos respondió 200: el attest pasó la guard y la racha se acaba. Si ya era terminal, deja rastro de
    /// que el teléfono se recuperó solo.
    static func recordAcceptance() {
        guard defaults.object(forKey: key) != nil else { return }
        let ended = current()
        defaults.removeObject(forKey: key)
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
