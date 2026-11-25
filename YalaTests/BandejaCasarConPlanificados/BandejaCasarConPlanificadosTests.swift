//
//  BandejaCasarConPlanificadosTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 4: lo que casa con un pago planificado no crea pendiente; completa el borrador del
//  planificado (o lo adelanta) y, si era estimado, le pone el monto real. Cada caso pasa por el código real de cada fuente
//  (`processPending` de Apple Pay, `materialize` del correo), la Bandeja (`InboxViewModel`) y «Separar». E7 es el de
//  `docs/propuestas/bandeja-sin-duplicados/README.md` §2.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized, .lastUsedAccountIsolated)
@MainActor
struct BandejaCasarConPlanificadosTests {

    private let applePayDefaults: UserDefaults

    init() {
        applePayDefaults = testDefaults(suiteName: "test.bandejaPlanificados.applePay.\(UUID().uuidString)")!
        iCloudSyncService.shared._testReset()
    }

    // MARK: - Andamio

    /// Noviembre de 2026 a la hora dada, en la zona del teléfono (el correo fecha por día en esa zona).
    private func nov(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func applePay(_ rawAmount: String, merchant: String?, at date: Date, context: ModelContext) -> Int {
        ApplePayPendingStore.append(
            ApplePayPendingExpense(rawAmount: rawAmount, merchant: merchant, savedAt: date.timeIntervalSince1970),
            defaults: applePayDefaults)
        return ApplePayDraftService.processPending(context: context, pendingStoreDefaults: applePayDefaults,
                                                   importQuiescent: true)
    }

    private func email(_ amount: Double, merchant: String, date: String, context: ModelContext) -> Int? {
        let json: [String: Any] = [
            "id": UUID().uuidString, "received_at_ms": nov(21, 23).timeIntervalSince1970 * 1000, "kind": "expense",
            "amount": amount, "currency": "PEN", "merchant": merchant, "date": date, "bank": "BCP",
            "account_last4": "4821",
        ]
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: json)
        // swiftlint:disable:next force_try
        let dto = try! JSONDecoder().decode(BankEmailDraftDTO.self, from: data)
        return BankEmailDraftService.materialize([dto], context: context)
    }

    private func payment(
        _ name: String, amount: Double, estimate: Bool, due: Date, account: Account, context: ModelContext,
        group: Bool = false
    ) -> ScheduledPayment {
        let payment = ScheduledPayment(name: name, amount: amount, currencyCode: account.currencyCode, account: account,
                                       nextDueDate: due, dayOfMonth: Calendar.current.component(.day, from: due),
                                       isVariableAmount: estimate)
        if group { payment.groupZoneID = "zona-de-grupo" }
        context.insert(payment)
        return payment
    }

    /// El borrador del vencimiento, como lo saca `processDuePayments` el día que vence.
    @discardableResult
    private func dueDraft(_ payment: ScheduledPayment, context: ModelContext) throws -> InboxDraft {
        let draft = ScheduledPaymentDraftService.createDraftForOccurrence(
            from: payment, date: payment.nextDueDate, context: context)
        try context.save()
        return draft
    }

    /// Lo aprendido de un mes anterior: un borrador aprobado del planificado con un cargo unido de ese comercio.
    private func learn(_ alias: String, for payment: ScheduledPayment, context: ModelContext) throws {
        let fields = InboxJoinRecord.Fields(note: payment.name, amount: -abs(payment.amount), date: nov(1),
                                            accountShortcutID: nil, subcategoryShortcutID: nil, cachedCurrencyCode: "PEN")
        let member = InboxJoinRecord.Member(
            facts: InboxJoinRecord.SourceFacts(source: "bankEmail", currencyCode: "PEN", last4: "4821", hasExactTime: false),
            fields: InboxJoinRecord.Fields(note: alias, amount: -abs(payment.amount), date: nov(1),
                                           accountShortcutID: nil, subcategoryShortcutID: nil, cachedCurrencyCode: "PEN"),
            sourceTypeRaw: DraftSourceType.emailAlert.rawValue, createdAt: nov(1), rawText: nil, evidence: nil,
            confidenceAmount: nil, confidenceDate: nil, confidenceMerchant: nil, confidenceSubcategory: nil,
            joinedAt: nov(1))
        let record = InboxJoinRecord(
            version: 1, holderSource: InboxJoinRecord.SourceFacts(source: "planned", currencyCode: "PEN", last4: nil,
                                                                  hasExactTime: false),
            holderBefore: fields, holderAfter: fields, members: [member])
        let approved = InboxDraft(note: payment.name, amount: -abs(payment.amount), date: nov(1),
                                  sourceType: .scheduledPayment, status: .approved)
        approved.sourceScheduledPaymentID = payment.id.uuidString
        approved.joinRecordRaw = record.encoded()
        context.insert(approved)
        try context.save()
    }

    private func pending(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.status == .pending }
    }

    private func viewModel(_ context: ModelContext, defaults: UserDefaults) -> InboxViewModel {
        let vm = InboxViewModel()
        vm.distinctDefaults = defaults
        vm.setContext(context)
        return vm
    }

    // MARK: - E7 · Luz del Sur, la primera vez

    @Test("E7, la primera vez: el correo de Luz del Sur no se une solo, la Bandeja pregunta y «Sí» le pone el monto real")
    func estimate_firstTime_asks_thenConfirmTakesTheRealAmount() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let luz = payment("Luz del Sur", amount: 120, estimate: true, due: nov(20), account: visa, context: context)
        let planned = try dueDraft(luz, context: context)

        #expect(email(134.80, merchant: "LUZ DEL SUR SAA", date: "2026-11-20", context: context) == 1)
        #expect(try pending(context).count == 2, "la primera vez no se une solo: el comercio aún no está aprendido")

        let defaults = makeIsolatedDefaults()
        let vm = viewModel(context, defaults: defaults)
        let question = try #require(vm.plannedQuestions.first)
        #expect(vm.plannedQuestions.count == 1)
        #expect(question.paymentID == luz.id)
        #expect(question.plannedDraft === planned, "el borrador del planificado va en la misma tarjeta")
        #expect(question.arriving.sourceType == .emailAlert)
        let items = vm.listSections(for: .pending, pairsSameExpense: true).flatMap(\.items)
        #expect(items.count == 1, "la tarjeta lleva a los dos: ninguno sale suelto")
        if case .planned = items.first {} else { Issue.record("la tarjeta no está en la lista") }

        #expect(InboxArrivalJoin.confirmPlanned(question.arriving, paymentID: luz.id, context: context))
        let drafts = try pending(context)
        #expect(drafts.count == 1)
        let joined = try #require(drafts.first)
        #expect(joined === planned, "lo sostiene el borrador del planificado")
        #expect(joined.amount == -134.80, "el estimado toma el monto real del banco")
        #expect(joined.note == "Luz del Sur", "la nota del planificado no se pisa con el texto del banco")
        #expect(joined.account?.shortcutID == visa.shortcutID)
        #expect(Calendar.current.isDate(try #require(joined.date), inSameDayAs: nov(20)))
        #expect(joined.plannedEstimateBeforeText?.contains("120") == true, "«Antes S/ 120.00 estimado»")
        #expect(joined.joinedSources?.count == 2)
        #expect(luz.amount == 120, "el planificado no se toca")
        vm.loadData()
        #expect(vm.plannedQuestions.isEmpty)
    }

    @Test("E7, ya aprendido: el correo de Luz del Sur completa solo el borrador del planificado")
    func estimate_learned_joinsOnArrival() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let luz = payment("Luz del Sur", amount: 120, estimate: true, due: nov(20), account: visa, context: context)
        let planned = try dueDraft(luz, context: context)
        try learn("LUZ DEL SUR SAA", for: luz, context: context)

        #expect(email(134.80, merchant: "LUZ DEL SUR S.A.A. PAGO", date: "2026-11-20", context: context) == 1)
        let drafts = try pending(context)
        #expect(drafts.count == 1, "lo que casa con un planificado no crea pendiente")
        #expect(drafts.first === planned)
        #expect(planned.amount == -134.80)
        #expect(planned.note == "Luz del Sur")
        guard case .record(let record) = InboxJoinRecord.read(planned.joinRecordRaw) else {
            Issue.record("sin registro de unión")
            return
        }
        #expect(record.holderIsPlanned)
        #expect(record.holderIsEstimate == true)
        #expect(record.holderCreatedByJoin == false)
        #expect(record.holderBefore.amount == -120)
    }

    @Test("Aprobar el borrador unido marca pagado el día del cargo y avanza la próxima fecha, como siempre")
    func approvingTheJoinedDraft_advancesThePayment() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let luz = payment("Luz del Sur", amount: 120, estimate: true, due: nov(20), account: visa, context: context)
        let planned = try dueDraft(luz, context: context)
        try learn("LUZ DEL SUR", for: luz, context: context)
        #expect(email(134.80, merchant: "LUZ DEL SUR", date: "2026-11-22", context: context) == 1)
        #expect(try pending(context).count == 1)

        ScheduledPaymentDraftService.handleDraftApproved(draft: planned, context: context)
        #expect(Calendar.current.isDate(try #require(luz.lastPaidDate), inSameDayAs: nov(22)))
        #expect(Calendar.current.component(.month, from: luz.nextDueDate) == 12, "avanza a diciembre")
    }

    // MARK: - Adelantar y separar

    @Test("Aún no vence: el cargo adelanta el borrador del planificado; «Separar» lo devuelve y borra el adelantado")
    func notYetDue_advances_andSeparateUndoes() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let netflix = payment("Netflix", amount: 44.90, estimate: false, due: nov(23), account: visa, context: context)
        try context.save()
        try learn("NETFLIX.COM", for: netflix, context: context)

        #expect(applePay("S/44.90", merchant: "Netflix.com", at: nov(20, 9, 30), context: context) == 1)
        var drafts = try pending(context)
        #expect(drafts.count == 1)
        let holder = try #require(drafts.first)
        #expect(holder.sourceScheduledPaymentID == netflix.id.uuidString, "el cargo adelantó el borrador del planificado")
        #expect(holder.note == "Netflix")
        #expect(holder.date == nov(20, 9, 30), "con la hora del cargo")
        guard case .record(let record) = InboxJoinRecord.read(holder.joinRecordRaw) else {
            Issue.record("sin registro de unión")
            return
        }
        #expect(record.holderCreatedByJoin == true)
        #expect(InboxJoinLogic.sources(of: record) == [.planned, .applePay])

        // El día que vence no sale otro borrador: ya hay uno pendiente.
        ScheduledPaymentDraftService.processDuePayments(context: context)
        #expect(try pending(context).count == 1)

        let separated = try #require(InboxArrivalJoin.separate(holder, context: context))
        #expect(separated.count == 1)
        drafts = try pending(context)
        #expect(drafts.count == 1, "vuelve el de Apple Pay y el adelantado se va")
        #expect(drafts.first?.sourceType == .applePay)
        #expect(drafts.first?.amount == -44.90)
    }

    // MARK: - Fijo con otro importe

    @Test("Fijo con otro cargo: no se une solo aunque el comercio esté aprendido; la Bandeja pregunta")
    func fixed_otherAmount_asks() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let netflix = payment("Netflix", amount: 39.90, estimate: false, due: nov(20), account: visa, context: context)
        try dueDraft(netflix, context: context)
        try learn("NETFLIX.COM", for: netflix, context: context)

        #expect(applePay("S/44.90", merchant: "Netflix.com", at: nov(20, 9), context: context) == 1)
        #expect(try pending(context).count == 2, "un fijo con otro importe no se actualiza solo")
        let vm = viewModel(context, defaults: makeIsolatedDefaults())
        #expect(vm.plannedQuestions.map(\.paymentID) == [netflix.id])
    }

    // MARK: - Una fuente más tras unir

    @Test("Apple Pay se une al planificado y el correo del mismo cargo llega después: un solo pendiente")
    func secondSource_joinsThePlannedDraftToo() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let netflix = payment("Netflix", amount: 44.90, estimate: false, due: nov(20), account: visa, context: context)
        let planned = try dueDraft(netflix, context: context)
        try learn("NETFLIX.COM", for: netflix, context: context)

        #expect(applePay("S/44.90", merchant: "Netflix.com", at: nov(20, 9), context: context) == 1)
        #expect(email(44.90, merchant: "NETFLIX", date: "2026-11-20", context: context) == 1)
        let drafts = try pending(context)
        #expect(drafts.count == 1)
        #expect(drafts.first === planned)
        guard case .record(let record) = InboxJoinRecord.read(planned.joinRecordRaw) else {
            Issue.record("sin registro de unión")
            return
        }
        #expect(InboxJoinLogic.sources(of: record) == [.planned, .applePay, .bankEmail])
        #expect(planned.note == "Netflix")
    }

    // MARK: - Lo que no casa

    @Test("Un pago planificado de grupo queda fuera (decisión 7)")
    func groupPayment_isIgnored() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let rent = payment("Alquiler", amount: 1_500, estimate: false, due: nov(20), account: visa, context: context,
                           group: true)
        try context.save()
        try learn("ALQUILER", for: rent, context: context)

        #expect(email(1_500, merchant: "ALQUILER", date: "2026-11-20", context: context) == 1)
        let drafts = try pending(context)
        #expect(drafts.count == 1)
        #expect(drafts.first?.sourceType == .emailAlert, "no se adelantó nada del grupo")
        #expect(viewModel(context, defaults: makeIsolatedDefaults()).plannedQuestions.isEmpty)
    }

    @Test("«No es ese pago»: no se vuelve a preguntar")
    func deny_hidesTheQuestion() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let luz = payment("Luz del Sur", amount: 120, estimate: true, due: nov(20), account: visa, context: context)
        try dueDraft(luz, context: context)
        #expect(email(134.80, merchant: "LUZ DEL SUR SAA", date: "2026-11-20", context: context) == 1)

        let defaults = makeIsolatedDefaults()
        let question = try #require(viewModel(context, defaults: defaults).plannedQuestions.first)
        InboxPlannedDistinct.markDistinct([question.arriving], paymentID: luz.id, defaults)
        #expect(viewModel(context, defaults: defaults).plannedQuestions.isEmpty)
        #expect(try pending(context).count == 2, "los dos siguen pendientes")
    }

    @Test("Fuera de los ±5 días no se une ni se pregunta")
    func farFromTheDueDate_isNothing() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let luz = payment("Luz del Sur", amount: 120, estimate: true, due: nov(5), account: visa, context: context)
        try dueDraft(luz, context: context)
        try learn("LUZ DEL SUR", for: luz, context: context)

        #expect(email(134.80, merchant: "LUZ DEL SUR", date: "2026-11-20", context: context) == 1)
        #expect(try pending(context).count == 2)
        #expect(viewModel(context, defaults: makeIsolatedDefaults()).plannedQuestions.isEmpty)
    }
}
