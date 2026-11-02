//
//  GroupBridgeCollectedTests.swift
//  YalaTests / CloudSync
//
//  Grupos B · card 10: al liquidar, el ingreso de una venta cuenta con la fecha del pago. De punta a punta con
//  `bridgeExpense` / `bridgeSettlement`, sobre el harness on-disk de `GroupBridgeSaleTests` (los tres stores, sin
//  autoguardado, el puente soltado al salir).
//
//  El caso del encargo: le vendes unas zapatillas a Ana por S/ 120 el 25 de septiembre y te las paga por Yape el 8 de
//  octubre ⇒ Yape +120, Grupos 0, y 120 de Ventas como ingreso de octubre (septiembre, 0). Fechas pasadas a propósito:
//  aprobar un pago fechado en el futuro revienta fuera de este cambio (ver el parte del PR).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos B · lo cobrado de una venta cuenta el día del pago", .serialized)
@MainActor
struct GroupBridgeCollectedTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupBridgeCollected-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear \(dir): \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch { print("cleanup: \(error)") }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GBC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GBC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GBC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        // Sin autoguardado: un guardado diferido que salte después de borrar el store tumba el proceso de tests entero.
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let yape: Account
        let ventas: Subcategory
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Ventas con Ana", currencyCode: "PEN")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let yape = Account(name: "Yape", currencyCode: "PEN", colorHex: "#6A1B9A", iconName: "iphone", type: "bank")
        context.insert(yape)
        let incomeCat = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let ventas = makeTestSubcategory(context: context, name: "Ventas", category: incomeCat)
        let expenseCat = makeTestCategory(context: context, name: "Comida")
        _ = makeTestSubcategory(context: context, name: "Almuerzo", category: expenseCat)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, yape: yape, ventas: ventas)
    }

    private func withBridge(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previous = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = previous
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            GroupTransactionBridge.shared._testClearContext()
        }
        try body()
    }

    private static func day(_ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2026
        components.month = month
        components.day = day
        components.hour = 12
        return components.date ?? .distantPast
    }

    private static func month(_ month: Int) -> DateInterval {
        let calendar = Calendar.current
        let start = day(month, 1)
        let first = calendar.startOfDay(for: start)
        let next = calendar.date(byAdding: .month, value: 1, to: first) ?? first
        return DateInterval(start: first, end: next.addingTimeInterval(-1))
    }

    /// Un gasto de grupo: lo pagaste tú (o Ana) por `total`, con tu parte `myShare` y el resto para Ana.
    @discardableResult
    private func expense(
        _ context: ModelContext, _ f: Fixture, total: Double, myShare: Double, paidByMe: Bool = true,
        category: String = "Ventas", description: String = "Venta de zapatillas", on date: Date
    ) throws -> SplitExpense {
        let expense = SplitExpense(
            groupZoneID: f.group.cloudKitZoneID, amount: total, currencyCode: "PEN",
            expenseDescription: description, date: date, paidByMemberID: (paidByMe ? f.me : f.ana).id.uuidString)
        expense.subcategoryName = category
        context.insert(expense)
        context.insert(SplitShare(expenseID: expense.id, memberID: f.me.id.uuidString, amount: myShare,
                                  groupZoneID: f.group.cloudKitZoneID))
        context.insert(SplitShare(expenseID: expense.id, memberID: f.ana.id.uuidString, amount: total - myShare,
                                  groupZoneID: f.group.cloudKitZoneID))
        try context.save()
        // Un gasto (no venta) que pagaste tú sale del formulario con su cuenta: sin ella el puente lo da por un error.
        let account = paidByMe && category != "Ventas" ? f.yape : nil
        try GroupTransactionBridge.shared.bridgeExpense(
            expense, in: f.group, accountForCurrentUser: account, shouldSave: false)
        try context.save()
        return expense
    }

    /// Ana te paga `amount` el día `date` (liquidación confirmada, Caso D del puente).
    @discardableResult
    private func anaPays(_ context: ModelContext, _ f: Fixture, _ amount: Double, on date: Date) throws -> SplitSettlement {
        let settlement = SplitSettlement(
            groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.ana.id.uuidString, toMemberID: f.me.id.uuidString,
            amount: amount, currencyCode: "PEN", date: date)
        settlement.isConfirmed = true
        context.insert(settlement)
        try context.save()
        try GroupTransactionBridge.shared.bridgeSettlement(settlement, in: f.group, shouldSave: false)
        try context.save()
        return settlement
    }

    private func legs(_ context: ModelContext, _ e: SplitExpense) throws -> [TransactionItem] {
        let id = e.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == id }))
    }

    private func receivable(_ context: ModelContext, _ e: SplitExpense) throws -> [TransactionItem] {
        try legs(context, e).filter { GroupSaleBridgeLogic.isReceivable($0.balanceAdjustmentType) }
    }

    private func collected(_ context: ModelContext, _ e: SplitExpense) throws -> [TransactionItem] {
        try legs(context, e).filter { GroupCollectedLegLogic.isCollected($0.splitLinesRaw) }
            .sorted { $0.date < $1.date }
    }

    private func all(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>())
    }

    private func balance(_ context: ModelContext, of account: (Account?) -> Bool) throws -> Double {
        try all(context).filter { account($0.account) }.reduce(0) { $0 + $1.amount }
    }

    /// Lo que Estadísticas cuenta como ingreso de Ventas en `interval` (`CashFlowCalculator` con el ajuste del puente).
    private func ventasIncome(_ context: ModelContext, in interval: DateInterval) throws -> Double {
        // El calculador no recorta por el intervalo: lo hace quien llama (como Estadísticas).
        let txs = try all(context).filter { $0.subcategory?.name == "Ventas" && interval.contains($0.date) }
        return CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .month, currencyCode: "PEN",
            adjustment: GroupBridgeStatsAdjustment.build(from: try all(context), context: context)).totalIncome
    }

    // MARK: - El caso Ana

    @Test func caseAna_yapePlus120_groupsZero_ventas120InThePaymentMonth() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            #expect(try ventasIncome(context, in: Self.month(9)) == 0)

            let payment = try anaPays(context, f, 120, on: Self.day(10, 8))

            #expect(try receivable(context, sale).isEmpty, "Cobrada entera: nada por cobrar.")
            let parts = try collected(context, sale)
            #expect(parts.count == 1)
            let part = try #require(parts.first)
            #expect(part.amount == 120)
            #expect(part.date == Self.day(10, 8))
            #expect(part.subcategory?.name == "Ventas")
            #expect(part.balanceAdjustmentType == nil)
            #expect(part.account?.isSystemAccount == true)
            #expect(GroupCollectedLegLogic.collectedEventID(part.splitLinesRaw) == payment.id)

            // La Bandeja: «Pago de Ana», eliges Yape.
            let settlementID = payment.id.uuidString
            let draft = try #require(try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitSettlementID == settlementID })).first { $0.status == .pending })
            draft.account = f.yape
            DraftService.shared.setContext(context)
            defer { DraftService.shared.setContext(nil) }
            _ = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())

            #expect(try balance(context) { $0?.name == "Yape" } == 120)
            #expect(try balance(context) { $0?.isSystemAccount == true } == 0, "Grupos vuelve a cero.")
            #expect(try ventasIncome(context, in: Self.month(10)) == 120)
            #expect(try ventasIncome(context, in: Self.month(9)) == 0)
        }
    }

    /// Una segunda pasada (del gasto o del pago) no duplica nada ni mueve fechas.
    @Test func repeatedPasses_keepTheSameLegs() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            let payment = try anaPays(context, f, 50, on: Self.day(10, 8))
            let before = try legs(context, sale).map(\.persistentModelID)

            try GroupTransactionBridge.shared.bridgeExpense(sale, in: f.group, shouldSave: false)
            try GroupTransactionBridge.shared.bridgeSettlement(payment, in: f.group, shouldSave: false)
            try context.save()

            #expect(Set(try legs(context, sale).map(\.persistentModelID)) == Set(before))
            #expect(try receivable(context, sale).map(\.amount) == [70])
            #expect(try collected(context, sale).map(\.amount) == [50])
        }
    }

    // MARK: - Pagos a medias y deudas cruzadas

    @Test func halfPayment_leaves70ToCollect_andGroupsStillMatchesTheGroup() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            try anaPays(context, f, 50, on: Self.day(10, 8))

            #expect(try receivable(context, sale).map(\.amount) == [70])
            #expect(try receivable(context, sale).first?.date == Self.day(9, 25))
            #expect(try collected(context, sale).map(\.amount) == [50])
            #expect(try balance(context) { $0?.isSystemAccount == true } == 70, "Ana te sigue debiendo 70.")
            #expect(try ventasIncome(context, in: Self.month(10)) == 50)
        }
    }

    /// Pago parcial de la página: la cena (adelantaste 100 de Ana) va antes que la venta. El
    /// primer pago cubre la cena; la venta sigue entera por cobrar.
    @Test func partialPayment_coversTheOlderDinnerFirst() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            try expense(context, f, total: 200, myShare: 100, category: "Almuerzo", description: "Cena",
                        on: Self.day(9, 2))
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            try anaPays(context, f, 100, on: Self.day(10, 8))

            #expect(try collected(context, sale).isEmpty)
            #expect(try receivable(context, sale).map(\.amount) == [120])

            try anaPays(context, f, 120, on: Self.day(10, 20))
            #expect(try collected(context, sale).map(\.amount) == [120])
            #expect(try collected(context, sale).first?.date == Self.day(10, 20))
            #expect(try receivable(context, sale).isEmpty)
        }
    }

    /// Deudas cruzadas: Ana pagó un almuerzo (tu parte, 64) después de la venta. Con su pago de 56 el saldo queda en cero
    /// y la venta está cubierta entera: 64 el día del almuerzo y 56 el del pago.
    @Test func crossedDebts_coverTheWholeSale() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            try expense(context, f, total: 128, myShare: 64, paidByMe: false, category: "Almuerzo",
                        description: "Almuerzo", on: Self.day(9, 28))
            #expect(try collected(context, sale).map(\.amount) == [64], "El almuerzo bajó tu saldo: cubre 64.")

            try anaPays(context, f, 56, on: Self.day(10, 8))
            #expect(try collected(context, sale).map(\.amount) == [64, 56])
            #expect(try receivable(context, sale).isEmpty)
            #expect(try balance(context) { $0?.isSystemAccount == true } == 0)
        }
    }

    // MARK: - Borrados y cambios

    /// Se borra el pago: lo que cubría vuelve a estar por cobrar y deja de contar como ingreso.
    @Test func deletingThePayment_putsTheSaleBackToCollect() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        defer {
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
        }
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            let payment = try anaPays(context, f, 120, on: Self.day(10, 8))
            #expect(try collected(context, sale).count == 1)

            try GroupExpenseService.shared.deleteSettlement(payment, in: f.group)

            #expect(try collected(context, sale).isEmpty)
            #expect(try receivable(context, sale).map(\.amount) == [120])
            #expect(try ventasIncome(context, in: Self.month(10)) == 0)
        }
    }

    /// Lo mismo cuando el borrado llega por el canal de sync (tombstone remoto).
    @Test func aRemoteDeletionOfThePayment_putsTheSaleBackToCollect() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            let payment = try anaPays(context, f, 120, on: Self.day(10, 8))
            let paymentID = payment.id
            context.delete(payment)
            try context.save()

            try GroupTransactionBridge.shared.unbridgeDeletedRemotely(expenseIDs: [], settlementIDs: [paymentID])

            #expect(try collected(context, sale).isEmpty)
            #expect(try receivable(context, sale).map(\.amount) == [120])
        }
    }

    /// Cambias el monto de una venta ya cobrada a medias: lo por cobrar pasa al monto nuevo menos lo ya pagado.
    @Test func changingTheSaleAmount_movesOnlyWhatIsLeft() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            try anaPays(context, f, 50, on: Self.day(10, 8))

            sale.amount = 150
            let saleID = sale.id
            let anaID = f.ana.id.uuidString
            let hers = try #require(try context.fetch(FetchDescriptor<SplitShare>(
                predicate: #Predicate { $0.expenseID == saleID && $0.memberID == anaID })).first)
            hers.amount = 150
            try context.save()
            try GroupTransactionBridge.shared.bridgeExpense(sale, in: f.group, shouldSave: false)
            try context.save()

            #expect(try receivable(context, sale).map(\.amount) == [100])
            #expect(try collected(context, sale).map(\.amount) == [50])
            #expect(try balance(context) { $0?.isSystemAccount == true } == 100)
        }
    }

    /// La venta pasa a ser un gasto (otra categoría): lo cobrado se va con lo por cobrar, y queda la forma de siempre.
    @Test func aSaleTurnedIntoAnExpense_dropsWhatWasCollected() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            try anaPays(context, f, 50, on: Self.day(10, 8))

            sale.subcategoryName = "Almuerzo"
            try context.save()
            // Llega como edición remota: sin cuenta local, el puente deja el borrador de la cuenta.
            try GroupTransactionBridge.shared.bridgeExpense(sale, in: f.group, isRemoteSync: true, shouldSave: false)
            try context.save()

            #expect(try collected(context, sale).isEmpty)
            #expect(try receivable(context, sale).isEmpty)
        }
    }

    /// Cambia el pagador de tu venta a Ana y te dejan fuera del reparto: ya no es tu venta, y sus patas se van aunque el
    /// puente salga antes de llegar a la venta (no participas).
    @Test func whenTheSaleIsNoLongerYours_itsLegsGo() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            try anaPays(context, f, 50, on: Self.day(10, 8))
            #expect(try collected(context, sale).count == 1)

            sale.paidByMemberID = f.ana.id.uuidString
            let saleID = sale.id
            let meID = f.me.id.uuidString
            for share in try context.fetch(FetchDescriptor<SplitShare>(
                predicate: #Predicate { $0.expenseID == saleID && $0.memberID == meID })) {
                context.delete(share)
            }
            try context.save()
            try GroupTransactionBridge.shared.bridgeExpense(sale, in: f.group, isRemoteSync: true, shouldSave: false)
            try context.save()

            #expect(try receivable(context, sale).isEmpty)
            #expect(try collected(context, sale).isEmpty)
        }
    }

    /// El pago llega por el pull de Grupos (lote): lo cobrado se repasa al final del lote y queda igual que en local.
    @Test func aPaymentArrivingInARemoteBatch_collectsTheSale() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            let settlement = SplitSettlement(
                groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.ana.id.uuidString, toMemberID: f.me.id.uuidString,
                amount: 120, currencyCode: "PEN", date: Self.day(10, 8))
            settlement.isConfirmed = true
            context.insert(settlement)
            try context.save()

            let bridged = try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [settlement.id])
            #expect(bridged == [settlement.id])
            #expect(GroupTransactionBridge.shared.receivableBatchZones == nil, "El lote suelta su apunte al terminar.")
            #expect(try receivable(context, sale).isEmpty)
            #expect(try collected(context, sale).map(\.amount) == [120])
        }
    }

    /// Borrar la venta se lleva lo cobrado, y el pago se queda como una devolución de siempre.
    @Test func deletingTheSale_takesTheCollectedLegsWithIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let sale = try expense(context, f, total: 120, myShare: 0, on: Self.day(9, 25))
            try anaPays(context, f, 120, on: Self.day(10, 8))
            #expect(try collected(context, sale).count == 1)

            try GroupTransactionBridge.shared.unbridgeExpense(expenseID: sale.id.uuidString)
            #expect(try legs(context, sale).isEmpty)
        }
    }

    /// Un gasto normal sin ventas en el grupo no escribe ninguna pata de venta.
    @Test func aGroupWithoutSales_hasNoSaleLegs() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            try expense(context, f, total: 200, myShare: 100, category: "Almuerzo", description: "Cena",
                        on: Self.day(9, 2))
            try anaPays(context, f, 100, on: Self.day(10, 8))
            let zone = f.group.cloudKitZoneID
            #expect(try GroupTransactionBridge.saleLegs(inZone: zone, context: context).isEmpty)
        }
    }

    // MARK: - La marca

    @Test func theCollectedMarker_roundTrips_andIsNotASplitLine() {
        let id = UUID()
        let raw = GroupSplitLinesRecipe.encodeCollectedMarker(eventID: id)
        #expect(GroupSplitLinesRecipe.parse(raw) == .collected(eventID: id))
        #expect(GroupCollectedLegLogic.collectedEventID(raw) == id)
        #expect(!GroupSplitLinesBridgeLogic.isDerivedMarker(raw))
        #expect(!GroupSplitLinesBridgeLogic.mayCarryRecipe(raw))
        // La marca de una línea sigue siendo eso, y no una pata cobrada.
        let line = GroupSplitLinesRecipe.encodeDerivedMarker(lineID: id)
        #expect(!GroupCollectedLegLogic.isCollected(line))
        #expect(GroupSplitLinesBridgeLogic.isDerivedMarker(line))
    }
}
