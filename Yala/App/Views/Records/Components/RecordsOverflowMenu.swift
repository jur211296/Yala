//
//  RecordsOverflowMenu.swift
//  Yala
//
//  Menú "···" de la toolbar de Registros: consolida Seleccionar + Filtrar +
//  "Identificar duplicados" (toggle con checkmark nativo) y un submenú "Coincidir
//  por" con los 4 criterios. Compartido por RecordsStandaloneView y por el tab
//  Registros de DetailContainerView. El punto rosa de filtros activos vive aquí.
//

import SwiftUI

struct RecordsOverflowMenu: View {
    @Bindable var viewModel: RecordsViewModel

    var body: some View {
        Menu {
            Button {
                viewModel.enterSelectionMode()
            } label: {
                Label(L10n.Action.select, systemImage: "checklist")
            }
            .accessibilityIdentifier("records_select_button")

            Button {
                viewModel.showFiltersSheet = true
            } label: {
                Label(L10n.Filters.title, systemImage: "line.3.horizontal.decrease")
            }
            .accessibilityIdentifier("filters_toolbar_button")

            Section {
                Toggle(isOn: $viewModel.duplicateModeActive) {
                    Label(L10n.Records.Duplicates.menuTitle, systemImage: "doc.on.doc")
                }

                Menu {
                    Toggle(L10n.Common.amount, isOn: $viewModel.duplicateCriteria.amount)
                    Toggle(L10n.Transaction.note, isOn: $viewModel.duplicateCriteria.note)
                    Toggle(L10n.Transaction.subcategory, isOn: $viewModel.duplicateCriteria.subcategory)
                    Toggle(L10n.Common.date, isOn: $viewModel.duplicateCriteria.date)
                } label: {
                    Label(L10n.Records.Duplicates.matchBy, systemImage: "slider.horizontal.3")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.thToolbarIcon)
        }
        // Iconos de los items del menú en color primary (el ellipsis conserva
        // su color por el foregroundStyle explícito del label).
        .tint(.primary)
        .filterBadge(isActive: viewModel.activeFilterCount > 0)
        .accessibilityLabel(L10n.Common.moreOptions)
    }
}
