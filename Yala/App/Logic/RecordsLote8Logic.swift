//
//  RecordsLote8Logic.swift
//  Yala
//
//  Decisiones sin vistas de la auditoría UX 2.2, lote 8 (Registros): qué enseña una fila, cómo se nombra el registro
//  que se va a borrar, de dónde salen «Pagaste / Tu parte / Te deben» en un gasto de grupo y qué dice el aviso tras
//  cambiar la subcategoría. Las vistas solo las cablean.
//

import Foundation

// MARK: - La fila (L8-3)

enum RecordRowPresentationLogic {

    /// El tono del importe de una fila. El ingreso lleva su color y el gasto el del texto (L4-14); las
    /// transferencias y los ajustes de saldo van en gris: mueven dinero entre cuentas o corrigen un saldo, y en rosa
    /// o en el color de un ingreso se leían como un gasto o como dinero que entra.
    enum AmountStyle: Equatable { case income, expense, neutral }

    static func amountStyle(isBalanceAdjustment: Bool, isIncome: Bool) -> AmountStyle {
        if isBalanceAdjustment { return .neutral }
        return isIncome ? .income : .expense
    }

    /// La categoría de la fila. La pata de una venta de grupo que aún no te pagan añade «Por cobrar» (Grupos B · card 8):
    /// sin la palabra, un `+120` gris en «Grupos» no se explica. El gris ya lo da su tipo. Lo ya cobrado añade «Cobrado»
    /// (card 10): un ingreso en «Grupos» que no es una devolución.
    static func categoryCaption(_ name: String, adjustmentType: String?, splitLinesRaw: String? = nil) -> String {
        if adjustmentType == TransactionItem.adjustmentTypeReceivable { return "\(name) • \(L10n.Records.receivable)" }
        if GroupCollectedLegLogic.isCollected(splitLinesRaw) { return "\(name) • \(L10n.Records.collected)" }
        return name
    }

    /// La píldora de necesidad (Esencial, Prioritaria, Opcional) solo en los gastos. En un ingreso, un saldo inicial,
    /// una transferencia o la parte que te deben en un grupo la necesidad no aplica, y la píldora salía con «Sin
    /// clasificación», que parecía un error.
    static func showsNeedPill(isBalanceAdjustment: Bool, isIncome: Bool, subcategoryIsSystem: Bool) -> Bool {
        !isBalanceAdjustment && !isIncome && !subcategoryIsSystem
    }
}

// MARK: - Borrar (L8-7)

enum RecordDeleteConfirmationLogic {

    /// Cómo se llama el registro en la pregunta: su nota, si tiene; si no, su subcategoría o su categoría. `nil` si no
    /// tiene nada, y la vista dice «este registro».
    static func displayName(note: String?, subcategoryName: String?, categoryName: String?) -> String? {
        for candidate in [note, subcategoryName, categoryName] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    /// «Uber · S/ 26»: el nombre y el importe, como se ve en la fila.
    static func summary(name: String, amount: String) -> String {
        "\(name) · \(amount)"
    }
}

// MARK: - Gasto de grupo (L8-5)

/// «Pagaste S/ 80 · Tu parte S/ 40 · Te deben S/ 40» a partir de las patas que el puente de grupos guarda con el mismo
/// gasto (`GroupBridgeStatsAdjustment` explica la anatomía): la pata REAL en tu cuenta vale lo que pagaste, y las de
/// préstamo en la cuenta de sistema de Grupos, lo que te deben. Tu parte es la resta, la misma que suman Estadísticas.
enum GroupExpenseBreakdownLogic {

    struct Leg: Equatable {
        let amount: Double
        let isSystemAccount: Bool
        /// Grupos B: pata derivada de una línea de tu parte (en «Grupos», con la marca de línea). Es parte de tu parte.
        var isSplitLineLeg: Bool = false
    }

    struct Breakdown: Equatable {
        /// Lo que salió de tu cuenta. `nil` cuando pagó otra persona.
        let youPaid: Double?
        /// Tu parte del gasto.
        let yourShare: Double
        /// Lo que el grupo te debe por haberlo pagado tú. `nil` si no te deben nada.
        let owedToYou: Double?
    }

    /// `nil` si las patas no permiten explicar nada sin inventar (ninguna de coste a la vista).
    static func breakdown(legs: [Leg]) -> Breakdown? {
        let real = legs.filter { !$0.isSystemAccount && !$0.isSplitLineLeg }
        let loans = legs.filter { $0.isSystemAccount && $0.amount > 0 }
        let systemCost = legs.filter { $0.isSystemAccount && $0.amount <= 0 && !$0.isSplitLineLeg }
        // Grupos B: las líneas derivadas de tu parte, en «Grupos» (negativas). El préstamo las incluye en el Caso A, y en
        // el Caso B suman a la pata conservada.
        let splitLines = legs.filter { $0.isSplitLineLeg && $0.isSystemAccount }.reduce(0) { $0 + $1.amount }

        if let realLeg = real.first {
            let owed = loans.reduce(0) { $0 + $1.amount } + splitLines
            return Breakdown(
                youPaid: abs(realLeg.amount),
                yourShare: abs(realLeg.amount + owed),
                owedToYou: owed > 0 ? owed : nil
            )
        }
        // Sin pata en tu cuenta (pagó otra persona, o el gasto no llegó a tu cuenta): la pata de coste en Grupos ya vale
        // tu parte. «Pagaste» no se dice: aquí no se sabe quién pagó.
        if let cost = systemCost.first {
            return Breakdown(youPaid: nil, yourShare: abs(cost.amount + splitLines), owedToYou: nil)
        }
        return nil
    }
}

// MARK: - Cambiar la subcategoría (L8-9)

enum SubcategoryChangeNoticeLogic {

    /// El aviso nombra la categoría y la necesidad solo si la necesidad cambió con la subcategoría (decisión de
    /// Jürgen, 2026-10-15): es lo que no se ve en la fila y cambia lo que suman Estadísticas por necesidad.
    static func mentionsNeed(old: SubcategoryNeed?, new: SubcategoryNeed?) -> Bool {
        guard let new else { return false }
        return old != new
    }
}
