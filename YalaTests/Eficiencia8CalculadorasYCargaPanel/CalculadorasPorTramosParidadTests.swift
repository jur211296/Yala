//
//  CalculadorasPorTramosParidadTests.swift
//  YalaTests / Eficiencia8CalculadorasYCargaPanel
//
//  Lote 8 de eficiencia (27-nov-2026). El saldo vivo y los saldos por cuenta pasaron a acumuladores fila a fila
//  (`SumaSaldoVivo`, `SumaSaldosPorCuenta`) para poder recorrerse por tramos que ceden el hilo (`CalculadorasPorTramos`) y,
//  en la foto de los widgets, sobre las filas ya leídas (`FilaFotoWidget`). Con 16.004 movimientos en el iPhone 14 cada uno
//  era un tramo de ~170-216 ms sin ceder.
//
//  Se fija que las TRES vías —la de una vez (misma firma de siempre), la de por tramos y la de filas— dan exactamente lo
//  mismo que la copia congelada del código previo (`ReferenciaCalculadorasPreLote8`), sobre un almacén con todo lo que
//  separa las reglas: dos divisas y movimientos en otra divisa que la de su cuenta, cuenta excluida, cuenta archivada,
//  movimientos sin cuenta, fechas futuras, ajustes de saldo, saldo inicial y transferencias; con y sin filtro de cuentas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

/// Un tipo de cambio fijo y distinto de 1, con la calidad que se pida: la conversión cambia la cifra y la marca «≈».
struct ConversorFijoLote8: CurrencyConverting {
    var calidadHoy: RateQuality = .exact

    private func factor(_ from: String, _ to: String) -> Decimal {
        func enSoles(_ code: String) -> Decimal {
            switch code {
            case "USD": return Decimal(375) / 100
            case "EUR": return Decimal(410) / 100
            default: return 1
            }
        }
        return enSoles(from) / enSoles(to)
    }

    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
        // Depende de la fecha, para que una conversión por fecha mal hecha se note.
        let dia = Decimal(Int(date.timeIntervalSince1970 / 86_400) % 7) / 100
        return amount * (factor(from, to) + (from == to ? 0 : dia))
    }
    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount * factor(from, to) }
    func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
        -> (amount: Decimal, quality: RateQuality) { (convert(amount, from: from, to: to, on: date), .exact) }
    func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
        -> (amount: Decimal, quality: RateQuality) { (convertWithLatestRate(amount, from: from, to: to), calidadHoy) }
    func rateFactors(for codes: Set<String>, to: String, on dates: [Date]) -> [Date: [String: RateFactor]] {
        var out: [Date: [String: RateFactor]] = [:]
        for date in dates {
            var porCodigo: [String: RateFactor] = [:]
            for code in codes {
                porCodigo[code] = RateFactor(factor: convert(1, from: code, to: to, on: date), quality: .exact)
            }
            out[date] = porCodigo
        }
        return out
    }
}

@MainActor
enum CalculadorasLote8Fixture {

    /// El «ahora» de las pruebas: una fecha fija (regla de `testing.md`).
    nonisolated static let ahora = Date(timeIntervalSince1970: 1_781_000_000)

    struct Cuentas {
        let pen: Account
        let usd: Account
        let excluida: Account
        let archivada: Account
        var todas: [Account] { [pen, usd, excluida, archivada] }
    }

    @discardableResult
    static func seed(_ context: ModelContext, count: Int, now: Date = ahora) throws -> Cuentas {
        let pen = Account(name: "Soles", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        let usd = Account(name: "Dólares", currencyCode: "USD", colorHex: "#111111", iconName: "x", type: "bank")
        let excluida = Account(name: "Excluida", currencyCode: "PEN", colorHex: "#222222", iconName: "x", type: "cash",
                               excludeFromStatistics: true)
        let archivada = Account(name: "Archivada", currencyCode: "EUR", colorHex: "#333333", iconName: "x", type: "cash",
                                isArchived: true)
        for cuenta in [pen, usd, excluida, archivada] { context.insert(cuenta) }
        let comida = Category(name: "Comida", colorHex: "#FF0000", isIncome: false)
        let sueldo = Category(name: "Sueldo", colorHex: "#00FF00", isIncome: true)
        context.insert(comida)
        context.insert(sueldo)

        for i in 0..<count {
            // De 12 días en el futuro hacia atrás, cada ~5 h: hay movimientos de hoy, de mañana y de hace un año.
            let date = now.addingTimeInterval(12 * 86_400 - Double(i) * 18_000)
            let cuenta: Account?
            switch i % 19 {
            case 0: cuenta = excluida
            case 1: cuenta = archivada
            case 2: cuenta = nil
            case 3, 4, 5, 6: cuenta = usd
            default: cuenta = pen
            }
            let ingreso = i % 7 == 0
            let value = ingreso ? 1_800 + Double(i % 13) * 0.37 : -(12.01 + Double(i % 90))
            // Una de cada once va en otra divisa que la de su cuenta: el saldo por cuenta la convierte.
            let divisaCuenta = cuenta?.currencyCode ?? "PEN"
            let currency = i % 11 == 0 ? (divisaCuenta == "PEN" ? "USD" : "PEN") : divisaCuenta
            let tx = TransactionItem(date: date, amount: value, currencyCode: currency, note: "n\(i % 31)",
                                     category: ingreso ? sueldo : comida, account: cuenta,
                                     amountInPreferredCurrency: value, preferredCurrencyCode: "PEN")
            tx.createdAt = date
            switch i % 53 {
            case 0: tx.balanceAdjustmentType = InitialBalanceService.typeAdjustment
            case 1: tx.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
            case 2: tx.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            default: break
            }
            context.insert(tx)
        }
        try context.save()
        return Cuentas(pen: pen, usd: usd, excluida: excluida, archivada: archivada)
    }

    static func movimientos(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>(sortBy: [
            SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)
        ]))
    }

    /// Una cesión que cede en cada tramo (límite cero) y nunca corta.
    static func cesionQueCedeSiempre() -> CesionDelHilo {
        CesionDelHilo(limite: .zero) { true }
    }

    static func igual(_ a: LiveBalanceCalculator.Breakdown, _ b: LiveBalanceCalculator.Breakdown) -> Bool {
        a.nativeBalances == b.nativeBalances && a.convertedTotal == b.convertedTotal
            && a.preferredCurrencyCode == b.preferredCurrencyCode && a.amountsAreApproximate == b.amountsAreApproximate
            && a.eligibleAccountIDs == b.eligibleAccountIDs && a.cutoff == b.cutoff
    }
}

@Suite("Eficiencia 8 · saldo vivo y saldos por cuenta por tramos, igual que antes", .serialized)
@MainActor
struct CalculadorasPorTramosParidadTests {

    @Test("El saldo vivo: de una vez, por tramos y sobre filas dan lo mismo que el código previo, con y sin filtros")
    func saldoVivo_tresVias_igualQueAntes() async throws {
        let context = try makeTestContext()
        let cuentas = try CalculadorasLote8Fixture.seed(context, count: 2_200)
        let movimientos = try CalculadorasLote8Fixture.movimientos(context)
        let ahora = CalculadorasLote8Fixture.ahora
        let filtros: [(Set<PersistentIdentifier>, Set<PersistentIdentifier>)] = [
            ([], []),
            ([cuentas.usd.persistentModelID], []),
            ([], [cuentas.pen.persistentModelID]),
            ([cuentas.excluida.persistentModelID], []),
        ]
        for calidad in [RateQuality.exact, .staticFallback] {
            let conversor = ConversorFijoLote8(calidadHoy: calidad)
            for (incluidas, excluidas) in filtros {
                let antes = ReferenciaCalculadorasPreLote8.liveBalanceBreakdown(
                    accounts: cuentas.todas, transactions: movimientos, preferredCurrencyCode: "PEN",
                    selectedAccountIDs: incluidas, excludedAccountIDs: excluidas, asOf: ahora, converter: conversor)
                let deUnaVez = LiveBalanceCalculator.liveBalanceBreakdown(
                    accounts: cuentas.todas, transactions: movimientos, preferredCurrencyCode: "PEN",
                    selectedAccountIDs: incluidas, excludedAccountIDs: excluidas, asOf: ahora, converter: conversor)
                let cesion = CalculadorasLote8Fixture.cesionQueCedeSiempre()
                let porTramos = try await CalculadorasPorTramos.saldoVivo(
                    accounts: cuentas.todas, transactions: movimientos, preferredCurrencyCode: "PEN",
                    selectedAccountIDs: incluidas, excludedAccountIDs: excluidas, asOf: ahora, converter: conversor,
                    cesion: cesion)
                var sobreFilas = LiveBalanceCalculator.SumaSaldoVivo(
                    accounts: cuentas.todas, selectedAccountIDs: incluidas, excludedAccountIDs: excluidas, asOf: ahora)
                let lector = LectorFilasFotoWidget(currencyCode: "PEN", adjustment: .none, converter: conversor)
                for fila in lector.leer(movimientos) { fila.sumarSaldoVivo(a: &sobreFilas) }
                let filas = sobreFilas.desglose(preferredCurrencyCode: "PEN", converter: conversor)

                #expect(CalculadorasLote8Fixture.igual(deUnaVez, antes), "de una vez cambió (\(incluidas.count)/\(excluidas.count))")
                #expect(CalculadorasLote8Fixture.igual(porTramos, antes), "por tramos cambió (\(incluidas.count)/\(excluidas.count))")
                #expect(CalculadorasLote8Fixture.igual(filas, antes), "sobre filas cambió (\(incluidas.count)/\(excluidas.count))")
                #expect(cesion.cesiones >= 2, "por tramos no cedió el hilo")
            }
        }
        // El fixture no es trivial: sin filtro suma dos divisas, deja fuera excluida y archivada, y hay futuros.
        let sinFiltro = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: cuentas.todas, transactions: movimientos, preferredCurrencyCode: "PEN", asOf: ahora,
            converter: ConversorFijoLote8())
        #expect(Set(sinFiltro.nativeBalances.keys) == ["PEN", "USD"])
        #expect(sinFiltro.eligibleAccountIDs == [cuentas.pen.persistentModelID, cuentas.usd.persistentModelID])
        #expect(movimientos.contains { !sinFiltro.cutoff.counts($0.date) })
    }

    @Test("Los saldos por cuenta: de una vez, por tramos y sobre filas dan lo mismo que el código previo")
    func saldosPorCuenta_tresVias_igualQueAntes() async throws {
        let context = try makeTestContext()
        let cuentas = try CalculadorasLote8Fixture.seed(context, count: 2_200)
        let movimientos = try CalculadorasLote8Fixture.movimientos(context)
        let ahora = CalculadorasLote8Fixture.ahora
        let conversor = ConversorFijoLote8()
        for pedidas in [cuentas.todas, [cuentas.pen, cuentas.archivada], []] {
            let antes = ReferenciaCalculadorasPreLote8.batchCalculateBalances(
                accounts: pedidas, transactions: movimientos, asOf: ahora, converter: conversor)
            let deUnaVez = AccountBalanceCalculator.batchCalculateBalances(
                accounts: pedidas, transactions: movimientos, asOf: ahora, converter: conversor)
            let cesion = CalculadorasLote8Fixture.cesionQueCedeSiempre()
            let porTramos = try await CalculadorasPorTramos.saldosPorCuenta(
                accounts: pedidas, transactions: movimientos, asOf: ahora, converter: conversor, cesion: cesion)
            var sobreFilas = AccountBalanceCalculator.SumaSaldosPorCuenta(
                accounts: pedidas, asOf: ahora, converter: conversor)
            let lector = LectorFilasFotoWidget(currencyCode: "PEN", adjustment: .none, converter: conversor)
            for fila in lector.leer(movimientos) { fila.sumarSaldoPorCuenta(a: &sobreFilas) }

            #expect(deUnaVez == antes, "de una vez cambió (\(pedidas.count) cuentas)")
            #expect(porTramos == antes, "por tramos cambió (\(pedidas.count) cuentas)")
            #expect(sobreFilas.saldos == antes, "sobre filas cambió (\(pedidas.count) cuentas)")
            #expect(cesion.cesiones >= 2, "por tramos no cedió el hilo")
        }
        // Discriminante: un movimiento en otra divisa que la de su cuenta se convierte (sumado en crudo daría otra cifra),
        // y lo fechado después de hoy no cuenta.
        let usdID = cuentas.usd.persistentModelID
        let crudo = movimientos.filter { $0.account?.persistentModelID == usdID && $0.date < ahora }
            .reduce(Decimal(0)) { $0 + Decimal($1.amount) }
        let saldos = AccountBalanceCalculator.batchCalculateBalances(
            accounts: cuentas.todas, transactions: movimientos, asOf: ahora, converter: conversor)
        #expect(saldos[usdID] != crudo)
        #expect(saldos.count == 4)
    }

    @Test("La foto de los widgets: saldo total y saldos de las tarjetas iguales al código previo")
    func foto_saldoYTarjetas_igualQueAntes() throws {
        let context = try makeTestContext()
        let now = CalculadorasLote8Fixture.ahora
        try CalculadorasLote8Fixture.seed(context, count: 1_400, now: now)
        let foto = WidgetDataCache.buildSnapshot(context: context, now: now).widget

        let movimientos = try CalculadorasLote8Fixture.movimientos(context)
        let cuentas = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
        let excluidas = Set(cuentas.filter { !$0.keepsHistory }.map(\.persistentModelID))
        let elegibles = movimientos.filter { WidgetDataCache.countsForWidgets($0, excludedAccountIDs: excluidas) }
        let saldo = ReferenciaCalculadorasPreLote8.liveBalanceBreakdown(
            accounts: cuentas, transactions: elegibles, preferredCurrencyCode: WidgetDataCache.preferredCurrencyCode())
        #expect(foto.totalBalance == (saldo.convertedTotal as NSDecimalNumber).doubleValue)

        let visibles = WidgetDataCache.filterVisibleAccountsForWidget(cuentas)
        let porCuenta = ReferenciaCalculadorasPreLote8.batchCalculateBalances(accounts: visibles, transactions: movimientos)
        #expect(foto.accountBalances.count == visibles.count)
        for (tarjeta, cuenta) in zip(foto.accountBalances, visibles) {
            let esperado = NSDecimalNumber(decimal: porCuenta[cuenta.persistentModelID] ?? 0).doubleValue
            #expect(tarjeta.balance == esperado, "la tarjeta de \(cuenta.name) cambió")
        }
        #expect(foto.totalBalance != 0)
    }
}
