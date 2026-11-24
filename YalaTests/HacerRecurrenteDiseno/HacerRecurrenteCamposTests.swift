//
//  HacerRecurrenteCamposTests.swift
//  YalaTests
//
//  Pedido de Jürgen del 2026-11-23: «Hacer recurrente» desde Nuevo registro / Editar copia TODO lo del registro, por la
//  opción rápida (una frecuencia) y por «Más opciones…» (el editor completo prellenado). Las dos salen de
//  `RecurringFromRecordService.FormRecord`; aquí se fijan campo por campo, más el ancla de la fecha, la próxima fecha tras
//  guardar (un registro de mañana no deja otro borrador mañana) y lo que enseña la hoja.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Hacer recurrente · campos copiados", .serialized)
@MainActor
struct HacerRecurrenteCamposTests {

    private func makeContext() throws -> (ModelContext, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HacerRecurrenteCampos-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let personal = ModelConfiguration(
            "HRC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "HRC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "HRC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (context, dir)
    }

    /// Lunes 23 de noviembre de 2026, al mediodía: el «hoy» fijo de estos casos.
    private nonisolated static let recordDate: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12)) ?? .distantPast
    }()

    private struct Fixture {
        let account: Account
        let subcategory: Subcategory
        let tags: [Yala.Tag]
    }

    /// Una cuenta en USD, «Deporte › Gimnasio» (esencial) y dos etiquetas.
    private func seed(_ context: ModelContext) throws -> Fixture {
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard",
                              type: "credit")
        context.insert(account)
        let category = Category(name: "Deporte", colorHex: "#123456", isIncome: false, iconName: "figure.run")
        context.insert(category)
        let subcategory = Subcategory(name: "Gimnasio", natureRawValue: SubcategoryNeed.essential.rawValue,
                                      category: category)
        context.insert(subcategory)
        let tags = [Yala.Tag(name: "Salud"), Yala.Tag(name: "Fijo")]
        tags.forEach { context.insert($0) }
        try context.save()
        return Fixture(account: account, subcategory: subcategory, tags: tags)
    }

    /// El registro tal como lo deja el formulario: con descripción, otra divisa que la de la cuenta y otra necesidad.
    private func form(
        _ fixture: Fixture, note: String = "Smart Fit", subcategory: Subcategory?? = .none,
        type: TransactionType = .expense, date: Date = Self.recordDate
    ) -> RecurringFromRecordService.FormRecord {
        RecurringFromRecordService.FormRecord(
            transactionType: type,
            amount: 129.9,
            currencyCode: "USD",
            note: note,
            account: fixture.account,
            subcategory: subcategory ?? fixture.subcategory,
            tags: fixture.tags,
            need: .optional,
            date: date)
    }

    private func payment(_ id: UUID, in context: ModelContext) throws -> ScheduledPayment {
        let all = try context.fetch(FetchDescriptor<ScheduledPayment>())
        return try #require(all.first { $0.id == id })
    }

    private func ids(_ tags: [Yala.Tag]?) -> Set<PersistentIdentifier> {
        Set((tags ?? []).map(\.persistentModelID))
    }

    // MARK: - Opción rápida

    @Test(arguments: [RecurrenceType.weekly, .monthly, .yearly])
    func quick_copiesEveryFieldOfTheRecord(_ recurrence: RecurrenceType) throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context)

        let id = try #require(RecurringFromRecordService.createQuickPayment(
            from: form(fixture), recurrence: recurrence, context: context,
            deletionService: EntityDeletionService.shared))
        let saved = try payment(id, in: context)

        #expect(saved.name == "Smart Fit")
        #expect(saved.note == "Smart Fit")
        #expect(saved.amount == 129.9)
        #expect(saved.currencyCode == "USD", "La divisa del importe, no la de la cuenta.")
        #expect(saved.transactionType == "expense")
        #expect(saved.account?.persistentModelID == fixture.account.persistentModelID)
        #expect(saved.subcategory?.persistentModelID == fixture.subcategory.persistentModelID)
        #expect(ids(saved.tags) == ids(fixture.tags), "Las dos etiquetas del registro.")
        #expect(saved.needOverride == SubcategoryNeed.optional.rawValue, "La necesidad elegida, distinta de la de la subcategoría.")
        #expect(saved.recurrenceType == recurrence.rawValue)
        #expect(saved.isRecurring && saved.isActive && saved.notifyOnDueDate)
        #expect(saved.paymentCategory == PaymentCategory.recurring.rawValue)

        let calendar = Calendar.current
        switch recurrence {
        case .weekly: #expect(saved.selectedWeekdays == String(calendar.component(.weekday, from: Self.recordDate)))
        case .monthly: #expect(saved.dayOfMonth == 23)
        case .yearly:
            #expect(saved.yearlyMonth == 11)
            #expect(saved.yearlyDay == 23)
        case .daily: Issue.record("La hoja no ofrece diario.")
        }
        #expect(calendar.startOfDay(for: saved.nextDueDate) == calendar.startOfDay(for: Self.recordDate),
                "El primer vencimiento es el del registro.")
    }

    @Test func quick_withTheSubcategoryNeed_doesNotStoreAnOverride() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context)
        let base = form(fixture)
        let sameNeed = RecurringFromRecordService.FormRecord(
            transactionType: base.transactionType, amount: base.amount, currencyCode: base.currencyCode,
            note: base.note, account: base.account, subcategory: base.subcategory, tags: base.tags,
            need: .essential, date: base.date)
        let id = try #require(RecurringFromRecordService.createQuickPayment(
            from: sameNeed, recurrence: .monthly, context: context, deletionService: EntityDeletionService.shared))
        #expect(try payment(id, in: context).needOverride == nil)
    }

    @Test func quick_withoutNote_isNamedAfterTheSubcategory_andThenTheType() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context)

        let withSub = try #require(RecurringFromRecordService.createQuickPayment(
            from: form(fixture, note: "  "), recurrence: .monthly, context: context,
            deletionService: EntityDeletionService.shared))
        #expect(try payment(withSub, in: context).name == "Gimnasio")

        let bare = try #require(RecurringFromRecordService.createQuickPayment(
            from: form(fixture, note: "", subcategory: .some(nil), type: .income), recurrence: .monthly,
            context: context, deletionService: EntityDeletionService.shared))
        let saved = try payment(bare, in: context)
        #expect(saved.name == TransactionType.income.displayName)
        #expect(saved.transactionType == "income")
    }

    @Test func quick_withoutAccount_createsNothing() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context)
        let base = form(fixture)
        let noAccount = RecurringFromRecordService.FormRecord(
            transactionType: base.transactionType, amount: base.amount, currencyCode: base.currencyCode,
            note: base.note, account: nil, subcategory: base.subcategory, tags: base.tags, need: base.need,
            date: base.date)
        #expect(RecurringFromRecordService.createQuickPayment(
            from: noAccount, recurrence: .monthly, context: context,
            deletionService: EntityDeletionService.shared) == nil)
        #expect(try context.fetchCount(FetchDescriptor<ScheduledPayment>()) == 0)
    }

    // MARK: - «Más opciones…»

    @Test func moreOptions_prefillsEveryFieldOfTheRecord() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context)

        let prefill = RecurringFromRecordService.moreOptionsPrefill(from: form(fixture))

        #expect(prefill.name == "Smart Fit")
        #expect(prefill.note == "Smart Fit")
        #expect(AmountInputHelper.parseDecimal(prefill.amount) == 129.9)
        #expect(prefill.currencyCode == "USD")
        #expect(prefill.transactionType == "expense")
        #expect(prefill.account?.persistentModelID == fixture.account.persistentModelID)
        #expect(prefill.subcategory?.persistentModelID == fixture.subcategory.persistentModelID)
        #expect(prefill.tagIDs == ids(fixture.tags))
        #expect(prefill.needOverride == .optional)
        #expect(prefill.transactionDate == Self.recordDate)
        #expect(prefill.group == nil)
    }

    /// Antes abría el editor con el nombre vacío si el registro no tenía descripción.
    @Test func moreOptions_withoutNote_isNamedLikeTheQuickOption() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context)
        #expect(RecurringFromRecordService.moreOptionsPrefill(from: form(fixture, note: "")).name == "Gimnasio")
    }

    // MARK: - La próxima fecha tras guardar

    /// Un registro fechado mañana: su vencimiento ya está pagado y la próxima fecha salta al siguiente. Antes la
    /// hoja solo avanzaba si el vencimiento era de hoy o anterior, y mañana dejaba un borrador del mismo gasto.
    @Test func quick_thenLink_aRecordDatedTomorrow_skipsItsOwnOccurrence() throws {
        let (context, dir) = try makeContext()
        defer { discardTestStoreDirectory(dir) }
        let fixture = try seed(context)
        let calendar = Calendar.current
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: Self.recordDate))
        let id = try #require(RecurringFromRecordService.createQuickPayment(
            from: form(fixture, date: tomorrow), recurrence: .monthly, context: context,
            deletionService: EntityDeletionService.shared))
        let record = TransactionItem(
            date: tomorrow, amount: -129.9, currencyCode: "USD", note: "Smart Fit", category: fixture.subcategory.category,
            subcategory: fixture.subcategory, account: fixture.account, amountInPreferredCurrency: -129.9,
            preferredCurrencyCode: "PEN")
        context.insert(record)

        let linked = try #require(RecurringFromRecordService.linkAsFirstPayment(
            record, paymentID: id, context: context, now: Self.recordDate))

        #expect(record.scheduledPaymentID == id.uuidString)
        #expect(calendar.startOfDay(for: linked.nextDueDate) > calendar.startOfDay(for: tomorrow))
        #expect(calendar.component(.day, from: linked.nextDueDate) == 24)
        #expect(calendar.component(.month, from: linked.nextDueDate) == 12)
    }

    /// La hoja de Nuevo registro usa esa regla, y la opción rápida y «Más opciones…» salen de la misma fuente.
    @Test func newTransactionView_usesTheSharedSource_andTheSharedLink() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/Views/Transactions/NewTransactionView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("RecurringFromRecordService.createQuickPayment("))
        #expect(source.contains("RecurringFromRecordService.moreOptionsPrefill(from: recurringFormRecord)"))
        #expect(source.contains("RecurringFromRecordService.linkAsFirstPayment("))
        #expect(!source.contains("ScheduledPaymentPrefill(\n                transactionType: viewModel.transactionType"),
                "El prellenado de «Más opciones…» no se vuelve a escribir a mano.")
        #expect(!source.contains("ScheduledPaymentDraftService.advanceToNextDueDate"),
                "La próxima fecha la avanza la regla compartida, no un avance suelto.")
    }
}

// MARK: - Lo que enseña la hoja

@Suite("Hacer recurrente · la hoja")
struct HacerRecurrenteHojaTests {

    typealias Logic = RecurringQuickChoiceLogic

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    /// Lunes 23 de noviembre de 2026.
    private static let date: Date = {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12)) ?? .distantPast
    }()

    @Test func badge_spanish() {
        let locale = Locale(identifier: "es_PE")
        #expect(Logic.badge(for: .weekly, date: Self.date, locale: locale, calendar: Self.calendar)
                == .init(band: nil, main: "LUN", mainIsWord: true))
        #expect(Logic.badge(for: .monthly, date: Self.date, locale: locale, calendar: Self.calendar)
                == .init(band: nil, main: "23", mainIsWord: false))
        #expect(Logic.badge(for: .yearly, date: Self.date, locale: locale, calendar: Self.calendar)
                == .init(band: "NOV", main: "23", mainIsWord: false))
    }

    @Test func badge_english() {
        let locale = Locale(identifier: "en_US")
        #expect(Logic.badge(for: .weekly, date: Self.date, locale: locale, calendar: Self.calendar).main == "MON")
        #expect(Logic.badge(for: .yearly, date: Self.date, locale: locale, calendar: Self.calendar).band == "NOV")
    }

    @Test func badge_matchesTheAnchorOfTheRow() {
        let anchor = Logic.anchor(for: Self.date, calendar: Self.calendar)
        let monthly = Logic.badge(for: .monthly, date: Self.date, locale: Locale(identifier: "es_PE"),
                                  calendar: Self.calendar)
        #expect(monthly.main == String(anchor.dayOfMonth))
    }

    @Test func summaryDetail_joinsWhatTheRecordHas() {
        #expect(Logic.summaryDetail(accountName: "Visa", categoryName: "Deporte", subcategoryName: "Gimnasio")
                == "Visa · Deporte › Gimnasio")
        #expect(Logic.summaryDetail(accountName: "Visa", categoryName: "Hogar", subcategoryName: "Hogar")
                == "Visa · Hogar")
        #expect(Logic.summaryDetail(accountName: "Visa", categoryName: nil, subcategoryName: nil) == "Visa")
        #expect(Logic.summaryDetail(accountName: nil, categoryName: nil, subcategoryName: "Gimnasio") == "Gimnasio")
        #expect(Logic.summaryDetail(accountName: " ", categoryName: nil, subcategoryName: nil).isEmpty)
    }
}
