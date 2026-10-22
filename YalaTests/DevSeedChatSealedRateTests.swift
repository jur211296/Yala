//
//  DevSeedChatSealedRateTests.swift
//  YalaTests
//
//  El fixture de `-uitest-seed-chat-sealed-rate <ISO>`: la fila **envenenada por el chat viejo**.
//  Ticket `chat-rows-sealed-before-the-fix-have-no-repair-path`.
//
//  **Qué defiende este archivo.** No que el barrido funcione —de eso ya hay 13 casos en
//  `FXOneToOneRepairSweepTests`— sino que el fixture cae en la población CORRECTA de las dos que
//  `ExchangeRateRepairLogic.rateFromStoredAmounts` distingue. Es la única propiedad que lo hace
//  útil, y la más fácil de romper sin darse cuenta:
//
//  - Si el fixture guardara el monto CRUDO, el cociente valdría 1, `rateFromStoredAmounts`
//    devolvería `nil` y el barrido REABRIRÍA la fila en vez de curarla. Seguiría pasando un test
//    que solo mirase «¿es candidata?», pero el QA vería el camino contrario al del ticket — y el
//    que las rules de divisas avisan que DESTRUYE datos buenos.
//  - Si el fixture no plantara `exchangeRate = 1.0` DESPUÉS de convertir, la fila nacería sana.
//  - Si el flag `isExchangeRateProvisional` quedara en `true`, la fila entraría en el reparador de
//    arranque por su propio pie y el ticket no tendría nada que demostrar.
//
//  Aislamiento: mismo molde que `DevSeedForeignCurrencyAccountTests` — in-memory con
//  `cloudKitDatabase: .none` explícito, porque con el default `.automatic` SwiftData adjunta el
//  mirror de CloudKit a un store in-memory y el `save()` mata el proceso sin cuenta iCloud.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct DevSeedChatSealedRateTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Una divisa que con seguridad NO es la preferida del entorno. Mismo patrón —y mismo motivo—
    /// que el test hermano: la preferida sale del `UserDefaults` del simulador y no se puede fijar.
    private var foreignCode: String {
        CurrencyDefaults.currentPreferred == "JPY" ? "CHF" : "JPY"
    }

    /// Contexto con una fila de tasas COMPLETA para ayer y para hoy.
    ///
    /// Completa a propósito, al revés que en el fixture hermano: aquí lo que se prueba es el
    /// veneno de la columna `exchangeRate`, no la degradación de la conversión. Con la fila
    /// completa la conversión es exacta, así que un `isExchangeRateProvisional == true` en el
    /// resultado solo puede venir del fixture, no del converter.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            ExchangeRate.self, TransactionItem.self, Account.self, Category.self, Subcategory.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let rates = Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map {
                ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
            }
        )
        let calendar = Calendar.current
        for offset in [-1, 0] {
            let day = calendar.date(byAdding: .day, value: offset, to: Date.now) ?? Date.now
            let row = try ExchangeRate(
                dateKey: Self.dateFormatter.string(from: day), base: "USD", ratesDictionary: rates
            )
            context.insert(row)
        }
        try context.save()
        return context
    }

    // MARK: - El contrato del fixture

    /// La fila nace con la forma exacta que `needsRepair` busca: tasa 1,0 y divisa ≠ preferida.
    @Test func seededRow_isACandidateOfTheLegacySweep() throws {
        let context = try makeContext()

        let tx = try #require(
            DevSeedChatSealedRate.create(
                currencyCode: foreignCode, subcategoryLookup: [:], in: context
            )
        )

        #expect(tx.exchangeRate == 1.0, "El veneno es la tasa 1,0; sin ella la fila no es candidata.")
        #expect(
            ExchangeRateRepairLogic.needsRepair(
                exchangeRate: tx.exchangeRate,
                currencyCode: tx.currencyCode,
                preferredCurrencyCode: CurrencyDefaults.currentPreferred
            ),
            "La fila sembrada no la reconocería el barrido legacy."
        )
    }

    /// **El caso que da sentido al fixture**: se cura EN EL SITIO, no se reabre.
    ///
    /// El monto convertido tiene que ser el bueno, así que el cociente de los dos montos guardados
    /// devuelve la tasa verdadera. Si el fixture guardara el monto crudo, esto daría `nil` y la
    /// fila iría por el camino de `fx-partial-rate-rows-silent-1to1` — otro ticket, otro daño.
    @Test func seededRow_yieldsADerivableRate_soTheSweepFixesItInPlace() throws {
        let context = try makeContext()

        let tx = try #require(
            DevSeedChatSealedRate.create(
                currencyCode: foreignCode, subcategoryLookup: [:], in: context
            )
        )

        let derived = ExchangeRateRepairLogic.rateFromStoredAmounts(
            amount: tx.amount, amountInPreferredCurrency: tx.amountInPreferredCurrency
        )
        let rate = try #require(derived, """
            De esta fila no se deduce ninguna tasa, así que el barrido la REABRIRÍA en vez de \
            curarla. Señal típica: el fixture guardó el monto crudo (cociente 1) en vez del \
            convertido, o se saltó `recalculatePreferredCurrency`.
            """)
        #expect(abs(rate - 1.0) > 0.0001, "La tasa deducida es 1,0: el monto no llegó a convertirse.")
    }

    /// El monto convertido NO es el crudo — la otra cara de lo mismo, medida sobre los importes.
    @Test func seededRow_storesAConvertedAmount_notTheRawOne() throws {
        let context = try makeContext()

        let tx = try #require(
            DevSeedChatSealedRate.create(
                currencyCode: foreignCode, subcategoryLookup: [:], in: context
            )
        )

        #expect(
            abs(abs(tx.amountInPreferredCurrency) - abs(tx.amount)) > 0.01,
            "El monto en divisa preferida coincide con el nativo: la conversión no ocurrió."
        )
        #expect(
            abs(tx.amountInPreferredCurrency) > 0.01,
            "El monto convertido es ~0: `rateFromStoredAmounts` lo filtraría por `isUsableRate`."
        )
    }

    /// El flag queda en `false`, que es lo que deja la fila FUERA del reparador de arranque.
    ///
    /// Es el daño literal del ticket: el `#Predicate` del reparador es `== true`, así que una fila
    /// sellada como definitiva no vuelve a mirarse nunca. Si el fixture la dejara provisional, el
    /// ticket se «arreglaría» solo y el barrido legacy no probaría nada.
    @Test func seededRow_isSealedAsFinal_soTheBootRepairerIgnoresIt() throws {
        let context = try makeContext()

        let tx = try #require(
            DevSeedChatSealedRate.create(
                currencyCode: foreignCode, subcategoryLookup: [:], in: context
            )
        )

        #expect(!tx.isExchangeRateProvisional)
    }

    /// Idempotencia: el segundo arranque no planta una fila nueva al lado de la ya curada.
    @Test func seedingTwice_doesNotDuplicateTheRow() throws {
        let context = try makeContext()

        let first = try #require(
            DevSeedChatSealedRate.create(
                currencyCode: foreignCode, subcategoryLookup: [:], in: context
            )
        )
        // Simula el paso del barrido: la fila ya no tiene tasa 1,0. El guard tiene que seguir
        // reconociéndola —busca por nota, no por tasa— o el segundo arranque duplicaría.
        first.exchangeRate = 0.25
        try context.save()

        let second = DevSeedChatSealedRate.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        let rows = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(rows.count == 1, "El fixture se sembró dos veces: la lectura del QA deja de ser un par limpio.")
        #expect(second?.persistentModelID == first.persistentModelID)
    }

    /// Con la divisa preferida no siembra nada, y eso es correcto: `needsRepair` exige divisa
    /// distinta, así que esa fila no sería candidata y el QA leería un falso negativo del barrido.
    @Test func seedingThePreferredCurrency_writesNothing() throws {
        let context = try makeContext()

        let tx = DevSeedChatSealedRate.create(
            currencyCode: CurrencyDefaults.currentPreferred, subcategoryLookup: [:], in: context
        )

        #expect(tx == nil)
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).isEmpty)
    }

    // MARK: - Paridad de la clave del one-shot

    /// La clave que el fixture rebobina es la MISMA que el barrido sella.
    ///
    /// `TransactionUpdateService.repairSweepKey` es `private`, así que la paridad no se puede
    /// comprobar por comportamiento sin ampliar su superficie pública solo para un test. Se fija
    /// por source-scan sobre el literal, que aquí sí es una red suficiente: es **un** literal y su
    /// declaración es una línea entera y estable, no un fragmento que un refactor inocuo desplace.
    ///
    /// Si divergieran, el fixture rebobinaría una clave que nadie lee: el barrido seguiría sellado,
    /// la fila se quedaría diciendo «1,0000» y el QA lo leería como un FAIL del producto.
    @Test func rewindKeyMatchesTheSweep() throws {
        let source = try Self.readSource(of: "Yala/Services/TransactionUpdateService.swift")
        let expected = "private static let repairSweepKey = \"\(DevSeedChatSealedRate.repairSweepKey)\""
        #expect(source.contains(expected), """
            `TransactionUpdateService` ya no declara la clave del one-shot como \
            \(DevSeedChatSealedRate.repairSweepKey). Si el barrido subió de versión, sube también \
            `DevSeedChatSealedRate.repairSweepKey`: si no, el fixture rebobina una clave muerta y \
            el barrido no vuelve a correr en ese simulador.
            """)
    }

    /// Lee un fichero del repo desde el test. La raíz se deriva de `#filePath`, que apunta a este
    /// archivo dentro de `YalaTests/`, así que no depende del directorio de trabajo del runner.
    private static func readSource(of relativePath: String, file: StaticString = #filePath) throws -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }
}
