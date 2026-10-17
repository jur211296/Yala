//
//  GroupLegWithoutAccountTests.swift
//  YalaTests
//
//  Una pata de grupo SIN cuenta: la real sale en el aviso «Movimientos sin cuenta» y se devuelve a una cuenta; la
//  virtual nunca se convierte en real. Ticket `orphaned-group-records-stay-out-of-the-notice`.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID` y vacía el store en cada llamada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - La regla pura

@MainActor
@Suite("Pata de grupo sin cuenta · la regla")
struct GroupLegKindLogicTests {

    private func leg(
        account: Bool? = nil, sub: GroupLegKindLogic.SubcategoryClass = .none, settlement: Bool = false,
        amount: Double = -60, currency: String = "PEN", source: GroupLegKindLogic.SourceEvidence? = nil
    ) -> GroupLegKindLogic.LegShape {
        .init(accountIsSystem: account, subcategory: sub, isSettlementLeg: settlement,
              amount: amount, currencyCode: currency, source: source)
    }

    private func paid(
        _ paid: Bool = true, amount: Double = 60, currency: String = "PEN",
        opening: Bool = false, realSibling: Bool = false
    ) -> GroupLegKindLogic.SourceEvidence {
        .init(currentUserPaid: paid, isOpeningBalance: opening, amount: amount,
              currencyCode: currency, siblingHasRealAccount: realSibling)
    }

    @Test("Con cuenta, manda la cuenta")
    func conCuenta_mandaLaCuenta() {
        #expect(GroupLegKindLogic.classify(leg(account: true)) == .virtual)
        #expect(GroupLegKindLogic.classify(leg(account: false)) == .real)
    }

    @Test("Sin cuenta y subcategoría de sistema de las virtuales: virtual")
    func sinCuenta_subcatDeVirtual_esVirtual() {
        #expect(GroupLegKindLogic.classify(leg(sub: .otherSystem, amount: 40)) == .virtual)
        #expect(GroupLegKindLogic.classify(leg(sub: .otherSystem, settlement: true)) == .virtual)
    }

    @Test("«Liquidación enviada» es real solo en una liquidación, y sin borrador pendiente suyo")
    func liquidacionEnviada() {
        #expect(GroupLegKindLogic.classify(leg(sub: .settlementSent, settlement: true)) == .real)
        #expect(GroupLegKindLogic.classify(leg(sub: .settlementSent, settlement: false)) == .unknown)
        var pending = leg(sub: .settlementSent, settlement: true)
        pending.settlementHasPendingDraft = true
        #expect(GroupLegKindLogic.classify(pending) == .unknown)
    }

    @Test("Pata real de un gasto que pagué: -total en su divisa, sin otra real al lado")
    func pataRealProbada() {
        #expect(GroupLegKindLogic.classify(leg(source: paid())) == .real)
        #expect(GroupLegKindLogic.classify(leg(sub: .user, source: paid())) == .real)
        // El medio céntimo de tolerancia, por los dos lados.
        #expect(GroupLegKindLogic.classify(leg(amount: -60.004, source: paid())) == .real)
        #expect(GroupLegKindLogic.classify(leg(amount: -60.01, source: paid())) == .unknown)
    }

    @Test("Lo que no prueba la pata real es «no se sabe»", arguments: [
        ("sin gasto aquí", nil as GroupLegKindLogic.SourceEvidence?, -60.0),
        ("pagó otro (la -miParte del Caso B)", GroupLegKindLogic.SourceEvidence(
            currentUserPaid: false, isOpeningBalance: false, amount: 60, currencyCode: "PEN",
            siblingHasRealAccount: false), -60.0),
        ("la -miParte de un gasto que pagué", GroupLegKindLogic.SourceEvidence(
            currentUserPaid: true, isOpeningBalance: false, amount: 60, currencyCode: "PEN",
            siblingHasRealAccount: false), -20.0),
        ("ya hay una pata real con cuenta", GroupLegKindLogic.SourceEvidence(
            currentUserPaid: true, isOpeningBalance: false, amount: 60, currencyCode: "PEN",
            siblingHasRealAccount: true), -60.0),
        ("saldo inicial", GroupLegKindLogic.SourceEvidence(
            currentUserPaid: true, isOpeningBalance: true, amount: 60, currencyCode: "PEN",
            siblingHasRealAccount: false), -60.0),
        ("otra divisa", GroupLegKindLogic.SourceEvidence(
            currentUserPaid: true, isOpeningBalance: false, amount: 60, currencyCode: "USD",
            siblingHasRealAccount: false), -60.0),
    ])
    func noProbada(_ caso: String, _ source: GroupLegKindLogic.SourceEvidence?, _ amount: Double) {
        #expect(GroupLegKindLogic.classify(leg(amount: amount, source: source)) == .unknown, "\(caso)")
    }

    @Test("Una liquidación sin «Liquidación enviada» no se prueba real por importe")
    func liquidacionSinSubcatDeEnviada_noSeSabe() {
        #expect(GroupLegKindLogic.classify(leg(settlement: true, source: paid())) == .unknown)
    }

    @Test("Barredor: «no se sabe» no se toca; virtual se borra; real se suelta")
    func barredor() {
        func decide(_ kind: GroupLegKindLogic.Kind) -> OrphanedBridgedTxSweeper.Action? {
            OrphanedBridgedTxSweeper.decide(.init(
                expensePointerIsOrphan: true, settlementPointerIsOrphan: false, leg: kind, zoneEvidenceIsFresh: true))
        }
        #expect(decide(.unknown) == nil)
        #expect(decide(.virtual) == .deleteVirtual)
        #expect(decide(.real) == .releasePointers)
    }

    @Test("Desasociar: «no se sabe» con conservar no se toca; con quitar se va")
    func desasociar() {
        #expect(GroupsAssociationDetach.action(leg: .unknown, choice: .keep) == .leaveUntouched)
        #expect(GroupsAssociationDetach.action(leg: .unknown, choice: .remove) == .delete)
        #expect(GroupsAssociationDetach.action(leg: .virtual, choice: .keep) == .delete)
        #expect(GroupsAssociationDetach.action(leg: .real, choice: .keep) == .releasePointers)
    }

    @Test("Retirada de legacy: «no se sabe» no se toca")
    func retirada() {
        #expect(LegacyGroupsRetirement.decide(.init(zoneIsLegacy: true, leg: .unknown)) == nil)
        #expect(LegacyGroupsRetirement.decide(.init(zoneIsLegacy: true, leg: .virtual)) == .deleteVirtual)
        #expect(LegacyGroupsRetirement.decide(.init(zoneIsLegacy: true, leg: .real)) == .releasePointers)
    }
}

// MARK: - Con el store: el aviso, el barredor y el desasociar

@MainActor
@Suite("Pata de grupo sin cuenta · con el store", .serialized)
struct GroupLegWithoutAccountStoreTests {

    private struct Fixture {
        let context: ModelContext
        let zone: String
        let me: SplitMember
        let other: SplitMember
        let cash: Account
        let bank: Account
        let usd: Account
        let groups: Account
        let category: YalaCategory
        let sub: Subcategory
    }

    private static let day = "2026-06-15"

    private func date() -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: Self.day + " 12:00") ?? Date()
    }

    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        for key in [Self.day, todayKey()] {
            _ = try makeTestExchangeRate(context: context, dateKey: key, rates: ["USD": 1.0, "PEN": 4.0])
        }
        let zone = "zona-\(UUID().uuidString)"
        let group = SplitGroup(name: "Viaje", currencyCode: "PEN")
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        context.insert(group)
        let me = SplitMember(groupZoneID: zone, displayName: "Yo", isCurrentUser: true)
        let other = SplitMember(groupZoneID: zone, displayName: "Ana")
        context.insert(me)
        context.insert(other)
        let groups = makeTestAccount(context: context, name: "Grupos", currencyCode: "PEN")
        groups.isSystemAccount = true
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let fixture = Fixture(
            context: context, zone: zone, me: me, other: other,
            cash: makeTestAccount(context: context, name: "Efectivo", currencyCode: "PEN"),
            bank: makeTestAccount(context: context, name: "Banco", currencyCode: "PEN"),
            usd: makeTestAccount(context: context, name: "Dólares", currencyCode: "USD"),
            groups: groups, category: category, sub: sub)
        try context.save()
        return fixture
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: .now)
    }

    private func expense(_ f: Fixture, amount: Double = 60, paidBy: SplitMember) -> SplitExpense {
        let e = SplitExpense(groupZoneID: f.zone, amount: amount, currencyCode: "PEN",
                             expenseDescription: "Cena", date: date(), paidByMemberID: paidBy.id.uuidString)
        f.context.insert(e)
        return e
    }

    @discardableResult
    private func leg(
        _ f: Fixture, _ amount: Double, account: Account?, expense: SplitExpense? = nil,
        settlementID: String? = nil, subcategory: Subcategory? = nil, note: String
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date(), amount: amount, currencyCode: "PEN", note: note,
            category: (subcategory ?? f.sub).safeCategory, subcategory: subcategory ?? f.sub, account: account)
        tx.splitExpenseID = expense?.id.uuidString
        tx.splitSettlementID = settlementID
        tx.splitGroupZoneID = f.zone
        f.context.insert(tx)
        return tx
    }

    private func orphanNotes(_ f: Fixture) throws -> Set<String> {
        Set(try OrphanedRecordsService.inventory(context: f.context).transactions.compactMap(\.note))
    }

    // MARK: El aviso

    /// El caso del ticket: pagué la cena (pata real -60 en «Efectivo», préstamo +40 en «Grupos») y eliminé
    /// «Efectivo» antes de la 2.1. La pata real se queda sin cuenta, fuera del saldo, y ahora el aviso la ve.
    @Test func pataRealSinCuenta_saleEnElAviso() throws {
        let f = try makeFixture()
        let e = expense(f, paidBy: f.me)
        let loan = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: f.context)
        leg(f, -60, account: f.cash, expense: e, note: "Cena (real)")
        leg(f, 40, account: f.groups, expense: e, subcategory: loan, note: "Cena (préstamo)")
        try f.context.save()
        f.context.delete(f.cash)
        try f.context.save()

        #expect(try orphanNotes(f) == ["Cena (real)"])
    }

    /// Moverla la devuelve al saldo SIN soltar su puntero (sigue siendo la pata real del gasto: el puente la reconoce)
    /// y sin cambiarle la divisa aunque el destino sea otra.
    @Test func pataRealSinCuenta_seMueve_conservaElPuntero_yNoSeConvierte() async throws {
        let f = try makeFixture()
        let e = expense(f, paidBy: f.me)
        let real = leg(f, -60, account: f.cash, expense: e, note: "Cena (real)")
        try f.context.save()
        f.context.delete(f.cash)
        try f.context.save()

        let inventory = try OrphanedRecordsService.inventory(context: f.context)
        #expect(inventory.outcome(to: f.usd).groupKeptInTheirCurrency == 1)
        #expect(inventory.outcome(to: f.usd).keptInTheirCurrency == 0, "la nota de las transferencias no habla de esta")
        OrphanedRecordsService.prepareRatesOverride = { _, _ in true }
        defer { OrphanedRecordsService.prepareRatesOverride = nil }
        let moved = try await OrphanedRecordsService.move(
            Set(inventory.transactions.map(\.persistentModelID)), to: f.usd, context: f.context)

        #expect(moved == 1)
        #expect(real.account?.persistentModelID == f.usd.persistentModelID)
        #expect(real.splitExpenseID == e.id.uuidString)
        #expect(real.splitGroupZoneID == f.zone)
        #expect(real.amount == -60)
        #expect(real.currencyCode == "PEN")
        #expect(try orphanNotes(f).isEmpty)
    }

    /// H1 de la review: mientras la pata real estaba sin cuenta, un re-puente dejó en la Bandeja «¿de qué cuenta salió?».
    /// Moverla re-puentea el gasto: el borrador se va, y aprobarlo ya no puede crear una segunda pata real.
    @Test func moverLaPataReal_retiraElBorradorQuePedíaSuCuenta() async throws {
        let f = try makeFixture()
        GroupTransactionBridge.shared.setContext(f.context)
        defer { GroupTransactionBridge.shared._testClearContext() }
        let e = expense(f, paidBy: f.me)
        let real = leg(f, -60, account: f.cash, expense: e, note: "Cena (real)")
        let askAccount = InboxDraft(
            note: "Cena", amount: -60, date: date(), account: nil, subcategory: nil, sourceType: .groupExpense,
            confidenceAmount: 1, confidenceDate: 1, confidenceMerchant: 1, confidenceSubcategory: nil,
            needsUserInput: [DraftInputRequirement.account], splitExpenseID: e.id.uuidString,
            splitGroupZoneID: f.zone, splitSettlementID: nil, targetTransactionID: nil)
        f.context.insert(askAccount)
        try f.context.save()
        f.context.delete(f.cash)
        try f.context.save()

        let inventory = try OrphanedRecordsService.inventory(context: f.context)
        #expect(inventory.transactions.map(\.persistentModelID) == [real.persistentModelID])
        try await OrphanedRecordsService.move(
            Set(inventory.transactions.map(\.persistentModelID)), to: f.bank, context: f.context)

        let expenseID = e.id.uuidString
        let pending = try f.context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.splitExpenseID == expenseID && $0.statusRaw == "pending" }))
        #expect(pending.isEmpty, "el borrador que pedía la cuenta sigue: aprobarlo crearía otra pata real")
        let legs = try f.context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { $0.splitExpenseID == expenseID }))
        #expect(legs.filter { $0.account?.isSystemAccount == false }.count == 1, "una sola pata real")
        #expect(real.account?.persistentModelID == f.bank.persistentModelID)
    }

    /// La pata real de una liquidación con un borrador pendiente («¿a qué cuenta llegó?») no entra: la salida es la
    /// Bandeja, y moverla además contaría el pago dos veces.
    @Test func pataRealDeLiquidacion_conBorradorPendiente_noSale() throws {
        let f = try makeFixture()
        let sent = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementSent, context: f.context)
        let settlementID = UUID().uuidString
        leg(f, -15, account: f.cash, settlementID: settlementID, subcategory: sent, note: "Liquidación (real)")
        let draft = InboxDraft(
            note: "Liquidación", amount: -15, date: date(), account: nil, subcategory: sent,
            sourceType: .groupSettlement, confidenceAmount: 1, confidenceDate: 1, confidenceMerchant: 1,
            confidenceSubcategory: 1, needsUserInput: [DraftInputRequirement.account], splitExpenseID: nil,
            splitGroupZoneID: f.zone, splitSettlementID: settlementID, targetTransactionID: nil)
        f.context.insert(draft)
        try f.context.save()
        f.context.delete(f.cash)
        try f.context.save()

        #expect(try orphanNotes(f).isEmpty)
    }

    /// La otra mitad del ticket: una pata VIRTUAL cuya cuenta «Grupos» no está nunca entra en el aviso, ni la -miParte
    /// de un gasto que pagó otro, ni el préstamo con su subcategoría de sistema.
    @Test func pataVirtualSinCuenta_nuncaSaleEnElAviso() throws {
        let f = try makeFixture()
        let paidByOther = expense(f, paidBy: f.other)
        let paidByMe = expense(f, amount: 90, paidBy: f.me)
        let loan = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: f.context)
        leg(f, -60, account: f.groups, expense: paidByOther, note: "miParte (pagó otro, = total)")
        leg(f, -30, account: f.groups, expense: paidByMe, note: "miParte (pagué yo)")
        leg(f, 60, account: f.groups, expense: paidByMe, subcategory: loan, note: "préstamo")
        try f.context.save()
        f.context.delete(f.groups)
        try f.context.save()

        #expect(try orphanNotes(f).isEmpty)
    }

    /// Con la pata real todavía en su cuenta, una fila sin cuenta del mismo gasto no se prueba real: sería la segunda.
    @Test func conLaPataRealConCuenta_laSinCuentaNoSale() throws {
        let f = try makeFixture()
        let e = expense(f, paidBy: f.me)
        leg(f, -60, account: f.bank, expense: e, note: "real con cuenta")
        leg(f, -60, account: nil, expense: e, note: "sin cuenta, mismo importe")
        try f.context.save()

        #expect(try orphanNotes(f).isEmpty)
    }

    /// La pata real de una liquidación que pagué lleva «Liquidación enviada»: sin cuenta, sale.
    @Test func pataRealDeLiquidacionSinCuenta_sale() throws {
        let f = try makeFixture()
        let sent = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementSent, context: f.context)
        let payoff = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementPayment, context: f.context)
        let settlementID = UUID().uuidString
        leg(f, -15, account: f.cash, settlementID: settlementID, subcategory: sent, note: "Liquidación (real)")
        leg(f, 15, account: f.groups, settlementID: settlementID, subcategory: payoff, note: "Liquidación (virtual)")
        try f.context.save()
        f.context.delete(f.cash)
        f.context.delete(f.groups)
        try f.context.save()

        #expect(try orphanNotes(f) == ["Liquidación (real)"])
    }

    /// El Panel cuenta lo mismo que la hoja: su recuento es `OrphanedRecordsService.orphanCount` sobre sus movimientos.
    /// Se llama directo y se fija el cableado aparte: montar un `PanelViewModel` con este corpus de grupos dejaba trabajo
    /// en vuelo que, en la suite completa, retrasaba el cierre del store de `SpikeR3ContainerReleaseTests` (medido el
    /// 2026-10-16: 3 descriptores abiertos en su eje 4a, verde en cuanto se saltaba este caso).
    @Test func panel_cuentaLaPataRealSinCuenta() throws {
        let f = try makeFixture()
        let e = expense(f, paidBy: f.me)
        leg(f, -60, account: f.cash, expense: e, note: "Cena (real)")
        leg(f, -20, account: f.groups, expense: expense(f, paidBy: f.other), note: "virtual")
        try f.context.save()
        f.context.delete(f.cash)
        f.context.delete(f.groups)
        try f.context.save()

        let all = try f.context.fetch(FetchDescriptor<TransactionItem>())
        #expect(OrphanedRecordsService.orphanCount(in: all, context: f.context) == 1)

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let panel = try String(contentsOf: root.appendingPathComponent("Yala/App/ViewModels/PanelViewModel.swift"),
                               encoding: .utf8)
        #expect(panel.contains("let orphans = OrphanedRecordsService.orphanCount(in: transactions, context: context)"),
                "el Panel ya no cuenta con la regla común: el aviso no vería la pata real de grupo")
    }

    // MARK: El barredor y el desasociar sobre filas reales

    /// El barredor ve la huérfana con su gasto ya borrado: sin cuenta y con subcategoría de préstamo es virtual y se
    /// borra; sin cuenta y con subcategoría del usuario no se sabe y NO se suelta (soltarla la metía en el aviso).
    @Test func barredor_clasificaLasSinCuenta() throws {
        let f = try makeFixture()
        let loan = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: f.context)
        let gone = expense(f, paidBy: f.me)
        let virtual = leg(f, 40, account: nil, expense: gone, subcategory: loan, note: "préstamo")
        let unknown = leg(f, -60, account: nil, expense: gone, note: "¿real o -miParte?")
        try f.context.save()
        f.context.delete(gone)
        try f.context.save()

        let evidence = GroupLegEvidence.read(for: [virtual, unknown], context: f.context, readSources: false)
        #expect(evidence.kind(of: virtual) == .virtual)
        #expect(evidence.kind(of: unknown) == .unknown)
    }

    /// Desasociar con «conservar»: la pata real probada se suelta (y entonces sí sale en el aviso, que es correcto); la
    /// -miParte sin cuenta no se toca y no sale.
    @Test func desasociar_soloSueltaLaRealProbada() throws {
        let f = try makeFixture()
        let mine = expense(f, paidBy: f.me)
        let theirs = expense(f, paidBy: f.other)
        let real = leg(f, -60, account: nil, expense: mine, note: "real")
        let myShare = leg(f, -60, account: nil, expense: theirs, note: "miParte")
        try f.context.save()

        let evidence = GroupLegEvidence.read(for: [real, myShare], context: f.context)
        #expect(GroupsAssociationDetach.action(leg: evidence.kind(of: real), choice: .keep) == .releasePointers)
        #expect(GroupsAssociationDetach.action(leg: evidence.kind(of: myShare), choice: .keep) == .leaveUntouched)
    }
}
