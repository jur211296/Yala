//
//  GroupsPendingBridgeIntent.swift
//  Yala
//
//  El intent DURABLE de «estos gastos y liquidaciones que bajaron por sync remoto todavía no tienen su
//  `TransactionItem`/`InboxDraft` personal».
//
//  Por qué existe, y por qué NO basta con los dos `Set<UUID>` en memoria que había antes
//  (`SplitSyncManager.pendingBridgeExpenseIDs`/`pendingBridgeSettlementIDs`): esos IDs se acumulan DESPUÉS
//  de aplicar el changeSet y de salvarlo, así que cuando el handler del fetch retorna el record ya está
//  local y el change token de CKSyncEngine YA AVANZÓ ⇒ CloudKit no lo re-entrega nunca; solo volvería con
//  una edición remota NUEVA del mismo record. Perder la intención en ese punto es definitivo: el gasto de
//  grupo se queda sin su transacción personal — invisible en Panel, en Inbox y en los presupuestos — para
//  siempre. La regla del repo afirmaba lo contrario («CKSyncEngine re-entrega después») y era falso;
//  corregido y medido el 2026-07-30.
//
//  **Y no hace falta que muera el proceso.** El drenaje en memoria era un _disarm-then-attempt_ (limpiaba
//  los Sets ANTES de llamar al bridge), y `GroupTransactionBridge.bridgeRemoteExpenses` tiene cuatro
//  superficies de throw —contexto ausente, el fetch de gastos, el fetch del grupo (fuera de su `do`) y el
//  `save()` final— más un `catch` por gasto que se traga el fallo individual. Cualquiera de ellas perdía el
//  lote con la app viva y sin un solo log en release. De ahí las dos mitades de este intent: se ARMA en el
//  mismo sitio donde se acumulan los IDs y solo se CONFIRMA por los IDs que el bridge devuelve como
//  puenteados de verdad.
//
//  **Por qué UserDefaults y no una fila.** Marcar `SplitExpense.bridgePending` —el mecanismo del Caso A
//  (user-action)— exige un `save()` sobre el `mainContext` COMPARTIDO, que es exactamente lo que la ventana
//  del import personal prohíbe: con el store personal a medio importar, ese save dispara el
//  `_assertionFailure` interno de SwiftData (`EXC_BREAKPOINT`, no atrapable, crash-loop en cada cold launch;
//  builds 29-32). La intención tiene que vivir FUERA de SwiftData, y el molde ya está estrenado en
//  `GroupsIdentityPurgeIntent`. El Caso A conserva su flag: aquel nace de una acción del usuario que ya
//  salvó el contexto, este de un evento remoto en una ventana donde salvar es lo que no se puede hacer.
//
//  **SIN TTL**, por la misma razón que el intent de la purga: caducar aquí significa no puentear, o sea
//  perder el gasto. La dirección segura es persistir hasta cumplirse.
//
//  **CON tope de intentos**, al revés que aquel, y también por su consecuencia: un ID envenenado (una fila
//  que ya no existe, un bridge que falla siempre) haría trabajo y un `save()` en CADA arranque para siempre.
//  El criterio es el mismo del Caso A (`SplitExpense.bridgeAttempts`, 3 intentos en `retryPendingBridges`):
//  a los 3 el ID se descarta con un breadcrumb que lo nombra. La diferencia con el TTL importa —el tope
//  cuenta INTENTOS reales, no tiempo: un intent que nunca llegó a intentarse (arranques sin quiescencia)
//  no consume ninguno.
//

import Foundation

/// Payload persistido: UUID (string) → intentos de bridge ya consumidos por ese ID. Un diccionario y no un
/// `Set` porque el tope de arriba es por ID, no por lote: un gasto envenenado no puede arrastrar consigo a
/// los que llegaron en el mismo batch y sí se pueden puentear.
private struct StoredPendingBridge: Codable {
    var expenses: [String: Int]
    var settlements: [String: Int]
    /// DIAGNÓSTICO (breadcrumb: cuántas horas se arrastró la intención), jamás un criterio de caducidad.
    var armedAt: Date

    var isEmpty: Bool { expenses.isEmpty && settlements.isEmpty }
}

@MainActor
enum GroupsPendingBridgeIntent {

    static let userDefaultsKey = "yala.groups.pendingRemoteBridge"

    /// Intentos por ID antes de descartarlo. Mismo número y mismo criterio que el `maxAttempts` del Caso A
    /// en `AppBootstrapper.retryPendingBridges`.
    static let maxAttempts = 3

    /// UserDefaults storage. `nonisolated(unsafe)` para permitir inyección en tests (molde
    /// `PendingJoinStore.defaults` / `GroupsIdentityPurgeIntent.defaults`): el host de los unit tests es la
    /// propia app, así que su `UserDefaults.standard` es el del simulador y un intent escrito ahí
    /// sobreviviría a la corrida.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    struct Pending: Equatable {
        var expenseIDs: Set<UUID> = []
        var settlementIDs: Set<UUID> = []

        var isEmpty: Bool { expenseIDs.isEmpty && settlementIDs.isEmpty }
    }

    // MARK: - API

    /// Anota que estos IDs necesitan bridge. Idempotente y acumulativo: re-armar sobre un intent vivo
    /// AÑADE los nuevos, CONSERVA los intentos ya consumidos por los viejos y CONSERVA el `armedAt`
    /// original — el dato accionable es desde cuándo se arrastra la intención más vieja.
    static func arm(expenseIDs: Set<UUID>, settlementIDs: Set<UUID>, at now: Date = .now) {
        guard !expenseIDs.isEmpty || !settlementIDs.isEmpty else { return }
        var stored = load() ?? StoredPendingBridge(expenses: [:], settlements: [:], armedAt: now)
        for id in expenseIDs where stored.expenses[id.uuidString] == nil {
            stored.expenses[id.uuidString] = 0
        }
        for id in settlementIDs where stored.settlements[id.uuidString] == nil {
            stored.settlements[id.uuidString] = 0
        }
        persist(stored)
    }

    static var pending: Pending {
        guard let stored = load() else { return Pending() }
        return Pending(
            expenseIDs: Set(stored.expenses.keys.compactMap(UUID.init(uuidString:))),
            settlementIDs: Set(stored.settlements.keys.compactMap(UUID.init(uuidString:)))
        )
    }

    static var isArmed: Bool { load()?.isEmpty == false }

    /// Instante en que se armó la intención más vieja que sigue viva, para el breadcrumb del retome.
    static var armedAt: Date? { load()?.armedAt }

    /// Se llama SOLO con los IDs que el bridge devolvió como puenteados DE VERDAD (fila encontrada, grupo
    /// resuelto y `bridgeExpense`/`bridgeSettlement` sin lanzar). Un ID que el `catch` por-fila del bridge
    /// se tragó NO entra aquí a propósito: ese es justo el fallo pequeño que el intent existe para no
    /// perder. Cuando ya no queda nada pendiente la key se borra entera, así que el `armedAt` del próximo
    /// ciclo vuelve a empezar de cero.
    static func confirm(expenseIDs: Set<UUID>, settlementIDs: Set<UUID>) {
        guard var stored = load() else { return }
        for id in expenseIDs { stored.expenses.removeValue(forKey: id.uuidString) }
        for id in settlementIDs { stored.settlements.removeValue(forKey: id.uuidString) }
        persist(stored)
    }

    /// Consume UN intento de los IDs que siguen pendientes tras una pasada del retome, y descarta los que
    /// alcanzan `maxAttempts`. Devuelve cuántos se descartaron, para el breadcrumb (sin PII: son counts).
    ///
    /// Solo lo llama el retome del boot, NO el camino en sesión: en sesión el retry ya reintenta solo y
    /// contar sus pasadas gastaría el presupuesto de un ID que aún puede resolverse en el mismo arranque.
    @discardableResult
    static func noteFailedAttempt(expenseIDs: Set<UUID>, settlementIDs: Set<UUID>) -> (expenses: Int, settlements: Int) {
        guard var stored = load() else { return (0, 0) }
        var droppedExpenses = 0
        var droppedSettlements = 0

        for id in expenseIDs {
            let key = id.uuidString
            guard let attempts = stored.expenses[key] else { continue }
            if attempts + 1 >= maxAttempts {
                stored.expenses.removeValue(forKey: key)
                droppedExpenses += 1
            } else {
                stored.expenses[key] = attempts + 1
            }
        }
        for id in settlementIDs {
            let key = id.uuidString
            guard let attempts = stored.settlements[key] else { continue }
            if attempts + 1 >= maxAttempts {
                stored.settlements.removeValue(forKey: key)
                droppedSettlements += 1
            } else {
                stored.settlements[key] = attempts + 1
            }
        }

        persist(stored)
        return (droppedExpenses, droppedSettlements)
    }

    /// Wipe total. Dos caminos, los dos de FRONTERA: la purga por cambio de Apple ID (las filas a las que
    /// apuntaba se van con ella) y el «empiezo de cero» del Welcome (arrastrar la intención del humano
    /// anterior al dispositivo del nuevo no tiene ningún sentido). Nunca en un camino normal.
    static func clearAll() {
        defaults.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Persistencia

    private static func load() -> StoredPendingBridge? {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(StoredPendingBridge.self, from: data)
        } catch {
            // Payload ilegible (formato viejo, escritura truncada). Se descarta: mantenerlo dejaría el
            // retome ciego para siempre sin forma de repararse.
            #if DEBUG
            print("GroupsPendingBridgeIntent: Error decoding: \(error)")
            #endif
            defaults.removeObject(forKey: userDefaultsKey)
            return nil
        }
    }

    private static func persist(_ stored: StoredPendingBridge) {
        guard !stored.isEmpty else {
            defaults.removeObject(forKey: userDefaultsKey)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            defaults.set(try encoder.encode(stored), forKey: userDefaultsKey)
        } catch {
            #if DEBUG
            print("GroupsPendingBridgeIntent: Error encoding: \(error)")
            #endif
        }
    }
}
