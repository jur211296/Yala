//
//  AccountBalanceCalculator.swift
//  Yala
//
//  Calcula el saldo actual de una cuenta a partir de todas sus transacciones.
//  El saldo inicial ahora también es una transacción, por lo que empezamos desde 0.
//  Reutilizar en todas las vistas que muestren el saldo de una cuenta.
//

import Foundation
import SwiftData

struct AccountBalanceCalculator {

    // MARK: - API principal (función pura)

    /// Calcula el saldo actual a partir de una colección de transacciones.
    /// El saldo inicial ahora es una transacción con balanceAdjustmentType = "initial_balance",
    /// por lo que empezamos desde 0.
    /// - Parameters:
    ///   - transactions: Lista de TransactionItem asociados a la cuenta.
    /// - Returns: Saldo actual como Decimal (misma moneda de la cuenta).
    ///
    /// Solo cuentan los movimientos fechados hasta hoy (`LiveBalanceCalculator.TodayCutoff`): un movimiento con fecha
    /// futura entra en el saldo cuando llega su fecha, igual que en el saldo total del Panel.
    ///
    /// Un movimiento en otra divisa que la de su cuenta entra convertido a la de la cuenta (`amountInAccountCurrency`).
    static func currentBalance(
        transactions: [TransactionItem],
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Decimal {
        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now)
        // Reducimos desde 0 y sumamos cada monto con su signo correcto
        return transactions.reduce(Decimal(0)) { partial, item in
            cutoff.counts(item.date) ? partial + amountInAccountCurrency(item, converter: converter) : partial
        }
    }

    /// Versión conveniente que recibe la Account y todas las transacciones
    /// y se encarga de filtrar internamente solo las de esa cuenta.
    static func currentBalance(
        for account: Account,
        allTransactions: [TransactionItem],
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Decimal {
        // Filtramos únicamente las transacciones de la cuenta dada.
        // Usamos `persistentModelID` en lugar de comparar modelos directamente para
        // evitar inconsistencias entre instancias/caches de SwiftData.
        let accountID = account.persistentModelID
        let accountTransactions = allTransactions.filter { $0.account?.persistentModelID == accountID }

        // Partimos de 0 - el saldo inicial es ahora una transacción.
        return currentBalance(transactions: accountTransactions, asOf: now, converter: converter)
    }

    // MARK: - Batch Calculation (Optimized)

    /// Calcula el saldo actual para múltiples cuentas en una sola pasada sobre las transacciones.
    /// - Returns: Diccionario [AccountID: SaldoDecimal]
    static func batchCalculateBalances(
        accounts: [Account],
        transactions: [TransactionItem],
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [PersistentIdentifier: Decimal] {
        var suma = SumaSaldosPorCuenta(accounts: accounts, asOf: now, converter: converter)
        for transaction in transactions { suma.sumar(transaction) }
        return suma.saldos
    }

    /// Los saldos por cuenta, fila a fila: la regla entera de `batchCalculateBalances`, que la recorre de una vez.
    ///
    /// **Lote 8 de eficiencia (27-nov-2026).** Con 16.004 movimientos en el iPhone 14 eran ~170 ms de hilo principal sin
    /// ceder, en la foto de los widgets y en la carga del Panel. Quien no puede bloquear tanto suma por tramos y cede
    /// entre uno y otro; la foto suma sobre las filas que ya leyó (`sumar(cuentaID:fecha:moneda:monto:)`). Las tres vías
    /// pasan por el mismo `sumar`: la cifra sale de un solo sitio.
    struct SumaSaldosPorCuenta {
        /// Empiezan en 0 (el saldo inicial es una transacción) y solo suman las cuentas pedidas.
        private(set) var saldos: [PersistentIdentifier: Decimal] = [:]
        /// La divisa de cada cuenta pedida, leída una vez: la de destino de `amountInAccountCurrency`.
        private let divisaDeCuenta: [PersistentIdentifier: String]
        private let cutoff: LiveBalanceCalculator.TodayCutoff
        private let converter: CurrencyConverting

        init(accounts: [Account], asOf now: Date = .now, converter: CurrencyConverting = CurrencyConverter.shared) {
            cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now)
            self.converter = converter
            var divisas: [PersistentIdentifier: String] = [:]
            for account in accounts {
                saldos[account.persistentModelID] = Decimal(0)
                divisas[account.persistentModelID] = account.currencyCode
            }
            divisaDeCuenta = divisas
        }

        /// Suma un movimiento, leyendo de él lo que la regla pide.
        mutating func sumar(_ transaction: TransactionItem) {
            // Solo los fechados hasta hoy, y solo en una cuenta del mapa.
            guard cutoff.counts(transaction.date), let account = transaction.account else { return }
            sumar(cuentaID: account.persistentModelID, fecha: transaction.date,
                  moneda: transaction.currencyCode, monto: Decimal(transaction.amount))
        }

        /// La regla, sobre lo ya leído de la fila: `moneda` y `monto` son `tx.currencyCode` y `Decimal(tx.amount)`.
        mutating func sumar(cuentaID: PersistentIdentifier?, fecha: Date, moneda: String, monto: Decimal) {
            guard cutoff.counts(fecha), let cuentaID, let current = saldos[cuentaID],
                  let divisaCuenta = divisaDeCuenta[cuentaID]
            else { return }
            saldos[cuentaID] = current + amountInAccountCurrency(
                monto, currencyCode: moneda, accountCurrencyCode: divisaCuenta, date: fecha, converter: converter)
        }
    }

    // MARK: - Normalización de monto

    /// El importe de un movimiento en la divisa de SU cuenta, con su signo.
    ///
    /// **Una fila en otra divisa que la de su cuenta entra convertida, a la tasa de su fecha, sin tocar lo guardado**
    /// (card «Cambiar la divisa de una cuenta en un teléfono puede dejar el otro con movimientos en la divisa vieja»,
    /// opción C, 2026-11-05). El teléfono que cambia la divisa convierte en el mismo guardado todo lo que tiene de la
    /// cuenta, con la tasa de la fecha de cada fila (`AccountCurrencyMigrationService`), y lo sube; el otro lo recibe por
    /// páginas, así que mientras llega —y para siempre en las filas que solo él tenía, que el primero no podía conocer—
    /// la cuenta dice una divisa y algunas filas otra. Sumadas en crudo, 900 soles contaban como 900 dólares. Convertidas
    /// con la MISMA regla del emisor, la cifra de la tarjeta es la que dará la fila cuando llegue convertida.
    ///
    /// Solo cuando las dos divisas son del catálogo: una divisa vacía o desconocida se sigue sumando tal cual, en vez de
    /// tomarla por dólares (`recognizedCurrencyCode`). Sin cuenta no hay divisa de destino: tal cual.
    private static func amountInAccountCurrency(_ item: TransactionItem, converter: CurrencyConverting) -> Decimal {
        let amount = Decimal(item.amount)
        guard let account = item.account else { return amount }
        return amountInAccountCurrency(
            amount, currencyCode: item.currencyCode, accountCurrencyCode: account.currencyCode, date: item.date,
            converter: converter)
    }

    /// La misma regla sobre lo ya leído de la fila y de su cuenta (`SumaSaldosPorCuenta`).
    static func amountInAccountCurrency(
        _ amount: Decimal, currencyCode: String, accountCurrencyCode: String, date: Date, converter: CurrencyConverting
    ) -> Decimal {
        guard let from = recognizedCurrencyCode(currencyCode),
              let to = recognizedCurrencyCode(accountCurrencyCode),
              from != to
        else { return amount }
        return converter.convert(amount, from: from, to: to, on: date)
    }
}
