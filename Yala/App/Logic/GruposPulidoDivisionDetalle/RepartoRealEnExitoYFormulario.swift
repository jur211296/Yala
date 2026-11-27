//
//  RepartoRealEnExitoYFormulario.swift
//  Yala
//
//  La etiqueta real del reparto, fuera del detalle (encargo del 2026-11-27). La pantalla de éxito al guardar un gasto
//  de grupo decía «Partes iguales» en un «es todo de Pia» (tipo `equal` con una sola persona con parte), y VoiceOver
//  leía lo mismo en la pieza «y dividido…» del formulario. Las dos usan ahora `GroupSplitLabelLogic`, como el detalle.
//

import Foundation

extension GruposPulidoDivisionDetalleText {

    /// La etiqueta del reparto a partir del tipo guardado y de las partes reales.
    /// - Parameters:
    ///   - splitType: el tipo guardado (`SplitType.rawValue`).
    ///   - shares: memberID y monto de cada parte; vacío si aún no hay monto.
    ///   - currentMemberID: quién eres; `nil` si la identidad no se resolvió.
    ///   - name: resuelve el nombre de un miembro para «Todo de …».
    static func splitLabel(
        splitType: String?,
        shares: [(memberID: String, amount: Double)],
        currentMemberID: String?,
        name: (String) -> String
    ) -> String {
        let kind = GroupSplitLabelLogic.kind(splitType: splitType, shares: shares, currentMemberID: currentMemberID)
        return splitLabel(for: kind, name: name)
    }
}

extension GroupExpenseSuccessData {

    /// El tipo de reparto que dicen las partes guardadas.
    var splitKind: GroupSplitLabelLogic.Kind {
        GroupSplitLabelLogic.kind(
            splitType: splitType.rawValue,
            shares: participants.map { (memberID: $0.id, amount: $0.amount) },
            currentMemberID: currentUserMemberID
        )
    }

    /// Lo que se pinta y se lee en la fila «Reparto» del éxito.
    var splitLabel: String {
        GruposPulidoDivisionDetalleText.splitLabel(for: splitKind) { memberID in
            participants.first { $0.id == memberID }?.name ?? "—"
        }
    }

    /// Una sola persona con parte lleva el icono de persona del detalle; el resto, el de su tipo, como antes.
    var splitIconName: String {
        switch splitKind {
        case .allForMe, .allFor: return GroupSplitLabelLogic.iconName(for: splitKind)
        default: return splitType.iconName
        }
    }
}
