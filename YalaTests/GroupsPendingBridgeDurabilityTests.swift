//
//  GroupsPendingBridgeDurabilityTests.swift
//  YalaTests
//
//  El bridge de un gasto de grupo que llegó por sync NO se puede perder — ni cuando el proceso muere antes
//  de que corra, ni cuando el propio intento falla con la app viva.
//
//  El defecto que estas celdas cierran: los IDs a puentear se acumulaban SOLO en dos `Set<UUID>` en memoria
//  de `SplitSyncManager`, y se acumulaban DESPUÉS de aplicar el changeSet. Cuando el handler del fetch
//  retorna, el record ya está local y el change token de CKSyncEngine YA AVANZÓ ⇒ CloudKit no lo re-entrega
//  jamás; solo volvería con una edición remota NUEVA del mismo record. O sea: morir en esa ventana dejaba
//  el gasto sin su `TransactionItem` y sin su `InboxDraft` — invisible en Panel, Inbox y presupuestos —
//  PARA SIEMPRE. La regla del repo afirmaba que «CKSyncEngine re-entrega después» y era falso.
//
//  Y no hacía falta que muriera el proceso: el drenaje limpiaba los Sets ANTES de llamar al bridge
//  (_disarm-then-attempt_), así que cualquiera de las cuatro superficies de throw de `bridgeRemoteExpenses`
//  —o su `catch` por gasto— perdía el lote con la app en primer plano y sin un log en release.
//
//  Por qué se ejercita el singleton REAL y no una extracción: sin `initialize()`, `SplitSyncManager.shared`
//  no tiene container ni engines, que es la situación exacta del arranque. El seam `_testNotePendingBridge`
//  existe porque `CKSyncEngine.Event.FetchedRecordZoneChanges` no tiene init público —el evento no se puede
//  fabricar—, y por eso el cableado real va pinneado aparte con source-scans: sin ellos, revertir el hunk de
//  producción dejaría esta suite entera en verde con el bug de vuelta.
//
//  Harness ON-DISK con los 3 stores (molde `GroupBridgeCaseBPreserveTests`): el bridge escribe en el store
//  PERSONAL leyendo del de GRUPOS, así que un contexto de un solo store no probaría nada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Bridge remoto · durable y sin perder lo que no se cumplió", .serialized)
struct GroupsPendingBridgeDurabilityTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsPendingBridge-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GPBD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GPBD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GPBD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    /// Aísla TODO lo que el escenario toca fuera de SwiftData y devuelve el cleanup. Nunca
    /// `UserDefaults.standard`: el host de los unit tests es la propia app, así que un intent escrito ahí
    /// sobreviviría a la corrida y contaminaría al simulador.
    private func makeIsolatedWorld(_ context: ModelContext, mode: OnboardingMode = .full) -> () -> Void {
        let previousDefaults = GroupsPendingBridgeIntent.defaults
        let previousMode = SessionState.shared.onboardingMode

        GroupsPendingBridgeIntent.defaults = makeIsolatedDefaults(prefix: "pendingbridge")
        GroupTransactionBridge.shared.setContext(context)
        SessionState.shared.onboardingMode = mode
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)

        return {
            SplitSyncManager.shared._testForgetInMemoryPendingBridge()
            GroupsPendingBridgeIntent.defaults = previousDefaults
            SessionState.shared.onboardingMode = previousMode
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
    }

    /// Grupo del canal CloudKit con el current user y quien paga. `isBackendGroup` queda en `false`, que es
    /// la única forma en que un gasto llega a `pendingBridge*` (el guard G6-3 descarta las zonas backend
    /// antes de clasificar nada).
    private func makeFixture(_ context: ModelContext, name: String = "Viaje") throws -> Fixture {
        let group = SplitGroup(name: name, currencyCode: "USD")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()
        return Fixture(group: group, me: me, ana: ana)
    }

    /// Gasto que YA bajó por sync (aplicado y salvado, como lo deja el handler del fetch) y cuyo bridge
    /// todavía no ocurrió: pagado por Ana, con mi share.
    @discardableResult
    private func makeRemoteExpense(
        _ context: ModelContext, _ f: Fixture, zoneID: String? = nil,
        total: Double = 90, myShare: Double = 30, description: String = "Taxi"
    ) throws -> SplitExpense {
        let zone = zoneID ?? f.group.cloudKitZoneID
        let expense = SplitExpense(
            groupZoneID: zone, amount: total, currencyCode: "USD",
            expenseDescription: description, paidByMemberID: f.ana.id.uuidString
        )
        context.insert(expense)
        let share = SplitShare(
            expenseID: expense.id, memberID: f.me.id.uuidString,
            amount: myShare, groupZoneID: zone
        )
        context.insert(share)
        try context.save()
        return expense
    }

    private func bridgedRows(_ context: ModelContext, expenseID: UUID) throws -> (txs: Int, drafts: Int) {
        let idStr = expenseID.uuidString
        let txs = try context.fetchCount(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == idStr }))
        let drafts = try context.fetchCount(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == idStr }))
        return (txs, drafts)
    }

    // MARK: - La intención sobrevive al proceso

    @Test("Un cambio remoto ARMA un intent durable, no solo los Sets en memoria")
    func remoteChange_armsADurableIntent() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeFixture(context)
        let expense = try makeRemoteExpense(context, f)

        SplitSyncManager.shared._testNotePendingBridge(expenseIDs: [expense.id], settlementIDs: [])

        #expect(GroupsPendingBridgeIntent.isArmed,
                """
                El bridge pendiente quedó anotado SOLO en memoria. El record ya se aplicó y el change token \
                de CKSyncEngine ya avanzó, así que CloudKit no lo re-entrega: morir aquí deja el gasto sin \
                su transacción personal para siempre.
                """)
        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [expense.id])
        #expect(GroupsPendingBridgeIntent.armedAt != nil)
    }

    @Test("Proceso nuevo: el retome del boot puentea el gasto que se había perdido")
    func newProcess_resumesTheLostBridge() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeFixture(context)
        let expense = try makeRemoteExpense(context, f)

        // 1. Llega el cambio remoto: el gasto ya está local, el bridge queda pendiente.
        SplitSyncManager.shared._testNotePendingBridge(expenseIDs: [expense.id], settlementIDs: [])

        // 2. «Proceso nuevo»: se olvida el camino rápido en memoria y se cancela el Task coalescido. Lo
        //    único que puede cruzar un reinicio es lo persistido — el escenario exacto del bug.
        SplitSyncManager.shared._testForgetInMemoryPendingBridge()

        let before = try bridgedRows(context, expenseID: expense.id)
        #expect(before.txs == 0 && before.drafts == 0, "Precondición: el bridge no ocurrió en esa sesión.")

        // 3. El arranque siguiente, tras la quiescencia del import personal y el gate de dominio (lo que
        //    prueba `retryPendingBridges` antes de llamar aquí).
        GroupsPendingBridgeResume.resumeIfNeeded(context: context)

        let after = try bridgedRows(context, expenseID: expense.id)
        #expect(after.txs + after.drafts > 0,
                """
                El gasto de grupo sigue sin ninguna fila personal tras un arranque nuevo: no aparece en \
                Panel, ni en Inbox, ni en los presupuestos, y nadie lo va a reintentar. Es la pérdida de \
                datos permanente que el intent durable existe para impedir.
                """)
        #expect(!GroupsPendingBridgeIntent.isArmed,
                "Cumplido el bridge, la intención se desarma; arrastrarla repetiría el trabajo cada arranque.")
    }

    // MARK: - El desarme es por ID CUMPLIDO, no por lote intentado

    @Test("Lo que no se pudo puentear sigue pendiente: el desarme no es «la llamada no lanzó»")
    func unbridgeableExpense_staysPending() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeFixture(context)
        // Gasto cuyo grupo todavía NO bajó a este device: el bridge lo salta sin lanzar.
        let huerfano = try makeRemoteExpense(context, f, zoneID: "SplitGroup-zona-que-no-llego")
        let normal = try makeRemoteExpense(context, f, description: "Cena")

        SplitSyncManager.shared._testNotePendingBridge(
            expenseIDs: [huerfano.id, normal.id], settlementIDs: [])
        SplitSyncManager.shared._testForgetInMemoryPendingBridge()
        GroupsPendingBridgeResume.resumeIfNeeded(context: context)

        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [huerfano.id],
                // (aquí el huérfano cae en el cubo ESPERANDO: su grupo no ha bajado)
                """
                Un lote donde una fila se puentea y otra no debe conservar EXACTAMENTE la que no. Desarmar \
                por «la llamada no lanzó» era el fallo pequeño que quedaba abierto: el `catch` por gasto del \
                bridge se traga el error individual y el lote entero desaparecía con él.
                """)
        let bridged = try bridgedRows(context, expenseID: normal.id)
        #expect(bridged.txs + bridged.drafts > 0, "La fila sana del mismo lote sí se puenteó.")
    }

    @Test("Una fila que ya no existe se ABANDONA en el primer retome, sin gastar los 3 intentos")
    func vanishedRow_isAbandonedImmediately() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let fantasma = UUID()  // ninguna fila con este id: no hay nada que puentear, y no lo habrá

        SplitSyncManager.shared._testNotePendingBridge(expenseIDs: [fantasma], settlementIDs: [])
        GroupsPendingBridgeResume.resumeIfNeeded(context: context)

        #expect(!GroupsPendingBridgeIntent.isArmed,
                """
                Una purga se llevó la fila: no es un fallo del bridge, es que no queda nada que puentear. \
                Gastar tres arranques y emitir el canario de descarte por esto convertiría el canario —que \
                significa «hay algo sistemáticamente roto»— en ruido.
                """)
    }

    @Test("Un gasto que el bridge no puede atender todavía SÍ consume presupuesto, y converge en 3")
    func unattendableExpense_convergesAfterThreeAttempts() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        // Grupo SIN member propio marcado: `isCurrentUser` es device-local y `refreshCurrentUserFlags` no
        // ha podido resolverlo (reinstalación, 2º device, fetch de identidad que falla). `bridgeExpense`
        // hace early-return SIN lanzar — el agujero que el veredicto de atención cierra.
        let group = SplitGroup(name: "Piso", currencyCode: "USD")
        context.insert(group)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()
        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID, amount: 60, currencyCode: "USD",
            expenseDescription: "Luz", paidByMemberID: ana.id.uuidString)
        context.insert(expense)
        try context.save()

        SplitSyncManager.shared._testNotePendingBridge(expenseIDs: [expense.id], settlementIDs: [])
        SplitSyncManager.shared._testForgetInMemoryPendingBridge()

        for arranque in 1...(GroupsPendingBridgeIntent.maxAttempts - 1) {
            GroupsPendingBridgeResume.resumeIfNeeded(context: context)
            #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [expense.id],
                    """
                    Arranque \(arranque): el gasto sigue sin poder puentearse, pero la intención tiene que \
                    seguir viva. Darla por cumplida porque `bridgeExpense` no lanzó era la pérdida silenciosa \
                    del device recién reinstalado: el gasto existe en Grupos y no aparece en Panel ni Inbox.
                    """)
        }

        GroupsPendingBridgeResume.resumeIfNeeded(context: context)
        #expect(!GroupsPendingBridgeIntent.isArmed,
                """
                Sin tope, un ID que nunca se puede atender haría trabajo y un `save()` en CADA arranque para \
                siempre. El criterio es el mismo del Caso A (`bridgeAttempts`, 3 intentos).
                """)
    }

    @Test("El gasto que espera a que baje su grupo NO gasta presupuesto — paridad con el Caso A")
    func expenseWaitingForItsGroup_neverBurnsAttempts() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeFixture(context)
        // El gasto bajó en un batch y su GroupMeta viaja en otro: `applyExpense` inserta la fila igual.
        let huerfano = try makeRemoteExpense(context, f, zoneID: "SplitGroup-zona-que-no-llego")

        SplitSyncManager.shared._testNotePendingBridge(expenseIDs: [huerfano.id], settlementIDs: [])
        SplitSyncManager.shared._testForgetInMemoryPendingBridge()

        for arranque in 1...(GroupsPendingBridgeIntent.maxAttempts + 2) {
            GroupsPendingBridgeResume.resumeIfNeeded(context: context)
            #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [huerfano.id],
                    """
                    Arranque \(arranque): se descartó un gasto que solo esperaba a que bajara su grupo. El \
                    Caso A no cobra por esto — `retryPendingBridges` hace `continue` ANTES de incrementar \
                    `bridgeAttempts` cuando el grupo no está —, y tres arranques sin conexión útil bastarían \
                    para perderlo.
                    """)
        }
    }

    @Test("Un grupo que volteó al backend entre armar y retomar se ABANDONA, no se puentea")
    func groupFlippedToBackend_isAbandoned() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeFixture(context)
        let expense = try makeRemoteExpense(context, f)

        SplitSyncManager.shared._testNotePendingBridge(expenseIDs: [expense.id], settlementIDs: [])
        SplitSyncManager.shared._testForgetInMemoryPendingBridge()

        // El grupo migra al canal backend mientras la intención esperaba en disco.
        f.group.isBackendGroup = true
        try context.save()

        GroupsPendingBridgeResume.resumeIfNeeded(context: context)

        let rows = try bridgedRows(context, expenseID: expense.id)
        #expect(rows.txs + rows.drafts == 0,
                """
                Se puenteó una fila de origen CloudKit de un grupo cuya verdad ya vive en el backend — \
                exactamente lo que el guard G6-3 impide en el instante del fetch. El retome cruza arranques, \
                así que tiene que volver a preguntarlo.
                """)
        #expect(!GroupsPendingBridgeIntent.isArmed,
                "No es reintentable: el canal nuevo trae y puentea lo suyo, así que la intención se abandona.")
    }

    // MARK: - El GEMELO: el canal BACKEND arma el MISMO intent

    /// Grupo del canal BACKEND —`isBackendGroup = true`, como lo deja `GroupsSyncClient.applyGroupMeta`—
    /// con el current user y quien paga.
    private func makeBackendFixture(_ context: ModelContext, zoneID: String = "SplitGroup-B") throws -> Fixture {
        let group = SplitGroup(name: "Piso")
        group.cloudKitZoneID = zoneID
        group.isBackendGroup = true
        context.insert(group)
        let me = SplitMember(groupZoneID: zoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: zoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()
        return Fixture(group: group, me: me, ana: ana)
    }

    /// Página del pull con UN gasto pagado por Ana. La `SplitShare` del current user se siembra aparte (el
    /// bridge la necesita para saber que participo; sin NINGUNA share el gasto no está «atendido»).
    private func expensePage(id: UUID, zoneID: String, paidBy: SplitMember) -> GroupPulledPage {
        let delta = GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitExpense.table, groupID: zoneID,
            rawSyncID: id.uuidString.lowercased(), syncID: id, op: .upsert,
            fields: ["expense_description": .string("Cena"), "amount": .string("90.0000"),
                     "currency_code": .string("USD"),
                     "paid_by_member_key": .string(paidBy.id.uuidString)],
            fieldHlcs: [:], hlc: "2026-07-30T00:00:00.000Z-0000-000000000000000d",
            serverSeq: 5, schemaVersion: 1)
        return GroupPulledPage(deltas: [delta], cursors: [zoneID: 5], memberships: [zoneID])
    }

    @Test("El canal BACKEND arma el intent aunque el bridge todavía no tenga contexto")
    func backendChannel_armsTheIntent_whenTheBridgeIsNotReady() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeBackendFixture(context)
        let expenseID = UUID()

        // El bridge todavía no recibió su contexto: `isReady == false`. Ese `guard` es lo PRIMERO que hace
        // `scheduleBridge`, antes de acumular nada — el camino que un «armar donde se acumula» no cubre.
        GroupTransactionBridge.shared._testClearContext()
        defer { GroupTransactionBridge.shared.setContext(context) }

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            expensePage(id: expenseID, zoneID: f.group.cloudKitZoneID, paidBy: f.ana),
            cursor: cursor, context: context)

        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [expenseID],
                """
                El gasto bajó por el canal backend y su bridge se tiró en el `guard` de `isReady`, sin \
                acumularse en ninguna parte y sin un log. El pull ya avanzó su cursor en el mismo `save` \
                que insertó la fila, así que el servidor no vuelve a mandar ese delta jamás: el gasto se \
                queda sin transacción personal para siempre.
                """)
    }

    @Test("El canal BACKEND arma el intent cuando la quiescencia difiere el bridge a un Task en memoria")
    func backendChannel_armsTheIntent_whenQuiescenceDefersTheBridge() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeBackendFixture(context)
        let expenseID = UUID()

        // Import personal recién terminado ⇒ `SubcategoryDedupGate` devuelve `waitQuiescence` ⇒ el bridge
        // se difiere a `scheduleBridgeRetry`, que es un `Task` + `sleep` EN MEMORIA. Matar la app en esa
        // ventana —o que otro lote entre y cancele el Task— se lo lleva entero.
        let previousImport = iCloudSyncService.shared.lastSuccessfulImportDate
        iCloudSyncService.shared._testSetLastSuccessfulImportDate(.now)
        defer { iCloudSyncService.shared._testSetLastSuccessfulImportDate(previousImport) }

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            expensePage(id: expenseID, zoneID: f.group.cloudKitZoneID, paidBy: f.ana),
            cursor: cursor, context: context)

        let rows = try bridgedRows(context, expenseID: expenseID)
        #expect(rows.txs + rows.drafts == 0, "Precondición: la quiescencia difirió el bridge de verdad.")
        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [expenseID],
                """
                El bridge diferido del canal backend vive SOLO en un `Task` con `sleep`: sin intent durable, \
                un kill de la app en esa ventana deja el gasto sin su transacción personal, y el pull no lo \
                re-entrega porque su cursor ya avanzó.
                """)
    }

    @Test("El retome PUENTEA lo que armó el canal backend, en vez de abandonarlo por ser zona backend")
    func backendResume_bridgesInsteadOfAbandoning() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        let f = try makeBackendFixture(context)
        let expenseID = UUID()

        // Sesión 1: baja el gasto y el bridge no llega a correr (sin contexto). La restauración va por
        // `defer` y no como sentencia suelta: entre medias hay un `try`, y si lanzara dejaría el singleton
        // sin contexto para el RESTO del proceso — con la suite `.serialized`, eso tumba a las siguientes
        // por una causa que no es la suya.
        GroupTransactionBridge.shared._testClearContext()
        defer { GroupTransactionBridge.shared.setContext(context) }
        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            expensePage(id: expenseID, zoneID: f.group.cloudKitZoneID, paidBy: f.ana),
            cursor: cursor, context: context)
        GroupTransactionBridge.shared.setContext(context)

        // Mi parte del gasto llega en otra página, como llega en producción.
        let share = SplitShare(expenseID: expenseID, memberID: f.me.id.uuidString,
                               amount: 30, groupZoneID: f.group.cloudKitZoneID)
        context.insert(share)
        try context.save()

        // Arranque siguiente.
        GroupsPendingBridgeResume.resumeIfNeeded(context: context)

        let rows = try bridgedRows(context, expenseID: expenseID)
        #expect(rows.txs + rows.drafts > 0,
                """
                El retome descartó el gasto por estar en una zona del backend. Para lo que armó el canal \
                CloudKit eso es correcto —su verdad se mudó—, pero para lo que armó el PROPIO canal backend \
                es su estado NORMAL: `applyGroupMeta` enciende `isBackendGroup` en todos sus grupos, así que \
                sin la marca de canal el retome abandonaría TODO lo del canal que el paso 2 enciende, y el \
                intent se armaría para no cumplirse nunca.
                """)
        #expect(!GroupsPendingBridgeIntent.isArmed, "Cumplido el bridge, la intención se desarma.")
    }

    @Test("El canal BACKEND confirma por ID cumplido, no por lote: lo no atendido sigue pendiente")
    func backendChannel_confirmsOnlyWhatWasAttended() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cleanup = makeIsolatedWorld(context); defer { cleanup() }
        // Grupo backend SIN member propio marcado: `bridgeExpense` hace early-return devolviendo «no
        // atendido», sin lanzar. Es el estado del device recién reinstalado o del 2º device.
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = "SplitGroup-C"
        group.isBackendGroup = true
        context.insert(group)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()
        let expenseID = UUID()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            expensePage(id: expenseID, zoneID: group.cloudKitZoneID, paidBy: ana),
            cursor: cursor, context: context)

        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [expenseID],
                """
                El canal backend descartaba el valor de retorno de `bridgeRemoteExpenses` y confirmaba el \
                lote entero. Un gasto que el bridge deja en estado INCOMPLETO sin lanzar —el `SplitMember` \
                propio aún sin marcar— quedaba así desarmado sin haber obtenido nunca su transacción \
                personal: la pérdida silenciosa que el desarme por ID cumplido existe para cerrar.
                """)
    }

    // MARK: - El intent en sí

    @Test("Re-armar acumula y conserva el sello original; el intent no caduca por tiempo")
    func arm_accumulates_andKeepsItsOriginalStamp() {
        let dir = freshDir(); defer { cleanup(dir) }
        let previous = GroupsPendingBridgeIntent.defaults
        GroupsPendingBridgeIntent.defaults = makeIsolatedDefaults(prefix: "pendingbridge.unit")
        defer { GroupsPendingBridgeIntent.defaults = previous }

        let primero = UUID(), segundo = UUID(), liquidacion = UUID()
        let armado = Date(timeIntervalSince1970: 1_700_000_000)

        GroupsPendingBridgeIntent.arm(
            expenseIDs: [primero], settlementIDs: [], channel: .cloudKit, at: armado)
        GroupsPendingBridgeIntent.arm(
            expenseIDs: [segundo], settlementIDs: [liquidacion], channel: .cloudKit,
            at: armado.addingTimeInterval(86_400 * 30))

        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [primero, segundo])
        #expect(GroupsPendingBridgeIntent.pending.settlementIDs == [liquidacion])
        #expect(GroupsPendingBridgeIntent.armedAt == armado,
                "El dato accionable es desde cuándo se arrastra la intención más vieja, no el último batch.")

        GroupsPendingBridgeIntent.confirm(expenseIDs: [primero], settlementIDs: [])
        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [segundo])
        #expect(GroupsPendingBridgeIntent.isArmed)

        GroupsPendingBridgeIntent.confirm(expenseIDs: [segundo], settlementIDs: [liquidacion])
        #expect(!GroupsPendingBridgeIntent.isArmed)
        #expect(GroupsPendingBridgeIntent.armedAt == nil)
    }

    @Test("Un intent escrito ANTES de que existiera el canal se sigue leyendo, como «todo CloudKit»")
    func storedPayloadWithoutChannel_stillDecodes() {
        let previous = GroupsPendingBridgeIntent.defaults
        let defaults = makeIsolatedDefaults(prefix: "pendingbridge.legacy")
        GroupsPendingBridgeIntent.defaults = defaults
        defer { GroupsPendingBridgeIntent.defaults = previous }

        // Formato exacto del payload anterior a la marca de canal: sin `backendExpenses` ni
        // `backendSettlements`. Un usuario que actualiza con una intención viva pasa por aquí.
        let viejo = UUID()
        let json = """
        {"expenses":{"\(viejo.uuidString)":1},"settlements":{},"armedAt":"2026-07-29T10:00:00Z"}
        """
        defaults.set(Data(json.utf8), forKey: GroupsPendingBridgeIntent.userDefaultsKey)

        let pending = GroupsPendingBridgeIntent.pending
        #expect(pending.expenseIDs == [viejo],
                """
                Añadir los campos del canal invalidó el payload anterior: el `catch` del decode borra la key, \
                así que un usuario que actualiza con un bridge pendiente perdería el gasto justo en la \
                actualización que venía a protegerlo. Los campos son OPCIONALES por esto.
                """)
        #expect(pending.backendExpenseIDs.isEmpty,
                "Sin marca de canal, lo de antes es del canal CloudKit — que es lo que era.")
        #expect(GroupsPendingBridgeIntent.armedAt != nil, "El sello original sobrevive a la lectura.")
    }

    @Test("Los intentos se cuentan por ID: uno envenenado no arrastra a los demás")
    func failedAttempts_areCountedPerID() {
        let previous = GroupsPendingBridgeIntent.defaults
        GroupsPendingBridgeIntent.defaults = makeIsolatedDefaults(prefix: "pendingbridge.attempts")
        defer { GroupsPendingBridgeIntent.defaults = previous }

        let malo = UUID(), bueno = UUID()
        GroupsPendingBridgeIntent.arm(expenseIDs: [malo, bueno], settlementIDs: [], channel: .cloudKit)

        for _ in 1...(GroupsPendingBridgeIntent.maxAttempts - 1) {
            let dropped = GroupsPendingBridgeIntent.noteFailedAttempt(expenseIDs: [malo], settlementIDs: [])
            #expect(dropped.expenses == 0)
        }
        let dropped = GroupsPendingBridgeIntent.noteFailedAttempt(expenseIDs: [malo], settlementIDs: [])
        #expect(dropped.expenses == 1)
        #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [bueno],
                "El que nunca falló conserva su presupuesto entero.")
    }
}

/// Cableado de producción (source-scan). El seam `_testNotePendingBridge` entra por DEBAJO del handler del
/// fetch —el evento de CKSyncEngine no se puede fabricar—, así que sin estos scans revertir el hunk que
/// cablea el intent dejaría la suite de arriba en verde con la pérdida de vuelta. Mismo patrón y misma razón
/// que `GroupsIdentityPurgeWiringTests` / `HandoverGroupsWiringTests`.
@Suite("Bridge remoto durable · cableado de producción (source-scan)")
struct GroupsPendingBridgeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El handler del fetch anota por el MISMO seam que el test, y ese seam arma el intent durable. Sin
    /// esto, el test de arriba mediría una función que producción no llama.
    ///
    /// Ancla en el CALL-SITE, dentro del cuerpo del handler, no en la declaración: comprobar que la función
    /// existe y que el `arm` está dentro de ella se satisface sola, sin exigir ningún llamador — un
    /// reescrito equivalente del handler (`formUnion` con otra variable) dejaría las celdas de arriba en
    /// verde, porque TODAS entran por el seam de DEBUG.
    @Test func theFetchHandler_armsThroughTheSameSeam() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        #expect(src.contains("private func notePendingBridge(expenseIDs: Set<UUID>, settlementIDs: Set<UUID>)"))
        #expect(src.contains("expenseIDs: expenseIDs, settlementIDs: settlementIDs, channel: .cloudKit)"))

        let handler = try #require(
            src.components(separatedBy: "private func handleFetchedRecordZoneChanges").dropFirst().first,
            "El handler del fetch cambió de nombre; este scan dejó de medir nada.")
        // El cuerpo termina donde empieza la siguiente declaración del tipo.
        let body = handler.components(separatedBy: "\n    private func ").first ?? ""
        #expect(body.contains("notePendingBridge("),
                """
                El handler del fetch dejó de anotar por `notePendingBridge`. Si vuelve a acumular los IDs por \
                su cuenta, el intent durable no se arma y la pérdida vuelve entera — y NINGUNA celda de \
                comportamiento se entera, porque todas entran por el seam de DEBUG.
                """)
        #expect(!body.contains("pendingBridgeExpenseIDs.formUnion"))
        #expect(!body.contains("pendingBridgeSettlementIDs.formUnion"))
    }

    /// Los dos gates de dominio del fix. Ninguno es alcanzable bajo el runner —el sello exceptúa
    /// `isRunningTests` a propósito, o cerraría las 14 pruebas del bridge—, así que el source-scan no es
    /// aquí una comodidad sino la única cobertura posible.
    @Test func bothDomainGates_areInPlaceAndOrdered() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")

        // 1) Armar: con el dominio sellado no se persiste intención. Si no, tras un «empiezo de cero» el
        //    corpus re-descargado del humano anterior se acumula y se materializa entero en el Panel del
        //    nuevo el día que adopte Grupos.
        let note = try #require(
            src.components(separatedBy: "private func notePendingBridge").dropFirst().first)
        let noteBody = note.components(separatedBy: "\n    /// ").first ?? note
        let guardAt = try #require(noteBody.range(of: "guard GroupTransactionBridge.isDomainOpenForBridge() else"))
        let armAt = try #require(noteBody.range(of: "GroupsPendingBridgeIntent.arm("))
        #expect(guardAt.lowerBound < armAt.lowerBound)

        // 2) Drenar en sesión: con el dominio sellado el bridge hace early-return sin lanzar, así que
        //    intentarlo desarmaría la intención sin haber puenteado nada.
        let drain = try #require(
            src.components(separatedBy: "private func processPendingRemoteChanges").dropFirst().first)
        let gate = try #require(drain.range(of: "guard GroupTransactionBridge.isDomainOpenForBridge() else"))
        let attempt = try #require(drain.range(of: "bridgeRemoteExpenses(ids:"))
        #expect(gate.lowerBound < attempt.lowerBound)
    }

    /// Gemelo del anterior para el canal BACKEND, y por la misma razón: el sello es inalcanzable bajo el
    /// runner, así que sin este scan los dos gates del canal que el paso 2 del encendido ENCIENDE no los
    /// pinnea nada — y el scan de arriba lee un fichero que la Fase 3 borra entero, así que tampoco heredaría
    /// su cobertura.
    @Test func backendChannel_domainGates_areInPlaceAndOrdered() throws {
        let src = try Self.source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")

        // 1) Armar: el guard de dominio precede al `arm`, igual que en `notePendingBridge`.
        let arm = try #require(
            src.components(separatedBy: "private func armBridgeIntent").dropFirst().first)
        let armBody = arm.components(separatedBy: "\n    private func ").first ?? arm
        let guardAt = try #require(armBody.range(of: "guard GroupTransactionBridge.isDomainOpenForBridge() else"))
        let armAt = try #require(armBody.range(of: "GroupsPendingBridgeIntent.arm("))
        #expect(guardAt.lowerBound < armAt.lowerBound,
                "Con el dominio sellado el canal backend no puede persistir intención: sería la cola del humano anterior.")

        // 2) Intentar: el guard de dominio precede al bridge, para no quemar los 3 intentos del ID contra
        //    una puerta cerrada.
        let run = try #require(
            src.components(separatedBy: "private func runBridge").dropFirst().first)
        let runBody = run.components(separatedBy: "\n    private func ").first ?? run
        let gate = try #require(runBody.range(of: "guard GroupTransactionBridge.isDomainOpenForBridge() else"))
        let attempt = try #require(runBody.range(of: "bridgeRemoteExpenses(ids:"))
        #expect(gate.lowerBound < attempt.lowerBound)
    }

    /// El `arm` del canal backend vive en `applyPulledPage` y en sus DOS salidas, no en `scheduleBridge`.
    /// Scan de ORDEN y de presencia en ambas ramas, porque las tres versiones —la rota, la intermedia y la
    /// buena— «contienen» las mismas llamadas: lo que las distingue es dónde.
    @Test func theBackendArm_coversBothExitsOfApply() throws {
        let src = try Self.source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        let apply = try #require(
            src.components(separatedBy: "func applyPulledPage").dropFirst().first)
        let body = apply.components(separatedBy: "\n    /// ").first ?? apply

        let armCalls = body.components(separatedBy: "armBridgeIntent(expenseIDs:").count - 1
        #expect(armCalls >= 2,
                """
                El `arm` dejó de cubrir las dos salidas de `applyPulledPage`. El `catch` del save importa \
                tanto como el camino de éxito: SwiftData no revierte el contexto al fallar, así que las filas \
                insertadas siguen vivas en el `mainContext` compartido y el próximo save de cualquiera las \
                persiste — con el cursor ya avanzado y sin nadie que recuerde puentearlas.
                """)

        // Y va ANTES del freeze del soft-delete, que hace su propio `save()` del store personal sin gate.
        let armAt = try #require(body.range(of: "armBridgeIntent(expenseIDs: bridgeExpenseIDs"))
        let freezeAt = try #require(body.range(of: "drainSoftDeleteFreeze("))
        #expect(armAt.lowerBound < freezeAt.lowerBound)
    }

    /// El veredicto de atención: `bridgeExpense`/`bridgeSettlement` distinguen «decidido» de «todavía no se
    /// puede», y los `bridgeRemote*` solo confirman lo primero. Un `bridged.insert` incondicional volvería a
    /// desarmar la intención de gastos que nunca obtuvieron su transacción personal.
    @Test func theBridge_reportsWhetherItActuallyAttended() throws {
        let src = try Self.source("Yala/Services/Groups/GroupTransactionBridge.swift")
        #expect(src.contains("if try bridgeExpense(expense, in: group, accountForCurrentUser: nil, isRemoteSync: true, shouldSave: false) {"))
        #expect(src.contains("if try bridgeSettlement(settlement, in: group, accountForCurrentUser: nil, shouldSave: false) {"))
        #expect(!src.contains("bridged.insert(expense.id)\n            } catch"))
    }

    /// ARM-then-attempt-then-DISARM: el desarme tiene que venir DESPUÉS del intento. Un scan de orden y no
    /// de presencia, porque la versión rota también «contenía» las dos cosas — en el orden inverso.
    @Test func theDisarm_comesAfterTheAttempt() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        let intento = try #require(src.range(of: "bridgeRemoteExpenses(ids: Array(expenseIDs))"))
        let desarme = try #require(src.range(of: "GroupsPendingBridgeIntent.confirm("))
        #expect(intento.lowerBound < desarme.lowerBound,
                """
                El desarme volvió a preceder al intento (`removeAll()` antes de llamar al bridge). Cualquiera \
                de las cuatro superficies de throw de `bridgeRemoteExpenses` pierde entonces el lote entero, \
                con la app viva y sin un log en release.
                """)
    }

    /// El retome vive DENTRO de `retryPendingBridges` y detrás de sus dos gates: el bridge salva el
    /// `mainContext` compartido (quiescencia) y con Grupos sellado no puede consumir la intención (dominio).
    @Test func theBootResume_isWiredBehindBothGates() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let dominio = try #require(src.range(of: "guard GroupTransactionBridge.isDomainOpenForBridge() else"))
        let retome = try #require(src.range(of: "GroupsPendingBridgeResume.resumeIfNeeded(context: context)"))
        #expect(dominio.lowerBound < retome.lowerBound)
        let quiescencia = try #require(src.range(of: "logger.notice(\"retryPendingBridges deferred"))
        #expect(quiescencia.lowerBound < retome.lowerBound)
    }

    /// La coartada del bug, borrada: la regla del repo y este comentario afirmaban que CKSyncEngine
    /// re-entrega el cambio más tarde. No lo hace — el token ya avanzó cuando el handler retornó.
    @Test func theFalseAlibi_isGone() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        #expect(!src.contains("CKSyncEngine re-delivers the change later"))
    }

    /// Frontera de usuario: la intención del humano anterior no viaja al dispositivo del nuevo. Importa
    /// porque el reset de tokens re-descarga el corpus con los MISMOS UUID.
    ///
    /// Aserción REAL y no un `contains` del símbolo: la función es un `static func` sin seam ni evento que
    /// fabricar, así que la coartada de esta suite para los scans no aplica. Un `contains` lo dejaría verde
    /// un comentario del estilo de las exclusiones deliberadas que ese mismo fichero ya usa.
    @MainActor
    @Test func theHandover_sweepsTheIntent() {
        let defaults = makeIsolatedDefaults(prefix: "handover.pendingbridge")
        defaults.set(Data("cualquier cosa".utf8), forKey: GroupsPendingBridgeIntent.userDefaultsKey)

        DataWipeService.removeGroupsDomainPreferenceKeys(from: defaults)

        #expect(defaults.data(forKey: GroupsPendingBridgeIntent.userDefaultsKey) == nil,
                """
                El «empiezo de cero» dejó viva la intención de bridge del humano anterior. Con el reset de \
                tokens re-descargando su corpus con los MISMOS UUID, en cuanto el usuario nuevo adopte \
                Grupos esos gastos se puentearían a SU Panel, su Inbox y sus presupuestos.
                """)
    }
}
