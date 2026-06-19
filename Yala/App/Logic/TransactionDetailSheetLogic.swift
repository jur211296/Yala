//
//  TransactionDetailSheetLogic.swift
//  Yala
//
//  Pure-logic del sheet de detalle de transacción (Records): detent inicial
//  (medium iPhone / large iPad) y clasificación visual de la TX. Sin
//  SwiftUI/L10n para tests sin UI ni ModelContext (evita flake R8 documentado
//  en CLAUDE.md → makeTestContext). El mapeo Detent → PresentationDetent vive
//  en TransactionDetailSheet.swift.
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

    /// Detent fijo del sheet de detalle: iPad/Mac fuerzan large
    /// (DS.Adaptive.usesLargeSheets); iPhone usa medium (quick look). La edición
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

    /// En un par de transferencia, la TX con monto negativo es el lado origen.
    static func transferOwnAccountIsOrigin(amount: Double) -> Bool {
        amount < 0
    }
}
