//
//  AccountCurrencyPlanConversionTests.swift
//  YalaTests
//
//  Al cambiar la divisa de una cuenta, los pagos programados y los favoritos pasan a la tasa de
//  HOY, los borradores pendientes a la tasa de SU fecha, y el aviso lo enseña antes.
//  Ticket `account-currency-change-leaves-scheduled-and-favorites-stale` (decisión 2A de Jürgen).
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. `.serialized` porque cada
//  test pide contexto y el helper vacía el store en cada llamada.
//
//  **Las tasas son DISCRIMINANTES a propósito.** Hoy un dólar vale 3,50 soles; el día del borrador,
//  4,00. Con una sola tasa, «hoy» y «la fecha de cada uno» darían el mismo número y la suite no
//  podría distinguir la decisión de su contraria. Y no hay red: `prepareRates` encuentra las filas
//  ya sembradas y no pide nada (en el simulador `ExchangeRateService` cae por AppAttest).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Programados, favoritos y borradores al cambiar la divisa de una cuenta", .serialized)
struct AccountCurrencyPlanConversionTests {

    // MARK: - Fixture

    /// 3.500 PEN a 3,50 son 1.000 USD exactos: el número que se lee en las aserciones.
    private static let todayPEN = 3.50
    /// 100 PEN a 4,00 son 25 USD. Si el borrador se convirtiera con la tasa de hoy saldría 28,57.
    private static let draftDayPEN = 4.00
    private static let draftDayKey = "2026-03-10"
    /// 150 yenes por dólar: 3.500 PEN → 1.000 USD → 150.000 JPY. Para el redondeo sin decimales se
    /// usa un importe que deja fracción (1.234 PEN → 52.885,71… JPY).
    private static let todayJPY = 150.0

    private func utcNoon(_ key: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: key + " 12:00") ?? Date()
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: .now)
    }

    private func seedRates(_ context: ModelContext, includeToday: Bool = true) throws {
        if includeToday {
            _ = try makeTestExchangeRate(
                context: context, dateKey: todayKey(),
                rates: ["USD": 1.0, "PEN": Self.todayPEN, "JPY": Self.todayJPY, "EUR": 0.9])
        }
        _ = try makeTestExchangeRate(
            context: context, dateKey: Self.draftDayKey,
            rates: ["USD": 1.0, "PEN": Self.draftDayPEN, "JPY": 140.0, "EUR": 0.9])
        try context.save()
    }

    private struct Fixture {
        let context: ModelContext
        let account: Account
        let rent: ScheduledPayment
        let favorite: FavoritePayment
    }

    /// Una cuenta en soles SIN movimientos, con el alquiler programado y un favorito de 3.500.
    private func makeFixture(includeTodayRate: Bool = true) throws -> Fixture {
        let context = try makeTestContext()
        try seedRates(context, includeToday: includeTodayRate)
        let account = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let rent = ScheduledPayment(
            name: "Alquiler", amount: 3500, currencyCode: "PEN",
            account: account, nextDueDate: .now)
        context.insert(rent)
        let favorite = FavoritePayment(
            name: "Mercado", amount: 3500, account: account, currencyCode: "PEN")
        context.insert(favorite)
        try context.save()
        return Fixture(context: context, account: account, rent: rent, favorite: favorite)
    }

    private func makeViewModel(_ fixture: Fixture) -> AccountFormViewModel {
        let vm = AccountFormViewModel(accountToEdit: fixture.account, existingNames: [])
        vm.name = fixture.account.name
        vm.setContext(fixture.context)
        return vm
    }

    // MARK: - El aviso enumera lo que se convierte

    /// **Antes, una cuenta sin movimientos cambiaba de divisa sin preguntar** y dejaba el alquiler en
    /// 3.500 con la etiqueta nueva. Ahora pregunta, y el aviso trae los dos importes de cada uno.
    @Test func sinMovimientosPeroConProgramados_preguntaYEnumera() throws {
        let fixture = try makeFixture()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)
        #expect(pending.rowCount == 0)
        #expect(pending.planCount == 2)
        #expect(pending.planPreview.map(\.name) == ["Alquiler", "Mercado"])
        let rent = try #require(pending.planPreview.first)
        #expect(rent.fromCurrencyCode == "PEN")
        #expect(rent.fromAmount == 3500)
        #expect(abs(rent.toAmount - 1000) < 0.001)
        #expect(rent.isEstimate == false)
        // Y no se guardó nada todavía.
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "PEN")
        #expect(fixture.rent.amount == 3500)

        let title = AccountFormView.currencyConversionTitle(pending)
        let message = AccountFormView.currencyConversionMessage(pending)
        #expect(title.contains("USD"))
        #expect(message.contains("Alquiler"))
        #expect(message.contains("Mercado"))
        #expect(message.contains("PEN 3,500.00") || message.contains("PEN 3.500,00"))
        #expect(message.contains("USD 1,000.00") || message.contains("USD 1.000,00"))
    }

    /// Más de tres: se enseñan tres con importe y el resto se cuenta.
    @Test func masDeTres_enseniaTresYCuentaElResto() throws {
        let fixture = try makeFixture()
        for index in 0..<3 {
            fixture.context.insert(ScheduledPayment(
                name: "Pago \(index)", amount: 100, currencyCode: "PEN",
                account: fixture.account, nextDueDate: .now))
        }
        try fixture.context.save()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)
        #expect(pending.planCount == 5)
        #expect(pending.planPreview.count == AccountFormViewModel.planPreviewLimit)
        let message = AccountFormView.currencyConversionMessage(pending)
        #expect(message.contains(L10n.Account.CurrencyChange.plansMore(2)))
    }

    /// Sin nada que convertir, el aviso no cambia: no sale, como antes. Un pago de grupo no cuenta
    /// (su importe es del grupo) y un favorito ya en la divisa nueva tampoco.
    @Test func sinNadaQueConvertir_noPreguntaYCambia() throws {
        let context = try makeTestContext()
        try seedRates(context)
        let account = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let groupRent = ScheduledPayment(
            name: "Alquiler compartido", amount: 3500, currencyCode: "PEN",
            account: account, nextDueDate: .now)
        groupRent.groupZoneID = "zona"
        context.insert(groupRent)
        context.insert(FavoritePayment(name: "Ya en dólares", amount: 10, account: account, currencyCode: "USD"))
        try context.save()

        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.name = "Soles"
        vm.setContext(context)
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: context) == true)
        #expect(vm.pendingCurrencyConversion == nil)
        #expect(normalizeCurrencyCode(account.currencyCode) == "USD")
        #expect(groupRent.amount == 3500)
        #expect(groupRent.currencyCode == "PEN")
    }

    // MARK: - Al confirmar: tasa de hoy, mismo guardado

    /// **El test que fija la decisión 2A.** El alquiler nace convertido cuando llega su fecha: el
    /// borrador del pago programado lleva el importe en la divisa nueva, no los 3.500 de antes.
    @Test func confirmar_elProgramadoNaceConElImporteConvertido() async throws {
        let fixture = try makeFixture()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        let saved = await vm.confirmCurrencyConversion(pending, context: fixture.context)

        #expect(saved)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "USD")
        #expect(abs(fixture.rent.amount - 1000) < 0.001)
        #expect(fixture.rent.currencyCode == "USD")
        // Lo que de verdad cuenta: el borrador que nace al vencer.
        #expect(ScheduledPaymentDraftService.processDuePayments(context: fixture.context) == 1)
        let drafts = try fixture.context.fetch(FetchDescriptor<InboxDraft>())
        let draft = try #require(drafts.first { $0.sourceScheduledPaymentID == fixture.rent.id.uuidString })
        #expect(abs((draft.amount ?? 0) - (-1000)) < 0.001)
        #expect(draft.displayCurrencyCode.map(normalizeCurrencyCode) == "USD")
    }

    /// El favorito precarga el importe convertido: `NewTransactionView.prefillFromFavorite` lee
    /// `favorite.amount` tal cual y pone la divisa de la cuenta, así que el número guardado es el que
    /// sale en el formulario.
    @Test func confirmar_elFavoritoQuedaConElImporteConvertido() async throws {
        let fixture = try makeFixture()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        #expect(await vm.confirmCurrencyConversion(pending, context: fixture.context))

        #expect(abs((fixture.favorite.amount ?? 0) - 1000) < 0.001)
        #expect(fixture.favorite.currencyCode == "USD")
    }

    /// JPY no tiene decimales: el programado se redondea a yenes enteros.
    @Test func confirmar_redondeaALosDecimalesDeLaDivisaNueva() async throws {
        let fixture = try makeFixture()
        fixture.rent.amount = 1234
        try fixture.context.save()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .jpy
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        #expect(await vm.confirmCurrencyConversion(pending, context: fixture.context))

        // 1.234 / 3,50 × 150 = 52.885,714… → 52.886
        #expect(fixture.rent.amount == 52886)
        #expect(fixture.rent.amount.rounded() == fixture.rent.amount)
    }

    /// **Sin la tasa de hoy no se convierte nada** (decisión D2, la misma del historial): ni el
    /// programado, ni el favorito, ni la divisa de la cuenta.
    @Test func sinTasaDeHoy_noConvierteNadaYLoDice() async throws {
        let fixture = try makeFixture(includeTodayRate: false)
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        let saved = await vm.confirmCurrencyConversion(pending, context: fixture.context)

        #expect(saved == false)
        #expect(vm.isShowingCurrencyRatesUnavailable)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "PEN")
        #expect(fixture.rent.amount == 3500)
        #expect(fixture.favorite.amount == 3500)
    }

    // MARK: - Borradores: con el historial, a la tasa de su fecha

    @Test func confirmar_elBorradorPendienteUsaLaTasaDeSuFecha() async throws {
        let fixture = try makeFixture()
        let pendingDraft = InboxDraft(
            note: "Apple Pay", amount: -100, date: utcNoon(Self.draftDayKey),
            account: fixture.account, sourceType: .applePay)
        fixture.context.insert(pendingDraft)
        let approved = InboxDraft(
            note: "Ya aprobado", amount: -100, date: utcNoon(Self.draftDayKey),
            account: fixture.account, sourceType: .applePay, status: .approved)
        fixture.context.insert(approved)
        let groupDraft = InboxDraft(
            note: "Liquidación", amount: -100, date: utcNoon(Self.draftDayKey),
            account: fixture.account, sourceType: .groupSettlement, splitSettlementID: "s1")
        fixture.context.insert(groupDraft)
        try fixture.context.save()

        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)
        #expect(pending.draftCount == 1)
        #expect(AccountFormView.currencyConversionMessage(pending)
            .contains(L10n.Account.CurrencyChange.draftsLine(1, "USD")))

        #expect(await vm.confirmCurrencyConversion(pending, context: fixture.context))

        // 100 PEN a 4,00 = 25 USD. Con la tasa de hoy (3,50) serían 28,57.
        #expect(abs((pendingDraft.amount ?? 0) - (-25)) < 0.001)
        #expect(approved.amount == -100)
        #expect(groupDraft.amount == -100)
    }

    // MARK: - Lo que cazó la review adversarial

    /// **Si en la espera de las tasas llega una transferencia, no se convierte NADA.** Antes el gate
    /// de `saveAccount` la bloqueaba, pero después de reescribir en memoria programados y borradores,
    /// que el siguiente guardado persistía bajo la divisa vieja.
    @Test func confirmar_conUnBloqueoQueLlegaDuranteLaEspera_noConvierteNada() async throws {
        let fixture = try makeFixture()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        // Lo que trae el sync en la ventana del `await`: una pata de transferencia en esta cuenta.
        let category = makeTestCategory(context: fixture.context)
        let sub = makeTestSubcategory(context: fixture.context, category: category)
        let transfer = makeTestTransaction(
            context: fixture.context, amount: -10, account: fixture.account,
            category: category, subcategory: sub)
        transfer.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        try fixture.context.save()

        let saved = await vm.confirmCurrencyConversion(pending, context: fixture.context)

        #expect(saved == false)
        #expect(vm.isShowingCurrencyChangeBlocked)
        #expect(fixture.rent.amount == 3500)
        #expect(fixture.rent.currencyCode == "PEN")
        #expect(fixture.favorite.amount == 3500)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "PEN")
    }

    /// Sin movimientos que reexpresar, el saldo inicial que la persona tecleó no se borra al pedir
    /// la confirmación (antes de esta versión, la cuenta sin movimientos guardaba sin preguntar).
    @Test func sinMovimientos_elSaldoTecleadoSobreviveALaPregunta() throws {
        let fixture = try makeFixture()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        vm.balanceText = "500"

        #expect(vm.saveAccount(context: fixture.context) == false)
        #expect(vm.pendingCurrencyConversion != nil)
        #expect(vm.balanceText == "500")
    }

    /// Un borrador rechazado y devuelto a pendientes guarda la divisa con la que se archivó; tras
    /// convertirlo tiene que decir la nueva, o «Convertir a gasto de grupo» lo precargaría en soles.
    @Test func confirmar_elBorradorDevueltoAPendientesCambiaSuDivisaGuardada() async throws {
        let fixture = try makeFixture()
        let draft = InboxDraft(
            note: "Devuelto", amount: -100, date: utcNoon(Self.draftDayKey),
            account: fixture.account, sourceType: .applePay)
        draft.cachedCurrencyCode = "PEN"
        fixture.context.insert(draft)
        try fixture.context.save()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        #expect(await vm.confirmCurrencyConversion(pending, context: fixture.context))

        #expect(abs((draft.amount ?? 0) - (-25)) < 0.001)
        #expect(draft.cachedCurrencyCode == "USD")
    }

    // MARK: - Lógica pura

    @Test func decimalesISO() {
        #expect(AccountCurrencyPlanLogic.fractionDigits(for: "JPY") == 0)
        #expect(AccountCurrencyPlanLogic.fractionDigits(for: "USD") == 2)
        #expect(AccountCurrencyPlanLogic.rounded(Decimal(string: "930.235")!, to: "USD")
            == Decimal(string: "930.24")!)
    }

    @Test func queBorradoresEntran() {
        func shape(_ type: DraftSourceType, pending: Bool = true, pointer: Bool = false, amount: Bool = true)
            -> AccountCurrencyPlanLogic.DraftShape {
            .init(isPending: pending, sourceType: type, hasGroupPointer: pointer, hasAmount: amount)
        }
        #expect(AccountCurrencyPlanLogic.convertsDraft(shape(.applePay)))
        #expect(AccountCurrencyPlanLogic.convertsDraft(shape(.scheduledPayment)))
        #expect(AccountCurrencyPlanLogic.convertsDraft(shape(.manual)))
        #expect(!AccountCurrencyPlanLogic.convertsDraft(shape(.applePay, pending: false)))
        #expect(!AccountCurrencyPlanLogic.convertsDraft(shape(.applePay, amount: false)))
        #expect(!AccountCurrencyPlanLogic.convertsDraft(shape(.applePay, pointer: true)))
        #expect(!AccountCurrencyPlanLogic.convertsDraft(shape(.groupExpense)))
        #expect(!AccountCurrencyPlanLogic.convertsDraft(shape(.groupSettlement)))
        #expect(!AccountCurrencyPlanLogic.convertsDraft(shape(.groupScheduledExpense)))
    }
}
