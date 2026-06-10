//
//  TransactionDetailSheetLogic.swift
//  Yala
//
//  Pure-logic del sheet de detalle de transacción (Records): decisiones de
//  detents, swap detalle→edición y clasificación visual de la TX. Sin
//  SwiftUI/L10n para tests sin UI ni ModelContext (evita flake R8 documentado
//  en CLAUDE.md → makeTestContext). El mapeo Detent → PresentationDetent vive
//  en TransactionDetailSheet.swift.
//

import Foundation

enum TransactionDetailSheetLogic {

    enum Mode: Equatable {
        case detail
        case edit
    }

    enum Detent: Equatable, Hashable {
        case medium
        case large
    }

    enum Kind: Equatable {
        case expense
        case income
        case transfer
    }

    /// iPad/Mac fuerzan sheets a large (DS.Adaptive.usesLargeSheets) — el
    /// detalle abre directo en large ahí; en iPhone abre en medium (quick look).
    static func initialDetent(usesLargeSheets: Bool) -> Detent {
        usesLargeSheets ? .large : .medium
    }

    /// El detalle en iPhone permite medium↔large (el drag a large convierte a
    /// edición); en edición o en iPad el sheet queda fijo en large.
    static func availableDetents(mode: Mode, usesLargeSheets: Bool) -> [Detent] {
        if mode == .detail && !usesLargeSheets {
            return [.medium, .large]
        }
        return [.large]
    }

    /// Drag-to-edit: solo en iPhone, solo desde el detalle, solo al llegar a
    /// large. En iPad el sheet ya vive en large y el único camino a edición es
    /// el botón Editar (decisión owner).
    static func shouldSwitchToEdit(newDetent: Detent, mode: Mode, usesLargeSheets: Bool) -> Bool {
        newDetent == .large && mode == .detail && !usesLargeSheets
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
