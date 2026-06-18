//
//  GroupDraftFinalizationScaffold.swift
//  Yala
//
//  Cuerpo compartido de los 3 sheets de finalización de drafts de grupo
//  (GroupExpenseAccountFinalizationSheet, GroupExpenseDraftFinalizationSheet,
//  GroupSettlementDraftFinalizationSheet). Replica el lenguaje visual del editor
//  normal (InboxDraftEditSheet): banner explicativo arriba, monto grande centrado,
//  nota y fecha read-only, y un único selector interactivo abajo para la pieza que
//  falta (cuenta o subcategoría). Todo lo que viene del grupo es read-only — el
//  bridge gobierna monto/fecha vía delete+recreate al sincronizar.
//

import SwiftUI

struct GroupDraftFinalizationScaffold<Selector: View>: View {

    // MARK: - Input

    /// Mensaje del banner explicativo (de qué grupo viene + qué falta).
    let bannerMessage: String
    let note: String
    /// Con signo (negativo = gasto/pago, positivo = ingreso/cobro). Read-only.
    let amount: Double?
    let currencyCode: String
    let date: Date
    /// Chip de categoría read-only en el centro (solo cuando el draft ya trae una
    /// subcategoría que NO es la que se está asignando — ej. settlement sistema).
    var categoryReadOnly: (name: String, iconName: String, colorHex: String)? = nil
    /// Bloque warning opcional (causa específica: creado en remoto / cambio de moneda).
    var hint: String? = nil
    let finalizeDisabled: Bool
    let onFinalize: () -> Void
    /// Selector interactivo de la pieza que falta (un `SelectionChip`).
    @ViewBuilder let selector: () -> Selector

    // MARK: - Scaled metrics

    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 64 // A11Y-DT: @ScaledMetric

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            banner
                .padding(.top, DS.Spacing.sm)

            Spacer()
            centralContent
            Spacer()

            HStack(spacing: DS.Spacing.sm) { selector() }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)

            if let hint {
                hintView(hint)
                    .padding(.bottom, DS.Spacing.md)
            }

            YalaPrimaryButton(L10n.Inbox.GroupDraft.finalize, icon: "checkmark.circle.fill") {
                onFinalize()
            }
            .disabled(finalizeDisabled)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        // Sheet full-height (sin detents en InboxView) → .subtle, igual que
        // InboxDraftEditSheet. El idiom-aware `usesLargeSheets ? .subtle : .transparent`
        // es solo para sheets con detents parciales.
        .yalaScreenBackground(.subtle)
    }

    // MARK: - Banner

    private var banner: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)
            Text(bannerMessage)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(.thCard))
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Central content (read-only)

    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            dateChip
            noteText
            amountDisplay
            if let category = categoryReadOnly {
                categoryChip(category)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var dateChip: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "calendar")
                .font(DS.Typography.label)
            Text(dateChipText)
                .font(DS.Typography.label)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(Capsule().fill(Color.primary.opacity(0.08)))
    }

    private var noteText: some View {
        Text(note.isEmpty ? "—" : note)
            .font(DS.Typography.headline)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
    }

    @ViewBuilder
    private var amountDisplay: some View {
        if let amount {
            // Formatea una sola vez por render (el font-size deriva de su longitud).
            let formatted = YalaFormatterStatic.number(value: abs(amount))
            let fontSize = amountFontSize(forLength: formatted.count)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(YalaFormatterStatic.currencyIdentifier(for: currencyCode))
                    .font(.system(size: fontSize * 0.44, weight: .medium, design: .rounded))
                    .foregroundStyle(amountColor.opacity(0.7))
                Text(formatted)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(amountColor)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }

    private func categoryChip(_ category: (name: String, iconName: String, colorHex: String)) -> some View {
        let color = Color(hex: category.colorHex)
        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: category.iconName)
                .font(DS.Typography.labelTiny)
            Text(category.name)
                .font(DS.Typography.labelTiny)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DS.Chip.paddingH)
        .padding(.vertical, DS.Chip.paddingV)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Hint (warning)

    private func hintView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Semantic.warningForeground)
            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(DS.Semantic.warningBackground))
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Helpers

    private var amountColor: Color {
        (amount ?? 0) < 0 ? Color.hotPink : Color.electricIndigo
    }

    /// Escala el tamaño del monto según la longitud del string formateado (réplica de
    /// `InboxDraftEditSheet.amountFontSize`).
    private func amountFontSize(forLength length: Int) -> CGFloat {
        let ratio: CGFloat
        switch length {
        case 0...7: ratio = 1.0
        case 8...9: ratio = 54.0 / 64.0
        case 10...11: ratio = 46.0 / 64.0
        case 12...13: ratio = 38.0 / 64.0
        default: ratio = 32.0 / 64.0
        }
        return baseAmountSize * ratio
    }

    private var dateChipText: String {
        if Calendar.current.isDateInToday(date) {
            return L10n.Date.today
        } else if Calendar.current.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            return GroupDraftDateFormatter.medium.string(from: date)
        }
    }
}

// Static stored properties no se permiten en tipos genéricos → formatter en un enum aparte.
private enum GroupDraftDateFormatter {
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = AppLocale.current
        return f
    }()
}

#Preview {
    GroupDraftFinalizationScaffold(
        bannerMessage: "Gasto del grupo Siu. Solo asígnale la cuenta de la que salió el dinero; el monto y la fecha los gestiona el grupo.",
        note: "Taxi",
        amount: -40,
        currencyCode: "PEN",
        date: .now,
        categoryReadOnly: nil,
        hint: nil,
        finalizeDisabled: true,
        onFinalize: {}
    ) {
        SelectionChip(icon: "creditcard", text: "Cuenta de origen", isSelected: false) {}
    }
}
