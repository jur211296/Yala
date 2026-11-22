//
//  RecordsQuickAccountSheet.swift
//  Yala
//
//  La hoja de «Cuenta ▾» en Registros (Jürgen, 15-nov): varias cuentas a la vez, con la misma fila que elige la cuenta
//  en Nuevo registro (`AccountSelectorRow`, tal cual). Tocar una la añade o la quita; al cerrar («Listo» o deslizando)
//  se aplica, como «Más filtros». Lo marcado lo guarda quien presenta la hoja (`RecordsQuickFilterBar`): si iOS rehace
//  su contenido, no se pierde nada.
//

import SwiftData
import SwiftUI

struct RecordsQuickAccountSheet: View {
    /// Las cuentas que se ofrecen: sin archivadas y cada tarjeta una vez, sin sus líneas.
    let accounts: [Account]
    /// Lo marcado: una tarjeta, sin sus líneas (la sesión las vuelve a meter al aplicarlo).
    @Binding var selection: Set<PersistentIdentifier>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDetent: PresentationDetent = .medium

    private let sizing = SelectorSheetSizing.mediumFirst

    var body: some View {
        NavigationStack {
            ScrollView {
                SectionBox(title: "") {
                    VStack(spacing: DS.Spacing.none) {
                        ForEach(Array(accounts.enumerated()), id: \.element.persistentModelID) { index, account in
                            if index > 0 {
                                SubsectionDivider()
                            }
                            AccountSelectorRow(
                                account: account,
                                isSelected: selection.contains(account.persistentModelID)
                            ) {
                                toggle(account.persistentModelID)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .yalaScreenBackground(sizing.background(
                selectedDetent: selectedDetent,
                usesLargeSheets: usesLargeSheets,
                dynamicTypeSize: dynamicTypeSize
            ))
            .navigationTitle(L10n.RecordsQuickFilters23.account)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !selection.isEmpty {
                        YalaToolbarTextButton(L10n.Filters.allAccounts) { clear() }
                            .accessibilityIdentifier("records_quick_account_all")
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                YalaPrimaryButton(L10n.Action.done) { dismiss() }
                    .accessibilityIdentifier("records_quick_account_done")
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
        .selectorSheetSizing(sizing, selectedDetent: $selectedDetent)
    }

    private func toggle(_ id: PersistentIdentifier) {
        DS.Haptic.selection()
        selection = RecordsQuickAccountSelectionLogic.toggled(id, in: selection)
    }

    private func clear() {
        DS.Haptic.selection()
        selection = []
    }
}
