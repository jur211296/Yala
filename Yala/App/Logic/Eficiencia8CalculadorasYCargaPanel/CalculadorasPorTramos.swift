//
//  CalculadorasPorTramos.swift
//  Yala
//
//  Lote 8 de eficiencia (27-nov-2026). Las calculadoras compartidas de saldo, recorridas por tramos que ceden el hilo
//  principal (`CesionDelHilo`, cortes de ~25 ms).
//
//  Con 16.004 movimientos en el iPhone 14 el saldo vivo (`LiveBalanceCalculator.liveBalanceBreakdown`) y los saldos por
//  cuenta (`AccountBalanceCalculator.batchCalculateBalances`) eran cada uno un tramo de ~170-216 ms sin ceder, en la foto
//  de los widgets y en el Panel (`docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-7-foto-widgets-y-arranque/`).
//
//  **No hay regla aquí.** Cada función recorre con el acumulador de su calculadora (`SumaSaldoVivo`,
//  `SumaSaldosPorCuenta`), el mismo con el que recorre la versión de una vez: misma suma, mismo orden. Lo único nuevo es
//  ceder entre tramo y tramo.
//

import Foundation
import SwiftData

@MainActor
enum CalculadorasPorTramos {

    /// Recorre `elementos` en orden y mira el reloj cada `CesionDelHilo.cadaCuantos`: si el tramo pasó del límite, cede.
    /// Lanza `CancellationError` si, al volver, el cálculo ya no sigue: quien llama abandona sin publicar.
    static func recorrer<T>(
        _ elementos: [T], cesion: CesionDelHilo, _ cuerpo: (T) -> Void
    ) async throws {
        for (indice, elemento) in elementos.enumerated() {
            cuerpo(elemento)
            if (indice + 1) % CesionDelHilo.cadaCuantos == 0 {
                try await cesion.cederSiToca()
            }
        }
    }

    /// `LiveBalanceCalculator.liveBalanceBreakdown`, por tramos.
    static func saldoVivo(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        selectedAccountIDs: Set<PersistentIdentifier> = [],
        excludedAccountIDs: Set<PersistentIdentifier> = [],
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared,
        cesion: CesionDelHilo
    ) async throws -> LiveBalanceCalculator.Breakdown {
        var suma = LiveBalanceCalculator.SumaSaldoVivo(
            accounts: accounts, selectedAccountIDs: selectedAccountIDs, excludedAccountIDs: excludedAccountIDs,
            asOf: now)
        try await recorrer(transactions, cesion: cesion) { suma.sumar($0) }
        return suma.desglose(preferredCurrencyCode: preferredCurrencyCode, converter: converter)
    }

    /// `AccountBalanceCalculator.batchCalculateBalances`, por tramos.
    static func saldosPorCuenta(
        accounts: [Account],
        transactions: [TransactionItem],
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared,
        cesion: CesionDelHilo
    ) async throws -> [PersistentIdentifier: Decimal] {
        var suma = AccountBalanceCalculator.SumaSaldosPorCuenta(accounts: accounts, asOf: now, converter: converter)
        try await recorrer(transactions, cesion: cesion) { suma.sumar($0) }
        return suma.saldos
    }
}

/// Las calculadoras de saldo sobre una fila de la foto de los widgets, que ya trae lo que leen: la foto suma sin volver a
/// leer de SwiftData los 16 mil movimientos (lote 8). Los campos de la fila dicen de qué lectura salen (`FilaFotoWidget`).
extension FilaFotoWidget {
    func sumarSaldoVivo(a suma: inout LiveBalanceCalculator.SumaSaldoVivo) {
        suma.sumar(cuentaID: cuentaID, entraEnSaldo: entraEnSaldo, fecha: fecha, moneda: monedaNativa, monto: montoNativo)
    }

    func sumarSaldoPorCuenta(a suma: inout AccountBalanceCalculator.SumaSaldosPorCuenta) {
        suma.sumar(cuentaID: cuentaID, fecha: fecha, moneda: monedaNativa, monto: montoNativo)
    }
}
