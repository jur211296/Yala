//
//  TransactionDetailSheetLogic.swift
//  Yala
//
//  Pure-logic del sheet de detalle de transacción (Records): detent inicial
//  (medium en ventana compacta / large en ventana ancha) y clasificación visual de la TX. Sin
//  SwiftUI/L10n para tests sin UI ni ModelContext (evita flake R8 documentado
//  en CLAUDE.md → makeTestContext). El mapeo Detent → PresentationDetent vive
//  en TransactionDetailSheet.swift. La fila «Tipo de cambio» decide aquí si pinta un importe o el
//  texto de «sin tipo de cambio para ese día» (`conversionDisplay`).
//

import Foundation

enum TransactionDetailSheetLogic {

    enum Detent: Equatable, Hashable {
        case medium
        case large
    }

    enum Kind: Equatable {
        case expense
        case income
        case transfer
    }

    /// Detent fijo del sheet de detalle: una ventana ancha o Mac fuerzan large
    /// (`\.usesLargeSheets`); una compacta usa medium (quick look). La edición
    /// nunca cambia el detent — abre como sheet aparte (decisión owner).
    static func initialDetent(usesLargeSheets: Bool) -> Detent {
        usesLargeSheets ? .large : .medium
    }

    /// Clasificación visual de la TX. Transfer gana siempre; si no, la
    /// categoría decide y el signo del monto es el fallback — paridad exacta
    /// con RecordRowView.amountColor para que el hero no contradiga a la row.
    static func kind(isTransfer: Bool, categoryIsIncome: Bool?, amount: Double) -> Kind {
        if isTransfer { return .transfer }
        let isIncome = categoryIsIncome ?? (amount >= 0)
        return isIncome ? .income : .expense
    }

    /// Lo que VoiceOver lee de una fila de Registros: las partes que existen, separadas por comas. Sin nota no empieza
    /// por una coma suelta, y el tipo («Gasto», «Ingreso») va antes del importe, que llega ya formateado en la divisa
    /// del propio registro (auditoría UX 2.2, lote 8: leía «S/ 2,000» de una cuenta en dólares y nunca decía si era
    /// gasto o ingreso).
    static func rowAccessibilityLabel(note: String?, kind: String, amount: String, category: String?, account: String?) -> String {
        [note, kind, amount, category, account]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// En un par de transferencia, la TX con monto negativo es el lado origen.
    static func transferOwnAccountIsOrigin(amount: Double) -> Bool {
        amount < 0
    }

    // MARK: - Fila «Tipo de cambio»

    /// Qué pinta la fila «Tipo de cambio» del detalle.
    enum ConversionDisplay: Equatable {
        /// Importe en la divisa principal y la tasa que lo produjo.
        case amount(value: Double, rate: Double)
        /// La conversión no se escribió y no hay tasa del día del registro: la fila lo dice con texto,
        /// nunca con un importe.
        case missingRateForDay
    }

    /// El importe convertido de la fila «Tipo de cambio».
    ///
    /// Con el convertido escrito se lee tal cual, con su tasa guardada. Un `0` con nativo distinto de 0
    /// no es un importe sino una conversión que no se escribió (`CashFlowCalculator.storedConversionIsMissing`):
    /// se reconvierte con la tasa de la fecha del registro por la misma regla que las estadísticas
    /// (`CashFlowCalculator.reconverted`), y solo vale si esa tasa es EXACTA (`approximateMagnitude == 0`).
    /// Una tasa arrastrada de otro día o la tabla estática no son «la tasa de ese día», así que la fila
    /// cae en `missingRateForDay`. Tampoco se pinta nunca un 0 reconvertido.
    static func conversionDisplay(
        for tx: TransactionItem,
        converter: CurrencyConverting
    ) -> ConversionDisplay {
        guard CashFlowCalculator.storedConversionIsMissing(tx) else {
            return .amount(value: tx.amountInPreferredCurrency, rate: tx.exchangeRate)
        }
        let reconverted = CashFlowCalculator.reconverted(
            tx.amount, from: tx.currencyCode, to: tx.preferredCurrencyCode, on: tx.date,
            converter: converter
        )
        guard reconverted.approximateMagnitude == 0, reconverted.value != 0, reconverted.value.isFinite else {
            return .missingRateForDay
        }
        return .amount(value: reconverted.value, rate: abs(reconverted.value / tx.amount))
    }
}
