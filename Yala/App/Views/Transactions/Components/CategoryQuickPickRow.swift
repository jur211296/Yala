//
//  CategoryQuickPickRow.swift
//  Yala
//
//  Decisión 21 de la revisión 2.3 (Jürgen, 9-nov-2026, C2): bajo el importe de un registro nuevo, las tres categorías que
//  la persona más usa —o las de arranque, mientras no las tenga— y «Más…», que abre la hoja con todas. Un café queda en
//  un toque, sin abrir ninguna hoja.
//

import SwiftData
import SwiftUI

struct CategoryQuickPickRow: View {
    let subcategories: [Subcategory]
    let selected: Subcategory?
    let onSelect: (Subcategory) -> Void
    let onMore: () -> Void

    var body: some View {
        // Las mismas pastillas que los selectores de abajo, en filas que bajan si no caben (texto grande), centradas.
        RecordSelectorChips(spacing: DS.Spacing.sm, alignment: .center) {
            ForEach(subcategories, id: \.persistentModelID) { subcategory in
                let isChosen = subcategory.persistentModelID == selected?.persistentModelID
                SelectionChip(
                    icon: subcategory.iconName ?? "tag.fill",
                    text: subcategory.name,
                    isSelected: isChosen,
                    color: Color(hex: subcategory.colorHex ?? subcategory.safeCategory.colorHex),
                    fillsWhenSelected: true,
                    horizontalPadding: DS.Spacing.md
                ) {
                    // Vibra la opción elegida (`DS.Haptic`, una por gesto); volver a tocar la elegida no hace nada.
                    guard !isChosen else { return }
                    DS.Haptic.selection()
                    onSelect(subcategory)
                }
                .accessibilityIdentifier("new_transaction_quick_category_\(subcategory.name)")
            }

            SelectionChip(
                icon: "ellipsis",
                text: L10n.Subcategory.quickPickMore,
                isSelected: false,
                horizontalPadding: DS.Spacing.md,
                action: onMore
            )
            .accessibilityIdentifier("new_transaction_quick_category_more")
        }
    }
}
