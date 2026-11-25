//
//  BandejaUnirAlLlegarTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 2: el mismo consumo que llega por Apple Pay, el aviso del banco, el correo del banco, Yala
//  web o tu IA queda en UN pendiente, con «Separar» (`InboxArrivalJoin`). Cada caso pasa por el código real de cada
//  fuente (`processPending` de Apple Pay y del aviso, `materialize` del correo, la web y la IA), con las colas aisladas.
//  Los escenarios son los de `docs/propuestas/bandeja-sin-duplicados/README.md` §2.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized, .lastUsedAccountIsolated)
@MainActor
struct BandejaUnirAlLlegarTests {

    private let applePayDefaults: UserDefaults
    private let noticeDefaults: UserDefaults

    init() {
        applePayDefaults = testDefaults(suiteName: "test.bandejaUnir.applePay.\(UUID().uuidString)")!
        noticeDefaults = testDefaults(suiteName: "test.bandejaUnir.notice.\(UUID().uuidString)")!
        iCloudSyncService.shared._testReset()
    }

    // MARK: - Andamio

    /// 20-nov-2026 a la hora dada, en la zona del teléfono (el correo fecha por día en esa zona).
    private func day20(_ hour: Int, _ minute: Int, day: Int = 20) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func applePay(_ rawAmount: String, merchant: String?, at date: Date, context: ModelContext) -> Int {
        ApplePayPendingStore.append(
            ApplePayPendingExpense(rawAmount: rawAmount, merchant: merchant, savedAt: date.timeIntervalSince1970),
            defaults: applePayDefaults)
        return ApplePayDraftService.processPending(context: context, pendingStoreDefaults: applePayDefaults,
                                                   importQuiescent: true)
    }

    private func notice(_ text: String, at date: Date, context: ModelContext) -> Int {
        let reading = BankNoticeParser.read(text, bankHint: .bcp) ?? .notUnderstood
        BankNoticePendingStore.append(
            BankNoticePendingEntry(rawText: text, bank: .bcp, reading: reading, receivedAt: date.timeIntervalSince1970),
            defaults: noticeDefaults)
        return BankNoticeDraftService.processPending(context: context, pendingStoreDefaults: noticeDefaults,
                                                     importQuiescent: true)
    }

    private func dto(
        amount: Double, merchant: String?, date: String, kind: String = "expense", currency: String? = "PEN",
        source: String? = nil, bank: String? = "BCP", last4: String? = "4821", receivedAt: Date? = nil,
        id: String = UUID().uuidString
    ) -> BankEmailDraftDTO {
        // Llegó después del día que dice (una fecha más de un día en el futuro cae a la de llegada).
        let arrived = receivedAt ?? day20(23, 0, day: 21)
        let json: [String: Any?] = [
            "id": id, "received_at_ms": arrived.timeIntervalSince1970 * 1000, "kind": kind, "amount": amount,
            "currency": currency, "merchant": merchant, "date": date, "bank": source == nil ? bank : nil,
            "account_last4": source == nil ? last4 : nil, "source": source, "client": source == "ai" ? "Claude" : nil,
        ]
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(BankEmailDraftDTO.self, from: data)
    }

    private func pending(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>()).filter { $0.status == .pending }
    }

    private func noticeText(_ amount: String, merchant: String = "STARBUCKS MIRAFLORES") -> String {
        "Consumo con tu tarjeta\nRealizaste un consumo de S/ \(amount) con tu Tarjeta de Débito BCP ****4821 en \(merchant)."
    }

    // MARK: - E1 · el mismo café por las tres fuentes

    @Test("E1: el mismo café por Apple Pay, aviso y correo es UN pendiente, con el importe del banco y el comercio de Apple Pay")
    func sameCoffee_threeSources_isOnePending() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()

        #expect(applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context) == 1)
        #expect(notice(noticeText("42.50"), at: day20(13, 6), context: context) == 1)
        #expect(BankEmailDraftService.materialize([dto(amount: 42.5, merchant: "STARBUCKS", date: "2026-11-20")],
                                                  context: context) == 1)

        let drafts = try pending(context)
        #expect(drafts.count == 1, "tres fuentes del mismo pago, un pendiente")
        let draft = try #require(drafts.first)
        #expect(draft.sourceType == .applePay, "lo sostiene el primero que llegó")
        #expect(draft.amount == -42.5)
        #expect(draft.note == "Starbucks", "el comercio de Apple Pay viene limpio")
        #expect(draft.date == day20(13, 5), "la hora exacta de Apple Pay")
        #expect(draft.account?.shortcutID == visa.shortcutID)
        guard case .record(let record) = InboxJoinRecord.read(draft.joinRecordRaw) else {
            Issue.record("sin registro de unión")
            return
        }
        #expect(InboxJoinLogic.sources(of: record) == [.applePay, .bankNotice, .bankEmail])
        #expect(BankNoticePendingStore.peekAll(defaults: noticeDefaults).isEmpty, "el aviso unido también consume su cola")
    }

    @Test("E2: Apple Pay a las 23:50 y el correo fechado al día siguiente se unen")
    func midnight_applePayAndNextDayEmail_join() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()

        #expect(applePay("S/89.90", merchant: "Wong", at: day20(23, 50, day: 15), context: context) == 1)
        _ = BankEmailDraftService.materialize([dto(amount: 89.9, merchant: "WONG SUPERMERCADO", date: "2026-11-16")],
                                              context: context)
        #expect(try pending(context).count == 1)
    }

    @Test("El importe lo manda el banco: un correo que difiere en un céntimo deja el suyo")
    func amountFromTheBank() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()

        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        _ = BankEmailDraftService.materialize([dto(amount: 42.51, merchant: "STARBUCKS", date: "2026-11-20")],
                                              context: context)
        let draft = try #require(try pending(context).first)
        #expect(try pending(context).count == 1)
        #expect(draft.amount == -42.51)
    }

    // MARK: - Lo que NO se une

    @Test("E8: dos compras iguales por Apple Pay son dos pendientes, en la misma tanda y en dos")
    func twoEqualApplePayPurchases_stayTwo() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()

        ApplePayPendingStore.append(ApplePayPendingExpense(rawAmount: "S/12.00", merchant: "Tambo",
                                                           savedAt: day20(8, 10).timeIntervalSince1970),
                                    defaults: applePayDefaults)
        ApplePayPendingStore.append(ApplePayPendingExpense(rawAmount: "S/12.00", merchant: "Tambo",
                                                           savedAt: day20(9, 40).timeIntervalSince1970),
                                    defaults: applePayDefaults)
        #expect(ApplePayDraftService.processPending(context: context, pendingStoreDefaults: applePayDefaults,
                                                    importQuiescent: true) == 2)
        _ = applePay("S/12.00", merchant: "Tambo", at: day20(10, 0), context: context)
        #expect(try pending(context).count == 3)
        #expect(try pending(context).allSatisfy { $0.joinRecordRaw == nil })
    }

    @Test("E8 con el correo: dos cafés iguales y UN correo se quedan en dos pendientes (uno a uno)")
    func twoPurchasesOneEmail_oneToOne() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()

        _ = applePay("S/12.00", merchant: "Tambo", at: day20(8, 10), context: context)
        _ = applePay("S/12.00", merchant: "Tambo", at: day20(18, 40), context: context)
        _ = BankEmailDraftService.materialize([dto(amount: 12, merchant: "TAMBO", date: "2026-11-20")], context: context)
        let drafts = try pending(context)
        #expect(drafts.count == 2)
        #expect(drafts.filter { $0.joinRecordRaw != nil }.count == 1)
    }

    @Test("E9: un gasto y su reembolso del mismo importe no se unen")
    func expenseAndRefund_stayApart() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()

        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        _ = BankEmailDraftService.materialize(
            [dto(amount: 42.5, merchant: "STARBUCKS", date: "2026-11-20", kind: "income")], context: context)
        #expect(try pending(context).count == 2)
    }

    @Test("Sin cuenta en una de las dos y sin últimos 4 que la aten, no se une solo (es dudosa)")
    func noAccountNoLast4_doesNotJoin() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        _ = makeTestAccount(context: context, name: "Interbank", currencyCode: "PEN")
        try context.save()

        // Con dos cuentas en soles Apple Pay no elige cuenta; el correo tampoco (sin banco ni últimos 4 que casen).
        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        _ = BankEmailDraftService.materialize(
            [dto(amount: 42.5, merchant: "STARBUCKS", date: "2026-11-20", bank: nil, last4: nil)], context: context)
        #expect(try pending(context).count == 2)
    }

    @Test("Los borradores de grupo quedan fuera: el mismo importe llega como pendiente aparte")
    func groupDrafts_areIgnored() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let group = InboxDraft(note: "Starbucks", amount: -42.5, date: day20(13, 0), account: visa,
                               sourceType: .groupExpense, splitExpenseID: UUID().uuidString)
        context.insert(group)
        try context.save()

        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        #expect(try pending(context).count == 2)
        #expect(group.joinRecordRaw == nil)
    }

    @Test("Un registro de unión que no se entiende (versión futura) no se usa como sostén ni se reescribe")
    func unreadableRecord_isLeftAlone() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()
        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        let holder = try #require(try pending(context).first)
        let future = #"{"version":99,"members":[{"x":1}]}"#
        holder.joinRecordRaw = future
        try context.save()

        _ = BankEmailDraftService.materialize([dto(amount: 42.5, merchant: "STARBUCKS", date: "2026-11-20")],
                                              context: context)
        #expect(try pending(context).count == 2)
        #expect(holder.joinRecordRaw == future)
        #expect(InboxJoinedSourcesSection.sources(of: holder) == nil, "sin «Separar» para lo que no se entiende")
    }

    // MARK: - IA, web y la misma tanda

    @Test("E4: la IA apunta el café que ya está pendiente por Apple Pay: se une, y otro aparato no lo vuelve a crear")
    func aiJoins_andIsNotMaterializedAgain() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()
        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)

        let ai = dto(amount: 42.5, merchant: "Starbucks", date: "2026-11-20", source: "ai", receivedAt: day20(14, 0))
        #expect(BankEmailDraftService.materialize([ai], context: context) == 1)
        #expect(try pending(context).count == 1)

        // Otro aparato que vuelve a traer la cola (el `ack` no llegó): lo reconoce dentro del registro de unión.
        #expect(BankEmailDraftService.materialize([ai], context: context) == 0)
        #expect(try pending(context).count == 1)
    }

    @Test("Correo y web de la misma tanda: lo que llega primero sostiene y lo siguiente se une a él")
    func sameBatch_secondJoinsTheFirst() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()

        let email = dto(amount: 42.5, merchant: "STARBUCKS", date: "2026-11-20")
        let ai = dto(amount: 42.5, merchant: "Starbucks", date: "2026-11-20", source: "ai", receivedAt: day20(14, 0))
        #expect(BankEmailDraftService.materialize([email, ai], context: context) == 2)
        let drafts = try pending(context)
        #expect(drafts.count == 1)
        #expect(drafts.first?.note == "Starbucks", "el comercio de la IA gana al texto del banco")
    }

    // MARK: - Separar

    @Test("Separar devuelve cada fuente como pendiente aparte, tal como llegó, y el que sostenía recupera sus valores")
    func separate_restoresEverySource() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()
        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        _ = notice(noticeText("42.50"), at: day20(13, 6), context: context)
        _ = BankEmailDraftService.materialize([dto(amount: 42.51, merchant: "STARBUCKS", date: "2026-11-20")],
                                              context: context)
        let holder = try #require(try pending(context).first)
        #expect(holder.amount == -42.51)

        let separated = try #require(InboxArrivalJoin.separate(holder, context: context))
        #expect(separated.count == 2)
        let drafts = try pending(context)
        #expect(drafts.count == 3)
        #expect(holder.amount == -42.5, "Apple Pay vuelve a su importe")
        #expect(holder.joinRecordRaw == nil)
        #expect(drafts.contains { $0.sourceType == .emailAlert && $0.amount == -42.51 && $0.note == "STARBUCKS" })
        #expect(drafts.contains { $0.sourceType == .automation && $0.evidence == "BCP" && $0.note == "STARBUCKS MIRAFLORES" })
        #expect(drafts.allSatisfy { $0.account != nil })
    }

    @Test("Separar conserva lo que la persona cambió después de unir")
    func separate_keepsEditsMadeAfterJoining() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()
        _ = BankEmailDraftService.materialize([dto(amount: 42.5, merchant: "STARBUCKS", date: "2026-11-20")],
                                              context: context)
        let emailDate = try #require(try pending(context).first?.date)
        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        let holder = try #require(try pending(context).first)
        #expect(holder.sourceType == .emailAlert)
        #expect(holder.date == day20(13, 5), "la hora exacta de Apple Pay")
        #expect(holder.note == "Starbucks")
        holder.note = "Café con Ana"
        try context.save()

        _ = InboxArrivalJoin.separate(holder, context: context)
        #expect(holder.note == "Café con Ana")
        #expect(holder.date == emailDate, "la fecha, que nadie tocó, sí vuelve")
        #expect(try pending(context).count == 2)
    }

    @Test("Separar no se ofrece ni hace nada en un borrador sin nada unido")
    func separate_withoutRecord_isNoOp() throws {
        let context = try makeTestContext()
        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        let draft = try #require(try pending(context).first)
        #expect(InboxJoinedSourcesSection.sources(of: draft) == nil)
        #expect(InboxArrivalJoin.separate(draft, context: context) == nil)
    }

    // MARK: - Deshacer si el guardado falla

    @Test("revert deja el pendiente como estaba antes de unir")
    func revert_restoresTheHolder() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        try context.save()
        _ = applePay("S/42.50", merchant: "Starbucks", at: day20(13, 5), context: context)
        let holder = try #require(try pending(context).first)

        let food = makeTestSubcategory(context: context, name: "Café", category: makeTestCategory(context: context))
        let arriving = InboxDraft(note: "STARBUCKS", amount: -42.51, date: day20(12, 0), account: visa,
                                  subcategory: food, sourceType: .emailAlert, evidence: "BCP · ****4821",
                                  confidenceSubcategory: 0.95)
        context.insert(arriving)
        let outcome = InboxArrivalJoin.joinBeforeSave(
            [InboxArrivalJoin.Arrival(draft: arriving, currencyCode: "PEN", last4: "4821")], context: context)
        #expect(outcome.joinedCount == 1)
        #expect(holder.amount == -42.51)
        #expect(holder.subcategory === food && holder.confidenceSubcategory == 0.95)

        InboxArrivalJoin.revert(outcome)
        #expect(holder.amount == -42.5)
        #expect(holder.subcategory == nil && holder.confidenceSubcategory == nil, "la categoría heredada se va con su confianza")
        #expect(holder.note == "Starbucks")
        #expect(holder.joinRecordRaw == nil)
    }
}
