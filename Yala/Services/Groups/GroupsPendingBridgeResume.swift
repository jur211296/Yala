//
//  GroupsPendingBridgeResume.swift
//  Yala
//
//  El RETOME del intent durable del bridge remoto (`GroupsPendingBridgeIntent`): lo que el arranque hace
//  con los gastos y liquidaciones que bajaron por sync —por CUALQUIERA de los dos canales— y cuyo bridge
//  no llegó a ocurrir.
//
//  **Por qué vive aquí y no dentro de `SplitSyncManager`, que es de donde salió.** Ese fichero es uno de
//  los 13 que el commit 1 de la Fase 3 borra ENTEROS (`MODO-NUBE-FASE3-BRIEF.md`). Con el retome dentro,
//  la Fase 3 dejaría el intent ARMÁNDOSE por el canal backend y a NADIE drenándolo: el patrón exacto de
//  `quotaFailedRecordIDs` —una intención sin drenador, ya declarada como bug aparte—, y peor que no tener
//  intent, porque habría IDs acumulándose en `UserDefaults` sin salida. Mismo trabajo y misma razón que el
//  commit 0 de la Fase 3 (`bc486c92`), que sacó `BootSaveGateLogic` y `zonePrefix` de ficheros condenados.
//  Un bloqueante anotado hay que recordarlo; un fichero movido, no.
//
//  **No importa CloudKit** a propósito: el criterio de salida de la Fase 3 es un grep de ese import sobre
//  `Yala/Services/Groups/` y `Yala/App/Views/Groups/` que tiene que dar CERO, y este retome no necesita
//  nada del transporte — solo el store, el bridge y el intent. La frase de arriba evita escribir la cadena
//  literal que ese grep busca: como este fichero SOBREVIVE al borrado, citarla lo convertiría en un falso
//  positivo permanente y el criterio no podría cumplirse nunca.
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum GroupsPendingBridgeResume {

    /// Categoría `SplitSync` **a propósito, aunque el fichero ya no sea `SplitSyncManager`**: el logging de
    /// este subsistema vive fuera de `#if DEBUG` por una excepción consciente —el bug solo reproduce en
    /// CloudKit Production, verificable únicamente vía TestFlight Release en Console.app— y el operador
    /// filtra por esta categoría. Mudarse de fichero no puede cambiar dónde aparecen los únicos tres logs
    /// que explican un bridge perdido. Renombrarla es trabajo de la Fase 3, cuando `SplitSync` deje de
    /// existir como concepto.
    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    /// Retome del intent DURABLE del bridge remoto, llamado desde `AppBootstrapper.retryPendingBridges` en
    /// cada arranque. No-op si no hay nada pendiente — el caso del 99,9 % de los boots.
    ///
    /// **El caller DEBE haber probado la quiescencia del store personal** (`awaitPersonalStoreReady()`) y el
    /// gate de dominio: los dos `bridgeRemote*` terminan en un `save()` incondicional del `mainContext`
    /// compartido. Por eso este camino NO pasa por `deferMainContextWork` — mismo razonamiento que el
    /// retome de la purga de identidad: `autoSyncActive` es un PROXY que puede encenderse por hard-cap,
    /// mientras `BootSaveGateLogic.decide` es la prueba directa y nunca fuerza.
    ///
    /// Vive DENTRO de `retryPendingBridges` y no en un `Task` propio del bootstrapper a propósito: los ~11
    /// Tasks de boot se encolan en orden pero todos suspenden en el mismo gate y cada uno resuelve por su
    /// cuenta, así que un Task hermano podría correr DESPUÉS del drenaje del Caso A y retrasar el bridge un
    /// arranque entero. Dentro de la función el orden es orden de programa.
    ///
    /// - Parameter onBridged: los IDs realmente puenteados, para que el camino rápido en memoria de la
    ///   sesión (`SplitSyncManager.pendingBridge*IDs`) no repita el trabajo. Es un callback y no una
    ///   dependencia porque esos Sets mueren con el transporte CloudKit en la Fase 3: entonces se borra el
    ///   argumento del call-site y este fichero no se toca.
    static func resumeIfNeeded(
        context: ModelContext,
        onBridged: (_ expenseIDs: Set<UUID>, _ settlementIDs: Set<UUID>) -> Void = { _, _ in }
    ) {
        let pending = GroupsPendingBridgeIntent.pending
        guard !pending.isEmpty else { return }
        // Sin contexto en el bridge no se puede intentar nada, y un intento imposible no puede consumir
        // presupuesto: se deja la intención intacta para el próximo arranque.
        guard GroupTransactionBridge.shared.isReady else { return }

        let pendingHours = GroupsPendingBridgeIntent.armedAt
            .map { Int(Date.now.timeIntervalSince($0) / 3600) } ?? 0
        GroupsSyncBreadcrumb.groupsPendingBridgeResumed(
            expenses: pending.expenseIDs.count,
            settlements: pending.settlementIDs.count,
            pendingHours: max(0, pendingHours))

        var expenses = Buckets()
        var settlements = Buckets()
        do {
            let backendZones = backendGroupZoneNames(context: context)
            let knownZones = Set(try context.fetch(FetchDescriptor<SplitGroup>()).map(\.cloudKitZoneID))
            let expenseZones = Dictionary(
                try context.fetch(FetchDescriptor<SplitExpense>())
                    .filter { pending.expenseIDs.contains($0.id) }
                    .map { ($0.id, $0.groupZoneID) },
                uniquingKeysWith: { first, _ in first })
            let settlementZones = Dictionary(
                try context.fetch(FetchDescriptor<SplitSettlement>())
                    .filter { pending.settlementIDs.contains($0.id) }
                    .map { ($0.id, $0.groupZoneID) },
                uniquingKeysWith: { first, _ in first })
            expenses = classify(
                pending.expenseIDs, zones: expenseZones, backendZones: backendZones,
                knownZones: knownZones, armedByBackend: pending.backendExpenseIDs)
            settlements = classify(
                pending.settlementIDs, zones: settlementZones, backendZones: backendZones,
                knownZones: knownZones, armedByBackend: pending.backendSettlementIDs)
        } catch {
            // Sin clasificación no se intenta nada: cobrar intentos a ciegas descartaría trabajo válido.
            logger.error("resumePendingRemoteBridge: classification failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        var bridgedExpenses: Set<UUID> = []
        var bridgedSettlements: Set<UUID> = []
        if !expenses.attemptable.isEmpty {
            do { bridgedExpenses = try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: Array(expenses.attemptable)) }
            catch {
                logger.error("resumePendingRemoteBridge: expenses failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if !settlements.attemptable.isEmpty {
            do { bridgedSettlements = try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: Array(settlements.attemptable)) }
            catch {
                logger.error("resumePendingRemoteBridge: settlements failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        GroupsPendingBridgeIntent.confirm(
            expenseIDs: bridgedExpenses.union(expenses.abandoned),
            settlementIDs: bridgedSettlements.union(settlements.abandoned))

        // Solo lo que se INTENTÓ y no se cumplió consume presupuesto. Sin tope, un ID envenenado —un bridge
        // que falla siempre— haría trabajo y un `save()` en cada arranque para siempre; con él converge en
        // tres, el mismo criterio que `bridgeAttempts` en el Caso A.
        let dropped = GroupsPendingBridgeIntent.noteFailedAttempt(
            expenseIDs: expenses.attemptable.subtracting(bridgedExpenses),
            settlementIDs: settlements.attemptable.subtracting(bridgedSettlements))
        if dropped.expenses + dropped.settlements > 0 {
            GroupsSyncBreadcrumb.groupsPendingBridgeDropped(
                expenses: dropped.expenses, settlements: dropped.settlements)
        }

        onBridged(bridgedExpenses, bridgedSettlements)
        if !bridgedExpenses.isEmpty || !bridgedSettlements.isEmpty {
            SessionState.shared.markRemoteChangePending()
        }
    }

    // MARK: - Clasificación

    /// Los tres destinos de un ID pendiente en el retome. `waiting` no aparece en ninguna operación sobre el
    /// intent a propósito: ni se cumple ni se cobra — se queda tal cual para el arranque siguiente.
    struct Buckets: Equatable {
        var abandoned: Set<UUID> = []
        var waiting: Set<UUID> = []
        var attemptable: Set<UUID> = []
    }

    /// Clasificación previa, en tres cubos. La hace el retome y no el camino en sesión porque el retome
    /// CRUZA ARRANQUES: entre armar y llegar aquí, el mundo pudo cambiar de tres formas distintas.
    ///
    ///  · ABANDONADO — la fila ya no existe (una purga se la llevó), o —**solo para lo que armó el canal
    ///    CloudKit**— su grupo volteó al canal backend (`applyGroupMeta` / `GroupBackendMembershipService`).
    ///    El guard G6-3 filtró por zona en el instante del fetch; aquí hay que volver a preguntarlo, porque
    ///    puentear filas de origen CloudKit de un grupo cuya verdad ya vive en el backend es lo que ese
    ///    guard existe para impedir. Ninguno de los dos es reintentable ⇒ se retiran del intent SIN consumir
    ///    presupuesto ni emitir el canario de descarte: no son un fallo del bridge.
    ///  · ESPERANDO — la fila está pero su `SplitGroup` todavía no ha bajado (el GroupMeta viaja en otro
    ///    batch/página). El Caso A trata este caso igual: `retryPendingBridges` hace `continue` ANTES de
    ///    incrementar `bridgeAttempts`. Cobrarlo aquí descartaría a los 3 arranques un gasto que solo
    ///    esperaba a su grupo.
    ///  · INTENTABLE — el resto.
    ///
    /// **`armedByBackend` es lo que impide que el canal nuevo se descarte entero.** Para un ID que armó
    /// `GroupsSyncClient`, «su zona es del backend» no es una anomalía sobrevenida: es su estado NORMAL
    /// —`applyGroupMeta` enciende `isBackendGroup` en todo grupo que baja por el pull— así que sin esta
    /// distinción el retome mandaría al cubo *abandonado* cada gasto del canal que el paso 2 del encendido
    /// enciende, y el intent quedaría armándose sin cumplirse nunca.
    ///
    /// `zones` mapea ID → zona SOLO para las filas que existen; un ID ausente del mapa es una fila que ya
    /// no está y por tanto no hay nada que puentear.
    static func classify(
        _ ids: Set<UUID>, zones: [UUID: String], backendZones: Set<String>, knownZones: Set<String>,
        armedByBackend: Set<UUID>
    ) -> Buckets {
        var buckets = Buckets()
        for id in ids {
            guard let zone = zones[id] else { buckets.abandoned.insert(id); continue }
            if backendZones.contains(zone), !armedByBackend.contains(id) { buckets.abandoned.insert(id) }
            else if !knownZones.contains(zone) { buckets.waiting.insert(id) }
            else { buckets.attemptable.insert(id) }
        }
        return buckets
    }

    /// Zonas cuyo grupo ya enruta por el canal backend. Copia local de `SplitSyncManager.backendGroupZoneNames`
    /// a propósito: aquélla se va con el transporte en la Fase 3 y este retome tiene que sobrevivirla.
    private static func backendGroupZoneNames(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.isBackendGroup == true })
        do {
            return Set(try context.fetch(descriptor).map(\.cloudKitZoneID))
        } catch {
            #if DEBUG
            logger.error("backendGroupZoneNames fetch failed: \(error.localizedDescription, privacy: .public)")
            #endif
            return []
        }
    }
}
