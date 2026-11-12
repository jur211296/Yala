//
//  RecordsListSearchField.swift
//  Yala
//
//  «Buscar en Registros» (decisión 14 de la revisión 2.3, opción B1, 2026-11-09): un campo arriba de la lista que asoma al
//  tirar hacia abajo, como en Mail o Notas. Busca dentro de lo que ya se ve —período y filtros incluidos— y también por
//  importe (`RecordsListSearchLogic`, aplicado en `RecordsViewModel.applyFilters`). Sin texto que lo compare con la
//  pestaña Buscar.
//
//  No es el cajón de la barra (`.searchable` con `.navigationBarDrawer(displayMode: .automatic)`): en una página de
//  pestaña ese cajón reserva su alto al volver y lo pliega, y el contenido salta (`swiftui-ds.md`,
//  `GroupsSearchDrawerWiringTests`). Por eso vive dentro del scroll, encima de la cabecera, y se enseña al tirar.
//
//  Lo lleva solo Registros: `RecordsTabView` lo monta también Estadísticas › Registros, y ahí el entorno no lo ofrece.
//

import SwiftUI

// MARK: - Entorno

private struct OffersRecordsListSearchKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Registros (`RecordsStandaloneView`) ofrece el campo; Estadísticas › Registros no.
    var offersRecordsListSearch: Bool {
        get { self[OffersRecordsListSearchKey.self] }
        set { self[OffersRecordsListSearchKey.self] = newValue }
    }
}

/// Cuánto hay que tirar de la lista, pasado su borde de arriba, para que asome el campo.
enum RecordsListSearchReveal {
    static let pullDistance: CGFloat = DS.Button.actionSize

    /// `overscroll`: lo que el contenido baja por debajo de su posición de reposo (positivo al tirar hacia abajo).
    static func reveals(overscroll: CGFloat) -> Bool { overscroll >= pullDistance }

    /// Con VoiceOver no hay gesto de tirar: el campo está siempre a la vista. Con texto, también.
    static func isShown(revealed: Bool, hasText: Bool, voiceOver: Bool) -> Bool {
        revealed || hasText || voiceOver
    }
}

// MARK: - El hueco en la lista

/// Va arriba del contenido de `RecordsTabView`. Sin `offersRecordsListSearch`, no pinta nada.
struct RecordsListSearchSlot: View {
    @Environment(\.offersRecordsListSearch) private var offersSearch
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var viewModel: RecordsViewModel
    var onQueryChange: () -> Void

    var body: some View {
        // Contenedor común del campo y de lo que baja por él: entra fundiéndose y la lista se aparta (implícita: dentro
        // de una pestaña un `withAnimation` no anima, `swiftui-ds.md`).
        VStack(spacing: DS.Spacing.none) {
            if offersSearch, RecordsListSearchReveal.isShown(
                revealed: viewModel.isListSearchRevealed,
                hasText: !viewModel.listSearchText.isEmpty,
                voiceOver: voiceOver
            ) {
                RecordsListSearchField(
                    text: $viewModel.listSearchText,
                    onClear: {
                        viewModel.listSearchText = ""
                        viewModel.isListSearchRevealed = false
                    }
                )
                .transition(.opacity)
            }
        }
        .dsAnimation(DS.Animation.appear, value: viewModel.isListSearchRevealed, reduceMotion: reduceMotion)
        .onChange(of: viewModel.listSearchText) { _, _ in onQueryChange() }
    }
}

// MARK: - El campo

private struct RecordsListSearchField: View {
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

// MARK: - Tirar para que asome

extension View {
    /// En el `ScrollView` de `RecordsTabView`: al tirar de la lista hacia abajo estando arriba, asoma el campo.
    func revealsRecordsListSearchOnPull(_ viewModel: RecordsViewModel) -> some View {
        modifier(RecordsListSearchPullModifier(viewModel: viewModel))
    }
}

private struct RecordsListSearchPullModifier: ViewModifier {
    @Environment(\.offersRecordsListSearch) private var offersSearch
    let viewModel: RecordsViewModel

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Bool.self) { geometry in
            RecordsListSearchReveal.reveals(overscroll: -(geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { _, pulled in
            guard offersSearch, pulled, !viewModel.isListSearchRevealed else { return }
            viewModel.isListSearchRevealed = true
        }
    }
}
