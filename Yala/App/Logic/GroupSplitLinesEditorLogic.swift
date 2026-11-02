//
//  GroupSplitLinesEditorLogic.swift
//  Yala
//
//  Lo que decide la tarjeta «Tu parte» (`GroupSplitLinesCard`) y la hoja de una línea (`GroupSplitLineSheet`), Grupos
//  opción B (`docs/disenos/grupos-tu-parte-en-lineas/README.md`, «Versión final acordada»).
//
//  LAS REGLAS DE LA RECETA NO SE REPITEN AQUÍ. Qué línea está mal, si cuadran y si se puede guardar lo dice
//  `GroupSplitLinesRecipe`. Esto añade solo lo que la receta no puede saber:
//   · si la cuenta destino de una recarga SIRVE. El puente (PR #737) solo crea la recarga si la cuenta existe, no es de
//     sistema y lleva la divisa del gasto; si no, deja tu parte en una sola línea SIN AVISAR. Por eso el selector solo
//     ofrece esas cuentas y una línea con un destino que dejó de servir (archivada, borrada, otra divisa) apaga
//     «Guardar». Archivada también fuera: los selectores de la app no ofrecen cuentas archivadas.
//   · el borrador de la hoja: el texto del importe, el tipo y lo elegido para cada tipo.
//
//  Lógica pura: sin SwiftData ni SwiftUI.
//

import Foundation

enum GroupSplitLinesEditorLogic {

    typealias Line = GroupSplitLinesRecipe.Line

    // MARK: - Cuenta destino

    /// Lo que hace falta saber de una cuenta para decidir si puede recibir una recarga.
    struct DestinationInfo: Equatable, Sendable {
        let currencyCode: String
        let isSystemAccount: Bool
        let isArchived: Bool
    }

    /// Una cuenta sirve de destino si es tuya (no de sistema), no está archivada y lleva la divisa del gasto. `nil` = la
    /// cuenta no está en este aparato.
    static func isEligibleDestination(_ info: DestinationInfo?, currencyCode: String) -> Bool {
        guard let info else { return false }
        return !info.isSystemAccount && !info.isArchived && info.currencyCode == currencyCode
    }

    /// Las recargas con una cuenta destino elegida que ya no sirve. Una recarga SIN cuenta no entra: eso ya lo dice la
    /// receta (`.transferWithoutDestination`).
    static func linesWithUnavailableDestination(
        _ lines: [Line], destinations: [UUID: DestinationInfo], currencyCode: String
    ) -> Set<UUID> {
        var result: Set<UUID> = []
        for line in lines where line.kind == .transfer {
            guard let id = line.destinationAccountID else { continue }
            if !isEligibleDestination(destinations[id], currencyCode: currencyCode) { result.insert(line.id) }
        }
        return result
    }

    /// «Guardar» / «Aprobar» de quien monta la tarjeta: lo que pide la receta y, además, que toda recarga vaya a una
    /// cuenta que el puente acepte.
    static func canSave(
        _ lines: [Line], share: Decimal, currencyCode: String, destinations: [UUID: DestinationInfo]
    ) -> Bool {
        GroupSplitLinesRecipe.canSave(lines, share: share, currencyCode: currencyCode)
            && linesWithUnavailableDestination(lines, destinations: destinations, currencyCode: currencyCode).isEmpty
    }

    // MARK: - Editar la lista

    /// Al tocar «Partir»: una sola línea de gasto por tu parte entera, con la categoría que ya tuviera (maqueta,
    /// escenario 1: «cambias la primera línea a Recarga»). Tu parte se redondea a los decimales de la divisa, como la ve
    /// la persona.
    static func initialLines(share: Decimal, subcategoryID: UUID?, currencyCode: String) -> [Line] {
        [.expense(amount: AccountCurrencyPlanLogic.rounded(share, to: currencyCode), subcategoryID: subcategoryID)]
    }

    /// El importe con que abre «Añadir línea»: lo que falta para cuadrar. `nil` si ya cuadra o sobra.
    static func amountForNewLine(_ lines: [Line], share: Decimal, currencyCode: String) -> Decimal? {
        if case .missing(let missing) = GroupSplitLinesRecipe.balance(of: lines, share: share, currencyCode: currencyCode) {
            return missing
        }
        return nil
    }

    /// Sustituye la línea con el mismo id o, si no está, la añade al final.
    static func upserting(_ line: Line, into lines: [Line]) -> [Line] {
        var result = lines
        if let index = result.firstIndex(where: { $0.id == line.id }) {
            result[index] = line
        } else {
            result.append(line)
        }
        return result
    }

    /// Se puede quitar una línea si quedan otras: sin líneas no hay receta (`.noLines`).
    static func canRemove(from lines: [Line]) -> Bool { lines.count > 1 }

    /// Quita la línea `id`. No quita la última.
    static func removing(_ id: UUID, from lines: [Line]) -> [Line] {
        guard canRemove(from: lines) else { return lines }
        return lines.filter { $0.id != id }
    }

    // MARK: - Borrador de la hoja

    /// Lo que la persona tiene escrito en la hoja de una línea. Guarda la categoría y la cuenta a la vez: cambiar de
    /// Gasto a Recarga y volver no pierde lo elegido. Al guardar, cada tipo se lleva solo lo suyo.
    struct Draft: Equatable, Sendable {
        let id: UUID
        var kind: GroupSplitLinesRecipe.Kind
        var amountText: String
        var subcategoryID: UUID?
        var destinationAccountID: UUID?

        /// Para editar una línea que ya existe.
        init(line: Line, currencyCode: String, locale: Locale) {
            id = line.id
            kind = line.kind
            amountText = GroupSplitLinesEditorLogic.fieldText(for: line.amount, currencyCode: currencyCode, locale: locale)
            subcategoryID = line.subcategoryID
            destinationAccountID = line.destinationAccountID
        }

        /// Para una línea nueva: gasto, con lo que falta como importe si falta algo.
        init(id: UUID = UUID(), suggestedAmount: Decimal?, currencyCode: String, locale: Locale) {
            self.id = id
            kind = .expense
            amountText = suggestedAmount.map {
                GroupSplitLinesEditorLogic.fieldText(for: $0, currencyCode: currencyCode, locale: locale)
            } ?? ""
            subcategoryID = nil
            destinationAccountID = nil
        }

        /// La línea que saldría al guardar. Un importe que no se entiende va como 0 para que la receta lo marque.
        func line(locale: Locale) -> Line {
            let amount = GroupSplitLinesEditorLogic.decimal(from: amountText, locale: locale) ?? 0
            switch kind {
            case .expense: return .expense(id: id, amount: amount, subcategoryID: subcategoryID)
            case .transfer: return .transfer(id: id, amount: amount, destinationAccountID: destinationAccountID)
            }
        }
    }

    /// «Guardar línea» se enciende si la receta no ve problemas en esta línea sola y, si es una recarga, su cuenta sirve.
    /// El cuadre no cuenta aquí: lo dice la tarjeta.
    static func canSave(
        _ draft: Draft, currencyCode: String, locale: Locale, destinations: [UUID: DestinationInfo]
    ) -> Bool {
        let line = draft.line(locale: locale)
        return GroupSplitLinesRecipe.problems(in: [line], currencyCode: currencyCode).isEmpty
            && linesWithUnavailableDestination([line], destinations: destinations, currencyCode: currencyCode).isEmpty
    }

    // MARK: - Importe ↔ texto

    /// El texto del campo de importe como `Decimal`, sin pasar por `Double` («500» + «10» tienen que dar «510» exacto).
    /// Acepta los separadores de `locale` y, como `AmountInputHelper.filterAmountInput`, también «.» o «,» como
    /// decimal. `nil` si está vacío o no es un número.
    static func decimal(from text: String, locale: Locale) -> Decimal? {
        let grouping = locale.groupingSeparator ?? ","
        let decimalSeparator = locale.decimalSeparator ?? "."
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        if !grouping.isEmpty, grouping != decimalSeparator { cleaned = cleaned.replacing(grouping, with: "") }
        cleaned = cleaned.replacing(decimalSeparator, with: ".")
        guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              cleaned.filter({ $0 == "." }).count <= 1
        else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// El importe como lo escribiría la persona en el campo: separadores de `locale`, sin decimales si es entero y con
    /// los de la divisa si no («500», «10.50»).
    static func fieldText(for amount: Decimal, currencyCode: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        let digits = AccountCurrencyPlanLogic.fractionDigits(for: currencyCode)
        var input = amount
        var whole = Decimal()
        NSDecimalRound(&whole, &input, 0, .plain)
        let isWhole = whole == amount
        formatter.minimumFractionDigits = isWhole ? 0 : digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? NSDecimalNumber(decimal: amount).stringValue
    }
}
