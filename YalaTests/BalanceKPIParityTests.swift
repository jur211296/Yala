//
//  BalanceKPIParityTests.swift
//  YalaTests
//
//  Fija que el KPI de Balance de Distribución es EL MISMO número que el del
//  Panel, y que no vuelve a ser el flujo del período.
//
//  El bug de origen (device-QA del owner, TF 2.1 build 12, cuenta multi-moneda):
//  la misma selección de filtros mostraba dos cifras distintas. Distribución sí
//  convertía divisas — la hipótesis "se salta el FX" era falsa— pero convertía
//  con el TC del DÍA DE CADA TRANSACCIÓN y sumaba el gasto del período (flujo),
//  mientras el Panel mostraba el saldo de HOY al TC ACTUAL (stock).
//
//  Por eso el caso central es multi-moneda con el TC actual distinto del
//  histórico: con un solo tipo de cambio los dos caminos dan el mismo número y
//  el test pasaría sin probar nada.
//
//  Sin ModelContext: fixtures locales + MockCurrencyConverter.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct BalanceKPIParityTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeAccount(
        name: String = "Main",
        currencyCode: String = "PEN",
        excludeFromStatistics: Bool = false
    ) -> Account {
        Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank",
            excludeFromStatistics: excludeFromStatistics
        )
    }

    /// `amountInPreferredCurrency` es el snapshot HISTÓRICO (lo que valía el día
    /// de la transacción). Separarlo de `amount` es lo que hace visible la
    /// diferencia entre stock (TC actual) y flujo (TC del día).
    private func makeTransaction(
        amount: Double,
        currencyCode: String = "PEN",
        date: Date = Date(),
        account: Account? = nil,
        category: YalaCategory? = nil,
        amountInPreferredCurrency: Double? = nil,
        preferredCurrencyCode: String = "PEN"
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            account: account,
            tags: [],
            amountInPreferredCurrency: amountInPreferredCurrency ?? amount,
            preferredCurrencyCode: preferredCurrencyCode
        )
        return tx
    }

    /// Réplica del cálculo del Panel, tal cual lo hace `PanelViewModel` al
    /// alimentar el KPI del widget de tendencia: override de saldo vivo +
    /// `TrendDataProcessor.finalBalance`. Si `BalanceKPICalculator` diverge de
    /// esto, el bug ha vuelto.
    private func panelBalanceKPI(
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        period: DetailPeriod,
        currencyCode: String,
        converter: CurrencyConverting
    ) -> Double {
        let override = LiveBalanceCalculator.liveBalanceOverride(
            for: .balance,
            interval: interval,
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            converter: converter
        )
        return TrendDataProcessor.processTrendData(
            transactions: transactions,
            accounts: accounts,
            metric: .balance,
            period: period,
            grouping: .day,
            interval: interval,
            currencyCode: currencyCode,
            liveBalanceOverride: override,
            // El Panel le pasa a la curva el mismo converter que a la cifra (`calcContext.converter`). Sin él, este
            // espejo convertía con el compartido y solo coincidía mientras la curva no convertía nada.
            converter: converter
        ).finalBalance
    }

    /// 1000 USD comprados a 3,0 (snapshot 3000 PEN) + 1000 PEN.
    /// Con el TC de hoy a 3,5 el saldo vivo son 4500 PEN; la suma de snapshots
    /// históricos son 4000. Los dos números existen y significan cosas distintas.
    private func multiCurrencyFixture(
        date: Date = Date()
    ) -> (accounts: [Account], transactions: [TransactionItem], converter: MockCurrencyConverter) {
        let usdAccount = makeAccount(name: "USD", currencyCode: "USD")
        let penAccount = makeAccount(name: "PEN", currencyCode: "PEN")

        let txUsd = makeTransaction(
            amount: 1000,
            currencyCode: "USD",
            date: date,
            account: usdAccount,
            amountInPreferredCurrency: 3000  // TC histórico 3,0
        )
        let txPen = makeTransaction(
            amount: 1000,
            currencyCode: "PEN",
            date: date,
            account: penAccount,
            amountInPreferredCurrency: 1000
        )

        var converter = MockCurrencyConverter()
        converter.fixedRate = 3.5  // TC de hoy

        return ([usdAccount, penAccount], [txUsd, txPen], converter)
    }

    private var currentPeriodInterval: DateInterval {
        DetailPeriod.thisMonth.dateInterval()
    }

    // MARK: - El caso del owner: multi-moneda, período que cubre hoy

    @Test func balanceKPI_multiCurrency_usesCurrentRate_notHistoricalSnapshot() {
        let fixture = multiCurrencyFixture()

        let kpi = BalanceKPICalculator.value(
            transactions: fixture.transactions,
            accounts: fixture.accounts,
            interval: currentPeriodInterval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: fixture.converter
        )

        // 1000 USD × 3,5 (hoy) + 1000 PEN = 4500 — el stock vivo.
        #expect(kpi == 4500)
        // Y NO 4000, que es lo que daría sumar los snapshots históricos.
        #expect(kpi != 4000)
    }

    @Test func balanceKPI_multiCurrency_matchesPanel() {
        let fixture = multiCurrencyFixture()
        let interval = currentPeriodInterval

        let distribution = BalanceKPICalculator.value(
            transactions: fixture.transactions,
            accounts: fixture.accounts,
            interval: interval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: fixture.converter
        )
        let panel = panelBalanceKPI(
            transactions: fixture.transactions,
            accounts: fixture.accounts,
            interval: interval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: fixture.converter
        )

        #expect(distribution == panel, "Distribución y Panel divergieron: \(distribution) vs \(panel)")
    }

    // MARK: - Paridad con DOS cuentas filtradas

    /// Regla de elegibilidad de `StatisticsViewModel.computeEligibleAccounts`,
    /// que es `private`. El Panel la espeja desde que respeta el conjunto; si
    /// las dos vuelven a divergir, este fichero es donde se ve.
    private func eligibleAccounts(
        _ accounts: [Account],
        selected: Set<PersistentIdentifier>,
        isExcludeMode: Bool = false
    ) -> [Account] {
        accounts.filter { account in
            guard !account.excludeFromStatistics else { return false }
            if selected.isEmpty { return true }
            if isExcludeMode {
                return !selected.contains(account.persistentModelID)
            } else {
                return selected.contains(account.persistentModelID)
            }
        }
    }

    /// El AC del ticket: con dos cuentas seleccionadas, Panel y Distribución
    /// muestran el mismo saldo.
    ///
    /// Los dos caminos son asimétricos a propósito, y esa asimetría era el bug:
    /// el **Panel** recibe TODAS las cuentas más el conjunto filtrado y resuelve
    /// dentro; **Distribución** recibe las cuentas ya filtradas. Antes el Panel
    /// colapsaba el conjunto a `.first` y devolvía el saldo de UNA.
    @Test func twoSelectedAccounts_panelMatchesDistribution() {
        let accA = makeAccount(name: "A", currencyCode: "PEN")
        let accB = makeAccount(name: "B", currencyCode: "PEN")
        let accC = makeAccount(name: "C", currencyCode: "PEN")
        let txA = makeTransaction(amount: 10_000, account: accA, amountInPreferredCurrency: 10_000)
        let txB = makeTransaction(amount: 5_000, account: accB, amountInPreferredCurrency: 5_000)
        let txC = makeTransaction(amount: 777, account: accC, amountInPreferredCurrency: 777)

        let all = [accA, accB, accC]
        let transactions = [txA, txB, txC]
        let selected: Set<PersistentIdentifier> = [accA.persistentModelID, accB.persistentModelID]
        let converter = MockCurrencyConverter()

        // Camino Panel: todas las cuentas + el conjunto.
        let panel = LiveBalanceCalculator.liveBalance(
            accounts: all,
            transactions: transactions,
            preferredCurrencyCode: "PEN",
            selectedAccountIDs: selected,
            converter: converter
        )

        // Camino Distribución: cuentas ya filtradas, sin conjunto.
        let distribution = LiveBalanceCalculator.liveBalance(
            accounts: eligibleAccounts(all, selected: selected),
            transactions: transactions,
            preferredCurrencyCode: "PEN",
            converter: converter
        )

        #expect(panel == distribution, "Panel y Distribución divergieron: \(panel) vs \(distribution)")
        #expect(panel == 15_000)
        // El bug, explícito: 10_000 o 5_000 es el saldo de UNA de las dos.
        #expect(panel != 10_000)
        #expect(panel != 5_000)
    }

    /// Mismo AC en modo excluir, que es el otro camino por el que el conjunto
    /// llega al Panel desde Registros → Filtros.
    @Test func twoExcludedAccounts_panelMatchesDistribution() {
        let accA = makeAccount(name: "A", currencyCode: "PEN")
        let accB = makeAccount(name: "B", currencyCode: "PEN")
        let accC = makeAccount(name: "C", currencyCode: "PEN")
        let txA = makeTransaction(amount: 10_000, account: accA, amountInPreferredCurrency: 10_000)
        let txB = makeTransaction(amount: 5_000, account: accB, amountInPreferredCurrency: 5_000)
        let txC = makeTransaction(amount: 777, account: accC, amountInPreferredCurrency: 777)

        let all = [accA, accB, accC]
        let transactions = [txA, txB, txC]
        let selected: Set<PersistentIdentifier> = [accA.persistentModelID, accB.persistentModelID]
        let converter = MockCurrencyConverter()

        let panel = LiveBalanceCalculator.liveBalance(
            accounts: all,
            transactions: transactions,
            preferredCurrencyCode: "PEN",
            selectedAccountIDs: selected,
            isExcludeMode: true,
            converter: converter
        )
        let distribution = LiveBalanceCalculator.liveBalance(
            accounts: eligibleAccounts(all, selected: selected, isExcludeMode: true),
            transactions: transactions,
            preferredCurrencyCode: "PEN",
            converter: converter
        )

        #expect(panel == distribution, "Panel y Distribución divergieron: \(panel) vs \(distribution)")
        #expect(panel == 777)
    }

    /// El toggle `includeGroupsInPanelTotal` aplica SOLO al total agregado: con
    /// un filtro de cuentas activo —una o varias— no debe recortar nada.
    @Test func includeGroupsToggle_appliesOnlyToAggregateTotal() {
        let normal = makeAccount(name: "Normal", currencyCode: "PEN")
        let groups = makeAccount(name: "Grupos PEN", currencyCode: "PEN")
        groups.isSystemAccount = true

        let all = [normal, groups]

        // Sin filtro: el toggle OFF sí recorta la cuenta sistema.
        let total = PanelTotalAccountsLogic.accountsForTotal(
            all, includeGroups: false, hasSelectedAccount: false
        )
        #expect(total.count == 1)
        #expect(total.first?.name == "Normal")

        // Con dos cuentas filtradas: el toggle no aplica.
        let filtered = PanelTotalAccountsLogic.accountsForTotal(
            all, includeGroups: false, hasSelectedAccount: true
        )
        #expect(filtered.count == 2)
    }

    /// El modo excluir es un AGREGADO: "todas menos éstas". El toggle de grupos
    /// tiene que seguir aplicando.
    ///
    /// Sin esto, excluir una cuenta devolvía al total las cuentas sistema que el
    /// toggle había apagado, y el saldo del Panel **subía** al excluir una cuenta
    /// con saldo positivo. El test de `accountsForTotal` aislado no lo veía: el
    /// defecto estaba en quién calcula el flag, no en la función que lo recibe.
    @Test func excludeMode_isAggregate_soGroupsToggleStillApplies() {
        let normal = makeAccount(name: "Normal", currencyCode: "PEN")
        let groups = makeAccount(name: "Grupos PEN", currencyCode: "PEN")
        groups.isSystemAccount = true
        let other = makeAccount(name: "Otra", currencyCode: "PEN")

        let all = [normal, groups, other]
        let transactions = [
            makeTransaction(amount: 1_000, account: normal, amountInPreferredCurrency: 1_000),
            makeTransaction(amount: 500, account: groups, amountInPreferredCurrency: 500),
            makeTransaction(amount: 200, account: other, amountInPreferredCurrency: 200),
        ]
        let converter = MockCurrencyConverter()
        let excluded: Set<PersistentIdentifier> = [other.persistentModelID]

        // El flag: en modo excluir NO hay "filtro de cuenta" a efectos del toggle.
        #expect(
            PanelTotalAccountsLogic.hasAccountFilter(
                selectedAccountIDs: excluded, isExcludeMode: true
            ) == false
        )
        #expect(
            PanelTotalAccountsLogic.hasAccountFilter(
                selectedAccountIDs: excluded, isExcludeMode: false
            ) == true
        )

        // Y el número que ve el usuario, componiendo como el Panel.
        let effective = PanelTotalAccountsLogic.accountsForTotal(
            all,
            includeGroups: false,
            hasSelectedAccount: PanelTotalAccountsLogic.hasAccountFilter(
                selectedAccountIDs: excluded, isExcludeMode: true
            )
        )
        let balance = LiveBalanceCalculator.liveBalance(
            accounts: effective,
            transactions: transactions,
            preferredCurrencyCode: "PEN",
            selectedAccountIDs: excluded,
            isExcludeMode: true,
            converter: converter
        )

        // Solo `Normal`: `Grupos` sigue apagada por el toggle y `Otra` está excluida.
        #expect(balance == 1_000)
        // 1_500 es el defecto: la cuenta de grupos reaparece al excluir.
        #expect(balance != 1_500)
        // Y el conteo "en N cuentas" del panorama tiene que decir lo mismo.
        #expect(effective.count == 2)
    }

    /// El bug original en una línea: el hero mostraba el gasto del período.
    /// Este test falla si alguien vuelve a cablear el KPI de Balance al flujo.
    @Test func balanceKPI_isNotThePeriodExpenseFlow() {
        let account = makeAccount(currencyCode: "PEN")
        let category = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)

        // Saldo de partida muy por encima del gasto del mes.
        let opening = makeTransaction(
            amount: 5000, date: Date(), account: account, amountInPreferredCurrency: 5000
        )
        let expense = makeTransaction(
            amount: -200, date: Date(), account: account, category: category,
            amountInPreferredCurrency: -200
        )
        let transactions = [opening, expense]

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let kpi = BalanceKPICalculator.value(
            transactions: transactions,
            accounts: [account],
            interval: currentPeriodInterval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: converter
        )

        let flow = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: transactions,
            interval: currentPeriodInterval,
            currencyCode: "PEN",
            converter: converter
        ).reduce(0) { $0 + $1.amount }

        #expect(kpi == 4800, "El saldo es 5000 - 200")
        #expect(flow == 200, "El flujo del período es el gasto: 200")
        #expect(kpi != flow, "El KPI de Balance volvió a ser el flujo del período")
    }

    // MARK: - Período cerrado: el saldo al cierre, a la tasa del cierre

    /// Una tasa por fecha: `antes` hasta el inicio de este mes, `hoy` desde entonces. Es lo que distingue «la tasa
    /// del cierre del mes pasado» de «la tasa de hoy»: con una sola tasa para todo, las dos dan el mismo número.
    private struct DatedRateConverter: CurrencyConverting {
        let cutoff: Date
        let antes: Decimal
        let hoy: Decimal

        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
            convertChecked(amount, from: from, to: to, on: date).amount
        }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
            convertCheckedWithLatestRate(amount, from: from, to: to).amount
        }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) {
            if from == to { return (amount, .exact) }
            return (amount * (date < cutoff ? antes : hoy), .exact)
        }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) {
            if from == to { return (amount, .exact) }
            return (amount * hoy, .exact)
        }
    }

    /// Un período pasado NO enseña el saldo de hoy: ni lo que pasó después del cierre ni el tipo de cambio de hoy.
    /// Desde `panel-balance-chart-contradicts-its-own-figure` (2026-10-16, decisión de Jürgen: «cada día a su
    /// tipo de cambio») tampoco suma cada fila al tipo de su día: vale lo que había en cada divisa al cierre, por
    /// la tasa de ESE día. 1.000 USD comprados a 3,0 + 1.000 PEN; el cierre del mes pasado a 3,2; hoy a 3,5 y con
    /// 500 PEN más.
    @Test func balanceKPI_closedPeriod_valuesTheCloseAtTheClosingRate() {
        let lastMonthInterval = DetailPeriod.lastMonth.dateInterval()
        let dateInLastMonth = calendar.date(
            byAdding: .day, value: 1, to: lastMonthInterval.start
        )!
        let fixture = multiCurrencyFixture(date: dateInLastMonth)
        let despues = makeTransaction(
            amount: 500, date: Date(), account: fixture.accounts[1], amountInPreferredCurrency: 500
        )
        let converter = DatedRateConverter(
            cutoff: DetailPeriod.thisMonth.dateInterval().start, antes: 3.2, hoy: 3.5
        )

        let kpi = BalanceKPICalculator.value(
            transactions: fixture.transactions + [despues],
            accounts: fixture.accounts,
            interval: lastMonthInterval,
            period: .lastMonth,
            currencyCode: "PEN",
            converter: converter
        )

        #expect(kpi == 4_200, "1.000 USD × 3,2 + 1.000 PEN")
        #expect(kpi != 4_000, "no la suma de cada fila a su tipo (el coste)")
        #expect(kpi != 4_500, "no la tasa de hoy")
        #expect(kpi != 5_000, "no el saldo vivo de hoy")
    }

    @Test func balanceKPI_closedPeriod_matchesPanel() {
        let lastMonthInterval = DetailPeriod.lastMonth.dateInterval()
        let dateInLastMonth = calendar.date(
            byAdding: .day, value: 1, to: lastMonthInterval.start
        )!
        let fixture = multiCurrencyFixture(date: dateInLastMonth)

        let distribution = BalanceKPICalculator.value(
            transactions: fixture.transactions,
            accounts: fixture.accounts,
            interval: lastMonthInterval,
            period: .lastMonth,
            currencyCode: "PEN",
            converter: fixture.converter
        )
        let panel = panelBalanceKPI(
            transactions: fixture.transactions,
            accounts: fixture.accounts,
            interval: lastMonthInterval,
            period: .lastMonth,
            currencyCode: "PEN",
            converter: fixture.converter
        )

        #expect(distribution == panel)
    }

    // MARK: - `hasDataInPeriod`: el 0 del Panel es ambiguo

    /// Sin movimientos en el período el KPI vale 0 igual que si el saldo fuera
    /// cero. El hero necesita distinguirlo: enseñar «0» a alguien que tiene saldo,
    /// solo por abrir un mes vacío, es peor que no enseñar nada.
    @Test func result_noTransactionsInPeriod_flagsNoData() {
        let account = makeAccount(currencyCode: "PEN")
        let old = makeTransaction(
            amount: 6000,
            date: calendar.date(byAdding: .year, value: -2, to: Date())!,
            account: account
        )

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let r = BalanceKPICalculator.result(
            transactions: [old], accounts: [account],
            interval: DetailPeriod.thisWeek.dateInterval(),
            period: .thisWeek, currencyCode: "PEN", converter: converter
        )

        #expect(r.value == 0, "Paridad con el Panel: su finalBalance también es 0")
        #expect(r.hasDataInPeriod == false, "…pero el hero debe saber que ese 0 no es un saldo")
    }

    @Test func result_withTransactionsInPeriod_flagsData() {
        let account = makeAccount(currencyCode: "PEN")
        let tx = makeTransaction(amount: 6000, account: account)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let r = BalanceKPICalculator.result(
            transactions: [tx], accounts: [account],
            interval: currentPeriodInterval,
            period: .thisMonth, currencyCode: "PEN", converter: converter
        )

        #expect(r.value == 6000)
        #expect(r.hasDataInPeriod)
    }

    /// Un saldo REALMENTE cero sí tiene datos que enseñar, y debe distinguirse del
    /// caso de arriba aunque el número sea idéntico.
    @Test func result_genuinelyZeroBalance_stillHasData() {
        let account = makeAccount(currencyCode: "PEN")
        let inTx = makeTransaction(amount: 100, account: account)
        let outTx = makeTransaction(amount: -100, account: account)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let r = BalanceKPICalculator.result(
            transactions: [inTx, outTx], accounts: [account],
            interval: currentPeriodInterval,
            period: .thisMonth, currencyCode: "PEN", converter: converter
        )

        #expect(r.value == 0)
        #expect(r.hasDataInPeriod, "El saldo es 0 de verdad, no por falta de datos")
    }

    // MARK: - El atajo de rendimiento no puede cambiar el número

    /// `BalanceKPICalculator` evita construir la curva cuando el override ya
    /// decide el resultado. Ese atajo es una condición DUPLICADA de
    /// `processTrendData`, y las condiciones duplicadas divergen — así que se
    /// compara contra el camino completo en todos los períodos, no en uno.
    @Test(arguments: [
        DetailPeriod.thisWeek, .last7Days, .last30Days, .thisMonth,
        .lastMonth, .thisYear, .lastYear, .allTime,
    ])
    func balanceKPI_shortcut_matchesFullProcessing(period: DetailPeriod) {
        let account = makeAccount(currencyCode: "PEN")
        let usdAccount = makeAccount(name: "USD", currencyCode: "USD")

        // Historia repartida por varios meses y años, para que cada período
        // encuentre datos dentro y fuera de su ventana.
        var transactions: [TransactionItem] = []
        for offset in [0, 1, 3, 10, 40, 100, 200, 400, 800] {
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            transactions.append(
                makeTransaction(
                    amount: 100, date: date, account: account,
                    amountInPreferredCurrency: 100
                )
            )
            transactions.append(
                makeTransaction(
                    amount: 50, currencyCode: "USD", date: date, account: usdAccount,
                    amountInPreferredCurrency: 150  // TC histórico 3,0
                )
            )
        }

        var converter = MockCurrencyConverter()
        converter.fixedRate = 3.5  // TC de hoy ≠ histórico

        let interval = period.dateInterval()
        let accounts = [account, usdAccount]

        let shortcut = BalanceKPICalculator.value(
            transactions: transactions,
            accounts: accounts,
            interval: interval,
            period: period,
            currencyCode: "PEN",
            converter: converter
        )
        let full = panelBalanceKPI(
            transactions: transactions,
            accounts: accounts,
            interval: interval,
            period: period,
            currencyCode: "PEN",
            converter: converter
        )

        #expect(
            shortcut == full,
            "El atajo divergió del cálculo completo en \(period): \(shortcut) vs \(full)"
        )
    }

    /// Borde del atajo: hay transacciones, pero NINGUNA dentro del período. El
    /// Panel devuelve 0 (early-return de `processTrendData`), no el saldo vivo —
    /// y el atajo tiene que hacer lo mismo aunque el override sí exista.
    @Test func balanceKPI_transactionsExistButNoneInPeriod_matchesPanel() {
        let account = makeAccount(currencyCode: "PEN")
        // Única transacción, muy anterior al período mostrado.
        let old = makeTransaction(
            amount: 900,
            date: calendar.date(byAdding: .year, value: -3, to: Date())!,
            account: account
        )

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let interval = DetailPeriod.thisWeek.dateInterval()

        let shortcut = BalanceKPICalculator.value(
            transactions: [old],
            accounts: [account],
            interval: interval,
            period: .thisWeek,
            currencyCode: "PEN",
            converter: converter
        )
        let full = panelBalanceKPI(
            transactions: [old],
            accounts: [account],
            interval: interval,
            period: .thisWeek,
            currencyCode: "PEN",
            converter: converter
        )

        #expect(shortcut == full)
        #expect(shortcut == 0, "Sin movimientos en el período, el KPI es 0 en las dos pantallas")
    }

    /// Borde del atajo: una única transacción justo en el primer instante del
    /// período, que es donde `bucketStartDate`/`effectiveEnd` se tocan.
    @Test func balanceKPI_transactionExactlyAtPeriodStart_matchesPanel() {
        let account = makeAccount(currencyCode: "PEN")
        let interval = DetailPeriod.thisMonth.dateInterval()
        let tx = makeTransaction(amount: 320, date: interval.start, account: account)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let shortcut = BalanceKPICalculator.value(
            transactions: [tx], accounts: [account], interval: interval,
            period: .thisMonth, currencyCode: "PEN", converter: converter
        )
        let full = panelBalanceKPI(
            transactions: [tx], accounts: [account], interval: interval,
            period: .thisMonth, currencyCode: "PEN", converter: converter
        )

        #expect(shortcut == full)
    }

    // MARK: - Bordes

    @Test func balanceKPI_noTransactionsInPeriod_returnsZeroLikePanel() {
        let account = makeAccount()
        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let kpi = BalanceKPICalculator.value(
            transactions: [],
            accounts: [account],
            interval: currentPeriodInterval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: converter
        )

        #expect(kpi == 0)
    }

    /// En el camino VIVO la exclusión la aplica `LiveBalanceCalculator`, que mira
    /// `excludeFromStatistics` al agrupar por moneda.
    @Test func balanceKPI_livePeriod_excludedAccount_notCounted() {
        let included = makeAccount(name: "Visible", currencyCode: "PEN")
        let excluded = makeAccount(
            name: "Oculta", currencyCode: "PEN", excludeFromStatistics: true
        )
        let txIncluded = makeTransaction(amount: 700, account: included)
        let txExcluded = makeTransaction(amount: 300, account: excluded)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let kpi = BalanceKPICalculator.value(
            transactions: [txIncluded, txExcluded],
            accounts: [included, excluded],
            interval: currentPeriodInterval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: converter
        )

        #expect(kpi == 700)
    }

    /// Contrato del helper, y conviene que esté escrito: en el camino HISTÓRICO
    /// (período cerrado) la exclusión por cuenta **no** la aplica el helper.
    /// `TrendDataProcessor.fillBalanceBuckets` recibe `accounts` y no lo usa: suma
    /// las transacciones que le llegan. Quien llama debe entregarlas ya filtradas
    /// —`StatisticsViewModel.balanceKPI` lo hace por `eligibleAccountIDs`, igual
    /// que `PanelViewModel` con `balanceTransactions`—.
    ///
    /// Este test fija el contrato tal cual es. Si algún día `fillBalanceBuckets`
    /// empieza a honrar `accounts`, este test se pondrá rojo y será señal de que
    /// el pre-filtrado de los dos callers pasó a ser redundante, no de una
    /// regresión.
    @Test func balanceKPI_closedPeriod_doesNotFilterAccountsItself() {
        let lastMonthInterval = DetailPeriod.lastMonth.dateInterval()
        let dateInLastMonth = calendar.date(
            byAdding: .day, value: 1, to: lastMonthInterval.start
        )!

        let included = makeAccount(name: "Visible", currencyCode: "PEN")
        let excluded = makeAccount(
            name: "Oculta", currencyCode: "PEN", excludeFromStatistics: true
        )
        let txIncluded = makeTransaction(
            amount: 700, date: dateInLastMonth, account: included
        )
        let txExcluded = makeTransaction(
            amount: 300, date: dateInLastMonth, account: excluded
        )

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let unfiltered = BalanceKPICalculator.value(
            transactions: [txIncluded, txExcluded],
            accounts: [included, excluded],
            interval: lastMonthInterval,
            period: .lastMonth,
            currencyCode: "PEN",
            converter: converter
        )
        #expect(unfiltered == 1000, "Sin pre-filtrar, el camino histórico suma las dos")

        // Con el pre-filtrado que hacen los dos callers reales:
        let filtered = BalanceKPICalculator.value(
            transactions: [txIncluded],
            accounts: [included],
            interval: lastMonthInterval,
            period: .lastMonth,
            currencyCode: "PEN",
            converter: converter
        )
        #expect(filtered == 700)
    }

    /// Un saldo negativo es un dato válido, y el hero debe poder mostrarlo. Si
    /// este número se volviera a colar por una condición `> 0`, el hero entero
    /// desaparecería justo cuando el usuario está en rojo.
    @Test func balanceKPI_negativeBalance_isReported() {
        let account = makeAccount(currencyCode: "PEN")
        let tx = makeTransaction(amount: -450, account: account)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let kpi = BalanceKPICalculator.value(
            transactions: [tx],
            accounts: [account],
            interval: currentPeriodInterval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: converter
        )

        #expect(kpi == -450)
    }

    /// El saldo necesita TODO el histórico: recortarlo al período es exactamente
    /// como se convirtió en flujo la primera vez.
    @Test func balanceKPI_includesTransactionsBeforeThePeriod() {
        let account = makeAccount(currencyCode: "PEN")
        let old = makeTransaction(
            amount: 2000,
            date: calendar.date(byAdding: .month, value: -6, to: Date())!,
            account: account
        )
        let recent = makeTransaction(amount: 500, account: account)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let kpi = BalanceKPICalculator.value(
            transactions: [old, recent],
            accounts: [account],
            interval: currentPeriodInterval,
            period: .thisMonth,
            currencyCode: "PEN",
            converter: converter
        )

        #expect(kpi == 2500, "El saldo arrastra lo anterior al período")
    }
}
