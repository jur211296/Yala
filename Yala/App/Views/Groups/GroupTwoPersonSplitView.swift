//
//  GroupTwoPersonSplitView.swift
//  Yala
//
//  Pre-pantalla de split rápido para grupos de DOS personas (estilo Splitwise): las 4
//  combinaciones más comunes de (pagador × reparto), con su saldo resultante. "Más opciones"
//  baja al editor detallado (GroupSplitSelectorView). Escribe estado válido del ViewModel vía
//  `applyTwoPersonChoice` — sin modelo de datos propio.
//
//  Desde el 2026-11-26 (pedido de Jürgen: «está un poco fea… podría ser un detent medium»): abre a
//  media altura y las cuatro opciones van en una rejilla 2×2 de tarjetas, una fila por quién pagó
//  («Pagaste tú» / «Pagó Pia») y una columna por cómo se reparte (partes iguales / es todo de uno).
//  Con texto de accesibilidad, una columna; la hoja se estira a grande si no cabe.
//

import SwiftUI

struct GroupTwoPersonSplitView: View {

    @Bindable var viewModel: GroupExpenseViewModel
    /// Baja esta sheet y sube el editor detallado (dismiss-then-present en el form).
    let onMoreOptions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesLargeSheets) private var usesLargeSheets

    @State private var selectedDetent: PresentationDetent = .medium

    /// Nombre de la otra persona (la deuda y las acciones "es todo de X" se refieren a ella).
    private var otherName: String { viewModel.otherActiveMemberName }

    /// A media altura, el cristal del sistema; en grande, el fondo del tema (regla «Ninguna hoja con fondo gris»).
    private var isLargeDetent: Bool { selectedDetent == .large || usesLargeSheets }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    payerSection(
                        header: GruposPulidoDivisionDetalleText.youPaidHeader,
                        choices: [.iPaidEqual, .iPaidOwedFull]
                    )
                    payerSection(
                        header: GruposPulidoDivisionDetalleText.theyPaidHeader(otherName),
                        choices: [.theyPaidEqual, .theyPaidOwedFull]
                    )
                    moreOptionsButton
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(L10n.Groups.Expense.TwoPerson.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Options

    private func payerSection(header: String, choices: [TwoPersonSplitOptions.Choice]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(header)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(choices) { optionTile($0) }
                }
            } else {
                // Mismo alto para las dos tarjetas de la fila aunque una tenga el texto más largo.
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    ForEach(choices) { optionTile($0) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func optionTile(_ choice: TwoPersonSplitOptions.Choice) -> some View {
        let isActive = viewModel.activeTwoPersonChoice == choice
        let subtitle = debtSubtitle(for: choice)
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        return Button {
            DS.Haptic.selection()
            viewModel.applyTwoPersonChoice(choice)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .top) {
                    Image(systemName: iconName(for: choice))
                        .font(DS.Typography.headline)
                        .foregroundStyle(theme.accentText)
                        .accessibilityHidden(true)
                    Spacer(minLength: DS.Spacing.xs)
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .font(DS.Typography.headline)
                        .foregroundStyle(isActive ? AnyShapeStyle(theme.accentText) : AnyShapeStyle(.tertiary))
                        .accessibilityHidden(true)
                }
                Text(tileTitle(for: choice))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DS.Spacing.md)
            .background(.thCard, in: shape)
            .overlay {
                shape.strokeBorder(theme.accentText, lineWidth: isActive ? 2 : 0)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: choice, subtitle: subtitle))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var moreOptionsButton: some View {
        Button {
            onMoreOptions()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "slider.horizontal.3")
                Text(L10n.Groups.Expense.TwoPerson.moreOptions)
            }
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(theme.accentText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text helpers

    /// Lo que va en grande en la tarjeta: cómo se reparte (quién pagó ya lo dice la cabecera de la fila).
    private func tileTitle(for choice: TwoPersonSplitOptions.Choice) -> String {
        switch choice {
        case .iPaidEqual, .theyPaidEqual: return L10n.Split.typeEqual
        case .iPaidOwedFull: return GruposPulidoDivisionDetalleText.allFor(otherName)
        case .theyPaidOwedFull: return GruposPulidoDivisionDetalleText.allForMe
        }
    }

    private func iconName(for choice: TwoPersonSplitOptions.Choice) -> String {
        switch choice {
        case .iPaidEqual, .theyPaidEqual: return GroupSplitLabelLogic.iconName(for: .equal)
        case .iPaidOwedFull, .theyPaidOwedFull: return GroupSplitLabelLogic.iconName(for: .allForMe)
        }
    }

    /// Saldo resultante. `nil` con monto vacío → la tarjeta muestra solo la acción (consistente
    /// con el footer del editor detallado, que oculta la línea de monto cuando amount == 0).
    private func debtSubtitle(for choice: TwoPersonSplitOptions.Choice) -> String? {
        guard viewModel.amount > 0 else { return nil }
        let amount = TwoPersonSplitOptions.debt(for: choice, total: viewModel.amount).amount
        let amountStr = appPreferences.currency(amount, currencyCode: viewModel.currencyCode)
        return choice.debtText(otherName: otherName, amountStr: amountStr)
    }

    /// VoiceOver lee la acción entera («Pagó Pia · partes iguales. Le debes S/ 107.00 a Pia»), como antes.
    private func accessibilityLabel(for choice: TwoPersonSplitOptions.Choice, subtitle: String?) -> String {
        let title = choice.actionTitle(otherName: otherName)
        guard let subtitle else { return title }
        return "\(title). \(subtitle)"
    }
}
