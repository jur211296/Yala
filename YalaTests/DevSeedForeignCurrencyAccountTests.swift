//
//  DevSeedForeignCurrencyAccountTests.swift
//  YalaTests
//
//  El fixture de `-uitest-seed-foreign-account <ISO>`: la cuenta en una divisa AUSENTE de la fila
//  de tasas. Ticket `qa-no-puede-crear-cuenta-en-otra-divisa`.
//
//  **Qué defiende este archivo, que no es lo que parece.** No prueba que el converter convierta —de
//  eso ya hay 54 casos— sino que el FIXTURE deja las transacciones marcadas por el camino de
//  producción. Es la diferencia que hace utilizable a todo el seam: el resto de `DevSeedTransactions`
//  planta `exchangeRate: basePenRate` a mano y deja `isExchangeRateProvisional` en su default
//  `false`, así que cualquier aserción sobre ese flag sobre el corpus normal es vacua por
//  construcción. Si alguien "simplifica" este fixture escribiendo la tasa en vez de llamar a
//  `recalculatePreferredCurrency`, los cuatro casos de aquí se ponen rojos.
//
//  Aislamiento: contexto in-memory con `cloudKitDatabase: .none` explícito, molde de
//  `CurrencyConverterPartialRateTests` — con el default `.automatic` SwiftData adjunta el mirror de
//  CloudKit a un store in-memory y el `save()` mata el proceso en un simulador sin cuenta iCloud.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct DevSeedForeignCurrencyAccountTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Una divisa que con seguridad NO es la preferida del entorno.
    ///
    /// Mismo patrón que `CurrencyConverterPartialRateTests.foreignCode`, y por el mismo motivo: la
    /// preferida sale de `CurrencyDefaults.currentPreferred`, que lee el `UserDefaults` del
    /// simulador — estos tests no pueden tocarlo ni darlo por conocido. Se fija el ORIGEN distinto
    /// de ella en vez de fijar la preferida.
    private var foreignCode: String {
        CurrencyDefaults.currentPreferred == "JPY" ? "CHF" : "JPY"
    }

    /// Contexto con la fila del día PARCIAL: trae todas las divisas menos la del fixture.
    ///
    /// Es el estado real que reproduce el seam — `DevSeedExchangeRates` siembra `PEN`/`EUR`/`USD` y
    /// cualquier otra queda fuera — y el único en el que este módulo falla.
    private func makeContext(missingForeignCurrency: Bool = true) throws -> ModelContext {
        let schema = Schema([
            ExchangeRate.self, TransactionItem.self, Account.self, Category.self, Subcategory.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        var rates = Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map {
                ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
            }
        )
        if missingForeignCurrency { rates.removeValue(forKey: foreignCode) }

        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: Date.now), base: "USD", ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
        return context
    }

    private func seededTransactions(in context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>())
    }

    // MARK: - El contrato del fixture

    /// La razón de ser del seam: las filas nacen MARCADAS como aproximadas.
    ///
    /// La fila del día existe pero no trae la divisa de la cuenta, así que `resolveRates` baja hasta
    /// la tabla estática y devuelve `.staticFallback`, cuyo `isExact` es `false`. Si el fixture
    /// escribiera la tasa a mano —como hace el resto del seed— el flag se quedaría en `false` y toda
    /// la familia FX seguiría sin estado de partida que observar.
    @Test func seededRows_areMarkedProvisional_whenCurrencyIsMissingFromTheDayRow() throws {
        let context = try makeContext()

        let account = DevSeedForeignCurrencyAccount.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        #expect(account != nil)
        let transactions = try seededTransactions(in: context)
        #expect(!transactions.isEmpty, "El fixture no sembró ninguna transacción.")
        for tx in transactions {
            #expect(tx.isExchangeRateProvisional, """
                La transacción de \(tx.currencyCode) nació sellada como DEFINITIVA. La fila del día no \
                trae esa divisa, así que la conversión fue `.staticFallback` y tenía que marcarse \
                provisional. Señal típica: el fixture escribió la tasa a mano en vez de llamar a \
                `recalculatePreferredCurrency`.
                """)
        }
    }

    /// La tasa guardada no es 1,0 — el AC literal del ticket.
    ///
    /// Es el mismo síntoma que `fx-partial-rate-rows-silent-1to1`: si la conversión se salta, el
    /// monto crudo se guarda como si estuviera convertido y la tasa queda en 1,0000.
    @Test func seededRows_storeARealRate_notOneToOne() throws {
        let context = try makeContext()

        DevSeedForeignCurrencyAccount.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        let transactions = try seededTransactions(in: context)
        for tx in transactions {
            #expect(tx.exchangeRate != 1.0, """
                Tasa 1,0000 con divisa \(tx.currencyCode) y preferida \
                \(CurrencyDefaults.currentPreferred): el monto crudo se guardó como si estuviera \
                convertido.
                """)
            #expect(abs(tx.amountInPreferredCurrency) != abs(tx.amount), """
                El monto convertido coincide con el crudo (\(tx.amount)): no hubo conversión.
                """)
        }
    }

    /// Los DOS lados, ingreso y gasto.
    ///
    /// No es simetría decorativa: la marca de aproximado va separada por lado —el hero del Panel en
    /// modo Solo Gastos pinta solo uno— así que un fixture de un solo signo dejaría al otro sin
    /// ninguna superficie que verificar.
    @Test func seededRows_coverBothSides() throws {
        let context = try makeContext()

        DevSeedForeignCurrencyAccount.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        let transactions = try seededTransactions(in: context)
        #expect(transactions.contains { $0.amount > 0 }, "Falta el lado de INGRESO.")
        #expect(transactions.contains { $0.amount < 0 }, "Falta el lado de GASTO.")
    }

    /// El peso se fija en la divisa PREFERIDA, no en la nativa.
    ///
    /// Es lo que hace que el mismo comando pese igual con cualquier ISO: con importes nativos fijos,
    /// 12.000 unidades son ~285 soles en yenes y ~45 en pesos chilenos — marca en una divisa y no en
    /// la otra. La tolerancia del 2 % absorbe el redondeo a 2 decimales del importe nativo.
    @Test func seededAmounts_hitTheirTargetInPreferredCurrency() throws {
        let context = try makeContext()

        DevSeedForeignCurrencyAccount.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        let transactions = try seededTransactions(in: context)
        let expected = [DevSeedForeignCurrencyAccount.incomeTargetInPreferred]
            + DevSeedForeignCurrencyAccount.expenseTargetsInPreferred
        let actual = transactions.map { abs($0.amountInPreferredCurrency) }.sorted()

        for target in expected.sorted() {
            let match = actual.contains { abs($0 - target) <= target * 0.02 }
            #expect(match, """
                Ninguna transacción convierte a ~\(target) en \(CurrencyDefaults.currentPreferred). \
                Convertidos: \(actual). El objetivo se fija en la divisa preferida y el importe \
                nativo se deriva; si esto falla, la derivación y la conversión no usan la misma tasa.
                """)
        }
    }

    // MARK: - Control negativo y bordes

    /// Pedir la divisa PREFERIDA no produce marca — y eso es correcto, no un fallo.
    ///
    /// `convertChecked` corta en `fromCode == toCode` y devuelve `.exact` por construcción. Sin este
    /// caso, los tres de arriba pasarían verdes con un fixture que marcara SIEMPRE, que es la
    /// aserción que no puede fallar.
    @Test func preferredCurrency_producesNoApproximation() throws {
        let context = try makeContext(missingForeignCurrency: false)

        DevSeedForeignCurrencyAccount.create(
            currencyCode: CurrencyDefaults.currentPreferred, subcategoryLookup: [:], in: context
        )

        let transactions = try seededTransactions(in: context)
        #expect(!transactions.isEmpty)
        for tx in transactions {
            #expect(!tx.isExchangeRateProvisional, """
                Pedir la divisa preferida marcó la fila como aproximada. La conversión identidad es \
                exacta por construcción: marcarla erosiona la marca igual que no ponerla.
                """)
        }
    }

    /// Un ISO que no existe no siembra nada — ni cuenta, ni transacciones a medias.
    @Test func unknownISO_seedsNothing() throws {
        let context = try makeContext()

        let account = DevSeedForeignCurrencyAccount.create(
            currencyCode: "XXX", subcategoryLookup: [:], in: context
        )

        #expect(account == nil)
        #expect(try seededTransactions(in: context).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Account>()).isEmpty)
    }

    /// El ISO se normaliza: el launch arg lo escribe una persona.
    @Test func lowercaseISO_isAccepted() throws {
        let context = try makeContext()

        let account = DevSeedForeignCurrencyAccount.create(
            currencyCode: foreignCode.lowercased(), subcategoryLookup: [:], in: context
        )

        #expect(account?.currencyCode == foreignCode)
    }

    // MARK: - El launch argument

    /// El parseo del arg, con la misma mecánica que el resto de seams (`parseValue(after:from:)`).
    @Test func launchArgument_parsesItsValue() {
        #expect(
            UITestHooks.parseValue(
                after: "-uitest-seed-foreign-account",
                from: ["-uitest", "-uitest-seed", "realista", "-uitest-seed-foreign-account", "JPY"]
            ) == "JPY"
        )
        // Sin valor: el token siguiente es otro flag.
        #expect(
            UITestHooks.parseValue(
                after: "-uitest-seed-foreign-account",
                from: ["-uitest", "-uitest-seed-foreign-account", "-uitest-pro"]
            ) == nil
        )
        // Último token, sin valor detrás.
        #expect(
            UITestHooks.parseValue(
                after: "-uitest-seed-foreign-account", from: ["-uitest", "-uitest-seed-foreign-account"]
            ) == nil
        )
        // Ausente.
        #expect(
            UITestHooks.parseValue(after: "-uitest-seed-foreign-account", from: ["-uitest"]) == nil
        )
    }
}
