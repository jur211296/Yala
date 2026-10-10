//
//  GroupBridgeApproximateMarkTests.swift
//  YalaTests
//
//  La marca «≈» cuando el importe NO sale de una sola fila.
//  Ticket `bridge-de-grupos-pierde-la-marca-de-sus-patas`.
//
//  **Por qué esta suite existe, y por qué en su propio archivo.** `ApproximateAmountMarkTests` mide
//  transacciones sueltas, donde el importe y la marca salen de la MISMA fila. En un gasto de grupo
//  bridgeado no: el importe que ven las estadísticas lo sintetiza `GroupBridgeStatsAdjustment`
//  sumando la pata real y las de préstamo, y esas últimas están SUPRIMIDAS del recorrido — su
//  `isExchangeRateProvisional` no lo leía nadie. Hasta el 2026-09-09 no había en aquel archivo **ni
//  un solo test con `adjustment` distinto de `.none`**, y por eso los cuatro numeradores del umbral
//  podían leer el flag de la fila sin que nada se pusiera rojo.
//
//  El archivo aparte NO es cosmético: `makeTestContext()` reusa el container por `#fileID`, y
//  `.serialized` solo ordena los tests DENTRO de una suite. Dos suites del mismo archivo que pidan
//  contexto corren a la vez sobre el mismo store y el `wipeAllModels` de una borra las filas de la
//  otra. Medido: con estas pruebas dentro de `ApproximateAmountMarkTests.swift` —donde ya vive
//  `RecordsSummaryApproximateMarkTests`, que también pide contexto— los dos casos de Registros
//  pasaban en solitario y daban `expense == 0` en la suite completa. `#fileID` propio, store propio.
//
//  El escenario es el del ticket y se repite en los cuatro consumidores porque cada uno tiene su
//  propio bucle: pata real de −1.000 con tasa exacta y pata de préstamo de +900 con tasa
//  provisional. El importe son −100 y el 90 % de la aritmética que lo produjo salió de una tasa
//  dudosa. Cada caso lleva su gemelo «las dos patas exactas ⇒ sin marca» (si no, marcar SIEMPRE
//  pasaría la suite) y el archivo cierra con el control del cociente: el fix propaga la marca, no la
//  convierte otra vez en un OR sobre el período.
//
//  MUTANTES VERIFICADOS (2026-09-09): quitar el `|| loanBySign.contains { ... }` del OR pone en rojo
//  los cuatro casos de «pata de préstamo dudosa» y ninguno de sus gemelos; devolver
//  `tx.isExchangeRateProvisional` en `HeroBucketsCalculator` pone en rojo solo el del hero.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Marca de aproximado · gastos de grupo bridgeados", .serialized)
struct GroupBridgeApproximateMarkTests {

    private let calendar = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    private func monthInterval(_ y: Int, _ m: Int) -> DateInterval {
        let start = day(y, m, 1)
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// El gasto de grupo del ticket, ya bridgeado, más las piezas que cada calculador necesita.
    private struct Escenario {
        let real: TransactionItem
        let lent: TransactionItem
        let cuentaReal: Account
        let cuentaGrupos: Account
        let ajuste: GroupBridgeStatsAdjustment
        var transacciones: [TransactionItem] { [real, lent] }
        var cuentas: [Account] { [cuentaReal, cuentaGrupos] }
        var idsElegibles: Set<PersistentIdentifier> {
            Set(cuentas.map(\.persistentModelID))
        }
    }

    /// - Parameters:
    ///   - lentProvisional: la pata de préstamo trae tasa dudosa (el caso del ticket).
    ///   - total: importe del gasto de grupo (la pata real vale `-total`).
    ///   - prestado: lo que presté al grupo (la pata de préstamo vale `+prestado`), así que mi
    ///     parte es `total - prestado`. Los dos parametrizados porque la proporción entre ellos es
    ///     justo lo que distingue un numerador en magnitudes de uno neteado.
    private func escenario(
        _ context: ModelContext,
        fecha: Date,
        lentProvisional: Bool,
        total: Double = 1_000,
        prestado: Double = 900
    ) throws -> Escenario {
        let cuentaReal = makeTestAccount(context: context, name: "Diaria", currencyCode: "PEN")
        let cuentaGrupos = makeTestAccount(context: context, name: "Grupos", currencyCode: "PEN")
        cuentaGrupos.isSystemAccount = true
        let gasto = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let prestamo = makeTestCategory(context: context, name: "Préstamo a grupos", isIncome: true)
        let eid = UUID().uuidString

        let real = TransactionItem(
            date: fecha, amount: -total, currencyCode: "PEN", note: "",
            category: gasto, account: cuentaReal, tags: [],
            amountInPreferredCurrency: -total, preferredCurrencyCode: "PEN",
            isExchangeRateProvisional: false
        )
        real.splitExpenseID = eid
        context.insert(real)

        let lent = TransactionItem(
            date: fecha, amount: prestado, currencyCode: "PEN", note: "",
            category: prestamo, account: cuentaGrupos, tags: [],
            amountInPreferredCurrency: prestado, preferredCurrencyCode: "PEN",
            isExchangeRateProvisional: lentProvisional
        )
        lent.splitExpenseID = eid
        context.insert(lent)
        try context.save()

        return Escenario(
            real: real, lent: lent,
            cuentaReal: cuentaReal, cuentaGrupos: cuentaGrupos,
            ajuste: GroupBridgeStatsAdjustment.build(from: [real, lent])
        )
    }

    /// Estado global del que depende `RecordsViewModel.applyFilters`, fijado y restaurado.
    ///
    /// `selectedPeriod` acota el intervalo; `includeGroupTransactionsInFeed` es el que muerde aquí y
    /// no es hipotético: en `false` el filtro descarta **toda** fila con `splitExpenseID`
    /// (`RecordsViewModel.swift:258`), y estos escenarios son solo filas bridgeadas ⇒ resumen a cero
    /// y rojo que no tiene nada que ver con la marca. La suite hermana era inmune porque sus filas
    /// no son de grupo.
    private func conEstadoDeRegistros(_ cuerpo: () throws -> Void) rethrows {
        let periodoAnterior = SessionState.shared.selectedPeriod
        let clave = AppPreferences.Keys.includeGroupTransactionsInFeed
        let incluirAnterior = UserDefaults.standard.object(forKey: clave)
        SessionState.shared.selectedPeriod = .allTime
        UserDefaults.standard.set(true, forKey: clave)
        defer {
            SessionState.shared.selectedPeriod = periodoAnterior
            if let incluirAnterior {
                UserDefaults.standard.set(incluirAnterior, forKey: clave)
            } else {
                UserDefaults.standard.removeObject(forKey: clave)
            }
        }
        try cuerpo()
    }

    /// Gasto suelto EXACTO, para mover el denominador del cociente sin tocar el numerador.
    private func gastoSueltoExacto(
        _ context: ModelContext, importe: Double, fecha: Date, en escenario: Escenario
    ) throws -> TransactionItem {
        let tx = TransactionItem(
            date: fecha, amount: -importe, currencyCode: "PEN", note: "",
            category: escenario.real.category, account: escenario.cuentaReal, tags: [],
            amountInPreferredCurrency: -importe, preferredCurrencyCode: "PEN"
        )
        context.insert(tx)
        try context.save()
        return tx
    }

    // MARK: - El hero del Panel

    @Test("Hero: la pata de préstamo dudosa marca el gasto del período")
    func heroBuckets_provisionalLentLeg_marksTheExpense() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(context, fecha: day(2026, 4, 10), lentProvisional: true)

        let buckets = HeroBucketsCalculator.calculate(
            transactions: e.transacciones,
            monthInterval: interval, prevInterval: monthInterval(2026, 3),
            periodInterval: interval,
            eligibleAccountIDs: e.idsElegibles,
            adjustment: e.ajuste
        )

        #expect(buckets.periodExpense == 100, """
            El importe NO cambia con este ticket: sigue siendo «mi parte», −1.000 + 900.
            """)
        #expect(buckets.periodIncome == 0, """
            Premisa del escenario: la pata de préstamo está SUPRIMIDA. Sin esto, borrar la supresión
            deja el test en verde midiendo otra cosa — el +900 entraría como ingreso fantasma y el
            gasto no se movería.
            """)
        #expect(buckets.periodExpenseApproximate, """
            El 90 % de la aritmética que produjo esos 100 salió de una tasa dudosa. Leyendo
            `tx.isExchangeRateProvisional` de la pata real, este gasto se contaba 100 % exacto.
            """)
    }

    @Test("Hero: con las dos patas exactas no hay marca")
    func heroBuckets_exactLegs_doNotMark() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(context, fecha: day(2026, 4, 10), lentProvisional: false)

        let buckets = HeroBucketsCalculator.calculate(
            transactions: e.transacciones,
            monthInterval: interval, prevInterval: monthInterval(2026, 3),
            periodInterval: interval,
            eligibleAccountIDs: e.idsElegibles,
            adjustment: e.ajuste
        )

        #expect(buckets.periodExpense == 100)
        #expect(!buckets.periodExpenseApproximate, """
            Ninguna de las dos patas se convirtió con una tasa dudosa. Si esto marca, el accessor
            devuelve `true` siempre y el «≈» sale en todos los gastos de grupo.
            """)
    }

    // MARK: - El flujo de caja

    @Test("Flujo de caja: la pata de préstamo dudosa marca el gasto")
    func cashFlow_provisionalLentLeg_marksTheExpense() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(context, fecha: day(2026, 4, 10), lentProvisional: true)

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: e.transacciones, interval: interval, grouping: .day,
            currencyCode: "PEN", adjustment: e.ajuste, converter: MockCurrencyConverter()
        )

        #expect(summary.totalExpense == 100)
        #expect(summary.totalIncome == 0, """
            La pata de préstamo está suprimida: si asoma como ingreso, el neteo del bridge se rompió
            y este test estaría midiendo otra cosa.
            """)
        #expect(summary.expenseAmountsAreApproximate)
    }

    @Test("Flujo de caja: con las dos patas exactas no hay marca")
    func cashFlow_exactLegs_doNotMark() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(context, fecha: day(2026, 4, 10), lentProvisional: false)

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: e.transacciones, interval: interval, grouping: .day,
            currencyCode: "PEN", adjustment: e.ajuste, converter: MockCurrencyConverter()
        )

        #expect(summary.totalExpense == 100)
        #expect(!summary.expenseAmountsAreApproximate)
    }

    // MARK: - El resumen de los widgets

    @Test("Widgets: la pata de préstamo dudosa marca el gasto del período")
    func widgetPeriodSummary_provisionalLentLeg_marksTheExpense() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(context, fecha: day(2026, 4, 10), lentProvisional: true)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: e.transacciones,
            periodStart: interval.start, periodEnd: interval.end,
            currencyCode: "PEN", adjustment: e.ajuste
        )

        #expect(summary.totalExpense == 100)
        #expect(summary.totalIncome == 0, "premisa: la pata de préstamo está suprimida")
        // `Bool?` a propósito en el DTO del App Group: comparar contra `true` distingue «no marca»
        // de «el campo no viajó».
        #expect(summary.expenseIsApproximate == true)
    }

    @Test("Widgets: con las dos patas exactas no hay marca")
    func widgetPeriodSummary_exactLegs_doNotMark() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(context, fecha: day(2026, 4, 10), lentProvisional: false)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: e.transacciones,
            periodStart: interval.start, periodEnd: interval.end,
            currencyCode: "PEN", adjustment: e.ajuste
        )

        #expect(summary.totalExpense == 100)
        #expect(summary.expenseIsApproximate == false)
    }

    // MARK: - El resumen de Registros

    /// Este va por el camino real (`applyFilters`), que construye el ajuste él solo desde el
    /// `ModelContext`: es lo único que demuestra que el cableado llega a la pantalla y no solo al
    /// calculador.
    @Test("Registros: la pata de préstamo dudosa marca el gasto")
    func recordsSummary_provisionalLentLeg_marksTheExpense() throws {
        try conEstadoDeRegistros {
            let context = try makeTestContext()
            let e = try escenario(context, fecha: Date(), lentProvisional: true)

            let vm = RecordsViewModel()
            vm.applyFilters(
                transactions: e.transacciones, accounts: e.cuentas,
                categories: [], tags: [], context: context, currencyCode: "PEN"
            )

            #expect(vm.recordsSummary.expense == 100)
            #expect(vm.recordsSummary.income == 0, "premisa: la pata de préstamo está suprimida")
            #expect(vm.recordsSummary.expenseIsApproximate)
        }
    }

    @Test("Registros: con las dos patas exactas no hay marca")
    func recordsSummary_exactLegs_doNotMark() throws {
        try conEstadoDeRegistros {
            let context = try makeTestContext()
            let e = try escenario(context, fecha: Date(), lentProvisional: false)

            let vm = RecordsViewModel()
            vm.applyFilters(
                transactions: e.transacciones, accounts: e.cuentas,
                categories: [], tags: [], context: context, currencyCode: "PEN"
            )

            #expect(vm.recordsSummary.expense == 100)
            #expect(!vm.recordsSummary.expenseIsApproximate)
        }
    }

    // MARK: - Sigue siendo un cociente, no un OR

    // MARK: - Sigue siendo un cociente, no un OR

    /// **El control que impide que este ticket deshaga el anterior.** Propagar la incertidumbre no
    /// puede volver a encender el «≈» sobre todo el período: la parte dudosa sigue teniendo que
    /// PESAR. Gasto de grupo de 1.000 con solo 100 prestados —y esos 100 con tasa dudosa—, más un
    /// gasto suelto exacto de 5.000: 100 sobre 5.900 es el 1,7 %.
    @Test("Un gasto de grupo con poca magnitud dudosa NO marca el período")
    func smallApproximateLegBelowThreshold_doesNotMark() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(
            context, fecha: day(2026, 4, 10), lentProvisional: true, total: 1_000, prestado: 100
        )
        let suelto = try gastoSueltoExacto(context, importe: 5_000, fecha: day(2026, 4, 11), en: e)

        let buckets = HeroBucketsCalculator.calculate(
            transactions: e.transacciones + [suelto],
            monthInterval: interval, prevInterval: monthInterval(2026, 3),
            periodInterval: interval,
            eligibleAccountIDs: e.idsElegibles,
            adjustment: e.ajuste
        )

        #expect(buckets.periodExpense == 5_900, "mi parte (900) + el suelto (5.000)")
        #expect(!buckets.periodExpenseApproximate, """
            100 sobre 5.900 es el 1,7 %, por debajo del 5 % que decidió el owner el 2026-09-08. Si
            esto marca, el arreglo de la propagación se comió el umbral y volvimos al OR sobre el
            período entero.
            """)
    }

    // MARK: - El numerador son MAGNITUDES, no el neto

    //  Los dos casos de abajo son los únicos que distinguen `Σ|patas provisionales|` de `|neto|`, y
    //  van en las dos direcciones a propósito: con el numerador neteado el primero sale sin marca y
    //  el segundo con ella — los dos al revés de lo que debe salir. Es la corrección que trajo la
    //  review adversarial del 2026-09-09, y el contrato que la zanja está escrito en
    //  `ApproximateMarkThreshold`: «un gasto de 1.000 y un reembolso de 900, los dos con tasa
    //  dudosa, no dejan 100 de incertidumbre: dejan 1.900».

    /// **Mi parte es pequeña y el préstamo enorme: el neto se queda corto.** Viaje, adelanto el
    /// hotel de diez personas (10.000, mi parte 1.000) con tasa dudosa en la pata de préstamo, y el
    /// resto del mes son 25.000 exactos. Un tercio de la aritmética del mes salió de una tasa que no
    /// era la de su día.
    @Test("Un préstamo grande con tasa dudosa marca aunque mi parte sea pequeña")
    func largeApproximateLeg_marksEvenWhenMyShareIsSmall() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(
            context, fecha: day(2026, 4, 10), lentProvisional: true, total: 10_000, prestado: 9_000
        )
        let suelto = try gastoSueltoExacto(context, importe: 25_000, fecha: day(2026, 4, 11), en: e)

        let buckets = HeroBucketsCalculator.calculate(
            transactions: e.transacciones + [suelto],
            monthInterval: interval, prevInterval: monthInterval(2026, 3),
            periodInterval: interval,
            eligibleAccountIDs: e.idsElegibles,
            adjustment: e.ajuste
        )

        #expect(buckets.periodExpense == 26_000, "mi parte (1.000) + el suelto (25.000)")
        #expect(buckets.periodExpenseApproximate, """
            9.000 sobre 26.000 es el 34,6 % y marca. Con el numerador neteado serían 1.000/26.000 =
            3,8 % y el mes saldría presentado como exacto.
            """)
    }

    /// **Mi parte es casi todo y el préstamo una miseria: el neto se pasa.** Cena de dos, pago
    /// 10.000 y me deben 300, y esos 300 son los únicos con tasa dudosa. Marcar el mes entero por
    /// ellos es la erosión que el umbral vino a evitar — en el límite, dos céntimos dudosos.
    @Test("Un préstamo minúsculo con tasa dudosa NO marca aunque mi parte sea casi todo")
    func tinyApproximateLeg_doesNotMarkEvenWhenMyShareIsHuge() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(
            context, fecha: day(2026, 4, 10), lentProvisional: true, total: 10_000, prestado: 300
        )
        let suelto = try gastoSueltoExacto(context, importe: 600, fecha: day(2026, 4, 11), en: e)

        let buckets = HeroBucketsCalculator.calculate(
            transactions: e.transacciones + [suelto],
            monthInterval: interval, prevInterval: monthInterval(2026, 3),
            periodInterval: interval,
            eligibleAccountIDs: e.idsElegibles,
            adjustment: e.ajuste
        )

        #expect(buckets.periodExpense == 10_300, "mi parte (9.700) + el suelto (600)")
        #expect(!buckets.periodExpenseApproximate, """
            300 sobre 10.300 es el 2,9 % y no llega al umbral. Con el numerador neteado serían
            9.700/10.300 = 94 %: el mes entero con «≈» por 300 dudosos.
            """)
    }

    /// Y la dirección que YA funcionaba antes del ticket, para que no se rompa en silencio: las dos
    /// patas dudosas suman **las dos** magnitudes, que es literalmente el ejemplo del contrato.
    @Test("Con las dos patas dudosas el numerador es la suma de las dos magnitudes")
    func bothLegsProvisional_sumBothMagnitudes() throws {
        let context = try makeTestContext()
        let interval = monthInterval(2026, 4)
        let e = try escenario(context, fecha: day(2026, 4, 10), lentProvisional: true)
        e.real.isExchangeRateProvisional = true
        try context.save()
        let ajuste = GroupBridgeStatsAdjustment.build(from: e.transacciones)
        // 1.900 de incertidumbre contra 100 de gasto: el suelto exacto de 5.000 no la tapa.
        let suelto = try gastoSueltoExacto(context, importe: 5_000, fecha: day(2026, 4, 11), en: e)

        let buckets = HeroBucketsCalculator.calculate(
            transactions: e.transacciones + [suelto],
            monthInterval: interval, prevInterval: monthInterval(2026, 3),
            periodInterval: interval,
            eligibleAccountIDs: e.idsElegibles,
            adjustment: ajuste
        )

        #expect(buckets.periodExpense == 5_100)
        #expect(buckets.periodExpenseApproximate, """
            1.900 sobre 5.100 es el 37 %. Con el numerador neteado serían 100/5.100 = 1,96 % y no
            marcaría: dos aproximaciones opuestas se habrían cancelado justo cuando el número menos
            limpio está.
            """)
    }
}
