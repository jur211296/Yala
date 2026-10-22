//
//  FXPnLLogicTests.swift
//  YalaTests
//
//  Ganancia/pérdida cambiaria del saldo vivo.
//
//  Buena parte de estos casos son defectos REALES que tuvo la primera versión de este cálculo (un
//  TC medio sobre todos los movimientos) y que la review adversarial reprodujo con números. Cada
//  uno lleva escrito qué enseñaba mal, porque son justo los que vuelven si alguien "simplifica"
//  el FIFO a un promedio.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct FXPnLLogicTests {

    // MARK: - Dobles

    /// Converter con tasa distinta para HOY y para el pasado, por divisa. Hace falta separar las
    /// dos: el coste base sale de conversiones históricas (`convertChecked(on:)`) y el valor de hoy
    /// del TC actual, y media suite trata justamente de que no se confundan.
    private struct FXConverter: CurrencyConverting {
        var todayRates: [String: Decimal] = [:]
        var historicalRates: [String: Decimal] = [:]
        var todayQualities: [String: RateQuality] = [:]
        var historicalQualities: [String: RateQuality] = [:]

        func convert(_ a: Decimal, from: String, to: String, on date: Date) -> Decimal {
            convertChecked(a, from: from, to: to, on: date).amount
        }
        func convertWithLatestRate(_ a: Decimal, from: String, to: String) -> Decimal {
            convertCheckedWithLatestRate(a, from: from, to: to).amount
        }
        func convertChecked(_ a: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality)
        {
            if from == to { return (a, .exact) }
            return (a * (historicalRates[from] ?? 1), historicalQualities[from] ?? .exact)
        }
        func convertCheckedWithLatestRate(_ a: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality)
        {
            if from == to { return (a, .exact) }
            return (a * (todayRates[from] ?? 1), todayQualities[from] ?? .exact)
        }
    }

    // MARK: - Helpers

    private func makeAccount(_ name: String = "Main", excluded: Bool = false) -> Account {
        Account(
            name: name, currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard",
            type: "bank", excludeFromStatistics: excluded
        )
    }

    private func day(_ n: Int) -> Date {
        Date(timeIntervalSince1970: 1_600_000_000 + Double(n) * 86_400)
    }

    private func tx(
        _ amount: Double,
        _ code: String = "USD",
        on dayN: Int,
        account: Account,
        historical: Double? = nil,
        preferred: String = "PEN",
        provisional: Bool = false,
        transfer: Bool = false
    ) -> TransactionItem {
        let item = TransactionItem(
            date: day(dayN), amount: amount, currencyCode: code, account: account,
            amountInPreferredCurrency: historical ?? 0,
            preferredCurrencyCode: preferred,
            isExchangeRateProvisional: provisional
        )
        if transfer { item.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer }
        return item
    }

    /// Corre el cálculo completo: saldo real y FX P&L sobre las mismas cuentas.
    private func run(
        accounts: [Account], transactions: [TransactionItem], converter: FXConverter,
        preferred: String = "PEN"
    ) -> FXPnLLogic.Summary? {
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: accounts, transactions: transactions,
            preferredCurrencyCode: preferred, converter: converter
        )
        return FXPnLLogic.summary(
            transactions: transactions, breakdown: breakdown, converter: converter
        )
    }

    private func isClose(_ a: Decimal, _ b: Decimal, tol: Decimal = Decimal(1) / Decimal(100))
        -> Bool
    { abs(a - b) <= tol }

    // MARK: - Caso base

    @Test func gain_dollarsWorthMoreToday() throws {
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 3500)],
                converter: FXConverter(todayRates: ["USD": 3.8])
            )
        )
        let row = summary.rows[0]
        #expect(isClose(row.averageEntryRate, 3.5))
        #expect(isClose(row.currentRate, 3.8))
        #expect(isClose(row.pnl, 300))
        #expect(FXPnLLogic.shouldPresent(summary))
    }

    @Test func loss_dollarsWorthLessToday() throws {
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 3500)],
                converter: FXConverter(todayRates: ["USD": 3.2])
            )
        )
        #expect(isClose(summary.rows[0].pnl, -300))
        #expect(summary.rows[0].rateVariation < 0)
    }

    // MARK: - Los dos casos que invertían el signo

    @Test func spentMoney_doesNotDragTheEntryRate() throws {
        // El defecto que mató al primer diseño. Con un TC medio sobre TODOS los movimientos, los
        // 1.000 USD comprados y vendidos en el día 20 arrastraban el coste de lo que quedaba, y la
        // card anunciaba GANANCIA a quien había perdido. FIFO consume esos lotes al salir.
        let acc = makeAccount()
        let txs = [
            tx(100, on: 1, account: acc, historical: 400),  // entran 100 a 4,00 y se quedan
            tx(1000, on: 20, account: acc, historical: 3000),  // compra a 3,00
            tx(-1000, on: 21, account: acc, historical: -3000)  // y venta
        ]
        let summary = try #require(
            run(accounts: [acc], transactions: txs, converter: FXConverter(todayRates: ["USD": 3.5]))
        )
        let row = summary.rows[0]
        #expect(row.nativeBalance == 100)
        #expect(
            isClose(row.averageEntryRate, 3.0),
            "FIFO: la venta se llevó los 100 de 4,00 y 900 de 3,00; lo vivo entró a 3,00"
        )
        #expect(isClose(row.pnl, 50))
    }

    @Test func internalTransfer_doesNotRewriteTheCost() throws {
        // Mover dinero de una cuenta propia a otra no compra ni vende divisa. Sus dos patas llevan
        // el TC del día del traspaso: contarlas empujaba el P&L hacia cero (medido: +300 → +33).
        let a = makeAccount("A")
        let b = makeAccount("B")
        let txs = [
            tx(1000, on: 1, account: a, historical: 3500),
            tx(-1000, on: 60, account: a, historical: -3900, transfer: true),
            tx(1000, on: 60, account: b, historical: 3900, transfer: true)
        ]
        let summary = try #require(
            run(
                accounts: [a, b], transactions: txs,
                converter: FXConverter(todayRates: ["USD": 3.8])
            )
        )
        #expect(summary.rows[0].nativeBalance == 1000, "el saldo no cambia al mover de bolsillo")
        #expect(
            isClose(summary.rows[0].averageEntryRate, 3.5),
            "y el coste tampoco: sigue siendo el de enero, no el del día del traspaso"
        )
        #expect(isClose(summary.rows[0].pnl, 300))
    }

    // MARK: - Deuda

    @Test func debtInForeignCurrency_isALossWhenRateRises() throws {
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(-1000, on: 1, account: acc, historical: -3500)],
                converter: FXConverter(todayRates: ["USD": 3.8])
            )
        )
        let row = summary.rows[0]
        #expect(isClose(row.currentRate, 3.8), "el TC es positivo aunque el saldo sea negativo")
        #expect(isClose(row.pnl, -300), "la deuda encarecida es una PÉRDIDA")
        #expect(row.rateVariation > 0, "y sin embargo el TC subió: son cosas distintas")
    }

    // MARK: - Las dos vías de la marca de aproximado

    @Test func provisionalHistoricalRate_marksTheRow() throws {
        // La rama GUARDADA. Una transacción sellada con la tabla estática (sin conexión) da un
        // coste base falso; sin esta vía el P&L salía disparado y se presentaba como exacto.
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 3500, provisional: true)],
                converter: FXConverter(todayRates: ["USD": 3.8])
            )
        )
        #expect(
            summary.rows[0].isApproximate,
            "el TC de hoy era exacto, pero el coste base venía de una tasa provisional"
        )
    }

    @Test func provisionalTodayRate_marksTheRow() throws {
        // La rama VIVA.
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 3500)],
                converter: FXConverter(
                    todayRates: ["USD": 3.8], todayQualities: ["USD": .staticFallback]
                )
            )
        )
        #expect(summary.rows[0].isApproximate)
    }

    @Test func exactBothWays_isNotMarked() throws {
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 3500)],
                converter: FXConverter(todayRates: ["USD": 3.8])
            )
        )
        #expect(!summary.rows[0].isApproximate)
        #expect(!summary.isApproximate)
    }

    @Test func approximateMark_isPerCurrency_notForTheWholeTable() throws {
        let acc = makeAccount()
        let txs = [
            tx(1000, "USD", on: 1, account: acc, historical: 3500),
            tx(90000, "JPY", on: 1, account: acc, historical: 2300)
        ]
        let summary = try #require(
            run(
                accounts: [acc], transactions: txs,
                converter: FXConverter(
                    todayRates: ["USD": 3.8, "JPY": Decimal(28) / Decimal(1000)],
                    todayQualities: ["USD": .exact, "JPY": .carriedForward(fromDateKey: "2026-09-06")]
                )
            )
        )
        let usd = try #require(summary.rows.first { $0.code == "USD" })
        let jpy = try #require(summary.rows.first { $0.code == "JPY" })
        #expect(!usd.isApproximate)
        #expect(jpy.isApproximate)
        // JPY aporta 220 de un P&L de 520: un 42 %, así que el total pesa y lleva «≈».
        #expect(summary.isApproximate, "la fila dudosa pesa en el total")
        #expect(summary.hasApproximateRow)
    }

    /// Decisión B del 2026-10-12 (`dos-criterios-de-aproximado-en-la-misma-pantalla`): el total del
    /// P&L sigue `ApproximateMarkThreshold`, como el resto del Panel. Con el OR anterior este caso
    /// salía marcado por 5 de 3.005.
    @Test func approximateMark_onTheTotal_needsTheDoubtfulRowToWeigh() throws {
        let acc = makeAccount()
        let txs = [
            tx(10000, "USD", on: 1, account: acc, historical: 35000),
            tx(1000, "JPY", on: 1, account: acc, historical: 23)
        ]
        let summary = try #require(
            run(
                accounts: [acc], transactions: txs,
                converter: FXConverter(
                    todayRates: ["USD": 3.8, "JPY": Decimal(28) / Decimal(1000)],
                    todayQualities: ["USD": .exact, "JPY": .carriedForward(fromDateKey: "2026-09-06")]
                )
            )
        )
        let jpy = try #require(summary.rows.first { $0.code == "JPY" })
        #expect(jpy.isApproximate, "la fila sigue marcada: su número sí es dudoso")
        #expect(summary.hasApproximateRow, "y la hoja explica el glifo de esa fila")
        #expect(!summary.isApproximate, "5 de un P&L de 3.005 (0,17 %) no marca el total")
    }

    // MARK: - Datos guardados que no sirven

    @Test func zeroHistoricalAmount_isTreatedAsAbsent_notAsFree() throws {
        // `amountInPreferredCurrency` por defecto es 0. Tomarlo como dato daba coste base 0, o sea
        // el saldo ENTERO presentado como ganancia. Se reconvierte con la tasa de aquel día.
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 0)],
                converter: FXConverter(todayRates: ["USD": 3.8], historicalRates: ["USD": 3.5])
            )
        )
        #expect(
            isClose(summary.rows[0].averageEntryRate, 3.5),
            "reconvertido al TC de su fecha, no cero"
        )
        #expect(isClose(summary.rows[0].pnl, 300), "y no +3.800, que es el saldo entero")
    }

    @Test func staleSnapshotCurrency_isReconverted_notDiscarded() throws {
        // Sellada contra otra moneda preferida (cambio de divisa a medias, o sync de otro aparato).
        // Descartarla sesga la muestra hacia las transacciones más antiguas, que es justo donde el
        // TC era distinto. Los once calculadores del repo reconvierten; éste también.
        let acc = makeAccount()
        let txs = [
            tx(1000, on: 1, account: acc, historical: 3500, preferred: "PEN"),
            tx(1000, on: 2, account: acc, historical: 900, preferred: "EUR")
        ]
        let summary = try #require(
            run(
                accounts: [acc], transactions: txs,
                converter: FXConverter(todayRates: ["USD": 3.8], historicalRates: ["USD": 3.6])
            )
        )
        #expect(summary.rows[0].nativeBalance == 2000)
        #expect(
            isClose(summary.rows[0].averageEntryRate, 3.55),
            "media de 3,50 (sellada) y 3,60 (reconvertida) — no 2,20, que es mezclar soles con euros"
        )
    }

    // MARK: - Cobertura de los lotes

    @Test func lotsThatDoNotCoverTheBalance_dropTheCurrency() throws {
        // Un traspaso ENTRANTE desde una cuenta que el filtro dejó fuera mete dinero cuyo origen no
        // se ve. Repartir el coste conocido sobre un saldo mayor inventaría base.
        let visible = makeAccount("Visible")
        let hidden = makeAccount("Fuera")
        let txs = [
            tx(1000, on: 1, account: visible, historical: 3500),
            tx(5000, on: 2, account: visible, historical: 19000, transfer: true)
        ]
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [visible, hidden], transactions: txs,
            preferredCurrencyCode: "PEN", converter: FXConverter(todayRates: ["USD": 3.8])
        )
        #expect(breakdown.nativeBalances["USD"] == 6000, "el saldo sí los cuenta")
        #expect(
            FXPnLLogic.summary(
                transactions: txs, breakdown: breakdown,
                converter: FXConverter(todayRates: ["USD": 3.8])
            ) == nil,
            "pero sin saber qué costaron los 5.000, la divisa se descarta entera"
        )
    }

    // MARK: - Moneda preferida y mono-divisa

    @Test func preferredCurrency_neverProducesPnL() throws {
        let acc = makeAccount()
        #expect(
            run(
                accounts: [acc],
                transactions: [tx(5000, "PEN", on: 1, account: acc, historical: 5200)],
                converter: FXConverter(todayRates: ["USD": 3.8])
            ) == nil
        )
    }

    // MARK: - Coherencia card ↔ sheet

    @Test func total_equalsSumOfRows() throws {
        let acc = makeAccount()
        let txs = [
            tx(1000, "USD", on: 1, account: acc, historical: 3500),
            tx(500, "EUR", on: 1, account: acc, historical: 1900)
        ]
        let summary = try #require(
            run(
                accounts: [acc], transactions: txs,
                converter: FXConverter(todayRates: ["USD": 3.8, "EUR": 4.0])
            )
        )
        #expect(summary.totalPnL == summary.rows.reduce(Decimal(0)) { $0 + $1.pnl })
        #expect(summary.rows.count == 2)
    }

    @Test func rows_orderedByExposure_butDominantIsTheOneThatMovedTheNumber() throws {
        // La tarjeta que se contradecía: la mayor posición era la que no había hecho nada, y el
        // titular «Pérdida» convivía con «tus dólares valen un 0 % más».
        let acc = makeAccount()
        let txs = [
            tx(10000, "USD", on: 1, account: acc, historical: 35000),  // grande y plano
            tx(1000, "EUR", on: 1, account: acc, historical: 4000)  // pequeño y caído
        ]
        let summary = try #require(
            run(
                accounts: [acc], transactions: txs,
                converter: FXConverter(todayRates: ["USD": 3.5, "EUR": 3.0])
            )
        )
        #expect(summary.rows.map(\.code) == ["USD", "EUR"], "el desglose ordena por exposición")
        #expect(
            summary.dominant?.code == "EUR",
            "pero la frase habla de la divisa que explica el número, no de la más grande"
        )
        #expect(summary.totalPnL < 0)
    }

    // MARK: - Umbral

    @Test func tinyMovement_isNoise() throws {
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 3500)],
                converter: FXConverter(todayRates: ["USD": 3.501])
            )
        )
        #expect(!FXPnLLogic.shouldPresent(summary))
    }

    @Test func movementOverThreshold_showsCard() throws {
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(1000, on: 1, account: acc, historical: 3500)],
                converter: FXConverter(todayRates: ["USD": 3.52])
            )
        )
        #expect(FXPnLLogic.shouldPresent(summary))
    }

    @Test func amountThatRoundsToZeroOnScreen_isNotPresented() throws {
        // «Ganancia por tipo de cambio +0,00 €» es ruido con aspecto de dato. El umbral relativo
        // por sí solo lo dejaba pasar, porque una posición diminuta tiene una base diminuta.
        let acc = makeAccount()
        let summary = try #require(
            run(
                accounts: [acc],
                transactions: [tx(0.02, on: 1, account: acc, historical: 0.017)],
                converter: FXConverter(todayRates: ["USD": 0.92])
            )
        )
        #expect(abs(summary.totalPnL) < FXPnLLogic.nearZero)
        #expect(!FXPnLLogic.shouldPresent(summary))
    }

    @Test func cancellingPositions_doNotDegenerateTheThreshold() throws {
        // Por esto el denominador es la exposición y no el balance: con +1.000 USD contra una deuda
        // en soles el balance ronda cero, y «0,5 % del balance» dejaría pasar cualquier céntimo.
        let acc = makeAccount()
        let txs = [
            tx(1000, "USD", on: 1, account: acc, historical: 3500),
            tx(-3500, "PEN", on: 1, account: acc, historical: -3500)
        ]
        let summary = try #require(
            run(
                accounts: [acc], transactions: txs,
                converter: FXConverter(todayRates: ["USD": 3.5005])
            )
        )
        #expect(isClose(summary.exposedBase, 3500))
        #expect(!FXPnLLogic.shouldPresent(summary))
    }

    // MARK: - El mismo conjunto de cuentas que el saldo

    @Test func excludedAccount_countsInNeitherSide() throws {
        let visible = makeAccount("Visible")
        let excluded = makeAccount("Excluida", excluded: true)
        let txs = [
            tx(1000, on: 1, account: visible, historical: 3500),
            tx(7000, on: 1, account: excluded, historical: 28000)
        ]
        let summary = try #require(
            run(
                accounts: [visible, excluded], transactions: txs,
                converter: FXConverter(todayRates: ["USD": 3.8])
            )
        )
        #expect(summary.rows[0].nativeBalance == 1000)
        #expect(
            isClose(summary.rows[0].averageEntryRate, 3.5),
            "la cuenta excluida de estadísticas tampoco pesa en el coste"
        )
    }

    @Test func residualBalance_isFilteredOut() throws {
        let acc = makeAccount()
        #expect(
            run(
                accounts: [acc],
                transactions: [
                    tx(1000, on: 1, account: acc, historical: 3500),
                    tx(-1000, on: 2, account: acc, historical: -3600)
                ],
                converter: FXConverter(todayRates: ["USD": 3.8])
            ) == nil,
            "saldo cero: no queda dinero del que hablar"
        )
    }
}
