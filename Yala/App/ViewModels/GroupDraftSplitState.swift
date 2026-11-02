//
//  GroupDraftSplitState.swift
//  Yala
//
//  Grupos B, card 5: «Partir» en las hojas de la Bandeja de un gasto de grupo (`GroupExpenseDraftFinalizationSheet` y las
//  dos que piden cuenta). La hoja de hoy más una pastilla «Partir» que abre la tarjeta «Tu parte»; con la tarjeta abierta,
//  «Aprobar» espera a que las líneas cuadren. Sin tocar «Partir», la hoja aprueba como siempre.
//
//  Lo comparten las tres hojas para que la puerta, las líneas iniciales y lo que se aprueba salgan de un solo sitio.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GroupDraftSplitState {

    typealias Line = GroupSplitLinesRecipe.Line

    /// Tu parte del gasto del borrador; `nil` si no se pudo leer.
    private(set) var target: GroupSplitLinesService.Target?
    /// Las líneas de la tarjeta.
    var lines: [Line] = []
    /// La tarjeta está abierta.
    private(set) var isSplitting = false

    /// La hoja enseña «Partir»: misma puerta que el puente.
    var offersSplit: Bool { target?.offersSplit == true }

    /// Lee tu parte del gasto del borrador. Una vez por hoja.
    func load(draft: InboxDraft, context: ModelContext) {
        guard target == nil, let splitID = draft.splitExpenseID else { return }
        do {
            target = try GroupSplitLinesService.target(splitExpenseID: splitID, context: context)
        } catch {
            #if DEBUG
            print("GroupDraftSplitState: Error: \(error)")
            #endif
        }
    }

    /// Abre la tarjeta. Con una receta guardada (el aviso de «no cuadra») abre con ella para arreglarla; si no, una línea
    /// de gasto por tu parte entera con la categoría que ya estuviera elegida en la hoja.
    func start(selectedSubcategoryID: UUID?) {
        guard let target, !isSplitting else { return }
        lines = GroupSplitLinesEntryLogic.initialLines(
            stored: GroupSplitLinesRecipe.parse(target.holder?.splitLinesRaw), share: target.share,
            subcategoryID: selectedSubcategoryID, currencyCode: target.currencyCode)
        isSplitting = true
    }

    /// «Aprobar» con la tarjeta abierta: las líneas cuadran, toda recarga va a una cuenta que el puente acepta y ninguna
    /// va a la cuenta de la que sale (en las hojas que piden cuenta, la elegida; se puede cambiar después de la línea).
    func canApprove(accounts: [Account], sourceAccount: Account? = nil) -> Bool {
        guard let target else { return false }
        let source = sourceAccount ?? target.transferSourceAccount
        return GroupSplitLinesEditorLogic.canSave(
            lines, share: target.share, currencyCode: target.currencyCode,
            destinations: GroupSplitLinesCard.destinationInfo(accounts))
            && !Self.rechargesToItsOwnSource(lines, sourceID: source?.shortcutID)
    }

    /// Alguna recarga va a la cuenta de la que sale.
    static func rechargesToItsOwnSource(_ lines: [Line], sourceID: UUID?) -> Bool {
        guard let sourceID else { return false }
        return lines.contains { $0.kind == .transfer && $0.destinationAccountID == sourceID }
    }

    /// Lo que se manda a `DraftService.approveDraft(splitLines:)`: `nil` con una sola línea de gasto, que se aprueba como
    /// siempre con su categoría.
    var approvalLines: [Line]? {
        GroupSplitLinesRecipe.isSingleExpense(lines) ? nil : lines
    }

    /// La categoría que va en el borrador: la de la única línea (sin receta) o la de la primera de gasto (la ancla del
    /// Caso A, que el puente también le pone a la pata real).
    func draftSubcategory(context: ModelContext) -> Subcategory? {
        let id = GroupSplitLinesEntryLogic.singleExpenseSubcategoryID(lines)
            ?? GroupSplitLinesEntryLogic.anchorSubcategoryID(lines)
        guard let id else { return nil }
        do {
            return try GroupTransactionBridge.subcategory(shortcutID: id, context: context)
        } catch {
            #if DEBUG
            print("GroupDraftSplitState: Error: \(error)")
            #endif
            return nil
        }
    }
}
