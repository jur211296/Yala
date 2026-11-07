//
//  GroupDraftSplitCard.swift
//  Yala
//
//  Grupos B, card 5: las dos piezas de «Partir» en las hojas de la Bandeja de un gasto de grupo. La pastilla «Partir» va
//  junto a las de la hoja (maqueta `opcion-b.html`, escenario 1, pantalla 2) y la tarjeta «Tu parte» ocupa su sitio al
//  tocarla, con la línea resumen debajo («Debes S/ 510 a Pía · Sip sube S/ 500»). El estado lo lleva
//  `GroupDraftSplitState`.
//

import SwiftUI

/// La pastilla «Partir».
struct GroupDraftSplitChip: View {
    let action: () -> Void

    var body: some View {
        SelectionChip(icon: "scissors", text: L10n.Groups.SplitLines.splitAction, isSelected: false, action: action)
            .accessibilityIdentifier("group_draft_split_button")
    }
}

/// La tarjeta «Tu parte» de la hoja. `sourceAccount`: en las hojas que piden cuenta (pagaste tú), la cuenta elegida, de
/// la que sale una recarga; en la del Caso B la recarga sale de «Grupos».
struct GroupDraftSplitCard: View {
    @Bindable var state: GroupDraftSplitState
    var sourceAccount: Account? = nil

    var body: some View {
        if let target = state.target {
            VStack(spacing: DS.Spacing.md) {
                GroupSplitLinesCard(
                    lines: $state.lines,
                    share: target.share,
                    currencyCode: target.currencyCode,
                    transferSourceName: sourceAccount?.name ?? target.transferSourceName,
                    transferSourceAccount: sourceAccount ?? target.transferSourceAccount
                )
                GroupSplitLinesSummaryLine(target: target, lines: state.lines)
            }
        }
    }
}
