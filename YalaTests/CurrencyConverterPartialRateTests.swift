//
//  CurrencyConverterPartialRateTests.swift
//  YalaTests
//
//  Fila de tasas PARCIAL: existe la fila del día, pero no trae la divisa que hace falta.
//  Ticket `fx-partial-rate-rows-silent-1to1`.
//
//  **Por qué este archivo existe y no bastaba con lo que ya había.** Medido el 2026-09-03: 53 casos
//  de test tocan FX en este repo y NINGUNO puede ponerse rojo por este bug, porque ninguna fila de
//  tasas de prueba omite una divisa que el test luego pida convertir. Es la trampa que
//  `.claude/rules/testing.md` describe como «el helper que omite el campo que decide», en su versión
//  inversa: aquí el helper construye siempre fixtures COMPLETOS, así que la suite entera es ciega a
//  la única forma que tiene el módulo de fallar.
//
//  **El hallazgo que ordena estos tests, y que el ticket no traía.** Una fila parcial es
//  ESTRICTAMENTE PEOR que no tener fila. `CurrencyConverter.getRatesForDate` degrada en tres
//  escalones —fila exacta → fila anterior más reciente → tabla estática de `CurrencyCode`— pero el
//  primero corta por EXISTENCIA: devuelve el diccionario incompleto y los otros dos no se alcanzan
//  jamás. Sin fila, el converter cae a la tabla estática, que cubre las 54 divisas por construcción
//  (`allCases.map`), y convierte bien. Con fila parcial, tapa ese camino y devuelve el monto crudo.
//  ⇒ la tasa que hace falta SÍ está disponible dos niveles más abajo; algo la está escondiendo.
//
//  Aislamiento: `CurrencyConverter()` propia (no `.shared`) y contexto in-memory con
//  `cloudKitDatabase: .none` explícito — molde de `CurrencyConverterCacheTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct CurrencyConverterPartialRateTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Contexto con UNA fila para `date`, con exactamente las divisas que se le pidan.
    /// El parámetro `rates` es el punto entero de este archivo: el helper TIENE que poder construir
    /// una fila a la que le falte una divisa, o los tests no pueden distinguir el bug del arreglo.
    private func makeContext(
        on date: Date,
        rates: [String: Double]
    ) throws -> ModelContext {
        // `TransactionItem` entra en el schema porque los tests del marcado insertan una. Lleva
        // relaciones, así que `cloudKitDatabase: .none` NO es decorativo: con el default `.automatic`
        // SwiftData adjunta el mirror de CloudKit a un store in-memory y el `save()` mata el proceso
        // en un simulador sin cuenta iCloud (`.claude/rules/testing.md`).
        let schema = Schema([ExchangeRate.self, TransactionItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date),
            base: "USD",
            ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
        return context
    }

    /// Una divisa que con seguridad NO es la preferida del entorno.
    ///
    /// `recalculatePreferredCurrency` resuelve el destino con `CurrencyDefaults.currentPreferred`, que
    /// lee `UserDefaults.standard` — la del simulador, que estos tests NO pueden tocar (regla del
    /// repo) ni pueden dar por conocida. En vez de fijar la preferida, se fija que el ORIGEN sea
    /// distinto de ella: así la conversión es real sea cual sea el entorno.
    private var foreignCode: String {
        CurrencyDefaults.currentPreferred == "JPY" ? "CHF" : "JPY"
    }

    /// Fila COMPLETA: todas las divisas de `CurrencyCode`. No se hardcodea ningún número — el ticket
    /// decía 53, el CLAUDE.md ~48 y lo medido son 54; contra `allRawValues` la cifra deja de importar.
    private func completeRates() -> [String: Double] {
        Dictionary(uniqueKeysWithValues: CurrencyCode.allRawValues.map { ($0, CurrencyCode.fallbackRates[$0] ?? 1.0) })
    }

    /// Fila PARCIAL: la completa menos la divisa de origen. Es exactamente lo que deja el preload
    /// histórico cuando el usuario añade DESPUÉS una cuenta en una divisa nueva.
    private func ratesMissingTheForeignCurrency() -> [String: Double] {
        var rates = completeRates()
        rates.removeValue(forKey: foreignCode)
        return rates
    }

    // MARK: - El bug

    /// Un gasto de 1000 JPY con la moneda preferida en PEN, en un día cuya fila trae USD y PEN pero
    /// NO JPY — el estado que deja el preload histórico cuando el usuario añade después una cuenta en
    /// una divisa nueva.
    ///
    /// Hoy `performConversion` sale por su `guard let fromRate = rates[fromCode]` y **devuelve el
    /// monto crudo**: 1000 JPY se cuentan como 1000 PEN, unas 260× de más. No hay error, no hay log,
    /// no hay señal: el número simplemente está mal y parece bueno.
    @Test func partialRow_neverReturnsTheRawAmountAsIfItWereConverted() throws {
        let today = Date.now
        let context = try makeContext(on: today, rates: ["USD": 1.0, "PEN": 3.75])

        let converted = CurrencyConverter().convert(
            Decimal(1000), from: "JPY", to: "PEN", on: today, context: context
        )

        #expect(converted != Decimal(1000), """
            1000 JPY no son 1000 PEN. La fila del día no trae JPY, así que la conversión devolvió el
            monto crudo y lo dio por bueno. La tasa real está disponible dos escalones más abajo (fila
            anterior o tabla estática), pero la fila parcial corta la cadena por existencia.
            """)
    }

    /// Control positivo del mismo caso: con la fila COMPLETA la conversión sí ocurre. Sin esto, el
    /// test de arriba se pondría verde con un converter roto que devolviera cualquier cosa distinta
    /// de la entrada.
    @Test func completeRow_convertsWithTheStoredRate() throws {
        let today = Date.now
        let context = try makeContext(on: today, rates: ["USD": 1.0, "PEN": 3.75, "JPY": 157.0])

        let converted = CurrencyConverter().convert(
            Decimal(1000), from: "JPY", to: "PEN", on: today, context: context
        )

        // 1000 JPY / 157 = 6.369… USD → × 3.75 = 23.88… PEN
        let expected = Decimal(1000) / Decimal(157.0) * Decimal(3.75)
        #expect(abs(converted - expected) < Decimal(0.01))
    }

    /// La demostración de que la fila parcial TAPA un camino que funciona: exactamente la misma
    /// conversión, sin ninguna fila en el store, sí convierte — cae a la tabla estática, que tiene
    /// las 54 divisas. Es el test que convierte «falta una tasa» en «hay una tasa y la escondemos».
    @Test func noRowAtAll_convertsBetterThanAPartialRow() throws {
        let today = Date.now
        let schema = Schema([ExchangeRate.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(for: schema, configurations: [config]))

        let withoutAnyRow = CurrencyConverter().convert(
            Decimal(1000), from: "JPY", to: "PEN", on: today, context: context
        )

        #expect(withoutAnyRow != Decimal(1000), """
            Sin fila, el converter cae a la tabla estática y convierte. Este test debe estar VERDE
            desde antes del fix: es la prueba de que el camino bueno ya existe.
            """)
    }

    // MARK: - Quien escribe, marca

    /// La otra mitad del fix: convertir mejor no basta si el número aproximado se sella como
    /// definitivo. `recalculatePreferredCurrency` es el punto de paso de la escritura —21 llamadas en
    /// 5 ficheros, once del bridge de Grupos— y hasta el 2026-09-03 **no tocaba el flag**, así que
    /// toda transacción que pasara por ahí nacía `isExchangeRateProvisional = false` por el default
    /// del modelo. Como el `#Predicate` del reparador solo busca `== true`, el monto malo se quedaba
    /// para siempre.
    @Test func partialRow_marksTheTransactionProvisional_soItGetsRepairedLater() throws {
        let today = Date.now
        let context = try makeContext(on: today, rates: ratesMissingTheForeignCurrency())

        let tx = TransactionItem(date: today, amount: 1000, currencyCode: foreignCode)
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)

        #expect(tx.isExchangeRateProvisional, """
            A la fila del día le faltaba justo esta divisa: la tasa salió de un escalón inferior, así
            que es aproximada y tiene que quedar marcada para que el reparador vuelva cuando lleguen
            las tasas reales.
            """)
    }

    /// Control positivo del anterior, y no es redundante: sin él, marcar SIEMPRE provisional pasaría
    /// el test de arriba y pondría al reparador a rehacer en cada arranque transacciones que ya están
    /// bien.
    @Test func completeRow_sealsTheTransactionAsDefinitive() throws {
        let today = Date.now
        let context = try makeContext(on: today, rates: completeRates())

        let tx = TransactionItem(date: today, amount: 1000, currencyCode: foreignCode)
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)

        #expect(!tx.isExchangeRateProvisional)
    }

    /// Misma divisa de origen y destino: la tasa 1.0 es LEGÍTIMA y no debe marcarse provisional. Es la
    /// confusión que el ticket avisa que arruinaría cualquier barrido de reparación —filtrar solo por
    /// `exchangeRate == 1.0` reconvertiría filas sanas— y aquí queda fijada en el origen.
    @Test func sameCurrency_isExactEvenWithNoRatesAtAll() throws {
        let today = Date.now
        let schema = Schema([ExchangeRate.self, TransactionItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(for: schema, configurations: [config]))

        let tx = TransactionItem(
            date: today, amount: 250, currencyCode: CurrencyDefaults.currentPreferred
        )
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)

        #expect(!tx.isExchangeRateProvisional)
        #expect(tx.exchangeRate == 1.0)
    }
}
