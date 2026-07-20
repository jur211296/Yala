//
//  GroupBatchLeaveStore.swift
//  Yala
//
//  Intent PERSISTENTE del batch "salir de todos mis grupos" (D10). Molde de `PendingJoinStore` (enum
//  estático + `UserDefaults` JSON keyed por `groupZoneID`), con dos diferencias deliberadas:
//    - SIN cap de entries: `PendingJoinStore.maxEntries = 8` evicta la más vieja, pero un usuario con >8
//      grupos perdería silenciosamente parte del batch. Aquí el set es el nº de grupos del usuario.
//    - TTL FASE-AWARE: nunca se purga una entry `.inProgress` (una op mutante pudo salir server-side; el
//      resume debe completarla). Solo se purgan las `.pending` vencidas (con canario) y las terminales.
//
//  Kill-safe: `GroupBatchLeaveOrchestrator` graba la transición de fase ANTES de la red que la avanza
//  (write-ahead) y reanuda desde la fase grabada en boot/foreground.
//

import Foundation

/// Una entry del batch: un grupo a procesar, con su clasificación congelada y su fase actual.
struct BatchLeaveEntry: Codable, Equatable {
    let groupZoneID: String
    /// Nombre del grupo capturado al armar (para el resultado / la lista "necesitan tu decisión" sin
    /// re-fetchear un grupo ya borrado localmente).
    let groupName: String
    var phase: GroupBatchLeaveLogic.Phase
    /// Clasificación CONGELADA al armar. En resume, las `.inProgress` re-ejecutan ESTA acción (no
    /// re-clasifican); las `.pending` sí se re-clasifican con facts frescos.
    var plannedAction: GroupBatchLeaveLogic.Action
    /// Motivo cuando `phase == .needsDecision` (copy honesto + telemetría).
    var needsDecisionReason: GroupBatchLeaveLogic.NeedsDecisionReason?
    /// `member_key` del heredero (informativo, del resultado del transfer; el server es la autoridad).
    var heirMemberKey: String?
    let createdAt: Date
    var lastError: String?

    init(
        groupZoneID: String,
        groupName: String,
        phase: GroupBatchLeaveLogic.Phase = .pending,
        plannedAction: GroupBatchLeaveLogic.Action,
        needsDecisionReason: GroupBatchLeaveLogic.NeedsDecisionReason? = nil,
        heirMemberKey: String? = nil,
        createdAt: Date = .now,
        lastError: String? = nil
    ) {
        self.groupZoneID = groupZoneID
        self.groupName = groupName
        self.phase = phase
        self.plannedAction = plannedAction
        self.needsDecisionReason = needsDecisionReason
        self.heirMemberKey = heirMemberKey
        self.createdAt = createdAt
        self.lastError = lastError
    }
}

@MainActor
enum GroupBatchLeaveStore {
    static let userDefaultsKey = "yala.groups.pendingBatchLeave"

    /// TTL por entry (7 días, mismo escenario que `PendingJoinStore`: la app se reabre días después). Fase-aware.
    static let ttl: TimeInterval = 7 * 24 * 60 * 60

    /// UserDefaults storage. `nonisolated(unsafe)` para inyección en tests (molde `PendingJoinStore`).
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    // MARK: - API

    /// Reemplaza TODO el batch (nueva corrida desde la UI): limpia lo previo y arma las entries frescas.
    static func replaceAll(_ entries: [BatchLeaveEntry]) {
        var dict: [String: BatchLeaveEntry] = [:]
        for e in entries { dict[e.groupZoneID] = e }
        persist(dict)
    }

    /// Upsert por `groupZoneID`.
    static func save(_ entry: BatchLeaveEntry) {
        var entries = load()
        entries[entry.groupZoneID] = entry
        persist(entries)
    }

    /// Muta una entry existente in-place (write-ahead de fase). No-op si no existe.
    static func update(_ groupZoneID: String, _ mutate: (inout BatchLeaveEntry) -> Void) {
        var entries = load()
        guard var entry = entries[groupZoneID] else { return }
        mutate(&entry)
        entries[groupZoneID] = entry
        persist(entries)
    }

    /// Entries vigentes (purga las EXPIRADAS al leer, salvo las `.inProgress`). `now` inyectable.
    static func all(now: Date = .now) -> [BatchLeaveEntry] {
        var entries = load()
        let expired = entries.values.filter {
            now.timeIntervalSince($0.createdAt) >= ttl && $0.phase != .inProgress
        }
        if !expired.isEmpty {
            for e in expired where e.phase == .pending { MetricsService.canary(.groupBatchLeaveExpired) }
            for e in expired { entries.removeValue(forKey: e.groupZoneID) }
            persist(entries)
        }
        return entries.values.sorted { $0.createdAt < $1.createdAt }
    }

    static func entry(groupZoneID: String, now: Date = .now) -> BatchLeaveEntry? {
        all(now: now).first { $0.groupZoneID == groupZoneID }
    }

    /// Entries no-terminales (pendientes de trabajo del orquestador).
    static func unfinished(now: Date = .now) -> [BatchLeaveEntry] {
        all(now: now).filter { !GroupBatchLeaveLogic.isTerminal($0.phase) }
    }

    /// `true` si queda trabajo por reanudar (resume en boot/foreground).
    static func hasUnfinishedWork(now: Date = .now) -> Bool {
        !unfinished(now: now).isEmpty
    }

    static func clear(groupZoneID: String) {
        var entries = load()
        guard entries.removeValue(forKey: groupZoneID) != nil else { return }
        persist(entries)
    }

    /// Wipe total: al acabar/acknowledge del batch, sign-out / `AppRouter.resetAll()`.
    static func clearAll() {
        defaults.removeObject(forKey: userDefaultsKey)
    }

    #if DEBUG
    /// QA/XCUITest (`-uitest-groups-batch-demo`): resultado determinista fabricado — 2 salidos + 1
    /// transferido + 1 «necesita tu decisión». NO ejecuta nada real; puebla el store para la pantalla de
    /// resultado. Solo DEBUG.
    static func seedDemoResult() {
        replaceAll([
            BatchLeaveEntry(groupZoneID: "demo-leave-1", groupName: "Viaje a Cusco",
                            phase: .done, plannedAction: .leave),
            BatchLeaveEntry(groupZoneID: "demo-solo-1", groupName: "Gastos casa",
                            phase: .done, plannedAction: .deleteSolo),
            BatchLeaveEntry(groupZoneID: "demo-transfer-1", groupName: "Depa compartido",
                            phase: .done, plannedAction: .transferThenLeave),
            BatchLeaveEntry(groupZoneID: "demo-needs-1", groupName: "Amigos del gym",
                            phase: .needsDecision, plannedAction: .needsDecision,
                            needsDecisionReason: .cloudKitOwnerWithCoMembers),
        ])
    }
    #endif

    // MARK: - Persistencia

    private static func load() -> [String: BatchLeaveEntry] {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([String: BatchLeaveEntry].self, from: data)
        } catch {
            #if DEBUG
            print("GroupBatchLeaveStore: Error decoding entries: \(error)")
            #endif
            return [:]
        }
    }

    private static func persist(_ entries: [String: BatchLeaveEntry]) {
        if entries.isEmpty {
            defaults.removeObject(forKey: userDefaultsKey)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(entries)
            defaults.set(data, forKey: userDefaultsKey)
        } catch {
            #if DEBUG
            print("GroupBatchLeaveStore: Error encoding entries: \(error)")
            #endif
        }
    }
}
