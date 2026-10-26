//
//  SegmentFilterChoiceSheet.swift
//  Yala
//
//  Tocar un segmento de una gráfica PREGUNTA qué hacer con él: «Ver solo X», «Ocultar X» y «Cancelar» a la vista
//  (propuesta A de Jürgen del 2026-10-25, ticket `stats-filter-segment-tap-should-ask-include-or-exclude`). Hasta ese
//  día el toque escribía en el modo activo sin preguntar: con «excluir» puesto, tocar un segmento lo excluía y no había
//  forma de ver solo ese.
//
//  Solo pregunta si hay algo oculto (decisión de Jürgen del 2026-10-26, card `segmento-solo-preguntar…-kjzs`): sin
//  nada oculto el toque hace lo de siempre sin hoja — «Ver solo X», o quitar el filtro si X ya se veía solo.
//
//  Es una hoja corta propia y no un `.alert` ni un `confirmationDialog`: los botones de un `.alert` no admiten texto
//  dinámico («Ver solo Comida») sin romper flujos ajenos, y un `confirmationDialog` anclado no pinta «Cancelar» en iOS 26
//  (las dos trampas, medidas, en `swiftui-ds.md`).
//
//  La pide cualquier vista con `@Environment(\.askSegmentFilter)`; la presenta el host que cuelga
//  `.segmentFilterChoiceHost()` (Panel y Distribución).
//

import SwiftUI

/// Lo que se pregunta al tocar un segmento.
struct SegmentFilterChoice: Identifiable {
    let id = UUID()
    let target: SegmentFilterTarget
    /// El nombre del segmento: «Comida».
    let name: String
    /// El importe del segmento ya formateado, para la cabecera («Comida · S/ 1.240»). `nil`: solo el nombre.
    var amountText: String? = nil
    /// Cómo está hoy en el filtro de su dimensión. Decide qué opciones se ofrecen.
    let membership: EntityFilterMembership
    /// «Ver solo X». Lo pone la pantalla: cada una tiene su manera (Distribución, al ver solo una categoría, quita las
    /// subcategorías elegidas; el Panel recuerda si la categoría salió de una subcategoría).
    let showOnly: () -> Void
    /// «Ocultar X». `nil`: `SessionState.hide`.
    var hide: (() -> Void)? = nil
    /// «Quitar el filtro». `nil`: `SessionState.clearFilter`.
    var clear: (() -> Void)? = nil
}

/// Qué opciones ofrece la pregunta según cómo esté hoy el segmento.
enum SegmentFilterChoiceLogic {
    enum Action: Equatable {
        case showOnly
        case hide
        case clear
    }

    /// Sin filtro: ver solo u ocultar. Ya visto solo: ocultarlo o quitar el filtro. Ya oculto: verlo solo o quitar el
    /// filtro. «Cancelar» va siempre, aparte.
    static func actions(for membership: EntityFilterMembership) -> [Action] {
        switch membership {
        case .none: return [.showOnly, .hide]
        case .included: return [.hide, .clear]
        case .excluded: return [.showOnly, .clear]
        }
    }

    /// Lo que hace el toque sin preguntar, o `nil` si hay que preguntar. Con algo oculto en cualquier dimensión, pregunta
    /// siempre. Sin nada oculto, el toque de antes de la pregunta: ver solo lo tocado, o quitarlo si ya se veía solo.
    static func directAction(for membership: EntityFilterMembership, hasHiddenFilters: Bool) -> Action? {
        guard !hasHiddenFilters else { return nil }
        switch membership {
        case .none: return .showOnly
        case .included: return .clear
        // Algo oculto es un filtro oculto: no llega aquí con `hasHiddenFilters` en falso. Si llegara, que pregunte.
        case .excluded: return nil
        }
    }
}

// MARK: - Entorno

private struct AskSegmentFilterKey: EnvironmentKey {
    static let defaultValue: ((SegmentFilterChoice) -> Void)? = nil
}

extension EnvironmentValues {
    /// Pide la pregunta «Ver solo / Ocultar» de un segmento. `nil` fuera de un host: la vista hace lo de antes.
    var askSegmentFilter: ((SegmentFilterChoice) -> Void)? {
        get { self[AskSegmentFilterKey.self] }
        set { self[AskSegmentFilterKey.self] = newValue }
    }
}

extension View {
    /// Monta la pregunta para todo lo que cuelga de esta vista.
    func segmentFilterChoiceHost() -> some View {
        modifier(SegmentFilterChoiceHostModifier())
    }
}

private struct SegmentFilterChoiceHostModifier: ViewModifier {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var choice: SegmentFilterChoice?

    func body(content: Content) -> some View {
        content
            .environment(\.askSegmentFilter) { newChoice in
                DS.Haptic.selection()
                if let action = SegmentFilterChoiceLogic.directAction(
                    for: newChoice.membership, hasHiddenFilters: sessionState.hasExcludedFilters
                ) {
                    perform(action, on: newChoice)
                } else {
                    choice = newChoice
                }
            }
            .sheet(item: $choice) { current in
                SegmentFilterChoiceSheet(choice: current) { action in
                    choice = nil
                    perform(action, on: current)
                } onCancel: {
                    choice = nil
                }
            }
    }

    private func perform(_ action: SegmentFilterChoiceLogic.Action, on current: SegmentFilterChoice) {
        dsWithAnimation(reduceMotion) {
            switch action {
            case .showOnly: current.showOnly()
            case .hide:
                if let hide = current.hide { hide() } else { sessionState.hide(current.target) }
            case .clear:
                if let clear = current.clear { clear() } else { sessionState.clearFilter(current.target) }
            }
        }
    }
}

// MARK: - La hoja

struct SegmentFilterChoiceSheet: View {
    let choice: SegmentFilterChoice
    let onAction: (SegmentFilterChoiceLogic.Action) -> Void
    let onCancel: () -> Void

    @Environment(\.yalaTheme) private var theme
    @State private var contentHeight: CGFloat = 0

    private var header: String {
        guard let amount = choice.amountText else { return choice.name }
        return "\(choice.name) · \(amount)"
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.none) {
                Text(header)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .padding(.horizontal, DS.Spacing.lg)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("segment_filter_title")

                ForEach(SegmentFilterChoiceLogic.actions(for: choice.membership), id: \.self) { action in
                    Divider()
                    actionButton(action)
                }
            }
            .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))

            Button(action: onCancel) {
                Text(L10n.Action.cancel)
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accentText)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .accessibilityIdentifier("segment_filter_cancel")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .yalaScreenBackground(.partialSheet)
        .yalaSheetDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func actionButton(_ action: SegmentFilterChoiceLogic.Action) -> some View {
        let (title, color, identifier): (String, Color, String) = {
            switch action {
            case .showOnly: return (L10n.SegmentFilter.showOnly(choice.name), theme.accentText, "segment_filter_show_only")
            case .hide: return (L10n.SegmentFilter.hide(choice.name), DS.Semantic.errorForeground, "segment_filter_hide")
            case .clear: return (L10n.SegmentFilter.clear, theme.accentText, "segment_filter_clear")
            }
        }()
        Button {
            onAction(action)
        } label: {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, DS.Spacing.lg)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
