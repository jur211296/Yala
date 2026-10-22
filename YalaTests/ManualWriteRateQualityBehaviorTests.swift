//
//  ManualWriteRateQualityBehaviorTests.swift
//  YalaTests
//
//  Que una transacción creada con una tasa APROXIMADA nazca marcada como provisional.
//  Ticket `fx-manual-writes-seal-approximate-as-final`.
//
//  Compañero de `ManualWriteRateQualityTests`, y la división del trabajo es deliberada: aquél fija
//  que la decisión está PUESTA en las catorce escrituras (barrido de fuente), éste fija que la
//  decisión es la CORRECTA (comportamiento real, con una fila de tasas a la que le falta la divisa).
//
//  **El escenario que estos tests montan y ninguna suite del repo montaba.** Una fila de tasas
//  PARCIAL: existe la del día, pero no trae la divisa de la cuenta. Es lo que deja el preload
//  histórico cuando el usuario añade DESPUÉS una cuenta en una divisa nueva. Con fila completa todo
//  esto pasa igual estando el bug presente — por eso cada test lleva su pareja exacta.
//
//  Fichero aparte a propósito: `makeTestContext()` reusa el container por `#fileID`, así que meter
//  estos tests junto a los de barrido ataría la suite entera a `.serialized` sin motivo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Una tasa aproximada nace marcada", .serialized)
struct ManualWriteRateQualityBehaviorTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Una divisa que con seguridad NO es la preferida del entorno.
    ///
    /// La preferida sale de `CurrencyDefaults.currentPreferred`, que lee el `UserDefaults` del
    /// simulador — que estos tests no pueden tocar ni dar por conocido. En vez de fijar el destino se
    /// fija que el ORIGEN sea distinto: así la conversión es real sea cual sea el entorno. Molde
    /// tomado de `CurrencyConverterPartialRateTests`.
    private var foreignCode: String {
        CurrencyDefaults.currentPreferred == "JPY" ? "CHF" : "JPY"
    }

    /// Fecha fija en el pasado: `approveDraft` rechaza las futuras, y anclar evita que el test
    /// dependa del momento del día en que se corra.
    private var pastDate: Date {
        Calendar.current.date(byAdding: .day, value: -10, to: Date.now) ?? Date.now
    }

    private func completeRates() -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map {
                ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
            }
        )
    }

    /// La fila completa menos la divisa de origen: el corazón de estos tests.
    private func ratesMissingForeign() -> [String: Double] {
        var rates = completeRates()
        rates.removeValue(forKey: foreignCode)
        return rates
    }

    @discardableResult
    private func seedRates(_ rates: [String: Double], on date: Date, in context: ModelContext) throws
        -> ExchangeRate
    {
        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date),
            base: "USD",
            ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
        return row
    }

    // MARK: - Familia: borrador (DraftService.approveDraft)

    /// Las cinco escrituras de `DraftService` comparten forma; se prueba el camino genérico, que es
    /// el que recorre la aprobación normal desde Inbox.
    @Test("Aprobar un borrador con la divisa ausente de la fila marca la transacción")
    func approvingDraftWithMissingCurrencyMarksIt() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }

        let date = pastDate
        try seedRates(ratesMissingForeign(), on: date, in: context)

        let account = makeTestAccount(context: context, name: "Extranjera", currencyCode: foreignCode)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(context: context, name: "Restaurantes", category: category)

        let draft = InboxDraft(
            note: "Cena",
            amount: -100,
            date: date,
            account: account,
            subcategory: subcategory,
            needsUserInput: []
        )
        context.insert(draft)
        try context.save()

        let tx = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())

        #expect(
            tx.isExchangeRateProvisional,
            """
            La fila de tasas de ese día NO trae \(foreignCode), así que el converter bajó un escalón
            (fila anterior o tabla estática) y el número es aproximado. Sellarlo en `false` lo deja
            fuera del `#Predicate` del reparador —que solo busca `== true`— y el número malo se queda
            para siempre, viaja por la nube y alimenta los informes.
            """
        )
    }

    @Test("Aprobar un borrador con la fila completa NO lo marca (pareja de control)")
    func approvingDraftWithCompleteRatesDoesNotMarkIt() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }

        let date = pastDate
        try seedRates(completeRates(), on: date, in: context)

        let account = makeTestAccount(context: context, name: "Extranjera", currencyCode: foreignCode)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(context: context, name: "Restaurantes", category: category)

        let draft = InboxDraft(
            note: "Cena",
            amount: -100,
            date: date,
            account: account,
            subcategory: subcategory,
            needsUserInput: []
        )
        context.insert(draft)
        try context.save()

        let tx = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())

        #expect(
            tx.isExchangeRateProvisional == false,
            """
            Sin esta pareja el test de arriba pasaría con un `isExchangeRateProvisional = true`
            incondicional, que marcaría COMO APROXIMADA cada transacción de la app. Devolver todo a la
            cola del reparador en cada arranque no es conservador: es un barrido perpetuo, y con
            `exchangeRate` viajando por el canal nube en el grupo de coherencia `money`, un aluvión de
            emisiones por nada.
            """
        )
    }

    // MARK: - Familia: cambio de moneda preferida (CurrencyChangeService)

    /// **El peor de los catorce sitios**: reescribe en bucle transacciones YA persistidas. Una que
    /// estaba sellada correctamente en `false` —porque su tasa era exacta contra la divisa vieja—
    /// se reconvertía a la nueva con una tasa aproximada y se quedaba en `false`.
    @Test("Cambiar de moneda preferida marca lo que se reconvirtió con tasa aproximada")
    func changingPreferredCurrencyMarksApproximateRewrites() async throws {
        let context = try makeTestContext()

        let date = pastDate
        // La fila NO trae la divisa de destino: la reconversión será aproximada.
        var rates = completeRates()
        rates.removeValue(forKey: foreignCode)
        try seedRates(rates, on: date, in: context)

        let account = makeTestAccount(context: context, name: "Cuenta", currencyCode: "USD")
        let tx = TransactionItem(
            date: date,
            amount: -100,
            currencyCode: "USD",
            account: account,
            isExchangeRateProvisional: false
        )
        context.insert(tx)
        try context.save()

        try await CurrencyChangeService.shared.updateAllTransactions(
            to: foreignCode,
            context: context
        )

        #expect(
            tx.isExchangeRateProvisional,
            """
            La transacción entró sellada en `false` y salió reconvertida con una tasa que no era la
            del día. Antes del arreglo el bucle no tocaba el flag nunca: el monto cambiaba y la marca
            se quedaba diciendo «definitivo». Es el caso más caro de los catorce porque afecta al
            histórico ENTERO de un solo gesto del usuario.
            """
        )
    }

    @Test("Cambiar de moneda preferida con tasas completas deja la marca abajo (pareja de control)")
    func changingPreferredCurrencyWithCompleteRatesLeavesItClean() async throws {
        let context = try makeTestContext()

        let date = pastDate
        try seedRates(completeRates(), on: date, in: context)

        let account = makeTestAccount(context: context, name: "Cuenta", currencyCode: "USD")
        let tx = TransactionItem(
            date: date,
            amount: -100,
            currencyCode: "USD",
            account: account,
            isExchangeRateProvisional: false
        )
        context.insert(tx)
        try context.save()

        try await CurrencyChangeService.shared.updateAllTransactions(
            to: foreignCode,
            context: context
        )

        #expect(
            tx.isExchangeRateProvisional == false,
            "con la tasa del día disponible, la reconversión es exacta y no hay nada que reparar"
        )
    }

    /// El flag describe la calidad del número que hay AHORA, no un historial. Una transacción que
    /// llegaba marcada y se reconvierte con una tasa buena debe quedar limpia — si no, se queda en la
    /// cola del reparador para siempre.
    @Test("Una transacción ya marcada se limpia si la reconversión sí fue exacta")
    func alreadyMarkedTransactionIsClearedWhenRewriteIsExact() async throws {
        let context = try makeTestContext()

        let date = pastDate
        try seedRates(completeRates(), on: date, in: context)

        let account = makeTestAccount(context: context, name: "Cuenta", currencyCode: "USD")
        let tx = TransactionItem(
            date: date,
            amount: -100,
            currencyCode: "USD",
            account: account,
            isExchangeRateProvisional: true
        )
        context.insert(tx)
        try context.save()

        try await CurrencyChangeService.shared.updateAllTransactions(
            to: foreignCode,
            context: context
        )

        #expect(
            tx.isExchangeRateProvisional == false,
            """
            El monto acaba de reescribirse con la tasa del día: ya no hay nada aproximado que
            reparar. Un `flag = flag || !isExact` —la lectura conservadora— la dejaría marcada para
            siempre y el reparador la recorrería en cada arranque sin poder cerrarla.
            """
        )
    }
}
