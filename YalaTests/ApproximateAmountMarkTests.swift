//
//  ApproximateAmountMarkTests.swift
//  YalaTests
//
//  La marca «≈» de los totales: cuándo se enciende y cuándo NO.
//  Ticket `fx-presentation-still-shows-1to1`.
//
//  **Las dos vías, y por qué hacen falta las dos.** Un total de estas pantallas casi nunca pasa por
//  el converter: cuando la divisa de destino es la preferida —el caso normal— se suma el
//  `amountInPreferredCurrency` que ya está guardado, convertido el día que se creó la transacción.
//  Así que «este número es aproximado» se sabe por dos caminos distintos según la rama:
//
//    · rama guardada  → el flag `isExchangeRateProvisional` de cada transacción
//    · rama convertida → la `RateQuality` que devuelve el converter
//
//  Cubrir solo una deja pantallas enteras sin marca. El control positivo de cada test es su gemelo
//  «todo exacto ⇒ sin marca»: sin él, marcar SIEMPRE pasaría la mitad de esta suite y le pondría el
//  «≈» a todos los usuarios, que es tan mentira como no ponerlo nunca.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Marca de aproximado en los totales")
struct ApproximateAmountMarkTests {

    private let calendar = Calendar.current

    private func makeAccount() -> Account {
        Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
    }

    private func makeCategory(isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: isIncome ? "Salary" : "Food", colorHex: "#FF0000", isIncome: isIncome)
    }

    /// Transacción ya convertida y guardada, con el flag en el estado que pida el test.
    private func makeStoredTx(
        amount: Double,
        date: Date,
        account: Account,
        category: YalaCategory,
        provisional: Bool
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: "",
            category: category,
            account: account,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.isExchangeRateProvisional = provisional
        return tx
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    private func monthInterval(_ y: Int, _ m: Int) -> DateInterval {
        let start = day(y, m, 1)
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    // MARK: - Rama guardada · el flag de la transacción

    @Test("Una transacción con tasa provisional marca el total del período")
    func cashFlow_storedProvisionalTx_marksTheTotal() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        let tx = makeStoredTx(
            amount: -100, date: day(2026, 4, 10),
            account: account, category: category, provisional: true
        )

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: [tx], interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(summary.amountsAreApproximate, """
            El monto se guardó con una tasa que no era la de su día. El total lo hereda: se sigue
            mostrando, pero con la marca de aproximado.
            """)
    }

    @Test("Con todas las tasas exactas no hay marca")
    func cashFlow_allExact_hasNoMark() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        let txs = [
            makeStoredTx(amount: -100, date: day(2026, 4, 10), account: account, category: category, provisional: false),
            makeStoredTx(amount: -50, date: day(2026, 4, 12), account: account, category: category, provisional: false),
        ]

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(!summary.amountsAreApproximate)
    }

    /// **La transacción aproximada va la PRIMERA a propósito.** Puesta la última, este test pasa
    /// igual con `acumulador = tx.isExchangeRateProvisional` —sin el `||`— porque el último valor
    /// escrito sería `true`: mediría el orden del array, no la acumulación. Con ella delante, las
    /// cinco exactas que vienen detrás apagarían la señal y el test se pone rojo.
    @Test("Una sola transacción aproximada entre muchas exactas basta para marcar")
    func cashFlow_oneProvisionalAmongMany_marksTheTotal() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        var txs = [makeStoredTx(
            amount: -10, date: day(2026, 4, 1),
            account: account, category: category, provisional: true
        )]
        txs += (2...6).map {
            makeStoredTx(amount: -10, date: day(2026, 4, $0), account: account, category: category, provisional: false)
        }

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(summary.expenseAmountsAreApproximate, """
            Una de seis con el mismo importe pesa un 16,7 %, muy por encima del 5 % que pide
            `ApproximateMarkThreshold` desde el 2026-09-08. Este test sigue verde con el criterio
            nuevo, y por eso NO sirve para demostrarlo: el que lo demuestra es
            `oneTinyProvisionalAmongMany_doesNotMark`, más abajo.
            """)
    }

    /// El gemelo del anterior para el bucket del hero, por el mismo motivo: allí el `||` vive en
    /// `HeroBucketsCalculator` y ningún test lo cargaba con más de una transacción.
    @Test("El hero acumula: la aproximada primera no la apagan las exactas siguientes")
    func heroBuckets_provisionalFirst_staysMarked() {
        let account = makeAccount()
        let category = makeCategory()
        let period = monthInterval(2026, 4)
        var txs = [makeStoredTx(
            amount: -10, date: day(2026, 4, 1),
            account: account, category: category, provisional: true
        )]
        txs += (2...6).map {
            makeStoredTx(amount: -10, date: day(2026, 4, $0), account: account, category: category, provisional: false)
        }

        let buckets = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: period,
            prevInterval: monthInterval(2026, 3),
            periodInterval: period,
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )

        #expect(buckets.periodExpenseApproximate)
    }

    // MARK: - La marca es del lado que se pinta

    /// **El hero de Tendencias muestra UNO de tres números según la métrica**, y el del Panel en
    /// modo Solo Gastos muestra solo el gasto. Con una señal única para todo el período, un gasto
    /// mal convertido le ponía «≈» al total de INGRESOS — un número en el que no hubo ninguna
    /// conversión. Este par fija que cada lado lleva la suya.
    @Test("Un gasto aproximado no marca el total de ingresos")
    func cashFlow_approximateExpense_doesNotMarkIncome() {
        let account = makeAccount()
        let interval = monthInterval(2026, 4)
        let ingreso = makeStoredTx(
            amount: 5000, date: day(2026, 4, 3),
            account: account, category: makeCategory(isIncome: true), provisional: false
        )
        let gasto = makeStoredTx(
            amount: -100, date: day(2026, 4, 5),
            account: account, category: makeCategory(), provisional: true
        )

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: [ingreso, gasto], interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(summary.expenseAmountsAreApproximate, "el gasto sí es aproximado")
        #expect(!summary.incomeAmountsAreApproximate, """
            El total de ingresos no incluye ese gasto. Marcarlo sería decirle al usuario que un
            número exacto es dudoso, que erosiona la marca igual que no ponerla.
            """)
        // Antes del umbral esta línea decía `#expect(summary.amountsAreApproximate)`: con el OR,
        // cualquier aproximación marcaba el neto. Con el criterio del 2026-09-08 el neto son 4.900 y
        // la incertidumbre 100 —un 2 %—, así que NO se marca, que es exactamente lo que se decidió.
        // El caso contrario (neto pequeño entre dos lados grandes) lo cubre
        // `cashFlow_smallNet_betweenTwoLargeSides_marks`.
        #expect(!summary.amountsAreApproximate, """
            100 de incertidumbre sobre un neto de 4.900 es un 2 %: por debajo del umbral. Marcarlo
            sería volver al «≈» que sale siempre.
            """)
    }

    @Test("Un ingreso aproximado no marca el total de gastos")
    func cashFlow_approximateIncome_doesNotMarkExpense() {
        let account = makeAccount()
        let interval = monthInterval(2026, 4)
        let ingreso = makeStoredTx(
            amount: 5000, date: day(2026, 4, 3),
            account: account, category: makeCategory(isIncome: true), provisional: true
        )
        let gasto = makeStoredTx(
            amount: -100, date: day(2026, 4, 5),
            account: account, category: makeCategory(), provisional: false
        )

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: [ingreso, gasto], interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(summary.incomeAmountsAreApproximate)
        #expect(!summary.expenseAmountsAreApproximate)
    }

    /// Su gemelo en el Panel: en modo Solo Gastos el número grande es `expense`, y un ingreso
    /// antiguo con tasa aproximada no debe ensuciarlo.
    @Test("En el hero del Panel, un ingreso aproximado no marca el gasto")
    func heroBuckets_approximateIncome_doesNotMarkExpense() {
        let account = makeAccount()
        let period = monthInterval(2026, 4)
        let ingreso = makeStoredTx(
            amount: 5000, date: day(2026, 4, 3),
            account: account, category: makeCategory(isIncome: true), provisional: true
        )
        let gasto = makeStoredTx(
            amount: -100, date: day(2026, 4, 5),
            account: account, category: makeCategory(), provisional: false
        )

        let buckets = HeroBucketsCalculator.calculate(
            transactions: [ingreso, gasto],
            monthInterval: period,
            prevInterval: monthInterval(2026, 3),
            periodInterval: period,
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )

        #expect(buckets.periodIncomeApproximate)
        #expect(!buckets.periodExpenseApproximate)
    }

    // MARK: - Rama convertida · la calidad del converter

    @Test("Una conversión en vivo con tasa inexacta marca el total")
    func cashFlow_inexactConversion_marksTheTotal() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        // `preferredCurrencyCode` ≠ divisa pedida ⇒ el cálculo NO puede usar el monto guardado y
        // tiene que convertir, que es la rama donde manda la calidad del converter.
        let tx = makeStoredTx(
            amount: -100, date: day(2026, 4, 10),
            account: account, category: category, provisional: false
        )

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: [tx], interval: interval, grouping: .day,
            currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .staticFallback)
        )

        #expect(summary.amountsAreApproximate, """
            La transacción está sellada como exacta, pero el total se pidió en otra divisa y esa
            conversión salió de la tabla estática. La marca tiene que venir del converter aquí.
            """)
    }

    @Test("Conversión en vivo con tasa exacta no marca")
    func cashFlow_exactConversion_hasNoMark() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        let tx = makeStoredTx(
            amount: -100, date: day(2026, 4, 10),
            account: account, category: category, provisional: false
        )

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: [tx], interval: interval, grouping: .day,
            currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .exact)
        )

        #expect(!summary.amountsAreApproximate)
    }

    // MARK: - El hero del Panel

    @Test("El bucket de período del Panel hereda el flag de sus transacciones")
    func heroBuckets_provisionalTxInPeriod_marksThePeriod() {
        let account = makeAccount()
        let category = makeCategory()
        let period = monthInterval(2026, 4)
        let tx = makeStoredTx(
            amount: -100, date: day(2026, 4, 10),
            account: account, category: category, provisional: true
        )

        let buckets = HeroBucketsCalculator.calculate(
            transactions: [tx],
            monthInterval: period,
            prevInterval: monthInterval(2026, 3),
            periodInterval: period,
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )

        #expect(buckets.periodExpenseApproximate)
    }

    /// La marca es del bucket que se PINTA. Una transacción aproximada fuera del período elegido no
    /// tiene por qué ensuciar un número que no la incluye — si no, cambiar de período no apagaría
    /// nunca la marca y dejaría de significar nada.
    @Test("Una transacción aproximada FUERA del período no marca")
    func heroBuckets_provisionalTxOutsidePeriod_doesNotMark() {
        let account = makeAccount()
        let category = makeCategory()
        let tx = makeStoredTx(
            amount: -100, date: day(2026, 3, 10),
            account: account, category: category, provisional: true
        )

        let buckets = HeroBucketsCalculator.calculate(
            transactions: [tx],
            monthInterval: monthInterval(2026, 4),
            prevInterval: monthInterval(2026, 3),
            periodInterval: monthInterval(2026, 4),
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )

        #expect(!buckets.periodExpenseApproximate)
    }

    // MARK: - El saldo vivo

    /// Este saldo usa el TC de HOY, así que aquí no hay monto guardado en el que apoyarse: la única
    /// fuente de la marca es la calidad que devuelve el converter.
    @Test("El saldo vivo marca cuando la tasa de hoy no es exacta")
    func liveBalance_inexactRate_marksTheTotal() {
        let account = makeAccount()
        let category = makeCategory()
        let tx = makeStoredTx(
            amount: 100, date: day(2026, 4, 10),
            account: account, category: category, provisional: false
        )
        tx.account = account

        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [account],
            transactions: [tx],
            preferredCurrencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .carriedForward(fromDateKey: "2026-04-09"))
        )

        #expect(breakdown.amountsAreApproximate)
    }

    @Test("El saldo vivo no marca con tasa exacta")
    func liveBalance_exactRate_hasNoMark() {
        let account = makeAccount()
        let category = makeCategory()
        let tx = makeStoredTx(
            amount: 100, date: day(2026, 4, 10),
            account: account, category: category, provisional: false
        )
        tx.account = account

        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [account],
            transactions: [tx],
            preferredCurrencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .exact)
        )

        #expect(!breakdown.amountsAreApproximate)
    }

    /// Un usuario monomoneda —la inmensa mayoría— no debe ver nunca la marca: con la divisa de
    /// destino igual a la nativa **no se llama al converter**, así que no hay conversión que pueda
    /// ser aproximada. Lo que fija este test es ese cortocircuito, no el comportamiento del
    /// converter (la calidad que declare el doble aquí es inerte, y por eso no se le pone ninguna
    /// llamativa: prometería cubrir algo que no cubre). Sin él, un `return true` descuidado le
    /// pondría «≈» permanente a la pantalla principal de todo el mundo.
    @Test("Monomoneda: no se convierte nada, así que no hay marca")
    func liveBalance_singleCurrency_neverMarks() {
        let account = makeAccount()
        let category = makeCategory()
        let tx = makeStoredTx(
            amount: 100, date: day(2026, 4, 10),
            account: account, category: category, provisional: false
        )
        tx.account = account

        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [account],
            transactions: [tx],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 3.75)
        )

        #expect(!breakdown.amountsAreApproximate)
    }

    // MARK: - El umbral: la marca hay que ganársela (decisión 2026-09-08)

    /// **Este es el test que demuestra el cambio, y el único.** Con el OR anterior salía marcado;
    /// con el umbral no. Los demás de este fichero pasan con los dos criterios porque usan importes
    /// iguales, donde una de seis ya pesa un 16,7 %.
    ///
    /// El caso es el del ticket: un usuario multidivisa edita la nota de una transacción vieja de 5
    /// —cuya fila de tasas es parcial— y el mes entero, de 1.000, se le queda con «≈».
    @Test("Una aproximada que no pesa NO marca el total del período")
    func cashFlow_oneTinyProvisionalAmongMany_doesNotMark() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        // 5 de 1.005 = 0,5 % ⇒ por debajo del 5 %.
        var txs = [makeStoredTx(
            amount: -5, date: day(2026, 4, 1),
            account: account, category: category, provisional: true
        )]
        txs += (2...6).map {
            makeStoredTx(amount: -200, date: day(2026, 4, $0), account: account, category: category, provisional: false)
        }

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(!summary.expenseAmountsAreApproximate, """
            Marcar de más erosiona la marca igual que no ponerla: si el «≈» sale casi siempre, el
            usuario aprende a ignorarlo. 0,5 % del mes no cambia lo que ese número le dice.
            """)
    }

    @Test("La misma aproximada, cuando SÍ pesa, marca")
    func cashFlow_provisionalOverThreshold_marks() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        // 100 de 1.100 = 9,1 % ⇒ por encima del 5 %.
        var txs = [makeStoredTx(
            amount: -100, date: day(2026, 4, 1),
            account: account, category: category, provisional: true
        )]
        txs += (2...6).map {
            makeStoredTx(amount: -200, date: day(2026, 4, $0), account: account, category: category, provisional: false)
        }

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(summary.expenseAmountsAreApproximate)
    }

    /// El gemelo para el hero del Panel, que es el número grande del ticket.
    @Test("En el hero, una aproximada que no pesa NO marca el mes")
    func heroBuckets_tinyProvisional_doesNotMark() {
        let account = makeAccount()
        let category = makeCategory()
        let period = monthInterval(2026, 4)
        var txs = [makeStoredTx(
            amount: -5, date: day(2026, 4, 1),
            account: account, category: category, provisional: true
        )]
        txs += (2...6).map {
            makeStoredTx(amount: -200, date: day(2026, 4, $0), account: account, category: category, provisional: false)
        }

        let buckets = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: period,
            prevInterval: monthInterval(2026, 3),
            periodInterval: period,
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )

        #expect(!buckets.periodExpenseApproximate)
        #expect(!buckets.periodIncomeApproximate)
    }

    // MARK: - Los bordes del umbral, en la unidad donde se decide

    @Test("Sin nada aproximado no se marca, ni siquiera con el total en cero")
    func threshold_noApproximate_neverMarks() {
        #expect(!ApproximateMarkThreshold.marks(approximate: 0, total: 1000))
        // El caso que blinda al usuario monomoneda: total cero Y aproximado cero. Si el orden de las
        // guardas se invirtiera, éste caería en «denominador inservible» y marcaría un número en el
        // que no hubo ninguna conversión.
        #expect(!ApproximateMarkThreshold.marks(approximate: 0, total: 0))
    }

    @Test("Con el denominador en cero se marca: no se puede medir la proporción, así que se avisa")
    func threshold_zeroDenominator_marks() {
        // Pasa de verdad: los totales se acumulan CON SIGNO, así que un reembolso que cancela su
        // gasto deja el lado en ~0 con transacciones dentro.
        #expect(ApproximateMarkThreshold.marks(approximate: 50, total: 0))
        #expect(ApproximateMarkThreshold.marks(approximate: 50, total: 0.001))
    }

    @Test("El umbral es inclusivo y decide sobre magnitudes")
    func threshold_boundaryAndSign() {
        #expect(ApproximateMarkThreshold.marks(approximate: 50, total: 1000))    // 5,0 % → marca
        #expect(!ApproximateMarkThreshold.marks(approximate: 49, total: 1000))   // 4,9 % → no
        // El signo no decide nada **a propósito**: los dos argumentos son magnitudes sumadas, y el
        // caller es responsable de acumularlas así. Un neto puede llegar negativo (mes en rojo) y no
        // cambia la respuesta.
        #expect(ApproximateMarkThreshold.marks(approximate: -50, total: -1000))
        #expect(ApproximateMarkThreshold.marks(approximate: 50, total: -1000))
    }

    @Test("Un 5 % exacto marca aunque la división en coma flotante diga que no llega")
    func threshold_inclusiveBoundary_survivesFloatingPoint() {
        // `0.15 / 3.0` = 0.049999999999999996 en `Double`: con un cociente, este caso NO marcaría
        // pese a ser exactamente el 5 %. Por eso la comparación es una multiplicación.
        #expect(ApproximateMarkThreshold.marks(approximate: 0.15, total: 3.0))
    }

    @Test("El numerador también tiene suelo: un residuo de coma flotante no marca")
    func threshold_numeratorNoiseFloor() {
        // Sin suelo en el numerador, una cancelación que deja 1e-15 pasaría un `> 0`, caería en la
        // guarda del denominador y marcaría; la misma cancelación exacta no. Dos respuestas para el
        // mismo caso de usuario según cómo cayeran los decimales.
        #expect(!ApproximateMarkThreshold.marks(approximate: 1e-15, total: 0))
        #expect(!ApproximateMarkThreshold.marks(approximate: 0.001, total: 1000))
    }

    // MARK: - Lo que cazó la review adversarial antes de mergear (2026-09-08)

    /// **La regresión más cara de este cambio, y no la vio ningún test hasta que se escribió éste.**
    ///
    /// Con umbrales por lado y el neto compuesto como `income || expense`, dos lados grandes cada uno
    /// por debajo del 5 % dejaban el «Disponible» **sin marca**, aunque la incertidumbre fuera
    /// muchísimo mayor que el propio número. Con el OR anterior sí salía marcado: era una regresión.
    @Test("Dos lados bajo el umbral con un neto pequeño SÍ marcan el disponible")
    func cashFlow_smallNet_betweenTwoLargeSides_marks() {
        let account = makeAccount()
        let income = makeCategory(isIncome: true)
        let expense = makeCategory()
        let interval = monthInterval(2026, 4)

        // Ingreso 1.000.000 con 49.000 aproximados = 4,9 % ⇒ el lado no marca.
        var txs = [makeStoredTx(amount: 49_000, date: day(2026, 4, 1),
                                account: account, category: income, provisional: true)]
        txs.append(makeStoredTx(amount: 951_000, date: day(2026, 4, 2),
                                account: account, category: income, provisional: false))
        // Gasto 999.000 exacto ⇒ el lado no marca. Neto = 1.000.
        txs.append(makeStoredTx(amount: -999_000, date: day(2026, 4, 3),
                                account: account, category: expense, provisional: false))

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(!summary.incomeAmountsAreApproximate, "4,9 % del ingreso no llega al umbral")
        #expect(!summary.expenseAmountsAreApproximate, "el gasto es exacto")
        #expect(summary.amountsAreApproximate, """
            El «Disponible» son 1.000 y la incertidumbre 49.000: 49 veces el número que se muestra.
            Es el caso donde la marca más falta, y el OR de los dos lados la apagaba.
            """)
    }

    /// Dos aproximaciones opuestas **no se cancelan**: la incertidumbre se suma.
    @Test("Un gasto aproximado y su reembolso aproximado marcan, aunque el neto quede en cero")
    func cashFlow_approximateRefundCancelsTotal_stillMarks() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        let txs = [
            makeStoredTx(amount: -200, date: day(2026, 4, 1),
                         account: account, category: category, provisional: true),
            // El reembolso también salió de una tasa dudosa.
            makeStoredTx(amount: 200, date: day(2026, 4, 2),
                         account: account, category: category, provisional: true),
        ]

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(summary.expenseAmountsAreApproximate, """
            Con numerador y denominador acumulados CON SIGNO, éste salía sin marcar: 0/0. Y peor —
            si el reembolso hubiera sido exacto SÍ marcaba, así que la respuesta dependía de a cuál
            de las dos transacciones le tocó el flag. Indefendible de cara al usuario.
            """)
    }

    @Test("La incertidumbre no se cancela: 1.000 aprox y 900 aprox pesan 1.900, no 100")
    func cashFlow_oppositeApproximations_doNotNetOut() {
        let account = makeAccount()
        let category = makeCategory()
        let interval = monthInterval(2026, 4)
        var txs = [
            makeStoredTx(amount: -1000, date: day(2026, 4, 1),
                         account: account, category: category, provisional: true),
            makeStoredTx(amount: 900, date: day(2026, 4, 2),
                         account: account, category: category, provisional: true),
        ]
        // Y mucho gasto exacto alrededor, para que un numerador con signo (100) quedara por debajo
        // del 5 % y uno honesto (1.900) lo supere.
        txs += (3...6).map {
            makeStoredTx(amount: -2000, date: day(2026, 4, $0), account: account, category: category, provisional: false)
        }

        let summary = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(summary.expenseAmountsAreApproximate, """
            Es la misma conclusión de `FXPnLLogic` con su `exposedBase = Σ|costBasis|`: los errores
            de dos conversiones distintas no se restan entre sí.
            """)
    }

    @Test("El hero también marca el disponible cuando el neto es pequeño entre dos lados grandes")
    func heroBuckets_smallNet_marksAvailable() {
        let account = makeAccount()
        let income = makeCategory(isIncome: true)
        let expense = makeCategory()
        let period = monthInterval(2026, 4)

        var txs = [makeStoredTx(amount: 49_000, date: day(2026, 4, 1),
                                account: account, category: income, provisional: true)]
        txs.append(makeStoredTx(amount: 951_000, date: day(2026, 4, 2),
                                account: account, category: income, provisional: false))
        txs.append(makeStoredTx(amount: -999_000, date: day(2026, 4, 3),
                                account: account, category: expense, provisional: false))

        let buckets = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: period,
            prevInterval: monthInterval(2026, 3),
            periodInterval: period,
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )

        #expect(!buckets.periodIncomeApproximate)
        #expect(!buckets.periodExpenseApproximate)
        #expect(buckets.periodNetApproximate, "«Disponible» = 1.000 con 49.000 de incertidumbre")
    }

}

//
//  MARK: - Productores nuevos (`fx-approximate-mark-missing-on-secondary-surfaces`, 2026-09-09)
//
//  Dos superficies secundarias no tenían señal que cablear: había que PRODUCIRLA. Estos son tests
//  de comportamiento, no de cableado — el source-scan de `ApproximateMarkWiringTests` fija el texto,
//  esto fija el resultado.
//

@MainActor
@Suite("Marca de aproximado: los productores que no existían")
struct ApproximateMarkNewProducersTests {

    private let calendar = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    private func makeStoredTx(
        amount: Double,
        date: Date,
        account: Account,
        category: YalaCategory,
        provisional: Bool
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date, amount: amount, currencyCode: "USD", note: "",
            category: category, account: account, tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.isExchangeRateProvisional = provisional
        return tx
    }

    // MARK: - El widget de la pantalla de inicio

    /// El widget no convierte: copia montos ya sellados. Su única vía es el flag de la transacción,
    /// y hasta hoy no lo miraba nadie.
    @Test("El resumen del widget marca el gasto cuando la parte aproximada pesa")
    func widgetSummary_marksExpenseWhenApproximateWeighs() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let category = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let start = day(2026, 4, 1)
        let end = day(2026, 4, 30)

        let txs = [
            makeStoredTx(amount: -300, date: day(2026, 4, 5), account: account, category: category, provisional: true),
            makeStoredTx(amount: -700, date: day(2026, 4, 6), account: account, category: category, provisional: false),
        ]

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: start, periodEnd: end, currencyCode: "USD"
        )

        #expect(summary.expenseIsApproximate == true, """
            300 de 1.000 es el 30 %, muy por encima del 5 %: el gasto del widget se marca.
            """)
        #expect(summary.incomeIsApproximate == false, """
            No hubo ni un ingreso. Marcarlo diría que un total de cero es aproximado.
            """)
    }

    /// El control positivo, sin el cual «marcar siempre» pasaría el test de arriba.
    @Test("Con todo exacto, el resumen del widget no marca nada")
    func widgetSummary_allExact_marksNothing() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let expense = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let income = YalaCategory(name: "Salary", colorHex: "#00FF00", isIncome: true)

        let txs = [
            makeStoredTx(amount: -300, date: day(2026, 4, 5), account: account, category: expense, provisional: false),
            makeStoredTx(amount: 900, date: day(2026, 4, 6), account: account, category: income, provisional: false),
        ]

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: day(2026, 4, 1), periodEnd: day(2026, 4, 30),
            currencyCode: "USD"
        )

        #expect(summary.expenseIsApproximate == false)
        #expect(summary.incomeIsApproximate == false)
        #expect(summary.netCashFlowIsApproximate == false)
    }

    /// El umbral tiene que ser el MISMO que el de la app, no un `> 0` disfrazado.
    @Test("Una aproximada que no pesa NO marca el gasto del widget")
    func widgetSummary_belowThreshold_doesNotMark() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let category = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)

        var txs = [makeStoredTx(amount: -40, date: day(2026, 4, 5), account: account, category: category, provisional: true)]
        // 40 de 1.040 es el 3,8 %: por debajo del 5 %.
        txs.append(makeStoredTx(amount: -1000, date: day(2026, 4, 6), account: account, category: category, provisional: false))

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: day(2026, 4, 1), periodEnd: day(2026, 4, 30),
            currencyCode: "USD"
        )

        #expect(summary.expenseIsApproximate == false, """
            Con un OR simple esto marcaría. La decisión del 2026-09-08 pide que PESE, y el widget
            tiene que usar el mismo criterio o el mismo mes sale marcado en una pantalla y exacto en
            la otra.
            """)
    }

    /// El saldo del período es el número del `BalanceWidget`, y su bucle es otro.
    @Test("El saldo del período del widget lleva su propia marca")
    func widgetSummary_periodBalanceCarriesItsOwnMark() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let category = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)

        // Fuera del período (no tocan income/expense) pero SÍ dentro del saldo acumulado.
        let historicas = [
            makeStoredTx(amount: -500, date: day(2026, 2, 3), account: account, category: category, provisional: true),
            makeStoredTx(amount: -500, date: day(2026, 2, 4), account: account, category: category, provisional: false),
        ]

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [], periodStart: day(2026, 4, 1), periodEnd: day(2026, 4, 30),
            currencyCode: "USD", allTransactionsForBalance: historicas
        )

        #expect(summary.periodBalanceIsApproximate == true, """
            El saldo acumula TODO el histórico, no solo el período: su marca sale de ese recorrido y
            no de los totales del mes, que aquí están vacíos.
            """)
        #expect(summary.expenseIsApproximate == false, """
            Y al revés: ninguna de esas dos cae en el período, así que el gasto del mes no se marca.
            Si esto sale `true`, los dos bucles se están pisando.
            """)
    }

    /// **El caso que separa el denominador bueno del malo, y por eso existe.** El test de arriba
    /// (−500 dudosa y −500 exacta) da 50 % por las DOS reglas: pasaba igual con el denominador mal
    /// puesto. Éste no: la review adversarial del 2026-09-09 encontró que `periodBalanceIsApproximate`
    /// dividía entre `Σ|monto|` —la facturación bruta— en vez de entre el saldo, y la marca se perdía
    /// justo en quien más historial tiene.
    @Test("El saldo del widget se mide contra el SALDO, no contra la facturación que lo formó")
    func widgetSummary_periodBalanceDividesByTheBalance() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let gasto = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let ingreso = YalaCategory(name: "Salary", colorHex: "#00FF00", isIncome: true)

        // Movimientos que casi se cancelan: entra 60.500 y sale 60.000, así que el saldo es 500.
        // De lo que salió, 400 se convirtió con una tasa que no era la de su día.
        let historicas = [
            makeStoredTx(amount: 60_500, date: day(2026, 1, 5), account: account, category: ingreso, provisional: false),
            makeStoredTx(amount: -59_600, date: day(2026, 1, 6), account: account, category: gasto, provisional: false),
            makeStoredTx(amount: -400, date: day(2026, 1, 7), account: account, category: gasto, provisional: true),
        ]

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [], periodStart: day(2026, 4, 1), periodEnd: day(2026, 4, 30),
            currencyCode: "USD", allTransactionsForBalance: historicas
        )

        #expect(summary.periodBalance == 500)
        #expect(summary.periodBalanceIsApproximate == true, """
            400 sobre el saldo de 500 es el 80 %: la marca tiene que salir. Sobre la facturación
            bruta (120.500) sería el 0,33 % y el widget afirmaría «500» exacto, cuando cuatro
            quintas partes de ese número salieron de una tasa dudosa.
            """)
    }

    @Test("Sin histórico no hay saldo y por tanto tampoco marca")
    func widgetSummary_noBalanceMeansNoMark() {
        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [], periodStart: day(2026, 4, 1), periodEnd: day(2026, 4, 30),
            currencyCode: "USD"
        )
        #expect(summary.periodBalance == nil)
        #expect(summary.periodBalanceIsApproximate == false)
    }

    // MARK: - El carril del saldo vivo hasta la hoja educativa

    /// El source-scan fija que cada salto existe; esto fija que el valor llega de verdad.
    @Test("La señal del saldo vivo llega al resultado del processor")
    func liveAnchorSignalReachesTheProcessorResult() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let category = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let hoy = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: calendar.date(byAdding: .day, value: -2, to: hoy) ?? hoy,
            end: calendar.date(byAdding: .day, value: 1, to: hoy) ?? hoy
        )
        let tx = makeStoredTx(
            amount: -100, date: calendar.date(byAdding: .day, value: -1, to: hoy) ?? hoy,
            account: account, category: category, provisional: false
        )

        for aproximado in [true, false] {
            let result = TrendDataProcessor.processTrendData(
                transactions: [tx], accounts: [], metric: .balance,
                period: .thisMonth, grouping: .day, interval: interval, currencyCode: "USD",
                liveBalanceOverride: .init(
                    value: 1234, nativeBalances: [:], amountsAreApproximate: aproximado
                )
            )
            #expect(result.liveAnchorIsApproximate == aproximado, """
                El processor tiene que reenviar la señal tal cual; con `aproximado == \(aproximado)`
                devolvió \(result.liveAnchorIsApproximate).
                """)
        }
    }

    /// Sin anchor no puede quedar una marca huérfana de su número.
    @Test("Sin saldo vivo, la señal del anchor es false")
    func noLiveAnchorMeansNoMark() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let category = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let interval = DateInterval(start: day(2026, 2, 1), end: day(2026, 2, 28))
        let tx = makeStoredTx(
            amount: -100, date: day(2026, 2, 10), account: account, category: category, provisional: true
        )

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx], accounts: [], metric: .balance,
            period: .lastMonth, grouping: .day, interval: interval, currencyCode: "USD",
            liveBalanceOverride: nil
        )

        #expect(result.liveAnchor == nil)
        #expect(!result.liveAnchorIsApproximate)
    }

    // MARK: - El KPI de Distribución

    /// El régimen vivo sí sabe; el cerrado no, y devolver `false` ahí dice «no lo sé».
    @Test("El KPI de Balance marca en el régimen vivo y no en el cerrado")
    func balanceKPIMarksOnlyTheLiveRegime() {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let category = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let hoy = calendar.startOfDay(for: Date())

        // Una cuenta en EUR con el converter en modo inexacto: la conversión de HOY es aproximada.
        let tx = TransactionItem(
            date: calendar.date(byAdding: .day, value: -1, to: hoy) ?? hoy,
            amount: -100, currencyCode: "EUR", note: "",
            category: category, account: account, tags: [], amountInPreferredCurrency: -100
        )
        tx.preferredCurrencyCode = "USD"

        let converter = MockCurrencyConverter(
            fixedRate: 1.1, quality: .carriedForward(fromDateKey: "2026-04-09")
        )

        let vivo = BalanceKPICalculator.result(
            transactions: [tx], accounts: [account],
            interval: DateInterval(
                start: calendar.date(byAdding: .day, value: -3, to: hoy) ?? hoy,
                end: calendar.date(byAdding: .day, value: 1, to: hoy) ?? hoy
            ),
            period: .thisMonth, currencyCode: "USD", converter: converter
        )
        #expect(vivo.isApproximate, """
            El período cubre hoy ⇒ saldo vivo ⇒ el `Breakdown` sabe que la tasa de hoy no era exacta.
            """)

        // La transacción va DENTRO del intervalo cerrado a propósito: con `hasDataInPeriod == false`
        // el calculador sale por el camino «sin datos», que devuelve el mismo `false` por otra vía y
        // haría que esta aserción se cumpliera sin haber pisado el régimen cerrado. Lo señaló la
        // review adversarial del 2026-09-09.
        let txCerrada = TransactionItem(
            date: day(2026, 1, 15), amount: -100, currencyCode: "EUR", note: "",
            category: category, account: account, tags: [], amountInPreferredCurrency: -100
        )
        txCerrada.preferredCurrencyCode = "USD"

        let cerrado = BalanceKPICalculator.result(
            transactions: [txCerrada], accounts: [account],
            interval: DateInterval(start: day(2026, 1, 1), end: day(2026, 1, 31)),
            period: .lastMonth, currencyCode: "USD", converter: converter
        )
        #expect(cerrado.hasDataInPeriod, """
            CONTROL DEL ESCENARIO: sin esto, el caso de abajo pasaría por «sin datos» y no por el
            régimen cerrado, que es lo que dice medir.
            """)
        #expect(!cerrado.isApproximate, """
            El período cerrado lee la curva histórica, que no acumula calidad de conversión. `false`
            aquí es un PIN del literal, no una red: lo que fija es que nadie lo cablee a la señal del
            saldo vivo, que describiría otro número. Producir la de verdad es
            `fx-historical-balance-curve-unmarked`.
            """)
    }
}

//
//  MARK: - El productor de Registros (review adversarial del 2026-09-09)
//
//  Se añade porque la primera versión de este trabajo dejó `RecordsViewModel.calculateSummary` —un
//  productor NUEVO, con acumuladores por lado y su propio cociente para el neto— cubierto solo por un
//  source-scan de la VISTA. Intercambiar los acumuladores de ingreso y gasto, o cambiar el neto por
//  un OR, no ponía nada en rojo.
//
//  Va por el camino real (`applyFilters`), no llamando al privado: es lo que la pantalla ejecuta.
//

@MainActor
@Suite("Marca de aproximado · el resumen de Registros", .serialized)
struct RecordsSummaryApproximateMarkTests {

    /// `period` vive en `SessionState.shared`. Se fija a `.allTime` para que el intervalo no dependa
    /// de la fecha de hoy, y se restaura: es estado global.
    private func conPeriodoCompleto(_ cuerpo: () throws -> Void) rethrows {
        let anterior = SessionState.shared.selectedPeriod
        SessionState.shared.selectedPeriod = .allTime
        defer { SessionState.shared.selectedPeriod = anterior }
        try cuerpo()
    }

    private func makeTx(
        amount: Double, date: Date, account: Account, category: YalaCategory,
        provisional: Bool, context: ModelContext
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date, amount: amount, currencyCode: account.currencyCode, note: "",
            category: category, account: account, tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = account.currencyCode
        tx.isExchangeRateProvisional = provisional
        context.insert(tx)
        return tx
    }

    private func resumen(
        _ txs: [TransactionItem], _ accounts: [Account], _ context: ModelContext
    ) -> RecordsViewModel.RecordsSummary {
        let vm = RecordsViewModel()
        vm.applyFilters(
            transactions: txs, accounts: accounts, categories: [], tags: [], context: context,
            currencyCode: "PEN"
        )
        return vm.recordsSummary
    }

    /// **La marca va por LADO, y este caso lo demuestra en las dos direcciones a la vez.** Con los
    /// acumuladores intercambiados, las dos aserciones se invierten y el test se pone rojo — que es
    /// lo que un source-scan de la vista no puede detectar.
    @Test("Un gasto aproximado marca el gasto y NO el ingreso")
    func approximateExpenseMarksOnlyTheExpenseSide() throws {
        try conPeriodoCompleto {
            let context = try makeTestContext()
            let account = makeTestAccount(context: context, name: "Diaria", currencyCode: "PEN")
            let gasto = makeTestCategory(context: context, name: "Comida", isIncome: false)
            let ingreso = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
            let hoy = Date()

            let txs = [
                makeTx(amount: -400, date: hoy, account: account, category: gasto,
                       provisional: true, context: context),
                makeTx(amount: -600, date: hoy, account: account, category: gasto,
                       provisional: false, context: context),
                makeTx(amount: 5_000, date: hoy, account: account, category: ingreso,
                       provisional: false, context: context),
            ]
            try context.save()

            let s = resumen(txs, [account], context)

            #expect(s.expenseIsApproximate, """
                400 de 1.000 es el 40 %: el gasto se marca.
                """)
            #expect(!s.incomeIsApproximate, """
                El ingreso no tuvo ni una conversión dudosa. Si esto sale `true`, los acumuladores
                están cruzados y el usuario ve «≈» sobre un número exacto.
                """)
        }
    }

    @Test("Con todo exacto no se marca ningún lado")
    func allExactMarksNothing() throws {
        try conPeriodoCompleto {
            let context = try makeTestContext()
            let account = makeTestAccount(context: context, name: "Diaria", currencyCode: "PEN")
            let gasto = makeTestCategory(context: context, name: "Comida", isIncome: false)
            let ingreso = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
            let hoy = Date()

            let txs = [
                makeTx(amount: -1_000, date: hoy, account: account, category: gasto,
                       provisional: false, context: context),
                makeTx(amount: 5_000, date: hoy, account: account, category: ingreso,
                       provisional: false, context: context),
            ]
            try context.save()

            let s = resumen(txs, [account], context)

            #expect(!s.expenseIsApproximate)
            #expect(!s.incomeIsApproximate)
            #expect(!s.balanceIsApproximate)
        }
    }

    /// El umbral, no un OR. Sin esto, `magnitude > 0` pasaría los dos tests de arriba.
    @Test("Una aproximada que no pesa NO marca el gasto")
    func tinyApproximateDoesNotMark() throws {
        try conPeriodoCompleto {
            let context = try makeTestContext()
            let account = makeTestAccount(context: context, name: "Diaria", currencyCode: "PEN")
            let gasto = makeTestCategory(context: context, name: "Comida", isIncome: false)
            let hoy = Date()

            let txs = [
                makeTx(amount: -5, date: hoy, account: account, category: gasto,
                       provisional: true, context: context),
                makeTx(amount: -1_000, date: hoy, account: account, category: gasto,
                       provisional: false, context: context),
            ]
            try context.save()

            #expect(!resumen(txs, [account], context).expenseIsApproximate, """
                5 de 1.005 es el 0,5 %, por debajo del 5 % que decidió el owner el 2026-09-08. Con un
                OR esto marcaría, y una marca que sale siempre deja de significar nada.
                """)
        }
    }

    /// **El neto necesita su propio cociente y NO el OR de los dos lados.** Es el caso que la review
    /// adversarial del ticket anterior cazó en `CashFlowCalculator` antes de mergear, replicado aquí
    /// porque `calculateSummary` reimplementa la misma regla.
    @Test("Dos lados bajo el umbral con un saldo pequeño SÍ marcan el saldo")
    func smallBalanceBetweenTwoBigSidesMarks() throws {
        try conPeriodoCompleto {
            let context = try makeTestContext()
            let account = makeTestAccount(context: context, name: "Diaria", currencyCode: "PEN")
            let gasto = makeTestCategory(context: context, name: "Comida", isIncome: false)
            let ingreso = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
            let hoy = Date()

            // Ingreso 1.000.000 con 49.000 dudosos → 4,9 %, no marca su lado.
            // Gasto 999.000 exacto → no marca su lado.
            // Saldo mostrado: 1.000, con 49.000 de incertidumbre encima.
            let txs = [
                makeTx(amount: 49_000, date: hoy, account: account, category: ingreso,
                       provisional: true, context: context),
                makeTx(amount: 951_000, date: hoy, account: account, category: ingreso,
                       provisional: false, context: context),
                makeTx(amount: -999_000, date: hoy, account: account, category: gasto,
                       provisional: false, context: context),
            ]
            try context.save()

            let s = resumen(txs, [account], context)

            #expect(s.balance == 1_000)
            #expect(!s.incomeIsApproximate, "49.000 de 1.000.000 es el 4,9 %: su lado no marca")
            #expect(!s.expenseIsApproximate, "el gasto es exacto")
            #expect(s.balanceIsApproximate, """
                Y aun así el saldo SÍ marca: su incertidumbre es 49 veces el número que se enseña.
                Con el OR de los dos lados este número saldría limpio precisamente cuando menos lo
                está.
                """)
        }
    }
}
