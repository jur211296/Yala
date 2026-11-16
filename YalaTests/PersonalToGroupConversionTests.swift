//
//  PersonalToGroupConversionTests.swift
//  YalaTests
//
//  «Convertir a gasto compartido» desde Editar de un registro (2.3). Lo que no puede pasar, y es lo que fijan estos
//  casos: que el gasto quede contado dos veces (en tus cuentas o en el grupo), que el registro pierda su importe, su
//  moneda, su fecha, su cuenta, su nota, su categoría o sus etiquetas, que quede un borrador en la Bandeja o un
//  «Préstamo a grupos» de más, que un error deje la conversión a medias, o que se ofrezca en lo que no es un gasto
//  personal.
//

import Testing
import Foundation
import SwiftData
@testable import Yala

// MARK: - Lógica pura

@Suite("Convertir a gasto compartido · qué registro se puede pasar")
struct PersonalToGroupConversionLogicTests {

    private func record(
        amount: Double = -90, categoryIsIncome: Bool? = false, groupPointer: Bool = false, derived: Bool = false,
        transfer: Bool = false, adjustment: Bool = false, hasAccount: Bool = true, system: Bool = false,
        archived: Bool = false, currencyMatches: Bool = true, personalSplit: Bool = false, paymentRecord: Bool = false,
        conserved: Bool = false
    ) -> PersonalToGroupConversionLogic.Record {
        .init(amount: amount, categoryIsIncome: categoryIsIncome, hasGroupPointer: groupPointer,
              isDerivedGroupLeg: derived, isTransfer: transfer, isBalanceAdjustment: adjustment,
              hasAccount: hasAccount, accountIsSystem: system, accountIsArchived: archived,
              accountCurrencyMatches: currencyMatches, usesPersonalSplit: personalSplit,
              isGroupPaymentRecord: paymentRecord, isConservedFromDetach: conserved)
    }

    private func verdict(_ r: PersonalToGroupConversionLogic.Record, privateSession: Bool = true)
        -> PersonalToGroupConversionLogic.Verdict {
        PersonalToGroupConversionLogic.verdict(r, hasPrivateSession: privateSession)
    }

    @Test func aPersonalExpense_isEligible() {
        #expect(verdict(record()) == .eligible)
        // Sin categoría decide el signo, como en Registros.
        #expect(verdict(record(categoryIsIncome: nil)) == .eligible)
    }

    /// Decisión de Jürgen (2026-11-07): solo gastos. Ingresos y transferencias no ven la opción.
    @Test func incomesAndTransfers_areNotOffered() {
        #expect(verdict(record(amount: 90, categoryIsIncome: true)) == .notOffered)
        #expect(verdict(record(amount: 90, categoryIsIncome: nil)) == .notOffered)
        // Una devolución apuntada en una categoría de ingreso no es un gasto.
        #expect(verdict(record(amount: -20, categoryIsIncome: true)) == .notOffered)
        #expect(verdict(record(transfer: true)) == .notOffered)
        #expect(verdict(record(adjustment: true)) == .notOffered)
    }

    @Test func whatIsAlreadyOfAGroup_isNotOffered() {
        #expect(verdict(record(groupPointer: true)) == .notOffered)
        #expect(verdict(record(derived: true)) == .notOffered)
        #expect(verdict(record(system: true)) == .notOffered)
        #expect(verdict(record(paymentRecord: true)) == .notOffered)
        #expect(verdict(record(conserved: true)) == .notOffered)
    }

    /// Lo que el puente no conservaría: sin cuenta, archivada, otra moneda o sin finanzas personales.
    @Test func whatTheBridgeWouldNotKeep_isNotOffered() {
        #expect(verdict(record(hasAccount: false)) == .notOffered)
        #expect(verdict(record(archived: true)) == .notOffered)
        #expect(verdict(record(currencyMatches: false)) == .notOffered)
        #expect(verdict(record(), privateSession: false) == .notOffered)
    }

    /// «Mi parte» guarda solo tu parte: pasarlo reescribiría lo que salió de la cuenta. Se dice, no se esconde.
    @Test func mySharedPart_isBlockedWithAReason() {
        #expect(verdict(record(personalSplit: true)) == .blockedByPersonalSplit)
        // Pero no si de todos modos no se ofrecería.
        #expect(verdict(record(amount: 90, categoryIsIncome: true, personalSplit: true)) == .notOffered)
    }

    @Test func theGroupName_isTheNote_orTheCategory() {
        #expect(PersonalToGroupConversionLogic.expenseDescription(note: "  Cena  ", subcategoryName: "Comida") == "Cena")
        #expect(PersonalToGroupConversionLogic.expenseDescription(note: "", subcategoryName: "Comida") == "Comida")
        #expect(PersonalToGroupConversionLogic.expenseDescription(note: nil, subcategoryName: nil) == "")
    }
}

// MARK: - Contra el puente real

@Suite("Convertir a gasto compartido · contra el puente real", .serialized, .wipeAppGroupMirrorIsolated)
@MainActor
struct PersonalToGroupConversionBehaviourTests {

    // Infra: el harness de `GroupExpenseLinkDraftBehaviourTests` (tres stores en disco, `cloudKitDatabase: .none`).

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersonalToGroup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "PTG-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "PTG-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "PTG-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let cash: Account
        let food: Subcategory
        let tag: Yala.Tag
        let record: TransactionItem
    }

    /// Un grupo en USD con Ana, y la cena que apunté yo en mi efectivo: 90, con nota, categoría, etiqueta y necesidad.
    private func makeFixture(
        _ context: ModelContext, currency: String = "USD", amount: Double = -90, withSubcategory: Bool = true
    ) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let cash = Account(name: "Efectivo", currencyCode: currency, colorHex: "#111111",
                           iconName: "banknote", type: "cash")
        context.insert(cash)
        let foodCategory = Category(name: "Comida", colorHex: "#FF0000", isIncome: false)
        context.insert(foodCategory)
        let food = Subcategory(name: "Restaurantes", category: foodCategory)
        context.insert(food)
        let tag = Yala.Tag(name: "Viaje")
        context.insert(tag)
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let record = TransactionItem(
            date: date, amount: amount, currencyCode: currency, note: "Cena con Ana",
            category: withSubcategory ? foodCategory : nil, subcategory: withSubcategory ? food : nil,
            account: cash, tags: [tag])
        record.needOverride = "priority"
        context.insert(record)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, cash: cash, food: food, tag: tag, record: record)
    }

    private func withEnvironment(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.requestSyncAfterLocalSave = {}
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        let previousIntentDefaults = GroupsPendingBridgeIntent.defaults
        GroupsPendingBridgeIntent.defaults = makeIsolatedDefaults()
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        SessionState.shared.hasPrivateSession = true
        defer {
            SessionState.shared.hasPrivateSession = previousPrivateSession
            GroupsPendingBridgeIntent.defaults = previousIntentDefaults
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            // El almacén del test se borra al salir: ningún singleton se queda apuntándolo.
            GroupTransactionBridge.shared._testClearContext()
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
        }
        try body()
    }

    private func convert(
        _ f: Fixture, shares: [(memberID: String, amount: Double)]? = nil, splitType: String = "equal",
        subcategoryName: String? = "Restaurantes"
    ) throws -> SplitExpense {
        let total = abs(f.record.amount)
        return try GroupExpenseService.shared.convertPersonalTransaction(
            f.record,
            to: f.group,
            description: "Cena",
            subcategoryName: subcategoryName,
            splitType: splitType,
            shares: shares ?? [(f.me.id.uuidString, total / 3), (f.ana.id.uuidString, total * 2 / 3)]
        )
    }

    private func expenses(_ context: ModelContext) throws -> [SplitExpense] {
        try context.fetch(FetchDescriptor<SplitExpense>())
    }

    private func legs(_ context: ModelContext, _ expense: SplitExpense) throws -> [TransactionItem] {
        let idStr = expense.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == idStr }))
    }

    private func pendingDrafts(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.status == .pending }
    }

    /// Lo que suma una cuenta: el saldo que ve la persona en ella.
    private func accountTotal(_ context: ModelContext, _ account: Account) throws -> Double {
        let id = account.persistentModelID
        return try context.fetch(FetchDescriptor<TransactionItem>())
            .filter { $0.account?.persistentModelID == id }
            .map(\.amount).reduce(0, +)
    }

    private func groupBalances(_ context: ModelContext, _ f: Fixture) throws -> [String: Double] {
        let zone = f.group.cloudKitZoneID
        let all = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zone }))
        let shares = try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zone }))
        let balances = GroupBalanceService.calculateBalances(
            expenses: all, shares: shares, members: [f.me, f.ana], settlements: [])
        return Dictionary(balances.map { ($0.memberID, $0.netBalance) }, uniquingKeysWith: +)
    }

    // MARK: Conservación, vínculo único y saldos

    @Test("pasar la cena deja un solo gasto, enlazado al registro, sin tocar lo que apuntaste")
    func converting_keepsTheRecord_andLinksIt() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let recordID = f.record.persistentModelID
            let date = f.record.date
            let cashBefore = try accountTotal(context, f.cash)

            let expense = try convert(f)

            // Un solo gasto en el grupo, con lo del registro.
            #expect(try expenses(context).count == 1)
            #expect(expense.amount == 90)
            #expect(expense.currencyCode == "USD")
            #expect(expense.date == date)
            #expect(expense.paidByMemberID == f.me.id.uuidString)
            // El registro es el mismo, enlazado, y conserva todo.
            #expect(f.record.persistentModelID == recordID)
            #expect(f.record.splitExpenseID == expense.id.uuidString)
            #expect(f.record.splitGroupZoneID == f.group.cloudKitZoneID)
            #expect(f.record.amount == -90)
            #expect(f.record.currencyCode == "USD")
            #expect(f.record.date == date)
            #expect(f.record.note == "Cena con Ana")
            #expect(f.record.account?.persistentModelID == f.cash.persistentModelID)
            #expect(f.record.subcategory?.persistentModelID == f.food.persistentModelID)
            #expect(f.record.resolvedTagIDs() == [f.tag.id])
            #expect(f.record.needOverride == "priority")
            // La cuenta no cambia: el dinero ya había salido.
            #expect(try accountTotal(context, f.cash) == cashBefore)

            let all = try legs(context, expense)
            #expect(all.filter { $0.account?.isSystemAccount == false }.count == 1, "hay dos patas reales")
            let loans = all.filter { $0.account?.isSystemAccount == true }
            #expect(loans.count == 1, "«Préstamo a grupos» repetido")
            #expect(loans.first?.amount == 60, "te deben la parte de Ana")
            #expect(all.map(\.amount).reduce(0, +) == -30, "tu coste es tu parte")
            #expect(try pendingDrafts(context).isEmpty, "quedó un borrador en la Bandeja")

            let balances = try groupBalances(context, f)
            #expect(balances[f.me.id.uuidString] == 60)
            #expect(balances[f.ana.id.uuidString] == -60)
            #expect(!context.hasChanges, "la conversión quedó sin guardar")
        }
    }

    @Test("con un reparto desigual, lo prestado es lo de los demás")
    func converting_withAnUnequalSplit() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try convert(
                f, shares: [(f.me.id.uuidString, 70), (f.ana.id.uuidString, 20)], splitType: "exact")

            let all = try legs(context, expense)
            #expect(all.filter { $0.account?.isSystemAccount == true }.map(\.amount) == [20])
            #expect(all.map(\.amount).reduce(0, +) == -70)
            let balances = try groupBalances(context, f)
            #expect(balances[f.ana.id.uuidString] == -20)
            #expect(try pendingDrafts(context).isEmpty)
        }
    }

    @Test("un registro en otra moneda que la del grupo pasa en su moneda, sin convertir nada")
    func converting_keepsTheRecordsCurrency() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, currency: "PEN", amount: -300)
        try withEnvironment(context) {
            let expense = try convert(f, shares: [(f.me.id.uuidString, 150), (f.ana.id.uuidString, 150)])

            #expect(expense.currencyCode == "PEN")
            #expect(expense.amount == 300)
            #expect(f.record.amount == -300)
            #expect(f.record.currencyCode == "PEN")
            let loans = try legs(context, expense).filter { $0.account?.isSystemAccount == true }
            #expect(loans.map(\.amount) == [150])
            #expect(loans.first?.currencyCode == "PEN")
            #expect(loans.first?.account?.currencyCode == "PEN")
        }
    }

    @Test("un registro sin categoría no deja un borrador pidiéndola")
    func converting_anUnclassifiedRecord_leavesNoDraft() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, withSubcategory: false)
        try withEnvironment(context) {
            let expense = try convert(f, subcategoryName: nil)
            #expect(try pendingDrafts(context).isEmpty, "el puente pidió la categoría en la Bandeja")
            #expect(try legs(context, expense).filter { $0.account?.isSystemAccount == true }.count == 1)
        }
    }

    @Test("con el puente apagado para el grupo, el registro se queda y no se pregunta nada")
    func converting_withTheBridgeOff_keepsTheRecord() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let prefs = AppPreferences(defaults: makeIsolatedDefaults())
            prefs.bridgeGroupExpensesToPersonalAccounts = false
            BridgeModeResolver.shared.setAppPreferences(prefs)
            defer { BridgeModeResolver.shared._testReset() }

            let expense = try convert(f)

            let all = try legs(context, expense)
            #expect(all.filter { $0.account?.isSystemAccount == false }.map(\.persistentModelID)
                == [f.record.persistentModelID])
            #expect(all.map(\.amount).reduce(0, +) == -30, "con el puente apagado el coste se contó dos veces")
            #expect(try pendingDrafts(context).isEmpty)
        }
    }

    // MARK: Doble toque, reintento y errores

    @Test("un registro ya pasado no se vuelve a pasar: falla sin crear otro gasto ni otro préstamo")
    func converting_twice_failsWithoutDuplicating() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let first = try convert(f)
            #expect(throws: GroupExpenseServiceError.self) { try convert(f) }

            #expect(try expenses(context).count == 1)
            #expect(f.record.splitExpenseID == first.id.uuidString)
            #expect(try legs(context, first).filter { $0.account?.isSystemAccount == true }.count == 1)
        }
    }

    /// El doble toque de verdad lo corta el formulario: el segundo «Guardar» no vuelve a llamar al servicio.
    @Test("doble toque en «Guardar» de la revisión: un solo gasto")
    func doubleTap_onTheReview_convertsOnce() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let ctx = try #require(PersonalToGroupConversion.context(
                transaction: f.record, group: f.group, modelContext: context))
            let vm = GroupExpenseViewModel(group: f.group, members: ctx.members, memberNameLookup: ctx.lookup)
            vm.setContext(context)
            vm.isGroupsOnlyOverride = false
            vm.effectiveBridgeEnabledOverride = true
            vm.applyConversion(from: f.record, template: ctx.template)
            #expect(vm.isConversion)
            #expect(vm.canSave, "la revisión prellenada no deja guardar: \(String(describing: vm.firstMissingField))")

            #expect(vm.save())
            #expect(vm.save())

            #expect(try expenses(context).count == 1)
            #expect(vm.saveError == nil)
            let expense = try #require(try expenses(context).first)
            #expect(try legs(context, expense).filter { $0.account?.isSystemAccount == true }.count == 1)
        }
    }

    /// El guardado final falla DESPUÉS de que el puente escribiera (registro enlazado, gasto, repartos y préstamo
    /// insertados; con una «Grupos» archivada, además la desarchiva). El `rollback()` lo deshace todo y no aborta: es la
    /// forma que `docs/aprendizajes-tecnicos.md` midió abortando con otro orden. Se aserta contra el almacén (contexto
    /// nuevo), no contra los objetos en memoria (regla de `testing.md`).
    @Test("si el guardado final falla, no queda nada a medias y el reintento pasa una sola vez",
          arguments: [false, true])
    func converting_whenTheFinalSaveFails_rollsBackCleanly(withArchivedGroupsAccount: Bool) throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        if withArchivedGroupsAccount {
            let grupos = try GroupBridgeSystemEntities.ensureSystemAccount(currencyCode: "USD", context: context)
            grupos.isArchived = true
            try context.save()
        }
        try withEnvironment(context) {
            GroupExpenseService._testFailConversionSave = true
            defer { GroupExpenseService._testFailConversionSave = false }
            #expect(throws: GroupExpenseServiceError.self) { try convert(f) }
            #expect(!context.hasChanges, "el rollback dejó cambios pendientes")

            let fresh = ModelContext(context.container)
            #expect(try fresh.fetch(FetchDescriptor<SplitExpense>()).isEmpty, "quedó un gasto")
            #expect(try fresh.fetch(FetchDescriptor<SplitShare>()).isEmpty, "quedaron repartos")
            let stored = try fresh.fetch(FetchDescriptor<TransactionItem>())
            #expect(stored.count == 1, "quedó un préstamo o se perdió el registro")
            #expect(stored.first?.splitExpenseID == nil, "el registro quedó enlazado")
            #expect(stored.first?.amount == -90)

            GroupExpenseService._testFailConversionSave = false
            let expense = try convert(f)
            #expect(try fresh.fetch(FetchDescriptor<SplitExpense>()).map(\.id) == [expense.id])
            #expect(try legs(context, expense).filter { $0.account?.isSystemAccount == true }.count == 1)
        }
    }

    @Test("un registro que ya es de otro grupo no se pasa, y no se toca nada")
    func converting_aRecordOfAnotherGroup_fails() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            f.record.splitExpenseID = UUID().uuidString
            f.record.splitGroupZoneID = "otra-zona"
            try context.save()

            #expect(throws: GroupExpenseServiceError.self) { try convert(f) }
            #expect(try expenses(context).isEmpty)
            #expect(f.record.splitGroupZoneID == "otra-zona")
        }
    }

    @Test("un ingreso, una transferencia, «Mi parte» o una cuenta archivada no se pasan")
    func converting_whatIsNotEligible_fails() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let cases: [(String, (TransactionItem) -> Void, (TransactionItem) -> Void)] = [
                ("ingreso", { $0.amount = 90 }, { $0.amount = -90 }),
                ("transferencia", { $0.transferPairID = "par" }, { $0.transferPairID = nil }),
                ("mi parte", { $0.splitTotalAmount = 270 }, { $0.splitTotalAmount = nil }),
                ("cuenta archivada", { $0.account?.isArchived = true }, { $0.account?.isArchived = false }),
            ]
            for (name, break_, restore) in cases {
                break_(f.record)
                try context.save()
                #expect(throws: GroupExpenseServiceError.self, "\(name): se pasó al grupo") { try convert(f) }
                #expect(try expenses(context).isEmpty, "\(name): quedó un gasto")
                #expect(f.record.splitExpenseID == nil, "\(name): el registro quedó enlazado")
                restore(f.record)
                try context.save()
            }
            // Control: restaurado, sí se pasa.
            #expect(throws: Never.self) { try convert(f) }
        }
    }

    @Test("con el grupo archivado o eliminado con la hoja abierta, falla y el registro sigue intacto")
    func converting_toAGroupThatWentAway_fails() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            f.group.isArchived = true
            try context.save()
            #expect(throws: GroupExpenseServiceError.self) { try convert(f) }
            #expect(try expenses(context).isEmpty)
            #expect(f.record.splitExpenseID == nil)
            #expect(try accountTotal(context, f.cash) == -90)
        }
    }

    @Test("sin permiso en el grupo (saliste o te quitaron) falla y el registro sigue intacto")
    func converting_withoutPermission_fails() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            f.me.status = SplitMemberStatus.left.rawValue
            try context.save()
            #expect(throws: GroupExpenseServiceError.self) { try convert(f) }
            #expect(try expenses(context).isEmpty)
            #expect(f.record.splitExpenseID == nil)
            #expect(try context.fetch(FetchDescriptor<SplitShare>()).isEmpty)
        }
    }

    @Test("si el puente no puede atenderlo, nada cambia; y al reintentar, se pasa una sola vez")
    func converting_whenTheBridgeIsNotReady_failsAndRetrySucceeds() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            GroupTransactionBridge.shared._testClearContext()
            #expect(throws: GroupExpenseServiceError.self) { try convert(f) }
            #expect(try expenses(context).isEmpty)
            #expect(f.record.splitExpenseID == nil)
            #expect(!context.hasChanges)

            GroupTransactionBridge.shared.setContext(context)
            let expense = try convert(f)
            #expect(try expenses(context).count == 1)
            #expect(try legs(context, expense).filter { $0.account?.isSystemAccount == true }.count == 1)
        }
    }

    @Test("una categoría de ingreso haría del gasto una venta y borraría el registro: no se pasa")
    func converting_withAnIncomeCategory_fails() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let salary = Category(name: "Ingresos", colorHex: "#00FF00", isIncome: true)
            context.insert(salary)
            context.insert(Subcategory(name: "Ventas", category: salary))
            try context.save()

            #expect(throws: GroupExpenseServiceError.self) { try convert(f, subcategoryName: "Ventas") }
            #expect(try expenses(context).isEmpty)
            #expect(!f.record.isDeleted)
            #expect(f.record.splitExpenseID == nil)
        }
    }

    // MARK: Cancelar

    /// Abrir la revisión (y cerrarla sin guardar) no escribe nada: la plantilla solo lee el registro.
    @Test("preparar la revisión no cambia nada; cancelar deja datos y saldos como estaban")
    func openingTheReview_changesNothing() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let ctx = try #require(PersonalToGroupConversion.context(
                transaction: f.record, group: f.group, modelContext: context))

            #expect(ctx.template.totalAmount == 90)
            #expect(ctx.template.currencyCode == "USD")
            #expect(ctx.template.date == f.record.date)
            #expect(ctx.template.description == "Cena con Ana")
            #expect(ctx.template.accountPrefill?.persistentModelID == f.cash.persistentModelID)
            #expect(ctx.template.subcategory?.persistentModelID == f.food.persistentModelID)
            #expect(!context.hasChanges)
            #expect(try expenses(context).isEmpty)
            #expect(f.record.splitExpenseID == nil)
            #expect(try accountTotal(context, f.cash) == -90)
        }
    }

    // MARK: Elegibilidad sobre el registro real

    @Test("el veredicto del editor lee el registro guardado")
    func verdict_readsTheStoredRecord() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            #expect(GroupExpenseService.conversionVerdict(for: f.record) == .eligible)
            f.record.splitTotalAmount = 270
            f.record.splitMyValue = 3
            #expect(GroupExpenseService.conversionVerdict(for: f.record) == .blockedByPersonalSplit)
            f.record.splitTotalAmount = nil
            f.record.splitMyValue = nil
            SessionState.shared.hasPrivateSession = false
            #expect(GroupExpenseService.conversionVerdict(for: f.record) == .notOffered)
            SessionState.shared.hasPrivateSession = true
            _ = try convert(f)
            #expect(GroupExpenseService.conversionVerdict(for: f.record) == .notOffered, "se ofrece pasarlo dos veces")
        }
    }
}
