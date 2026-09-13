//
//  SettlementReminderTracker.swift
//  Yala
//
//  «¿Ya avisé de esta deuda, y cuándo?» — el estado que hace falta para no repetir el recordatorio
//  de liquidación antes de tiempo. Molde de `BudgetAlertTracker`.
//
//  **Vive en `.standard`, igual que las otras dos familias de keys del dominio de Grupos**
//  (`GroupNotifications.lastNotified.*` y `groupPrefs_*`), y esa alineación es funcional, no estética:
//  quien las barre es `DataWipeService.removeGroupsDomainPreferenceKeys`, cuyo `defaults` **es
//  `.standard` por defecto y su único call-site no lo pasa**. Un tracker en otro dominio quedaría
//  fuera de ese barrido.
//
//  El aislamiento entre personas no se pierde por compartir dominio: la key lleva dentro el `Debt.id`
//  (`deudor-acreedor-divisa`) y `dueReminders` solo mira deudas cuyo deudor soy yo, así que los
//  conjuntos de keys de dos humanos distintos son **disjuntos por construcción** — ni se pisan ni se
//  silencian. Es lo que hace que el dominio compartido sea inocuo AQUÍ, y no una regla general.
//
//  **NO se persiste el importe de la deuda, y conviene saber qué cubre eso y qué no.** Un gasto o una
//  liquidación NUEVOS entre las dos personas sí mueven la última actividad del par y vuelven a callar
//  el aviso por antigüedad. Lo que NO se detecta es la EDICIÓN de un gasto viejo: `SplitExpense` no
//  tiene `updatedAt` y la actividad se mide con `createdAt`, así que corregir hoy el importe de un
//  gasto de hace dos meses cambia la deuda sin resetear el reloj. El aviso sale con el importe nuevo
//  —correcto— pero con el marco «lleva semanas sin moverse», que en ese caso no lo está. Cerrarlo
//  exige un campo de fecha nuevo en el modelo: ticket `groups-settlement-reminder-stale-clock`.
//

import Foundation

@MainActor
final class SettlementReminderTracker {

    static let shared = SettlementReminderTracker()

    /// Prefijo de las keys de dedup. Expuesto porque `DataWipeService` las barre POR PREFIJO:
    /// llevan el `Debt.id` dentro (dos member UUID + la divisa), así que ninguna lista explícita
    /// puede nombrarlas.
    static let keyPrefix = "GroupSettlementReminders.lastNotified."

    private let defaults: UserDefaults

    private init() {
        self.defaults = .standard
    }

    /// Init de test — `UserDefaults` aislado (`makeIsolatedDefaults()`); jamás en producción.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Lectura

    private func key(forDebtID debtID: String) -> String {
        Self.keyPrefix + debtID
    }

    /// Cuándo se avisó por última vez de cada una de estas deudas. Las que nunca se avisaron no
    /// aparecen en el mapa — es justo la forma que `SettlementReminderLogic.dueReminders` espera.
    func lastNotified(forDebtIDs debtIDs: [String]) -> [String: Date] {
        var result: [String: Date] = [:]
        for debtID in debtIDs {
            let timestamp = defaults.double(forKey: key(forDebtID: debtID))
            guard timestamp > 0 else { continue }
            result[debtID] = Date(timeIntervalSince1970: timestamp)
        }
        return result
    }

    // MARK: - Escritura

    /// Marca la deuda como avisada. **Solo debe llamarse con entrega confirmada por iOS**
    /// (`NotificationService.sendNotification -> Bool`): marcar tras un `false` quema la semana de
    /// supresión sin que el usuario haya visto nada — el bug que el docblock de `sendNotification`
    /// nombra y que `BudgetAlertService.notifyCrossedThresholds` ya evita.
    func markNotified(debtID: String, at date: Date = .now) {
        defaults.set(date.timeIntervalSince1970, forKey: key(forDebtID: debtID))
    }

    // MARK: - Limpieza

    /// Suelta las entradas que ya no pueden suprimir nada (más viejas que 3 rate-limits).
    ///
    /// Sin esto, una deuda saldada hace un año deja su key en el dominio para siempre: inerte, pero
    /// acumulable — un grupo con mucha rotación las cuenta por decenas.
    func cleanupOldEntries(now: Date = .now, olderThan: TimeInterval = 3 * SettlementReminderLogic.defaultRateLimit) {
        let cutoff = now.addingTimeInterval(-olderThan).timeIntervalSince1970
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) {
            let timestamp = defaults.double(forKey: key)
            // `0` es «no es un número» o una key corrupta: se va igual, no suprime nada.
            if timestamp < cutoff {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
