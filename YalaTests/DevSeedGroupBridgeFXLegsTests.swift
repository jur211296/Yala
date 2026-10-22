//
//  DevSeedGroupBridgeFXLegsTests.swift
//  YalaTests
//
//  El fixture de `-uitest-seed-group-bridge-fx <ISO>`: el gasto de grupo con las dos patas selladas
//  con coberturas de tasa distintas. Ticket `bridge-de-grupos-pierde-la-marca-de-sus-patas`.
//
//  **Qué defiende este archivo, y por qué no basta con «que siembre dos filas».** Un fixture de
//  este ticket solo vale si es DISCRIMINANTE: tiene que dar un veredicto distinto con el bug dentro
//  y con el bug fuera. Eso exige tres propiedades a la vez, y las tres se rompen por separado:
//
//  1. Que el adjustment reconozca el par (mismo `splitExpenseID`, préstamo positivo en cuenta de
//     sistema). Si no, las dos patas se cuentan sueltas y el gasto sale por 1.050 en vez de 150.
//  2. Que la pata REAL nazca **exacta**. Si naciera provisional, el mes marcaría igual leyendo solo
//     su propio flag — con el bug dentro — y el fixture daría verde sobre código roto.
//  3. Que la magnitud dudosa que llega al numerador sea la de la pata SUPRIMIDA, en magnitudes y
//     no en neto.
//
//  El caso `approximateMagnitude_comesFromTheSuppressedLeg_notFromTheRealOne` es el que sostiene
//  las tres: con el bug del ticket devuelve 0.
//
//  Aislamiento: mismo molde que sus hermanos — in-memory con `cloudKitDatabase: .none` explícito.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct DevSeedGroupBridgeFXLegsTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private var foreignCode: String {
        CurrencyDefaults.currentPreferred == "JPY" ? "CHF" : "JPY"
    }

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
        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: Date.now), base: "USD", ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
        return context
    }

    private func legs(in context: ModelContext) throws -> (real: TransactionItem, loan: TransactionItem) {
        let target = DevSeedGroupBridgeFXLegs.splitExpenseID
        let rows = try context.fetch(
            FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == target })
        )
        let real = try #require(rows.first { $0.account?.isSystemAccount == false })
        let loan = try #require(rows.first { $0.account?.isSystemAccount == true })
        return (real, loan)
    }

    private func adjustment(in context: ModelContext) throws -> GroupBridgeStatsAdjustment {
        GroupBridgeStatsAdjustment.build(
            from: try context.fetch(FetchDescriptor<TransactionItem>()), context: context
        )
    }

    // MARK: - La anatomía

    /// Las dos patas nacen con la forma que el adjustment exige para emparejarlas.
    @Test func seedsTwoLegs_withTheShapeTheAdjustmentRequires() throws {
        let context = try makeContext()

        DevSeedGroupBridgeFXLegs.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        let (real, loan) = try legs(in: context)
        #expect(real.splitExpenseID == loan.splitExpenseID, "Sin el mismo id no hay par que agrupar.")
        #expect(real.account?.isSystemAccount == false)
        #expect(loan.account?.isSystemAccount == true)
        #expect(real.amount < 0, "La pata real es el gasto COMPLETO en negativo.")
        #expect(loan.amount > 0, "El filtro `loanBySign` es por signo: una pata negativa no se suprime.")
    }

    /// **La asimetría, que es el escenario entero**: real exacta, préstamo provisional.
    ///
    /// Si las dos nacieran iguales el fixture no probaría nada: el ticket describe justo el estado
    /// al que llegan los tres caminos de asimetría, no el de la creación.
    @Test func theTwoLegs_areSealedWithDifferentCoverage() throws {
        let context = try makeContext()

        DevSeedGroupBridgeFXLegs.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        let (real, loan) = try legs(in: context)
        #expect(!real.isExchangeRateProvisional, """
            La pata real nació PROVISIONAL. Entonces el mes marcaría leyendo solo su flag, incluso \
            con el bug del bridge dentro, y el fixture daría verde sobre código roto.
            """)
        #expect(loan.isExchangeRateProvisional, "La pata de préstamo es la magnitud dudosa del escenario.")
    }

    // MARK: - Lo que ve el adjustment

    /// La pata de préstamo queda suprimida y la real ajustada a `-myShare`.
    @Test func theAdjustment_suppressesTheLoanLeg_andNetsTheRealOne() throws {
        let context = try makeContext()

        DevSeedGroupBridgeFXLegs.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )
        let (real, loan) = try legs(in: context)
        let adj = try adjustment(in: context)

        #expect(adj.isSuppressed(loan), "La pata de préstamo no se suprimió: sumaría como INGRESO.")
        #expect(!adj.isSuppressed(real))
        #expect(
            abs(adj.amountInPreferredCurrency(real) + DevSeedGroupBridgeFXLegs.myShareInPreferred) < 1.0,
            """
            El importe sintetizado no es `-myShare` (\(DevSeedGroupBridgeFXLegs.myShareInPreferred)). \
            Salió \(adj.amountInPreferredCurrency(real)). Si sale positivo, la pata real se sembró \
            con «mi parte» en vez de con el TOTAL y la resta quedó invertida.
            """
        )
    }

    /// **El caso que distingue el código arreglado del código con el bug.**
    ///
    /// La pata real es exacta, así que toda la magnitud dudosa del gasto sintetizado viene de la
    /// pata suprimida. Con el bug del ticket —la síntesis ignora el flag de las patas de préstamo—
    /// esto devuelve 0 y el mes sale «100 % exacto» con el 86 % de su aritmética dudosa.
    @Test func approximateMagnitude_comesFromTheSuppressedLeg_notFromTheRealOne() throws {
        let context = try makeContext()

        DevSeedGroupBridgeFXLegs.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )
        let (real, loan) = try legs(in: context)
        let adj = try adjustment(in: context)

        let magnitude = abs(adj.amountInPreferredCurrency(real))
        let approximate = adj.approximateMagnitude(real, magnitude: magnitude)

        #expect(approximate > 0, """
            La magnitud dudosa del gasto es CERO aunque su pata de préstamo esté sellada como \
            provisional. Es exactamente el bug de `bridge-de-grupos-pierde-la-marca-de-sus-patas`.
            """)
        #expect(
            abs(approximate - abs(loan.amountInPreferredCurrency)) < 0.01,
            """
            La magnitud dudosa (\(approximate)) no es la de la pata de préstamo \
            (\(abs(loan.amountInPreferredCurrency))). Si se parece al NETO (~\(magnitude)), el \
            numerador se está calculando sobre la resta y no sobre magnitudes — el error que el \
            contrato de `ApproximateMarkThreshold` prohíbe explícitamente.
            """
        )
    }

    /// Y pesa lo suficiente para que la marca sea observable con el umbral real.
    ///
    /// No es decoración: un fixture cuya magnitud dudosa no llegue al 5 % del lado daría un QA sin
    /// «≈» y se leería como un FAIL del producto.
    @Test func theDoubtfulMagnitude_clearsTheThreshold_againstItsOwnSide() throws {
        let context = try makeContext()

        DevSeedGroupBridgeFXLegs.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )
        let (real, loan) = try legs(in: context)
        let adj = try adjustment(in: context)

        let magnitude = abs(adj.amountInPreferredCurrency(real))
        let approximate = adj.approximateMagnitude(real, magnitude: magnitude)
        #expect(
            ApproximateMarkThreshold.marks(approximate: approximate, total: magnitude),
            """
            A solas el fixture ya no marca: \(approximate) sobre \(magnitude). Con el corpus del \
            perfil el denominador es mayor, así que si falla aquí falla en todas partes. La pata de \
            préstamo vale \(abs(loan.amountInPreferredCurrency)).
            """
        )
    }

    /// Idempotencia: un segundo arranque no planta un segundo par.
    @Test func seedingTwice_doesNotDuplicateTheLegs() throws {
        let context = try makeContext()

        DevSeedGroupBridgeFXLegs.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )
        DevSeedGroupBridgeFXLegs.create(
            currencyCode: foreignCode, subcategoryLookup: [:], in: context
        )

        let target = DevSeedGroupBridgeFXLegs.splitExpenseID
        let rows = try context.fetch(
            FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == target })
        )
        #expect(rows.count == 2, "Se sembró un segundo par: el importe del mes se duplicaría.")
    }
}
