//
//  AccountFormUXLogic.swift
//  Yala
//
//  Cálculos puros del formulario de cuenta de la auditoría UX 2.2, lote 7:
//  la pantalla «Editar el saldo» (L7-6), el saldo que queda al cambiar la moneda (L7-7)
//  y la sugerencia de moneda para el Panel (L7-8).
//

import Foundation

// MARK: - L7-6 · Editar el saldo

/// Lo que pasa con el saldo cuando la persona escribe cuánto tiene de verdad hoy.
///
/// **Una sola entrada para las dos formas de corregir.** La persona escribe su saldo de HOY, y las dos
/// opciones de «¿Cómo lo corregimos?» llegan al mismo saldo final por caminos distintos:
/// - **con un registro de ajuste**: se añade un registro por la diferencia;
/// - **corrigiendo el saldo de partida**: el saldo inicial sube o baja en esa misma diferencia y no se
///   añade nada.
///
/// Antes el modo «Cambiar saldo inicial» pedía con cuánto EMPEZÓ la cuenta, y quien escribía su saldo de hoy
/// obtenía otro distinto (B7). Con la diferencia como dato común, el número que se escribe es siempre el
/// que la persona conoce.
enum AccountBalanceCorrectionLogic {

    struct Plan: Equatable, Sendable {
        /// Lo que Yala calcula hoy con los registros de la cuenta.
        let current: Double
        /// Lo que la persona dice que tiene hoy.
        let target: Double
        /// `target − current`: lo que hay que sumar (o restar) para cuadrar.
        let difference: Double
        /// El saldo de partida que deja la segunda opción: el de ahora más la diferencia.
        let newInitialBalance: Double
        /// El saldo de partida de ahora.
        let currentInitialBalance: Double

        /// Las dos opciones dejan la cuenta en el saldo escrito: es lo que dice «Al guardar, … queda en».
        var resultingBalance: Double { target }

        /// Por debajo de un céntimo no hay nada que corregir (el mismo umbral que el guardado).
        var needsCorrection: Bool { abs(difference) > Self.threshold }

        static let threshold = 0.01
    }

    /// - Parameters:
    ///   - current: el saldo de hoy según los registros.
    ///   - currentInitialBalance: la suma de los registros de «Saldo inicial» de la cuenta (0 si no hay).
    ///   - target: lo que la persona escribió, ya con su signo.
    static func plan(current: Double, currentInitialBalance: Double, target: Double) -> Plan {
        let difference = target - current
        return Plan(
            current: current,
            target: target,
            difference: difference,
            newInitialBalance: currentInitialBalance + difference,
            currentInitialBalance: currentInitialBalance
        )
    }
}

// MARK: - L7-7 · El saldo al cambiar la moneda

/// El saldo de la cuenta tal como quedará después de convertir sus registros a la moneda nueva.
///
/// Cada registro se convierte con el tipo de cambio de SU fecha —igual que `convertHistory`—, así que el
/// saldo convertido no es «saldo × tipo de hoy»: es la suma de cada registro convertido. La función de
/// conversión entra por parámetro para que el aviso use la misma que escribe y el test no necesite tasas.
enum AccountCurrencyBalancePreviewLogic {

    struct Row: Equatable, Sendable {
        let amount: Double
        let currencyCode: String
        let date: Date
    }

    struct Preview: Equatable, Sendable {
        /// El saldo de hoy, en la moneda de antes (suma cruda de los registros, como `currentBalance`).
        let before: Double
        /// El saldo después de convertir, redondeado a los decimales de la moneda nueva.
        let after: Double
        /// Todas las filas se convirtieron con el tipo exacto de su día. Si no, la cifra sale con «≈».
        let isExact: Bool
    }

    /// - Parameter convert: convierte un importe de una moneda a otra en una fecha; devuelve el importe y si el
    ///   tipo era el exacto de ese día.
    static func preview(
        rows: [Row],
        to target: String,
        convert: (_ amount: Double, _ from: String, _ to: String, _ date: Date) -> (amount: Decimal, isExact: Bool)
    ) -> Preview {
        let targetCode = normalizeCurrencyCode(target)
        var before = Decimal(0)
        var after = Decimal(0)
        var exact = true
        for row in rows {
            before += Decimal(row.amount)
            let source = normalizeCurrencyCode(row.currencyCode)
            if source == targetCode {
                after += Decimal(row.amount)
                continue
            }
            let converted = convert(row.amount, source, targetCode, row.date)
            after += converted.amount
            if !converted.isExact { exact = false }
        }
        let rounded = AccountCurrencyPlanLogic.rounded(after, to: targetCode)
        return Preview(
            before: (before as NSDecimalNumber).doubleValue,
            after: (rounded as NSDecimalNumber).doubleValue,
            isExact: exact
        )
    }
}

// MARK: - L7-8 · Ver la moneda nueva en el Panel

/// Qué se le ofrece a quien crea una cuenta en una moneda que no es la suya.
///
/// El Panel enseña como mucho dos monedas secundarias. Con hueco, se ofrece añadirla; con las dos ocupadas
/// —el caso que antes callaba—, se ofrece cambiar una de ellas por la nueva.
enum SecondaryCurrencySuggestionLogic {

    static let limit = 2

    enum Suggestion: Equatable, Sendable {
        /// Hay hueco: «¿Quieres ver en tu Panel cuánto vale 1 EUR en PEN?».
        case add(String)
        /// Ya hay dos: «¿Cambias una por MXN?», con las dos de ahora.
        case replace(new: String, current: [String])
    }

    /// - Parameters:
    ///   - saved: la moneda de la cuenta guardada.
    ///   - preferred: la moneda principal de la persona.
    ///   - stored: el valor de la preferencia `secondaryCurrencies` (códigos separados por comas).
    static func suggestion(saved: String, preferred: String, stored: String) -> Suggestion? {
        let code = normalizeCurrencyCode(saved)
        guard code != normalizeCurrencyCode(preferred) else { return nil }
        let existing = parse(stored)
        guard !existing.contains(code) else { return nil }
        if existing.count < limit { return .add(code) }
        return .replace(new: code, current: Array(existing.prefix(limit)))
    }

    /// El valor nuevo de `secondaryCurrencies` tras aceptar.
    /// - Parameter replacing: la que sale (solo en `.replace`); `nil` en `.add`.
    static func applying(_ new: String, replacing old: String?, to stored: String) -> String {
        var existing = parse(stored)
        let code = normalizeCurrencyCode(new)
        if let old {
            let oldCode = normalizeCurrencyCode(old)
            if let index = existing.firstIndex(of: oldCode) {
                existing[index] = code
            } else if existing.count < limit {
                existing.append(code)
            }
        } else if !existing.contains(code) {
            existing.append(code)
        }
        var seen: Set<String> = []
        return existing.filter { seen.insert($0).inserted }.joined(separator: ",")
    }

    static func parse(_ stored: String) -> [String] {
        stored.split(separator: ",")
            .map { normalizeCurrencyCode($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }
}
