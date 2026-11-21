//
//  RecordsListSearchField.swift
//  Yala
//
//  El campo de búsqueda en cápsula de cristal que nació con «Buscar en Registros» (decisión 14 de la revisión 2.3). Desde
//  el 20-nov-2026 la lista de Registros ya no lo lleva (Jürgen: la pestaña Buscar cumple esa función); lo usa la hoja
//  «Reusar» de Pagos planificados, siempre a la vista. La regla de qué casa vive en `RecordsListSearchLogic`.
//

import SwiftUI

// MARK: - El campo

/// Lo usa, siempre a la vista, la hoja de «Reusar» de Pagos planificados (encargo del 17-nov).
struct RecordsListSearchField: View {
    @Binding var text: String
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(
                L10n.RecordsListSearch.placeholder,
                text: $text,
                prompt: Text(L10n.RecordsListSearch.placeholder)
            )
            .font(DS.Typography.body)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityIdentifier("records_list_search_field")
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: DS.Button.actionSize, minHeight: DS.Button.actionSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.RecordsListSearch.clear)
            .accessibilityIdentifier("records_list_search_clear")
        }
        .padding(.leading, DS.Spacing.md)
        .frame(minHeight: DS.Button.actionSize)
        .glassEffect(.regular, in: .capsule)
    }
}
