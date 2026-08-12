//
//  LegacyGroupsRetirementTests.swift
//  YalaTests
//
//  C3 (§12 del SPEC del consent de Grupos): los grupos de la era CloudKit desaparecen. Cuatro bloques, y
//  cada uno cubre algo que los otros no pueden:
//    1. la DECISIÓN pura — y su POLARIDAD, que es la del barredor y no la del freeze (R5)
//    2. el PREDICADO por ZONA (ANY-row) — con el duplicado MIXTO montado a propósito: sin él, el escenario
//       limpio pasa igual sin el fix (R2)
//    3. el BARRIDO — las dos fases, la idempotencia y los tres tipos de borrador
//    4. el CABLEADO (source-scan) — el call-site del arranque, la prohibición de las mecánicas
//       destructivas y el seed, que es lo que sostiene los 22 XCUITest de Grupos (R12)
//
//  Harness ON-DISK con los 3 stores (molde `GroupRemoteDeletionUnbridgeTests`): la retirada cruza stores
//  —lee Grupos y escribe el PERSONAL— y `makeTestContext()` no sirve para eso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Infra compartida

@MainActor
private enum RetirementHarness {

    static func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LGR-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    static func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "LGR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "LGR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "LGR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    /// Grupo de la era CloudKit: ni `isBackendGroup` ni `movedToBackendAt`. Es lo que el seed acuñaba y lo
    /// que `GroupService.createGroup` producía hasta C4.
    @discardableResult
    static func makeLegacyGroup(
        zoneID: String, hidden: Bool = false, ckSystemFields: Data? = nil, context: ModelContext
    ) -> SplitGroup {
        let g = SplitGroup(name: "Viaje")
        g.cloudKitZoneID = zoneID
        g.isHiddenForAll = hidden
        g.ckSystemFieldsData = ckSystemFields
        context.insert(g)
        return g
    }

    @discardableResult
    static func makeBackendGroup(zoneID: String, context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "Piso")
        g.cloudKitZoneID = zoneID
        g.isBackendGroup = true
        context.insert(g)
        return g
    }

    /// La copia CONGELADA de un grupo migrado: el marcador viajó por CloudKit y el miembro aún no re-joineó.
    @discardableResult
    static func makeFrozenCopy(zoneID: String, context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "Migrado")
        g.cloudKitZoneID = zoneID
        g.movedToBackendAt = .now
        context.insert(g)
        return g
    }

    static func makeAccount(_ context: ModelContext, isSystem: Bool) -> Account {
        let a = Account(
            name: isSystem ? "Grupos" : "Efectivo", currencyCode: "USD", colorHex: "#111111",
            iconName: "banknote", type: "cash", isSystemAccount: isSystem)
        context.insert(a)
        return a
    }

    /// Una `TransactionItem` puenteada tal cual la deja el bridge (los tres punteros a la vez).
    /// `accountIsSystem: nil` = SIN cuenta, el caso donde las dos mecánicas existentes discrepan.
    @discardableResult
    static func makeBridgedTx(
        expenseID: UUID? = nil, settlementID: UUID? = nil, zone: String, amount: Double = 10,
        accountIsSystem: Bool? = true, context: ModelContext
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: .now, amount: amount, currencyCode: "USD",
            account: accountIsSystem.map { makeAccount(context, isSystem: $0) })
        tx.splitExpenseID = expenseID?.uuidString
        tx.splitSettlementID = settlementID?.uuidString
        tx.splitGroupZoneID = zone
        context.insert(tx)
        return tx
    }

    @discardableResult
    static func makeBridgedDraft(
        expenseID: UUID? = nil, settlementID: UUID? = nil, zone: String,
        needsUserInput: [String] = [DraftInputRequirement.account], context: ModelContext
    ) -> InboxDraft {
        let d = InboxDraft(
            note: "Cena", amount: 10, date: .now,
            sourceType: expenseID != nil ? .groupExpense : .groupSettlement,
            needsUserInput: needsUserInput,
            splitExpenseID: expenseID?.uuidString, splitGroupZoneID: zone,
            splitSettlementID: settlementID?.uuidString)
        context.insert(d)
        return d
    }

    /// Borrador de un PAGO PLANIFICADO de grupo: lleva zona pero ningún puntero de gasto, y su
    /// `sourceType` no lo mira `computeFreezePlan`.
    @discardableResult
    static func makeScheduledDraft(zone: String, context: ModelContext) -> InboxDraft {
        let d = InboxDraft(
            note: "Alquiler", amount: -100, date: .now,
            sourceType: .groupScheduledExpense, needsUserInput: [], splitGroupZoneID: zone)
        d.sourceScheduledPaymentID = UUID().uuidString
        context.insert(d)
        return d
    }

    @discardableResult
    static func makeExpense(id: UUID, zone: String, context: ModelContext) -> SplitExpense {
        let e = SplitExpense(
            groupZoneID: zone, amount: 30, currencyCode: "USD", paidByMemberID: UUID().uuidString)
        e.id = id
        context.insert(e)
        return e
    }

    static func txCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<TransactionItem>())
    }

    static func draftCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<InboxDraft>())
    }
}

// MARK: - Bloque 1 · la decisión pura y su polaridad

@Suite("Retirada de grupos legacy · decisión", .serialized)
@MainActor
struct LegacyGroupsRetirementDecisionTests {

    private func decide(legacy: Bool, system: Bool) -> LegacyGroupsRetirement.Action? {
        LegacyGroupsRetirement.decide(
            .init(zoneIsLegacy: legacy, accountIsSystem: system))
    }

    @Test func realAccountTx_isReleased() {
        #expect(decide(legacy: true, system: false) == .releasePointers)
    }

    @Test func virtualMirror_isDeleted() {
        #expect(decide(legacy: true, system: true) == .deleteVirtual)
    }

    /// Una zona con canal vivo no se toca, diga lo que diga la cuenta.
    @Test func zoneWithChannel_isNeverTouched() {
        #expect(decide(legacy: false, system: false) == nil)
        #expect(decide(legacy: false, system: true) == nil)
    }

    /// **R5, y es la aserción que carga el peso del chip.** La polaridad es la del BARREDOR —real: liberar;
    /// virtual: borrar— y NO la del freeze, que conserva el espejo virtual INTACTO. En una zona legacy el
    /// barredor ya no puede limpiarlos después (`OrphanedBridgedTxSweeper.zoneIsSweepable` corta con
    /// `guard status.belongsToBackendChannel` antes de mirar la frescura), así que elegir el freeze deja
    /// fantasmas permanentes y sin canario.
    @Test func polarity_matchesTheSweeper() {
        for system in [true, false] {
            let mine = decide(legacy: true, system: system)
            let sweeper = OrphanedBridgedTxSweeper.decide(
                .init(expensePointerIsOrphan: true, settlementPointerIsOrphan: false,
                      accountIsSystem: system, zoneEvidenceIsFresh: true))
            switch (mine, sweeper) {
            case (.releasePointers, .releasePointers), (.deleteVirtual, .deleteVirtual):
                break
            default:
                Issue.record("La polaridad divergió del barredor para accountIsSystem=\(system): \(String(describing: mine)) vs \(String(describing: sweeper))")
            }
        }
    }

    /// **Y es la INVERSA del freeze para el espejo virtual.** Escrito aparte porque es la mitad que un
    /// «unifiquemos las dos limpiezas» rompería sin que ninguna otra aserción cayera: el freeze excluye la
    /// virtual de su plan (la preserva) y aquí se borra.
    @Test func polarity_divergesFromTheFreeze_forTheVirtualMirror() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        let virtual = RetirementHarness.makeBridgedTx(
            expenseID: UUID(), zone: "Z", accountIsSystem: true, context: ctx)
        try ctx.save()

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [virtual], drafts: [])
        #expect(plan.txsToRelease.isEmpty, "El freeze dejó de preservar la virtual; esta comparación ya no mide nada.")
        #expect(LegacyGroupsRetirement.decide(.init(zoneIsLegacy: true, accountIsSystem: true)) == .deleteVirtual)
    }

    /// `account == nil` → REAL (conservar). Hay que fijarlo porque las dos mecánicas existentes discrepan
    /// justo ahí, y la dirección segura es preservar el rastro.
    @Test func txWithoutAccount_countsAsReal() {
        #expect(decide(legacy: true, system: false) == .releasePointers)
    }
}

// MARK: - Bloque 2 · el predicado por ZONA (ANY-row)

@Suite("Retirada de grupos legacy · qué zona es legacy", .serialized)
@MainActor
struct LegacyGroupsRetirementZoneTests {

    @Test func zoneWithOnlyLegacyRows_isLegacy() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        try ctx.save()

        #expect(Set(LegacyGroupsRetirement.legacyZones(context: ctx).keys) == ["Z1"])
    }

    @Test func backendZone_isNotLegacy() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeBackendGroup(zoneID: "Z1", context: ctx)
        try ctx.save()

        #expect(LegacyGroupsRetirement.legacyZones(context: ctx).isEmpty)
    }

    /// La copia CONGELADA (`movedToBackendAt != nil`, `isBackendGroup == false`) pertenece al canal por
    /// RETENCIÓN: su verdad se mudó al servidor y su miembro puede volver a entrar.
    @Test func frozenCopy_isNotLegacy() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeFrozenCopy(zoneID: "Z1", context: ctx)
        try ctx.save()

        #expect(LegacyGroupsRetirement.legacyZones(context: ctx).isEmpty)
    }

    /// **R2 · el duplicado MIXTO, montado a propósito.** Dos `SplitGroup` con el MISMO `cloudKitZoneID`, uno
    /// backend y otro no — el estado que `SplitGroupDeduplicationService` documenta y que nacía cuando el
    /// canal CloudKit insertaba una gemela sin `isBackendGroup`. Con el predicado por FILA la gemela legacy
    /// se retira y se lleva por delante el puente de un grupo VIVO; con ANY-row la zona entera se salva.
    /// Sin este test el escenario limpio pasa igual sin el fix.
    @Test func mixedDuplicateZone_isNotLegacy() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        RetirementHarness.makeBackendGroup(zoneID: "Z1", context: ctx)
        try ctx.save()

        #expect(LegacyGroupsRetirement.legacyZones(context: ctx).isEmpty)
    }

    @Test func mixedStore_separatesTheTwoWorlds() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "LEGACY", context: ctx)
        RetirementHarness.makeBackendGroup(zoneID: "BACKEND", context: ctx)
        RetirementHarness.makeFrozenCopy(zoneID: "FROZEN", context: ctx)
        try ctx.save()

        #expect(Set(LegacyGroupsRetirement.legacyZones(context: ctx).keys) == ["LEGACY"])
    }
}

// MARK: - Bloque 3 · el barrido

@Suite("Retirada de grupos legacy · barrido", .serialized)
@MainActor
struct LegacyGroupsRetirementSweepTests {

    @Test func emptyStore_isNoOp() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)

        #expect(LegacyGroupsRetirement.retire(context: ctx).isEmpty)
    }

    /// El caso central: el grupo se oculta, el dinero REAL se queda como transacción personal editable y el
    /// espejo virtual desaparece.
    @Test func retire_hidesGroup_releasesReal_deletesVirtual() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        let group = RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        let expenseID = UUID()
        let real = RetirementHarness.makeBridgedTx(
            expenseID: expenseID, zone: "Z1", amount: 40, accountIsSystem: false, context: ctx)
        RetirementHarness.makeBridgedTx(
            expenseID: expenseID, zone: "Z1", amount: 20, accountIsSystem: true, context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.groupsHidden == 1)
        #expect(outcome.released == 1)
        #expect(outcome.deleted == 1)
        #expect(group.isHiddenForAll)
        #expect(try RetirementHarness.txCount(ctx) == 1, "El espejo virtual sigue ahí (o se llevó la real).")
        #expect(real.splitExpenseID == nil)
        #expect(real.splitSettlementID == nil)
        #expect(real.splitGroupZoneID == nil)
        // Lo que hace que la liberada siga siendo útil: conserva el hecho financiero.
        #expect(real.amount == 40)
        #expect(real.account != nil)
    }

    @Test func retire_handlesSettlementPointers() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        let settlementID = UUID()
        let real = RetirementHarness.makeBridgedTx(
            settlementID: settlementID, zone: "Z1", accountIsSystem: false, context: ctx)
        RetirementHarness.makeBridgedTx(
            settlementID: settlementID, zone: "Z1", accountIsSystem: true, context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.released == 1)
        #expect(outcome.deleted == 1)
        #expect(real.splitSettlementID == nil)
    }

    /// `account == nil` → se CONSERVA liberada. Borrarla por no poder clasificarla sería destruir un rastro
    /// que puede ser dinero real.
    @Test func retire_txWithoutAccount_isReleasedNotDeleted() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        let orphanAccount = RetirementHarness.makeBridgedTx(
            expenseID: UUID(), zone: "Z1", accountIsSystem: nil, context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.released == 1)
        #expect(outcome.deleted == 0)
        #expect(try RetirementHarness.txCount(ctx) == 1)
        #expect(orphanAccount.splitGroupZoneID == nil)
    }

    /// Una zona con canal vivo no se toca: ni su grupo se oculta ni su puente se suelta.
    @Test func retire_sparesBackendZone() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        let group = RetirementHarness.makeBackendGroup(zoneID: "Z1", context: ctx)
        let tx = RetirementHarness.makeBridgedTx(
            expenseID: UUID(), zone: "Z1", accountIsSystem: true, context: ctx)
        try ctx.save()

        #expect(LegacyGroupsRetirement.retire(context: ctx).isEmpty)
        #expect(!group.isHiddenForAll)
        #expect(tx.splitGroupZoneID == "Z1")
        #expect(try RetirementHarness.txCount(ctx) == 1)
    }

    /// **R2 end-to-end.** Con el predicado por fila, la gemela legacy de la zona mixta se retiraría y el
    /// espejo virtual de un grupo VIVO se borraría.
    @Test func retire_sparesMixedDuplicateZone_whileRetiringTheLegacyOne() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        let legacyTwin = RetirementHarness.makeLegacyGroup(zoneID: "MIXTA", context: ctx)
        RetirementHarness.makeBackendGroup(zoneID: "MIXTA", context: ctx)
        let liveMirror = RetirementHarness.makeBridgedTx(
            expenseID: UUID(), zone: "MIXTA", accountIsSystem: true, context: ctx)
        let deadGroup = RetirementHarness.makeLegacyGroup(zoneID: "LEGACY", context: ctx)
        RetirementHarness.makeBridgedTx(
            expenseID: UUID(), zone: "LEGACY", accountIsSystem: true, context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.groupsHidden == 1)
        #expect(outcome.deleted == 1)
        #expect(!legacyTwin.isHiddenForAll, "La gemela legacy de una zona MIXTA se ocultó: el predicado volvió a ser por fila.")
        #expect(deadGroup.isHiddenForAll)
        #expect(liveMirror.splitGroupZoneID == "MIXTA", "Se tocó el puente de un grupo vivo.")
        #expect(try RetirementHarness.txCount(ctx) == 1)
    }

    /// Idempotente y sin sentinel: la segunda pasada no encuentra nada.
    @Test func retire_isIdempotent() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        let expenseID = UUID()
        RetirementHarness.makeBridgedTx(
            expenseID: expenseID, zone: "Z1", accountIsSystem: false, context: ctx)
        RetirementHarness.makeBridgedTx(
            expenseID: expenseID, zone: "Z1", accountIsSystem: true, context: ctx)
        RetirementHarness.makeBridgedDraft(expenseID: expenseID, zone: "Z1", context: ctx)
        try ctx.save()

        let first = LegacyGroupsRetirement.retire(context: ctx)
        #expect(!first.isEmpty)

        let second = LegacyGroupsRetirement.retire(context: ctx)
        #expect(second.isEmpty, "La segunda pasada volvió a trabajar: el barrido no converge.")
        #expect(try RetirementHarness.txCount(ctx) == 1)
        #expect(try RetirementHarness.draftCount(ctx) == 1)
    }

    /// El borrador de grupo pasa a `.manual` preservando lo que el usuario ya tenía.
    @Test func retire_convertsGroupDraftToManual() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        let draft = RetirementHarness.makeBridgedDraft(expenseID: UUID(), zone: "Z1", context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.draftsConverted == 1)
        #expect(draft.sourceTypeRaw == DraftSourceType.manual.rawValue)
        #expect(draft.splitGroupZoneID == nil)
        #expect(draft.splitExpenseID == nil)
        #expect(draft.needsUserInput.isEmpty)
        #expect(draft.amount == 10, "La conversión perdió lo que el usuario ya había puesto.")
    }

    /// **La mitad que prueba que las DOS FASES están separadas.** Un draft-puntero de clasificación
    /// (`[.subcategory]`, apunta a una TX que existe) tiene que BORRARSE, no convertirse: convertido a
    /// `.manual`, aprobarlo insertaría una `TransactionItem` NUEVA junto a la recién liberada = gasto
    /// DUPLICADO. Y esa comparación solo puede salir bien si el plan se calcula ANTES de nilear punteros:
    /// mutando primero, `transactions.contains(where: splitExpenseID == …)` da `false` siempre.
    @Test func retire_deletesRedundantPointerDraft_insteadOfConvertingIt() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        let expenseID = UUID()
        RetirementHarness.makeBridgedTx(
            expenseID: expenseID, zone: "Z1", accountIsSystem: false, context: ctx)
        RetirementHarness.makeBridgedDraft(
            expenseID: expenseID, zone: "Z1",
            needsUserInput: [DraftInputRequirement.subcategory], context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.draftsDeleted == 1)
        #expect(outcome.draftsConverted == 0)
        #expect(try RetirementHarness.draftCount(ctx) == 0)
    }

    /// El TERCER tipo de borrador, el que `computeFreezePlan` no mira: sin esto sobrevive apuntando a una
    /// zona muerta.
    @Test func retire_convertsScheduledGroupDraft() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        let draft = RetirementHarness.makeScheduledDraft(zone: "Z1", context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.draftsConverted == 1)
        #expect(draft.sourceTypeRaw == DraftSourceType.manual.rawValue)
        #expect(draft.splitGroupZoneID == nil)
    }

    /// **El grupo legacy que el usuario ya había ocultado con soft-delete.** Su freeze conservó el espejo
    /// virtual INTACTO, y el barredor de huérfanas jamás podrá tocarlo (excluye las zonas sin canal): es el
    /// fantasma permanente que el contrato de salida de C3 nombra. Se retira igual aunque ya esté oculto.
    @Test func retire_clearsGhostMirrorsOfAnAlreadyHiddenLegacyGroup() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", hidden: true, context: ctx)
        RetirementHarness.makeBridgedTx(
            expenseID: UUID(), zone: "Z1", accountIsSystem: true, context: ctx)
        try ctx.save()

        let outcome = LegacyGroupsRetirement.retire(context: ctx)

        #expect(outcome.groupsHidden == 0, "Contó como oculto uno que ya lo estaba: el barrido salvaría en cada arranque.")
        #expect(outcome.deleted == 1)
        #expect(try RetirementHarness.txCount(ctx) == 0)
    }

    /// **La fila `SplitGroup` se CONSERVA.** Borrarla deja `zoneHasSettledGroup == false` ⇒ el gate de
    /// frescura devuelve `.noSettledGroup` ⇒ el editor DESHABILITA Borrar y Duplicar sobre un gasto que ya
    /// no existe: el dinero fantasma ATRAPADO, que es el bug que este chip no puede reintroducir.
    @Test func retire_neverDeletesTheGroupRow() throws {
        let dir = RetirementHarness.freshDir()
        defer { RetirementHarness.cleanup(dir) }
        let ctx = try RetirementHarness.makeContext(dir)
        RetirementHarness.makeLegacyGroup(zoneID: "Z1", context: ctx)
        RetirementHarness.makeExpense(id: UUID(), zone: "Z1", context: ctx)
        RetirementHarness.makeBridgedTx(
            expenseID: UUID(), zone: "Z1", accountIsSystem: false, context: ctx)
        try ctx.save()

        LegacyGroupsRetirement.retire(context: ctx)

        #expect(try ctx.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(try ctx.fetchCount(FetchDescriptor<SplitExpense>()) == 1,
                "Se cascadearon las hijas: fuera del alcance de C3 y sin nadie que las eche de menos.")
    }
}

// MARK: - Bloque 4 · cableado (source-scan)

@Suite("Retirada de grupos legacy · cableado de producción (source-scan)")
struct LegacyGroupsRetirementWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Solo CÓDIGO: la cabecera de la retirada NOMBRA las mecánicas prohibidas para explicar por qué lo
    /// están, y contar prosa haría que documentar el invariante lo rompiera.
    private static func codeLines(_ src: String) -> [String] {
        src.components(separatedBy: "\n")
            .filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.hasPrefix("//") && !t.hasPrefix("///") && !t.hasPrefix("*")
            }
    }

    /// Sin call-site sería una reparación que nunca corre — la familia de
    /// `AppAttestClient.ensureRegistered()`.
    @Test func retirement_isWiredIntoBootstrap() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        #expect(src.contains("LegacyGroupsRetirement.retire(context: context)"),
                "La retirada de grupos legacy perdió su call-site en el arranque.")
        #expect(src.contains("SaveBreadcrumb.deferred(\"AppBootstrapper.legacyGroupsRetirement\""),
                "La retirada dejó de estar gateada por la quiescencia del import personal.")
    }

    /// **R5.** Ninguna de las cuatro mecánicas que BORRAN la transacción de cuenta real puede aparecer en
    /// este camino. `deleteBridgedTransactions` es la peor: borra la real y conserva el fantasma.
    @Test func retirement_neverUsesTheDestructiveMechanics() throws {
        let code = Self.codeLines(try Self.source("Yala/Services/Groups/LegacyGroupsRetirement.swift"))
            .joined(separator: "\n")
        for symbol in ["unbridgeExpense(", "unbridgeSettlement(", "unbridgeDeletedRemotely(",
                       "deleteBridgedTransactions("] {
            #expect(!code.contains(symbol),
                    "`\(symbol)` entró en la retirada: destruye la transacción de cuenta REAL.")
        }
        #expect(!code.contains("freezeForSoftDelete("),
                "La retirada delegó en el freeze: conservaría el espejo virtual como fantasma permanente.")
    }

    /// **Las dos fases, en este orden.** El plan de borradores se calcula con los punteros intactos; mutar
    /// antes hace que `computeFreezePlan` mande TODOS los punteros-de-clasificación a `.manual` y aprobarlos
    /// duplica el gasto. Ningún test de comportamiento lo caza si el escenario no lleva un draft-puntero.
    @Test func retirement_classifiesBeforeMutating() throws {
        let src = try Self.source("Yala/Services/Groups/LegacyGroupsRetirement.swift")
        let body = try #require(
            src.components(separatedBy: "static func retire(context: ModelContext) -> Outcome {")
                .dropFirst().first,
            "`retire(context:)` cambió de firma; este scan dejó de medir nada.")
        let plan = try #require(body.range(of: "computeFreezePlan(")?.lowerBound,
                                "La retirada dejó de calcular el plan de borradores.")
        // La PRIMERA mutación de cualquiera de las dos formas: nilear el puntero (que es justo el campo que
        // `computeFreezePlan` compara) o borrar la fila.
        let mutations = ["splitExpenseID = nil", "context.delete("]
            .compactMap { body.range(of: $0)?.lowerBound }
        #expect(!mutations.isEmpty, "El scan dejó de encontrar la fase de aplicar; ya no mide nada.")
        for mutation in mutations {
            #expect(plan < mutation,
                    "La clasificación se movió por debajo de la mutación: gasto DUPLICADO al aprobar borradores.")
        }
    }

    /// **R12 · lo que sostiene los 22 XCUITest de Grupos.** El seed acuñaba grupos LEGACY (el default del
    /// modelo es `false`), así que sin esto la retirada los oculta en el arranque siguiente y nueve ficheros
    /// de XCUITest se quedan sin datos. Un `isBackendGroup = true` por cada `SplitGroup(` construido.
    @Test func devSeed_createsBackendGroups() throws {
        let code = Self.codeLines(try Self.source("Yala/Seed/DevSeedGroups.swift"))
        let constructions = code.filter { $0.contains("SplitGroup(") }.count
        let marks = code.filter { $0.contains("isBackendGroup = true") }.count
        #expect(constructions == 3, "Cambió el número de grupos del seed; revisa que todos sigan siendo backend.")
        #expect(marks == constructions,
                "Un grupo del seed volvió a nacer legacy: la retirada lo oculta y los XCUITest de Grupos se quedan sin datos.")
    }

    /// El caveat GDPR no se apaga al ocultar: `hasLegacy` mira TODOS los grupos.
    @Test func legacyFootprint_isComputedOverAllGroups() throws {
        let src = try Self.source("Yala/Services/Groups/GroupService.swift")
        #expect(src.contains("let hasLegacy = allGroups.contains { $0.ckSystemFieldsData != nil }"),
                "`hasLegacy` volvió a filtrar por `isHiddenForAll`: retirar los legacy apaga el aviso de la huella CloudKit sin borrarla.")
    }
}
