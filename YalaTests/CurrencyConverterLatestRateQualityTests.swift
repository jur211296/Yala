//
//  CurrencyConverterLatestRateQualityTests.swift
//  YalaTests
//
//  La ruta del TC ACTUAL (`convertWithLatestRate`) frente a una fila de tasas parcial.
//  Ticket `fx-presentation-still-shows-1to1`.
//
//  **Por qué existe este archivo aparte de `CurrencyConverterPartialRateTests`.** Aquél cerró la
//  ruta con fecha (`convert(_:on:)`), que resuelve por escalones desde
//  `fx-partial-rate-rows-silent-1to1`. Esta ruta es OTRA y quedó fuera: se sirve de una caché en
//  memoria que se llena con `needing: []` —no puede saber qué divisas le van a pedir después—, así
//  que una fila parcial del día entraba entera y `performConversion` salía por su `guard let`.
//
//  Medido el 2026-09-06 antes del arreglo, con la fila del día trayendo USD y PEN pero no JPY:
//
//      convertWithLatestRate  1000 JPY -> 1000 PEN          (el monto CRUDO, ~40x de más)
//      convertWithLatestRate  sin fila -> 24,79 PEN         (convierte bien)
//      convert(_:on:)         fila parcial -> 24,99 PEN, quality = .staticFallback
//
//  Las dos primeras líneas juntas son el hallazgo: **la fila parcial volvía a ser estrictamente
//  peor que no tener fila**, la misma forma exacta del bug que ya se había cerrado en la otra ruta.
//  Y es la ruta que más pinta: saldo vivo del Panel, saldos de Grupos, presupuestos, pagos
//  programados.
//
//  Aislamiento: `CurrencyConverter()` propia (no `.shared`) y contexto in-memory con
//  `cloudKitDatabase: .none` explícito — molde de `CurrencyConverterCacheTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("TC actual · calidad de la tasa sobre una fila parcial")
struct CurrencyConverterLatestRateQualityTests {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func makeContext(on date: Date, rates: [String: Double]) throws -> ModelContext {
        let schema = Schema([ExchangeRate.self, TransactionItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(for: schema, configurations: [config]))
        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date),
            base: "USD",
            ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
        return context
    }

    /// Añade una fila con fecha relativa a hoy (negativa = pasado).
    private func addRow(_ ctx: ModelContext, daysAgo: Int, rates: [String: Double]) throws {
        let date = Date.now.addingTimeInterval(-86400 * Double(daysAgo))
        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date), base: "USD", ratesDictionary: rates
        )
        ctx.insert(row)
        try ctx.save()
    }

    private func emptyContext() throws -> ModelContext {
        let schema = Schema([ExchangeRate.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    // MARK: - El bug

    @Test("La fila parcial no devuelve el monto crudo")
    func partialRow_neverReturnsTheRawAmount() throws {
        let context = try makeContext(on: Date.now, rates: ["USD": 1.0, "PEN": 3.75])

        let got = CurrencyConverter().convertWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: context
        )

        #expect(got != Decimal(1000), """
            1000 JPY no son 1000 PEN. La fila de hoy no trae JPY, así que la caché la sirvió
            incompleta y la conversión devolvió el monto crudo dándolo por bueno.
            """)
    }

    /// La fila parcial no solo debe dejar de tapar el camino bueno: debe quedar **mejor** que no
    /// tener fila, porque aporta un dato real. Con la fila trayendo PEN=3,75 y sin JPY, el resultado
    /// correcto mezcla los dos escalones —el PEN de la fila y el JPY de la tabla estática (150)—:
    /// 1000 / 150 × 3,75 = 25,0. Sin fila, todo sale de la tabla (PEN=3,72) y da 24,8.
    ///
    /// Fijar el número exacto y no un «se parecen» es lo que distingue las tres versiones posibles:
    /// 1000 (el bug), 24,8 (ignorar la fila) y 25,0 (usar de cada escalón lo que aporta).
    @Test("La fila parcial aporta lo suyo y completa el resto")
    func partialRow_mixesTheRowWithTheStaticTable() throws {
        let partial = CurrencyConverter().convertWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN",
            context: try makeContext(on: Date.now, rates: ["USD": 1.0, "PEN": 3.75])
        )
        let none = CurrencyConverter().convertWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: try emptyContext()
        )

        let expectedPartial = Decimal(1000) / Decimal(CurrencyCode.jpy.fallbackRateToUSD) * Decimal(3.75)
        #expect(abs(partial - expectedPartial) < Decimal(0.01), """
            Con fila parcial dio \(partial); se esperaba \(expectedPartial) — el PEN de la fila con el
            JPY de la tabla estática. Ni el monto crudo, ni ignorar el dato real que la fila sí traía.
            """)

        let expectedNone = Decimal(1000) / Decimal(CurrencyCode.jpy.fallbackRateToUSD)
            * Decimal(CurrencyCode.pen.fallbackRateToUSD)
        #expect(abs(none - expectedNone) < Decimal(0.01))
    }

    // MARK: - La calidad que se declara

    @Test("Fila parcial ⇒ la tasa se declara NO exacta")
    func partialRow_reportsInexactQuality() throws {
        let context = try makeContext(on: Date.now, rates: ["USD": 1.0, "PEN": 3.75])

        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: context
        )

        #expect(!outcome.quality.isExact, """
            La tasa de JPY no salió de la fila de hoy sino de un escalón inferior: el número es
            aproximado y quien lo pinte tiene que poder decirlo.
            """)
    }

    /// Control positivo — sin él, declarar SIEMPRE «aproximado» pasaría el test de arriba y pondría
    /// la marca en todas las pantallas de todos los usuarios.
    /// Las tasas de la fila son **distintas de las estáticas** a propósito: construida con
    /// `CurrencyCode.fallbackRates`, el resultado salía idéntico al del caso sin fila y la aserción
    /// no podía distinguir «usó la fila» de «cayó a la tabla». Con JPY 100 y PEN 4,00 el número
    /// esperado (40) solo sale si de verdad se leyó la fila del día.
    @Test("Fila completa ⇒ tasa exacta, y se usa LA DE LA FILA")
    func completeRow_reportsExactQuality() throws {
        var complete = Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map {
                ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
            })
        complete["JPY"] = 100.0
        complete["PEN"] = 4.00
        let context = try makeContext(on: Date.now, rates: complete)

        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: context
        )

        #expect(outcome.quality.isExact)
        #expect(abs(outcome.amount - Decimal(40)) < Decimal(0.01), """
            1000 JPY / 100 × 4,00 = 40. Si sale 24,8 se usó la tabla estática y la fila del día se
            ignoró.
            """)
    }

    // MARK: - El escalón que estaba muerto en esta ruta

    /// **El defecto que cazó la review, medido antes de arreglarlo.** Sin fila de hoy pero con una
    /// fila real completa de ayer, esta ruta devolvía 24,79 —la tabla estática— mientras
    /// `convert(_:on:)` devolvía 40 con la fila de ayer. Dos APIs, el mismo instante, y la que más
    /// pinta eligiendo la peor fuente.
    ///
    /// La causa era que la caché se sembraba con `resolveRates(needing: [])`, que sin fila del día
    /// devuelve la tabla estática **entera**; como esa tabla cubre todas las divisas, la
    /// comprobación de cobertura daba siempre positiva y el escalón de la fila anterior no se
    /// alcanzaba nunca.
    @Test("Sin fila de hoy se usa la fila REAL de ayer, no la tabla estática")
    func noRowToday_usesYesterdaysRealRow() throws {
        let context = try emptyContext()
        try addRow(context, daysAgo: 1, rates: ["USD": 1.0, "PEN": 4.00, "JPY": 100.0])

        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: context
        )

        #expect(abs(outcome.amount - Decimal(40)) < Decimal(0.01), """
            Con la fila de ayer: 1000 / 100 × 4,00 = 40. Si sale 24,8 se está usando la tabla
            estática y tapando una tasa real disponible un escalón más abajo.
            """)
        #expect(outcome.quality == .carriedForward(fromDateKey: Self.dateFormatter.string(
            from: Date.now.addingTimeInterval(-86400))), """
            Y se declara de dónde salió: no es exacta, pero tampoco es el peor escalón.
            """)
    }

    /// La ruta con fecha y la del TC actual deben coincidir cuando miran el mismo día. Es la forma
    /// general del defecto: dos APIs que responden a la misma pregunta no pueden dar números
    /// distintos.
    @Test("Las dos rutas coinciden sobre los mismos datos")
    func bothRoutesAgree() throws {
        let context = try emptyContext()
        try addRow(context, daysAgo: 1, rates: ["USD": 1.0, "PEN": 4.00, "JPY": 100.0])

        let conv = CurrencyConverter()
        let latest = conv.convertCheckedWithLatestRate(Decimal(1000), from: "JPY", to: "PEN", context: context)
        let dated = conv.convertChecked(Decimal(1000), from: "JPY", to: "PEN", on: Date.now, context: context)

        #expect(abs(latest.amount - dated.amount) < Decimal(0.01))
        #expect(latest.quality == dated.quality)
    }

    // MARK: - Tasas inservibles

    /// **Una tasa `0` guardada devolvía el monto crudo sellado como exacto.** Pasaba la comprobación
    /// de presencia, nunca contaba como ausente, y `performConversion` salía por su guard. Es el bug
    /// del ticket por otra puerta: el número está mal Y se declara bueno.
    @Test("Una tasa 0 en el ORIGEN no devuelve el monto crudo")
    func zeroRateOnSource_doesNotReturnRawAmount() throws {
        let context = try makeContext(on: Date.now, rates: ["USD": 1.0, "PEN": 3.75, "JPY": 0.0])

        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: context
        )

        #expect(outcome.amount != Decimal(1000), "1000 JPY no son 1000 PEN")
        #expect(!outcome.quality.isExact, "y una tasa que hubo que sustituir no es exacta")
    }

    /// El gemelo, y es peor: un `0` en la divisa de DESTINO no devolvía el crudo sino **0**, que
    /// parece un dato real. Un total desaparecía de la pantalla en silencio.
    @Test("Una tasa 0 en el DESTINO no convierte el total en cero")
    func zeroRateOnTarget_doesNotZeroTheAmount() throws {
        let context = try makeContext(on: Date.now, rates: ["USD": 1.0, "PEN": 0.0, "JPY": 150.0])

        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: context
        )

        #expect(outcome.amount != Decimal(0), "un saldo no se vuelve cero porque falte una tasa")
        #expect(!outcome.quality.isExact)
    }

    /// La cobertura de la caché se comprueba sobre las DOS divisas. Los demás casos omiten siempre
    /// la de origen, así que la mitad del destino se quedaba sin cubrir.
    @Test("Cobertura asimétrica: falta la divisa de DESTINO")
    func missingTargetCurrency_isAlsoResolved() throws {
        let context = try makeContext(on: Date.now, rates: ["USD": 1.0, "JPY": 100.0])
        try addRow(context, daysAgo: 1, rates: ["USD": 1.0, "PEN": 4.00, "JPY": 100.0])

        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: context
        )

        #expect(abs(outcome.amount - Decimal(40)) < Decimal(0.01), """
            JPY está en la fila de hoy y PEN no; PEN sale de la de ayer. Si la comprobación solo
            mirara la divisa de origen, esto devolvería el monto crudo.
            """)
        #expect(!outcome.quality.isExact)
    }

    // MARK: - Sin ModelContext

    /// Antes de `setContext` —la ventana del arranque— no hay tasas guardadas: se convierte con la
    /// tabla estática, que es aproximada, y hay que declararlo.
    @Test("Sin contexto: convierte por la tabla estática y lo declara")
    func withoutContext_reportsStaticFallback() {
        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN"
        )

        #expect(outcome.amount != Decimal(1000))
        #expect(outcome.quality == .staticFallback)
    }

    /// La excepción que impide el «≈» permanente: convertir una divisa a sí misma es exacto por
    /// construcción. Sin este caso, en el arranque todo total monomoneda —la inmensa mayoría de los
    /// usuarios— saldría marcado como aproximado.
    @Test("Sin contexto y misma divisa: sigue siendo exacta")
    func withoutContext_sameCurrencyIsExact() {
        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(250), from: "PEN", to: "PEN"
        )

        #expect(outcome.quality.isExact)
        #expect(outcome.amount == Decimal(250))
    }

    /// La misma divisa es exacta por construcción, no por dato: sin este caso, un usuario
    /// monomoneda —la inmensa mayoría— vería la marca de aproximado en todos sus totales el día que
    /// no bajen tasas.
    @Test("Misma divisa ⇒ exacta aunque no haya ninguna tasa")
    func sameCurrency_isExactWithoutAnyRates() throws {
        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(250), from: "PEN", to: "PEN", context: try emptyContext()
        )

        #expect(outcome.quality.isExact)
        #expect(outcome.amount == Decimal(250))
    }

    /// Sin fila del día la caché se llena de la tabla estática: convierte —el test de arriba lo
    /// fija— pero es aproximado y debe declararlo. Es el caso de «hoy todavía no bajaron las tasas»,
    /// mucho más frecuente que la fila parcial.
    @Test("Sin fila del día ⇒ convierte, pero se declara aproximado")
    func noRow_convertsButReportsInexact() throws {
        let outcome = CurrencyConverter().convertCheckedWithLatestRate(
            Decimal(1000), from: "JPY", to: "PEN", context: try emptyContext()
        )

        #expect(outcome.amount != Decimal(1000))
        #expect(!outcome.quality.isExact)
    }
}
