//
//  GroupsAssociationDetachTests.swift
//  YalaTests
//
//  Paso 10 · **las dos salidas de desasociar**, que Jürgen decidió el 2026-09-09 y que son lo único de
//  este ticket donde equivocarse cuesta datos del usuario.
//
//  Tres bloques:
//    1. la POLARIDAD pura — qué le pasa a cada fila según la salida y su cuenta
//    2. el BARRIDO sobre los tres stores — las dos salidas, los borradores y la idempotencia
//    3. el LIBRO de conservados — el sello por cuenta, que es lo que separa «re-asociar la mía» de
//       «asociar otra»
//
//  Harness ON-DISK con los 3 stores (molde `LegacyGroupsRetirementTests`): el barrido cruza stores —lee
//  Grupos y escribe el PERSONAL— y `makeTestContext()` no sirve para eso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

/// Fuera del harness `@MainActor` a propósito: lo usan también las suites puras del libro, que no
/// necesitan contexto y por tanto no necesitan el hilo principal.
private func isolatedDetachDefaults() -> UserDefaults {
    UserDefaults(suiteName: "test.detach.\(UUID().uuidString)")!
}

// MARK: - Harness

@MainActor
private enum DetachHarness {

    static func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GAD-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    static func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GAD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GAD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GAD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// El grupo de la zona. **Hace falta en todo fixture**: el barrido solo toca zonas del canal
    /// BACKEND, así que sin él `backendChannelZones` sale vacío y no se toca nada — que es justo la
    /// defensa que protege a los puentes de la era CloudKit.
    @discardableResult
    static func makeBackendGroup(zone: String = "zona-1", context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "Viaje")
        g.cloudKitZoneID = zone
        g.isBackendGroup = true
        context.insert(g)
        return g
    }

    /// Un grupo de la era CloudKit: ni `isBackendGroup` ni `movedToBackendAt`. Su puente no es de la
    /// cuenta que se desasocia.
    @discardableResult
    static func makeLegacyGroup(zone: String, context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "Legacy")
        g.cloudKitZoneID = zone
        context.insert(g)
        return g
    }

    static func makeAccount(_ context: ModelContext, isSystem: Bool) -> Account {
        let a = Account(
            name: isSystem ? "Préstamo a grupos" : "Efectivo", currencyCode: "USD",
            colorHex: "#111111", iconName: "banknote", type: "cash", isSystemAccount: isSystem)
        context.insert(a)
        return a
    }

    /// Una `TransactionItem` puenteada tal cual la deja el bridge (los tres punteros a la vez).
    @discardableResult
    static func makeBridgedTx(
        expenseID: UUID? = nil, settlementID: UUID? = nil, zone: String = "zona-1",
        amount: Double = -20, accountIsSystem: Bool? = false, context: ModelContext
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: .now, amount: amount, currencyCode: "USD",
            account: accountIsSystem.map { makeAccount(context, isSystem: $0) })
        tx.note = "Cena del viaje"
        tx.splitExpenseID = expenseID?.uuidString
        tx.splitSettlementID = settlementID?.uuidString
        tx.splitGroupZoneID = zone
        context.insert(tx)
        return tx
    }

    @discardableResult
    static func makeBridgedDraft(
        expenseID: UUID? = nil, zone: String = "zona-1",
        needsUserInput: [String] = [DraftInputRequirement.account], context: ModelContext
    ) -> InboxDraft {
        let d = InboxDraft(
            note: "Cena", amount: -20, date: .now, sourceType: .groupExpense,
            needsUserInput: needsUserInput,
            splitExpenseID: expenseID?.uuidString, splitGroupZoneID: zone)
        context.insert(d)
        return d
    }

    static func txs(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>())
    }

    static func drafts(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>())
    }
}

// MARK: - 1 · La polaridad

@Suite("GroupsAssociationDetach · la polaridad de cada fila")
struct GroupsAssociationDetachPolarityTests {

    /// **Conservar es la polaridad del BARREDOR, no la del freeze.** El espejo virtual («debo 10»,
    /// «presté 40») se BORRA: sin grupo detrás no representa nada, y aquí nadie podrá limpiarlo después
    /// porque `OrphanedBridgedTxSweeper` exige un veredicto de zona que se construye de filas vivas, y
    /// desasociar las borra todas.
    @MainActor
    @Test("Conservar: la cuenta real libera punteros, el espejo de sistema se borra")
    func polaridadConservar() {
        #expect(GroupsAssociationDetach.action(choice: .keep, accountIsSystem: false) == .releasePointers)
        #expect(GroupsAssociationDetach.action(choice: .keep, accountIsSystem: true) == .delete)
    }

    /// Quitar es `unbridge*`: las dos mitades se van. Es lo que el ticket llama «el camino de borrado es
    /// el `unbridge*` de hoy».
    @MainActor
    @Test("Quitar: se van las dos, la real y el espejo")
    func polaridadQuitar() {
        #expect(GroupsAssociationDetach.action(choice: .remove, accountIsSystem: false) == .delete)
        #expect(GroupsAssociationDetach.action(choice: .remove, accountIsSystem: true) == .delete)
    }

    /// `account == nil` cuenta como REAL. Las dos mecánicas existentes discrepan justo ahí (el freeze
    /// conserva, el barredor libera) y este camino sigue al clasificador COMPARTIDO: ante la duda,
    /// preservar el rastro.
    @MainActor
    @Test("Una transacción SIN cuenta se trata como real y se conserva")
    func sinCuentaEsReal() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let tx = DetachHarness.makeBridgedTx(
            expenseID: UUID(), accountIsSystem: nil, context: context)
        try context.save()

        #expect(GroupsAssociationDetach.action(for: tx, choice: .keep) == .releasePointers)
    }

    /// Las cuatro celdas, afirmadas. Un bucle que descarte el resultado con `_ =` sugiere una cobertura
    /// que no existe: lo único vivo sería el conteo.
    @MainActor
    @Test("Las cuatro celdas están decididas, y una salida nueva no nace sin polaridad")
    func ejeCompleto() {
        #expect(GroupsAssociationDetach.BridgedRowsChoice.allCases.count == 2,
                "apareció una salida nueva: decide qué le pasa a la cuenta real y al espejo virtual")
        var tabla: [String: GroupsAssociationDetach.Action] = [:]
        for choice in GroupsAssociationDetach.BridgedRowsChoice.allCases {
            for sistema in [true, false] {
                tabla["\(choice)-\(sistema)"] = GroupsAssociationDetach.action(
                    choice: choice, accountIsSystem: sistema)
            }
        }
        #expect(tabla == [
            "keep-false": .releasePointers,
            "keep-true": .delete,
            "remove-false": .delete,
            "remove-true": .delete,
        ])
    }
}

// MARK: - 2 · El barrido

@Suite("GroupsAssociationDetach · el barrido del puente al desasociar", .serialized)
struct GroupsAssociationDetachSweepTests {

    /// El criterio de aceptación literal: tres gastos puenteados en el Panel siguen ahí, sin marca de
    /// grupo. «Sin marca» es lo que hace que vuelvan a ser editables y borrables — con el puntero puesto
    /// y sin filas de grupo, `NewTransactionView` los deja ATRAPADOS.
    @MainActor
    @Test("Conservar deja las tres transacciones reales en el Panel, sin puntero de grupo")
    func conservarTresGastos() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        let defaults = isolatedDetachDefaults()
        DetachHarness.makeBackendGroup(context: context)

        let ids = (0..<3).map { _ in UUID() }
        for id in ids {
            DetachHarness.makeBridgedTx(expenseID: id, accountIsSystem: false, context: context)
        }
        try context.save()

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "sub-1", defaults: defaults))

        #expect(outcome.released == 3)
        #expect(outcome.deleted == 0)
        let vivas = try DetachHarness.txs(context)
        #expect(vivas.count == 3, "las tres siguen en el Panel")
        for tx in vivas {
            #expect(tx.splitExpenseID == nil)
            #expect(tx.splitSettlementID == nil)
            #expect(tx.splitGroupZoneID == nil)
            #expect(tx.amount == -20, "el importe no se toca")
            #expect(tx.note == "Cena del viaje", "la nota tampoco")
        }
    }

    @MainActor
    @Test("Conservar borra el espejo virtual de sistema y deja la real")
    func conservarBorraElEspejo() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let id = UUID()
        DetachHarness.makeBridgedTx(expenseID: id, amount: -20, accountIsSystem: false, context: context)
        DetachHarness.makeBridgedTx(expenseID: id, amount: 12, accountIsSystem: true, context: context)
        try context.save()

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "s", defaults: isolatedDetachDefaults()))

        #expect(outcome.released == 1)
        #expect(outcome.deleted == 1)
        let vivas = try DetachHarness.txs(context)
        #expect(vivas.count == 1)
        #expect(vivas.first?.account?.isSystemAccount == false, """
            Sobrevivió el espejo de sistema en vez de la transacción de cuenta real: es la INVERSA de la
            polaridad correcta, y se lleva el dinero de verdad dejando el fantasma.
            """)
    }

    @MainActor
    @Test("Quitar se lleva las dos mitades")
    func quitarSeLlevaTodo() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let id = UUID()
        DetachHarness.makeBridgedTx(expenseID: id, accountIsSystem: false, context: context)
        DetachHarness.makeBridgedTx(expenseID: id, amount: 12, accountIsSystem: true, context: context)
        DetachHarness.makeBridgedDraft(expenseID: id, context: context)
        try context.save()

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .remove, associatedSub: "s", defaults: isolatedDetachDefaults()))

        #expect(outcome.deleted == 2)
        #expect(outcome.released == 0)
        #expect(outcome.draftsDeleted == 1, "el recuento de borradores de la rama `.remove` no se alimenta")
        #expect(try DetachHarness.txs(context).isEmpty)
        #expect(try DetachHarness.drafts(context).isEmpty)
    }

    /// **El orden de las dos fases.** `computeFreezePlan` decide si un borrador es un puntero redundante
    /// comparando su `splitExpenseID` con el de las transacciones; calculado DESPUÉS de mutar daría
    /// `false` siempre, el borrador se convertiría a manual y aprobarlo insertaría una transacción NUEVA
    /// junto a la recién liberada: el gasto DUPLICADO.
    @MainActor
    @Test("Conservar borra el borrador redundante en vez de convertirlo (o el gasto se duplicaría)")
    func borradorRedundanteSeBorra() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let id = UUID()
        DetachHarness.makeBridgedTx(expenseID: id, accountIsSystem: false, context: context)
        DetachHarness.makeBridgedDraft(
            expenseID: id, needsUserInput: [DraftInputRequirement.subcategory], context: context)
        try context.save()

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "s", defaults: isolatedDetachDefaults()))

        #expect(outcome.draftsDeleted == 1)
        #expect(outcome.draftsConverted == 0)
        #expect(try DetachHarness.drafts(context).isEmpty)
    }

    /// El borrador que SÍ pide algo que la transacción no tiene (la cuenta) no es redundante: se
    /// conserva como manual, con lo que el usuario ya había puesto.
    @MainActor
    @Test("Conservar convierte a manual el borrador que no es redundante")
    func borradorNoRedundanteSeConvierte() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        DetachHarness.makeBridgedDraft(expenseID: UUID(), context: context)
        try context.save()

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "s", defaults: isolatedDetachDefaults()))

        #expect(outcome.draftsConverted == 1)
        let vivos = try DetachHarness.drafts(context)
        #expect(vivos.count == 1)
        #expect(vivos.first?.sourceTypeRaw == DraftSourceType.manual.rawValue)
        #expect(vivos.first?.splitExpenseID == nil)
        #expect(vivos.first?.splitGroupZoneID == nil)
    }

    /// **La defensa que protege el dinero de los grupos de la era CloudKit.** Su puente no es de la
    /// cuenta que se desasocia: con `.remove` y sin filtro por canal, este barrido se llevaría por
    /// delante transacciones de cuenta REAL —dinero que salió de verdad— en un store sin mirror que las
    /// reponga. El escenario que lo hace real es el primer minuto tras «Restaurar desde iCloud», antes de
    /// que `LegacyGroupsRetirement` haya corrido.
    @MainActor
    @Test("Un puente de zona LEGACY no se toca, ni conservando ni quitando")
    func zonaLegacyNoSeToca() throws {
        for choice in GroupsAssociationDetach.BridgedRowsChoice.allCases {
            let dir = DetachHarness.freshDir()
            defer { DetachHarness.cleanup(dir) }
            let context = try DetachHarness.makeContext(dir)
            DetachHarness.makeLegacyGroup(zone: "zona-legacy", context: context)
            DetachHarness.makeBridgedTx(
                expenseID: UUID(), zone: "zona-legacy", accountIsSystem: false, context: context)
            try context.save()

            let outcome = try #require(GroupsAssociationDetach.detachBridge(
                context: context, choice: choice, associatedSub: "s",
                defaults: isolatedDetachDefaults()))

            #expect(outcome.isEmpty, "con `\(choice)` se tocó un puente de la era CloudKit")
            let viva = try #require(try DetachHarness.txs(context).first)
            #expect(viva.splitExpenseID != nil, "le soltaron el puntero a una fila que no le tocaba")
        }
    }

    /// El control positivo del anterior: la MISMA forma, con la zona en el canal backend, sí se toca. Sin
    /// él, un filtro que dejara fuera todas las zonas pasaría los dos tests.
    @MainActor
    @Test("La misma fila, con zona del canal backend, SÍ se suelta")
    func zonaBackendSiSeToca() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(zone: "zona-backend", context: context)
        DetachHarness.makeBridgedTx(
            expenseID: UUID(), zone: "zona-backend", accountIsSystem: false, context: context)
        try context.save()

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "s", defaults: isolatedDetachDefaults()))

        #expect(outcome.released == 1)
    }

    /// El borrador conservado tiene que entrar al libro igual que una transacción: si no, al re-asociar
    /// la misma cuenta el puente crea OTRO borrador del mismo gasto y el Inbox muestra dos entradas
    /// idénticas — aprobarlas mete el gasto dos veces en el Panel.
    @MainActor
    @Test("El borrador conservado entra al libro")
    func borradorConservadoEntraAlLibro() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let defaults = isolatedDetachDefaults()
        let gasto = UUID()
        DetachHarness.makeBridgedDraft(expenseID: gasto, context: context)
        try context.save()

        _ = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "sub-mia", defaults: defaults))

        #expect(GroupsDetachedBridgeLedger.isConserved(
            expenseID: gasto.uuidString, associatedSub: "sub-mia", defaults: defaults))
    }

    @MainActor
    @Test("Es idempotente: la segunda pasada no encuentra nada")
    func idempotente() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let defaults = isolatedDetachDefaults()
        DetachHarness.makeBridgedTx(expenseID: UUID(), accountIsSystem: false, context: context)
        try context.save()

        _ = GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "s", defaults: defaults)
        let segunda = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "s", defaults: defaults))

        #expect(segunda.isEmpty)
        #expect(try DetachHarness.txs(context).count == 1, "la segunda pasada no se llevó la conservada")
    }

    /// Sin puente que soltar, el libro de una desasociación anterior deja de significar nada. Si se
    /// quedara, frenaría el puente de gastos que nadie conservó.
    @MainActor
    @Test("Sin filas puenteadas, el libro anterior se limpia")
    func sinPuenteLimpiaElLibro() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let defaults = isolatedDetachDefaults()
        GroupsDetachedBridgeLedger.record(
            sub: "viejo", expenseIDs: ["a"], settlementIDs: [], defaults: defaults)

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "s", defaults: defaults))

        #expect(outcome.isEmpty)
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil)
    }
}

// MARK: - 3 · El libro de conservados

@Suite("GroupsDetachedBridgeLedger · el sello por cuenta")
struct GroupsDetachedBridgeLedgerTests {

    @MainActor
    @Test("Conservar escribe el libro sellado con la cuenta que se fue")
    func conservarEscribeElLibro() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let defaults = isolatedDetachDefaults()
        let gasto = UUID()
        let liquidacion = UUID()
        DetachHarness.makeBridgedTx(expenseID: gasto, accountIsSystem: false, context: context)
        DetachHarness.makeBridgedTx(settlementID: liquidacion, accountIsSystem: false, context: context)
        try context.save()

        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "sub-mia", defaults: defaults))

        #expect(outcome.conservedExpenses == 1)
        #expect(outcome.conservedSettlements == 1)
        let libro = GroupsDetachedBridgeLedger.read(defaults: defaults)
        #expect(libro?.sub == "sub-mia")
        #expect(libro?.expenseIDs == [gasto.uuidString])
        #expect(libro?.settlementIDs == [liquidacion.uuidString])
    }

    @MainActor
    @Test("Quitar NO escribe libro: no hay nada que frenar después")
    func quitarNoEscribeLibro() throws {
        let dir = DetachHarness.freshDir()
        defer { DetachHarness.cleanup(dir) }
        let context = try DetachHarness.makeContext(dir)
        DetachHarness.makeBackendGroup(context: context)
        let defaults = isolatedDetachDefaults()
        DetachHarness.makeBridgedTx(expenseID: UUID(), accountIsSystem: false, context: context)
        try context.save()

        _ = GroupsAssociationDetach.detachBridge(
            context: context, choice: .remove, associatedSub: "s", defaults: defaults)

        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil)
    }

    /// **La mitad que cumple «re-asociar la misma cuenta → 0 duplicados».**
    @Test("Con la MISMA cuenta, el gasto conservado frena el puente")
    func mismaCuentaFrena() {
        let defaults = isolatedDetachDefaults()
        GroupsDetachedBridgeLedger.record(
            sub: "sub-mia", expenseIDs: ["g1"], settlementIDs: ["s1"], defaults: defaults)

        #expect(GroupsDetachedBridgeLedger.isConserved(
            expenseID: "g1", associatedSub: "sub-mia", defaults: defaults))
        #expect(GroupsDetachedBridgeLedger.isConserved(
            settlementID: "s1", associatedSub: "sub-mia", defaults: defaults))
    }

    /// **La mitad que cumple «asociar otra cuenta → los grupos nuevos llegan limpios».** Sin el sello,
    /// los conservados de una cuenta frenarían el puente de otra y se perderían gastos que nadie pidió
    /// conservar.
    @Test("Con OTRA cuenta, el libro no frena nada")
    func otraCuentaNoFrena() {
        let defaults = isolatedDetachDefaults()
        GroupsDetachedBridgeLedger.record(
            sub: "sub-mia", expenseIDs: ["g1"], settlementIDs: ["s1"], defaults: defaults)

        #expect(GroupsDetachedBridgeLedger.isConserved(
            expenseID: "g1", associatedSub: "sub-otra", defaults: defaults) == false)
        #expect(GroupsDetachedBridgeLedger.isConserved(
            expenseID: "g1", associatedSub: nil, defaults: defaults) == false)
    }

    /// **El libro se retira en el borrado de filas, no en el barrido de claves del corpus** (ticket
    /// `wipe-data-keeps-groups-but-drops-their-bridged-rows`). `removeRowDerivedKeys` corre también en el borrado del
    /// arranque tras cerrar sesión, que borra ficheros y cuyas filas pueden volver a bajar del espejo: allí el libro lo
    /// decide ese camino (lo retira cuando los grupos se van con la sesión). Quien lo retira al borrar filas es
    /// `wipeAllUserData`, y eso lo miden los casos de `GroupsBridgeRestoreConvergenceTests`.
    @MainActor
    @Test("el barrido de claves del corpus NO retira el libro: lo decide cada borrado")
    func rowDerivedSweep_keepsTheLedger() {
        let defaults = isolatedDetachDefaults()
        GroupsDetachedBridgeLedger.record(
            sub: "sub-mia", expenseIDs: ["g1"], settlementIDs: ["s1"], defaults: defaults)
        DataWipeService.removeRowDerivedKeys(from: defaults)
        #expect(GroupsDetachedBridgeLedger.isConserved(
            expenseID: "g1", associatedSub: "sub-mia", defaults: defaults))
    }

    @Test("Un gasto que no está en el libro nunca se frena")
    func gastoAjenoNoSeFrena() {
        let defaults = isolatedDetachDefaults()
        GroupsDetachedBridgeLedger.record(
            sub: "sub-mia", expenseIDs: ["g1"], settlementIDs: [], defaults: defaults)
        #expect(GroupsDetachedBridgeLedger.isConserved(
            expenseID: "g2", associatedSub: "sub-mia", defaults: defaults) == false)
    }

    @Test("Registrar otra cuenta REEMPLAZA el libro anterior")
    func registrarReemplaza() {
        let defaults = isolatedDetachDefaults()
        GroupsDetachedBridgeLedger.record(
            sub: "s1", expenseIDs: ["g1"], settlementIDs: [], defaults: defaults)
        GroupsDetachedBridgeLedger.record(
            sub: "s2", expenseIDs: ["g2"], settlementIDs: [], defaults: defaults)

        let libro = GroupsDetachedBridgeLedger.read(defaults: defaults)
        #expect(libro?.sub == "s2")
        #expect(libro?.expenseIDs == ["g2"])
    }

    @Test("Un libro vacío no se escribe, y un payload ilegible se descarta")
    func libroVacioYCorrupto() {
        let defaults = isolatedDetachDefaults()
        GroupsDetachedBridgeLedger.record(sub: "s", expenseIDs: [], settlementIDs: [], defaults: defaults)
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil)

        defaults.set(Data("no soy json".utf8), forKey: GroupsDetachedBridgeLedger.userDefaultsKey)
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil)
        #expect(defaults.data(forKey: GroupsDetachedBridgeLedger.userDefaultsKey) == nil, """
            Un payload ilegible se retira: conservarlo dejaría el bridge frenado sin forma de repararse,
            que es el lado peligroso.
            """)
    }
}
