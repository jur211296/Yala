//
//  GroupSaleBridgeLogic.swift
//  Yala
//
//  Grupos B · cards 7 y 8 (versión final acordada el 2026-11-01, `docs/disenos/grupos-tu-parte-en-lineas/README.md`): un
//  gasto de grupo que pagaste tú con una categoría de INGRESO es una venta. No salió dinero de ninguna cuenta, y lo que te
//  deben queda «por cobrar» en tu cuenta «Grupos»: suma a su saldo (sigue coincidiendo con el del grupo) y Estadísticas no
//  lo cuenta como ingreso hasta que te paguen.
//
//  La pata por cobrar lleva `balanceAdjustmentType = "receivable"` (`TransactionItem.adjustmentTypeReceivable`). Con eso la
//  dejan fuera todas las superficies que ya excluyen ajustes y transferencias (medido el 2026-11-02: 52 `== nil` en
//  `Yala/`, ver el Paso 0 del encargo `2026-11-02-grupos-b-ventas-por-cobrar`). **Un sitio que lea `!= nil` como «es una
//  recarga» tiene que mirar el valor**: la reversión de la pata conservada lo hacía (`revertsKeptLeg`).
//
//  Los demás miembros no ven nada nuevo: para ellos es un gasto normal que pagaste tú. En su aparato la categoría de
//  ingreso NO clasifica su parte (`classifiesShare`), o su `−120` contaría como ingreso.
//

import Foundation

nonisolated enum GroupSaleBridgeLogic {

    /// Por debajo de medio céntimo no hay nada por cobrar (mismo umbral que `GroupExpenseSuccessLogic`).
    static let epsilon = 0.005

    /// El valor de `balanceAdjustmentType` de una pata por cobrar (`TransactionItem.adjustmentTypeReceivable`).
    static let receivableType = "receivable"

    /// Venta = pagaste tú y la categoría del gasto resuelve a una subcategoría de ingreso del usuario.
    /// - Parameters:
    ///   - isCaseA: pagaste tú.
    ///   - subcategoryIsIncome: la categoría de la subcategoría que casó por nombre; `nil` si no casó ninguna.
    ///   - subcategoryIsSystem: la subcategoría es de sistema (esas nunca deciden nada).
    static func isSale(isCaseA: Bool, subcategoryIsIncome: Bool?, subcategoryIsSystem: Bool) -> Bool {
        isCaseA && subcategoryIsIncome == true && !subcategoryIsSystem
    }

    /// `false` si la subcategoría del gasto no puede clasificar tu parte: una de ingreso fuera de una venta (pagó otro).
    /// Tu parte de un gasto es un gasto; con la categoría de ingreso contaría como ingreso.
    static func classifiesShare(isSale: Bool, subcategoryIsIncome: Bool?) -> Bool {
        isSale || subcategoryIsIncome != true
    }

    /// La pata por cobrar de una venta. La escribe entera el puente (importe, fecha y categoría salen del gasto en cada
    /// pasada), así que el editor, el lote y el menú la tratan como una pata derivada: todo bloqueado y «se edita desde el
    /// grupo» (review adversarial de la card 8: el editor dejaba cambiar la categoría y el puente la pisaba).
    static func isReceivable(_ adjustmentType: String?) -> Bool {
        adjustmentType == receivableType
    }

    /// Lo que queda por cobrar: el gasto menos tu parte. `nil` si nadie te debe nada.
    static func receivableAmount(total: Double, myShare: Double) -> Double? {
        let owed = total - max(0, myShare)
        return owed >= epsilon ? owed : nil
    }

    /// Si la pata que el puente conserva tiene que volver a ser tu parte en una línea (sin tipo ni categoría) antes de
    /// seguir: la de una recarga que ya no lo es, o la de una venta que dejó de serlo.
    /// - Parameters:
    ///   - currentType: su `balanceAdjustmentType`.
    ///   - isSale: esta pasada es una venta.
    ///   - isCaseA: pagaste tú.
    ///   - anchorIsTransfer: la receta de esta pasada la usa como recarga (solo en el Caso B).
    static func revertsKeptLeg(currentType: String?, isSale: Bool, isCaseA: Bool, anchorIsTransfer: Bool) -> Bool {
        guard let currentType else { return false }
        if currentType == receivableType { return !isSale }
        if isSale { return true }
        return isCaseA || !anchorIsTransfer
    }
}

/// En qué tipo abre el selector de categoría (Grupos B · card 7). Con las de ingreso a la vista, en el de lo que ya está
/// elegido: abrir en «Gasto» con «Ventas» puesta escondería la selección.
enum SubcategorySelectorTypeLogic {
    static func initialType(requested: TransactionType, offersIncome: Bool, selectedIsIncome: Bool?) -> TransactionType {
        guard offersIncome, let selectedIsIncome else { return requested }
        return selectedIsIncome ? .income : .expense
    }
}

/// Lo COBRADO de una venta de grupo (Grupos B · card 10). La pata por cobrar guarda solo lo que falta; cada parte cobrada es
/// una pata de ingreso normal en «Grupos», con la categoría de la venta y la fecha del movimiento que la cubrió
/// (`GroupReceivableCoverageLogic`), marcada en `splitLinesRaw` (`GroupSplitLinesRecipe.Stored.collected`). Estadísticas la
/// cuenta como ingreso ese día; el saldo de «Grupos» suma lo mismo que antes (por cobrar + cobrado = lo que te debían).
enum GroupCollectedLegLogic {

    /// `true` si `splitLinesRaw` marca una pata cobrada de una venta.
    static func isCollected(_ raw: String?) -> Bool {
        collectedEventID(raw) != nil
    }

    /// El movimiento (gasto o liquidación del grupo) que cubrió esta parte de la venta, o `nil`.
    static func collectedEventID(_ raw: String?) -> UUID? {
        if case let .collected(eventID) = GroupSplitLinesRecipe.parse(raw) { return eventID }
        return nil
    }

    /// Una pata de venta que escribe entera el puente —la por cobrar o una cobrada—: el editor, el lote y el menú la tratan
    /// como derivada (todo bloqueado, «se edita desde el grupo»).
    static func isBridgeWrittenSaleLeg(adjustmentType: String?, splitLinesRaw: String?) -> Bool {
        GroupSaleBridgeLogic.isReceivable(adjustmentType) || isCollected(splitLinesRaw)
    }
}

/// La frase de la hoja de pago de la Bandeja (Grupos B · card 10): qué venta cobra este pago y que cuenta como ingreso ese
/// día. «Cobras «Venta de zapatillas»: S/ 120.00 de Ventas cuentan como ingreso hoy.»
enum GroupSettlementCollectedLineLogic {

    /// La fecha de un pago que no es de hoy, en el idioma de la app («8 nov 2026»).
    static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Lo que un pago cobra de UNA venta.
    struct Part: Equatable, Sendable {
        let saleName: String
        let categoryName: String?
        let amount: Double
    }

    /// `nil` si el pago no cobra ninguna venta (es una devolución, como siempre).
    /// - Parameters:
    ///   - parts: una por venta, en el orden en que el pago las cubre.
    ///   - date: la fecha del pago, que es la del ingreso.
    ///   - formatAmount: el importe con su divisa.
    ///   - formatDate: la fecha, para un pago que no es de hoy.
    static func line(
        parts: [Part],
        date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        formatAmount: (Double) -> String,
        formatDate: (Date) -> String
    ) -> String? {
        let parts = parts.filter { $0.amount >= GroupSaleBridgeLogic.epsilon }
        guard !parts.isEmpty else { return nil }
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let total = formatAmount(parts.reduce(0) { $0 + $1.amount })
        // Una venta con su categoría: «Cobras «X»: S/ 120.00 de Ventas…». Varias (o una sin categoría legible): sin
        // nombres, que en una lista no se citan bien en todos los idiomas.
        if parts.count == 1, let part = parts.first, let category = part.categoryName, !category.isEmpty {
            return isToday
                ? L10n.Inbox.GroupSettlementDraft.collectsOneToday(part.saleName, total, category)
                : L10n.Inbox.GroupSettlementDraft.collectsOneOn(part.saleName, total, category, formatDate(date))
        }
        return isToday
            ? L10n.Inbox.GroupSettlementDraft.collectsManyToday(total)
            : L10n.Inbox.GroupSettlementDraft.collectsManyOn(total, formatDate(date))
    }
}
