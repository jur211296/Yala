//
//  InboxGroupDraftHiddenHereLogic.swift
//  Yala
//
//  Quitar de la Bandeja, SOLO en este teléfono, un gasto de grupo cuyo grupo no está aquí.
//  Ticket `prior-icloud-group-records-summed-without-their-group`.
//

import Foundation

/// Las decisiones puras de «Quitar de aquí» en la Bandeja.
///
/// **De dónde salen estos borradores.** Al volver a iCloud y elegir «Sumarlos a mis datos», las filas de grupo de antes se
/// suman tal cual (decisión de `reverse-to-icloud-merges-prior-icloud-data-without-asking`): en iCloud pueden ser de otro
/// dispositivo con el mismo Apple ID que SÍ tiene esos grupos. En este teléfono el grupo no está, así que la Bandeja
/// enseña gastos de grupo que nadie puede explicar, y un borrador `.groupExpense` no se rechaza ni se borra
/// (`DraftSourceType.blocksInboxDismissal`).
///
/// **Por qué la salida no es rechazar ni borrar.** Las dos cambian la fila, y la fila viaja por el espejo de iCloud y por
/// el canal de la nube: en el otro dispositivo el borrador del Caso A (`[.account]`) es lo único que crea la pata real del
/// gasto, y rechazarlo o borrarlo allí se la quitaría. La salida es **ocultarlo en este teléfono**: una lista local de
/// gastos (`InboxGroupDraftsHiddenHere`) que no viaja a ningún sitio y no cambia ninguna fila.
///
/// **Por qué no espera a que el canal de Grupos esté al día.** Ocultar es reversible: si el grupo llega después, el
/// borrador vuelve a salir solo (`isHidden` exige que el grupo siga sin estar). Esperar al canal dejaría sin salida, para
/// siempre, a quien no tiene sesión de Grupos, que es justo la persona de este caso.
enum InboxGroupDraftHiddenHereLogic {

    struct DraftShape: Equatable {
        let sourceType: DraftSourceType
        let status: DraftStatus
        /// El gasto de grupo al que apunta el borrador (`splitExpenseID`). Es la clave de la lista: el otro dispositivo
        /// crea borradores NUEVOS del mismo gasto al re-puentear, y con la clave del borrador volverían a salir.
        let expenseID: String?
        /// El grupo existe en este teléfono: hay un `SplitGroup` de su zona o el `SplitExpense` del gasto.
        let groupExistsHere: Bool
    }

    /// ¿Se ofrece «Quitar de aquí»? Solo para un gasto de grupo pendiente, con gasto conocido y sin su grupo aquí.
    static func canHideHere(_ draft: DraftShape) -> Bool {
        draft.sourceType == .groupExpense
            && draft.status == .pending
            && !(draft.expenseID ?? "").isEmpty
            && !draft.groupExistsHere
    }

    /// ¿Está oculto ahora? Mientras su gasto esté en la lista y el grupo siga sin estar aquí. Si el grupo llega, vuelve a
    /// salir sin que nadie lo pida: con el grupo, el borrador ya tiene quien lo explique.
    static func isHidden(_ draft: DraftShape, hiddenExpenseIDs: Set<String>) -> Bool {
        guard canHideHere(draft), let expenseID = draft.expenseID else { return false }
        return hiddenExpenseIDs.contains(expenseID)
    }
}
