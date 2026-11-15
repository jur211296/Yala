//
//  RecurrenteDesdeRegistroTests.swift
//  YalaTests
//
//  «Hacer recurrente» a partir de un registro (encargo del 15-nov): cuándo se ofrece, el prellenado, el vínculo del
//  registro como primer pago sin duplicar el gasto, la detección de un recurrente parecido y la Bandeja.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lógica pura

@Suite("Recurrente desde un registro · decisiones")
struct RecurrenteDesdeRegistroLogicTests {

    typealias Logic = RecurringFromRecordLogic

    private static let calendar = Calendar(identifier: .gregorian)

    private static func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? .distantPast
    }

    // MARK: Cuándo se ofrece

    @Test func offers_onAPlainRecord() {
        #expect(Logic.offersMakeRecurring(.init(
            isGroupRecord: false, hasBalanceAdjustmentType: false, isLinkedToScheduledPayment: false,
            accountIsSystem: false)))
    }

    @Test(arguments: [
        Logic.RecordFacts(isGroupRecord: true, hasBalanceAdjustmentType: false, isLinkedToScheduledPayment: false,
                          accountIsSystem: false),
        Logic.RecordFacts(isGroupRecord: false, hasBalanceAdjustmentType: true, isLinkedToScheduledPayment: false,
                          accountIsSystem: false),
        Logic.RecordFacts(isGroupRecord: false, hasBalanceAdjustmentType: false, isLinkedToScheduledPayment: true,
                          accountIsSystem: false),
        Logic.RecordFacts(isGroupRecord: false, hasBalanceAdjustmentType: false, isLinkedToScheduledPayment: false,
                          accountIsSystem: true),
    ])
    func doesNotOffer_onGroupTransferLinkedOrSystemRecords(_ facts: Logic.RecordFacts) {
        #expect(!Logic.offersMakeRecurring(facts))
    }

    // MARK: Bandeja

    @Test(arguments: [DraftSourceType.emailAlert, .screenshotSingle, .receiptPhoto, .applePay, .voice, .manual])
    func inbox_offersApproveAndMakeRecurring_onAPendingCapturedDraft(_ source: DraftSourceType) {
        #expect(Logic.offersApproveAndMakeRecurring(sourceType: source, sourceScheduledPaymentID: nil, isPending: true))
    }

    @Test(arguments: [DraftSourceType.scheduledPayment, .subscription, .groupScheduledExpense, .groupExpense,
                      .groupSettlement])
    func inbox_doesNotOffer_whenTheDraftComesFromARecurringOrAGroup(_ source: DraftSourceType) {
        #expect(!Logic.offersApproveAndMakeRecurring(sourceType: source, sourceScheduledPaymentID: nil, isPending: true))
    }

    @Test func inbox_doesNotOffer_whenTheDraftAlreadyPointsToARecurring_orIsNotPending() {
        #expect(!Logic.offersApproveAndMakeRecurring(
            sourceType: .emailAlert, sourceScheduledPaymentID: UUID().uuidString, isPending: true))
        #expect(!Logic.offersApproveAndMakeRecurring(sourceType: .emailAlert, sourceScheduledPaymentID: nil,
                                                     isPending: false))
    }

    // MARK: Prellenado

    @Test func name_isTheNote_orTheSubcategory() {
        #expect(Logic.paymentName(note: "  Cloudflare  ", subcategoryName: "Hosting") == "Cloudflare")
        #expect(Logic.paymentName(note: "   ", subcategoryName: "Hosting") == "Hosting")
        #expect(Logic.paymentName(note: nil, subcategoryName: nil) == "")
    }

    // MARK: Un recurrente parecido

    private static let streaming = UUID()
    private static let hosting = UUID()

    private static func candidate(
        _ name: String, amount: Double, currency: String = "USD", type: String = "expense",
        subcategory: UUID? = nil, variable: Bool = false, active: Bool = true, group: Bool = false
    ) -> Logic.Candidate {
        Logic.Candidate(
            id: UUID(), name: name, storedBrandID: nil, amount: amount, currencyCode: currency,
            transactionType: type, subcategoryID: subcategory, isVariableAmount: variable, isActive: active,
            isGroupPayment: group)
    }

    private static func probe(
        _ name: String, amount: Double, currency: String = "USD", type: String = "expense", subcategory: UUID? = nil
    ) -> Logic.Probe {
        Logic.Probe(name: name, amount: amount, currencyCode: currency, transactionType: type, subcategoryID: subcategory)
    }

    @Test func similar_sameMerchantAndCloseAmount_matches() {
        let cloudflare = Self.candidate("Cloudflare", amount: 5)
        let match = Logic.similarPayment(to: Self.probe("CLOUDFLARE", amount: 5.4), among: [cloudflare])
        #expect(match?.id == cloudflare.id)
    }

    @Test func similar_nameThatStartsWithTheOther_matches() {
        let netflix = Self.candidate("Netflix", amount: 15)
        #expect(Logic.similarPayment(to: Self.probe("Netflix familiar", amount: 15), among: [netflix])?.id == netflix.id)
    }

    @Test func similar_otherCurrency_orFarAmount_orOtherType_doesNotMatch() {
        let cloudflare = Self.candidate("Cloudflare", amount: 5)
        #expect(Logic.similarPayment(to: Self.probe("Cloudflare", amount: 5, currency: "PEN"), among: [cloudflare]) == nil)
        #expect(Logic.similarPayment(to: Self.probe("Cloudflare", amount: 6.5), among: [cloudflare]) == nil)
        #expect(Logic.similarPayment(to: Self.probe("Cloudflare", amount: 5, type: "income"), among: [cloudflare]) == nil)
    }

    @Test func similar_variableAmount_ignoresTheAmount() {
        let luz = Self.candidate("Luz del Sur", amount: 80, currency: "PEN", variable: true)
        #expect(Logic.similarPayment(to: Self.probe("Luz del Sur", amount: 140, currency: "PEN"), among: [luz])?.id == luz.id)
    }

    @Test func similar_differentNames_neverMatchBySubcategory() {
        let netflix = Self.candidate("Netflix", amount: 15, subcategory: Self.streaming)
        #expect(Logic.similarPayment(
            to: Self.probe("Disney+", amount: 15, subcategory: Self.streaming), among: [netflix]) == nil)
    }

    @Test func similar_withoutAName_fallsBackToTheSubcategory() {
        let hosting = Self.candidate("Servidor", amount: 20, subcategory: Self.hosting)
        #expect(Logic.similarPayment(to: Self.probe("", amount: 20, subcategory: Self.hosting), among: [hosting])?.id
                == hosting.id)
        #expect(Logic.similarPayment(to: Self.probe("", amount: 20, subcategory: Self.streaming), among: [hosting]) == nil)
    }

    @Test func similar_pausedAndGroupPayments_areLeftOut() {
        let paused = Self.candidate("Cloudflare", amount: 5, active: false)
        let group = Self.candidate("Cloudflare", amount: 5, group: true)
        #expect(Logic.similarPayment(to: Self.probe("Cloudflare", amount: 5), among: [paused, group]) == nil)
    }

    @Test func similar_prefersTheSameMerchant_thenTheClosestAmount() {
        let bySub = Self.candidate("", amount: 5, subcategory: Self.hosting)
        let far = Self.candidate("Cloudflare", amount: 5.6)
        let close = Self.candidate("Cloudflare Pro", amount: 5.1)
        let match = Logic.similarPayment(
            to: Self.probe("Cloudflare", amount: 5, subcategory: Self.hosting), among: [bySub, far, close])
        #expect(match?.id == close.id)
    }

    // MARK: La próxima fecha

    @Test func firstPayment_advancesPastTheRecord_andPastWhatIsBeforeToday_butKeepsToday() {
        let now = Self.day(2026, 11, 15)
        // El vencimiento del día del registro: avanza.
        #expect(Logic.firstPaymentAdvances(
            nextDueDate: Self.day(2026, 11, 3, hour: 0), recordDate: Self.day(2026, 11, 3), now: now, calendar: Self.calendar))
        // Uno entre el registro (septiembre) y hoy: también.
        #expect(Logic.firstPaymentAdvances(
            nextDueDate: Self.day(2026, 10, 3), recordDate: Self.day(2026, 9, 3), now: now, calendar: Self.calendar))
        // El de hoy se queda: es el pago de hoy, que aún no se registró.
        #expect(!Logic.firstPaymentAdvances(
            nextDueDate: Self.day(2026, 11, 15, hour: 0), recordDate: Self.day(2026, 10, 15), now: now,
            calendar: Self.calendar))
        // Uno futuro, tampoco.
        #expect(!Logic.firstPaymentAdvances(
            nextDueDate: Self.day(2026, 12, 3), recordDate: Self.day(2026, 11, 3), now: now, calendar: Self.calendar))
    }

    @Test func link_advances_whenTheRecordPaysTheDueOccurrence_orAFewDaysEarly() {
        let due = Self.day(2026, 12, 3, hour: 0)
        #expect(Logic.linkAdvances(nextDueDate: due, recordDate: Self.day(2026, 12, 3), recurrenceType: "monthly",
                                   calendar: Self.calendar))
        #expect(Logic.linkAdvances(nextDueDate: due, recordDate: Self.day(2026, 12, 9), recurrenceType: "monthly",
                                   calendar: Self.calendar))
        #expect(Logic.linkAdvances(nextDueDate: due, recordDate: Self.day(2026, 11, 29), recurrenceType: "monthly",
                                   calendar: Self.calendar))
        // Un pago de hace un mes no mueve el próximo.
        #expect(!Logic.linkAdvances(nextDueDate: due, recordDate: Self.day(2026, 11, 3), recurrenceType: "monthly",
                                    calendar: Self.calendar))
        // A la semana, solo un día antes.
        #expect(!Logic.linkAdvances(nextDueDate: due, recordDate: Self.day(2026, 11, 30), recurrenceType: "weekly",
                                    calendar: Self.calendar))
    }
}

// MARK: - Sobre el almacén

@MainActor
@Suite("Recurrente desde un registro · vínculo sin duplicar", .serialized)
struct RecurrenteDesdeRegistroServiceTests {

    private func makeContext() throws -> (ModelContext, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecurrenteDesdeRegistro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let personal = ModelConfiguration(
            "RFR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "RFR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "RFR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (context, dir)
    }

    private struct Fixture {
        let account: Account
        let subcategory: Subcategory
        let record: TransactionItem
    }

    private func seed(_ context: ModelContext, recordDate: Date, note: String? = "Cloudflare") throws -> Fixture {
        let account = Account(name: "Visa", currencyCode: "USD", colorHex: "#000000", iconName: "creditcard",
                              type: "credit")
        context.insert(account)
        let category = Category(name: "Servicios", colorHex: "#123456", isIncome: false, iconName: "server.rack")
        context.insert(category)
        let subcategory = Subcategory(name: "Hosting", category: category)
        context.insert(subcategory)
        let record = TransactionItem(
            date: recordDate, amount: -5, currencyCode: "USD", note: note, category: category,
            subcategory: subcategory, account: account, amountInPreferredCurrency: -5, preferredCurrencyCode: "USD")
        context.insert(record)
        try context.save()
        return Fixture(account: account, subcategory: subcategory, record: record)
    }

    private func recordCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<TransactionItem>())
    }

    /// Lo que crea el editor con el prellenado: primer vencimiento en la fecha del registro.
    private func insertPayment(
        _ context: ModelContext, name: String = "Cloudflare", nextDueDate: Date, fixture: Fixture
    ) throws -> ScheduledPayment {
        let calendar = Calendar.current
        let payment = ScheduledPayment(
            name: name, amount: 5, currencyCode: "USD", account: fixture.account, subcategory: fixture.subcategory,
            nextDueDate: calendar.startOfDay(for: nextDueDate), dayOfMonth: calendar.component(.day, from: nextDueDate))
        context.insert(payment)
        try context.save()
        return payment
    }

    // MARK: Prellenado

    @Test func prefill_carriesAmountCurrencyCategoryAccountNoteAndDay() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let date = Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now
        let fixture = try seed(context, recordDate: date)
        let prefill = RecurringFromRecordService.prefill(from: fixture.record)
        #expect(prefill.transactionType == "expense")
        #expect(AmountInputHelper.parseDecimal(prefill.amount) == 5)
        #expect(prefill.currencyCode == "USD")
        #expect(prefill.account?.persistentModelID == fixture.account.persistentModelID)
        #expect(prefill.subcategory?.persistentModelID == fixture.subcategory.persistentModelID)
        #expect(prefill.note == "Cloudflare")
        #expect(prefill.name == "Cloudflare")
        #expect(prefill.transactionDate == date)
    }

    @Test func prefill_withoutNote_namesThePaymentAfterTheSubcategory() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context, recordDate: .now, note: nil)
        #expect(RecurringFromRecordService.prefill(from: fixture.record).name == "Hosting")
    }

    // MARK: Primer pago

    @Test func firstPayment_linksTheRecord_withoutCreatingAnotherRecord() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let calendar = Calendar.current
        let recordDate = calendar.date(byAdding: .day, value: -12, to: .now) ?? .now
        let fixture = try seed(context, recordDate: recordDate)
        let before = try recordCount(context)
        let payment = try insertPayment(context, nextDueDate: recordDate, fixture: fixture)

        let linked = try #require(RecurringFromRecordService.linkAsFirstPayment(
            fixture.record, paymentID: payment.id, context: context))

        #expect(try recordCount(context) == before, "Hacer recurrente no puede crear otro gasto.")
        #expect(fixture.record.scheduledPaymentID == payment.id.uuidString)
        #expect(linked.lastPaidDate == recordDate)
        // El vencimiento del registro ya está pagado: el próximo es el del mes siguiente.
        #expect(calendar.startOfDay(for: linked.nextDueDate) > calendar.startOfDay(for: recordDate))
        #expect(calendar.startOfDay(for: linked.nextDueDate) >= calendar.startOfDay(for: .now))
        // Y ya no se ofrece otra vez sobre el mismo registro.
        #expect(!RecurringFromRecordService.offersMakeRecurring(fixture.record))
    }

    @Test func firstPayment_fromAnOldRecord_doesNotLeaveMissedOccurrencesDue() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let calendar = Calendar.current
        let recordDate = calendar.date(byAdding: .month, value: -3, to: .now) ?? .now
        let fixture = try seed(context, recordDate: recordDate)
        let payment = try insertPayment(context, nextDueDate: recordDate, fixture: fixture)

        let linked = try #require(RecurringFromRecordService.linkAsFirstPayment(
            fixture.record, paymentID: payment.id, context: context))

        // Nada vencido antes de hoy: los meses de en medio no salen en la Bandeja.
        #expect(calendar.startOfDay(for: linked.nextDueDate) >= calendar.startOfDay(for: .now))
        #expect(linked.isActive)
    }

    // MARK: Vincular a uno que ya existe

    @Test func similarPayment_findsTheExistingRecurring() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context, recordDate: .now)
        let existing = try insertPayment(
            context, nextDueDate: Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now, fixture: fixture)
        #expect(RecurringFromRecordService.similarPayment(for: fixture.record, in: context)?.id == existing.id)
    }

    @Test func link_toExisting_coversTheDueOccurrence_andRetiresItsPendingDraft() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let fixture = try seed(context, recordDate: .now)
        let before = try recordCount(context)
        // El recurrente vencía hoy y ya dejó su borrador en la Bandeja.
        let payment = try insertPayment(context, nextDueDate: today, fixture: fixture)
        let draft = InboxDraft(note: "Cloudflare", amount: -5, date: today, account: fixture.account,
                               subcategory: fixture.subcategory, sourceType: .scheduledPayment)
        draft.sourceScheduledPaymentID = payment.id.uuidString
        context.insert(draft)
        try context.save()

        #expect(RecurringFromRecordService.link(fixture.record, to: payment, context: context))

        #expect(try recordCount(context) == before)
        #expect(fixture.record.scheduledPaymentID == payment.id.uuidString)
        #expect(calendar.startOfDay(for: payment.nextDueDate) > today, "El vencimiento de hoy ya está pagado.")
        #expect(draft.status == .rejected, "El borrador del mismo vencimiento sería el mismo gasto dos veces.")
    }

    @Test func link_toExisting_withAnOldRecord_doesNotMoveTheNextDueDate() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let calendar = Calendar.current
        let recordDate = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
        let fixture = try seed(context, recordDate: recordDate)
        let nextDue = calendar.date(byAdding: .day, value: 10, to: .now) ?? .now
        let payment = try insertPayment(context, nextDueDate: nextDue, fixture: fixture)
        let dueBefore = payment.nextDueDate

        #expect(RecurringFromRecordService.link(fixture.record, to: payment, context: context))

        #expect(payment.nextDueDate == dueBefore)
        #expect(fixture.record.scheduledPaymentID == payment.id.uuidString)
    }
}

// MARK: - Cableado

@Suite("Recurrente desde un registro · las tres entradas llegan al mismo flujo")
struct RecurrenteDesdeRegistroWiringTests {

    private static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return text.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    @Test func recordMenu_andDetail_openTheFlow() throws {
        let menu = try Self.code("Yala/App/Views/Records/Components/RecordRowContextMenu.swift")
        #expect(menu.contains("viewModel.recurringFromRecord = record"))
        #expect(menu.contains(".sheet(item: $viewModel.recurringFromRecord)"))
        #expect(menu.contains("RecurringFromRecordSheet(record: record)"))
        let detail = try Self.code("Yala/App/Views/Records/TransactionDetailSheet.swift")
        #expect(detail.contains("RecurringFromRecordSheet(record: transaction)"))
        #expect(detail.contains(".accessibilityLabel(L10n.RecurringFromRecord.makeRecurring)"))
    }

    /// «Aprobar y hacer recurrente» aprueba por el camino de siempre y, al terminar, la hoja pasa al flujo con el
    /// registro recién creado: no hay otra copia del alta.
    @Test func inbox_approveAndMakeRecurring_handsTheApprovedRecordToTheFlow() throws {
        let sheet = try Self.code("Yala/App/Views/Inbox/InboxDraftEditSheet.swift")
        #expect(sheet.contains("approvesIntoRecurring = true\n                    approveDraft()"))
        #expect(sheet.contains("approvesIntoRecurring = false\n                    approveDraft()"))
        #expect(sheet.contains("recurringRecord = transaction"))
        #expect(sheet.contains("RecurringFromRecordSheet(record: recurringRecord)"))
        #expect(sheet.contains("RecurringFromRecordLogic.offersApproveAndMakeRecurring("))
    }

    @Test func planning_fromRecord_opensThePicker() throws {
        let view = try Self.code("Yala/App/Views/Planning/ScheduledPaymentsView.swift")
        #expect(view.contains("onCreateFromRecord: { showsRecordPicker = true }"))
        #expect(view.contains("RecurringRecordPickerSheet()"))
    }
}
