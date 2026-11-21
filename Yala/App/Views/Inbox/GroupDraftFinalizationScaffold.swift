//
//  GroupDraftFinalizationScaffold.swift
//  Yala
//
//  Cuerpo compartido de los 3 sheets de finalización de drafts de grupo
//  (GroupExpenseAccountFinalizationSheet, GroupExpenseDraftFinalizationSheet,
//  GroupSettlementDraftFinalizationSheet). Replica el lenguaje visual del editor
//  normal (InboxDraftEditSheet, hoja B1 desde el 2026-11-20): banner explicativo arriba,
//  nota y monto read-only con la cápsula de moneda, la subcategoría por elegir bajo el
//  monto, y abajo una fila de una línea con la fecha y la cuenta que falta. Todo lo que viene del grupo es read-only — el
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
    /// Texto del botón principal; sin él, «Finalizar».
    var finalizeTitle: String? = nil
    /// Acción secundaria opcional bajo el botón principal (el «Dejar en…» del aviso de importe cambiado).
    var secondaryAction: (title: String, action: () -> Void)? = nil
    /// Bloque opcional sobre el selector: «¿Ya lo apuntaste?» con los movimientos parecidos (UX 2.2 · L13-15).
    var accessory: AnyView? = nil
    /// La subcategoría por elegir, bajo el monto como en la hoja B1 de Nuevo registro (el chip relleno de su color).
    var categorySelector: AnyView? = nil
    /// Frase opcional bajo el selector: qué ingreso cobra este pago (Grupos B · card 10).
    var footnote: String? = nil
    /// Selector interactivo de la pieza que falta (un `SelectionChip`).
    @ViewBuilder let selector: () -> Selector

    // MARK: - Scaled metrics

    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 64 // A11Y-DT: @ScaledMetric

    // MARK: - Body

    var body: some View {
        // Con un bloque de movimientos parecidos (L13-15) la hoja ya no cabe en un iPhone SE: el contenido se desplaza y
        // los botones quedan fijos abajo. Cuando cabe, los `Spacer` reparten igual que antes y no hay scroll
        // (molde de `.claude/rules/swiftui-ds.md`, «Una pantalla que reparte su alto con `Spacer`s…»).
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    banner
                        .padding(.top, DS.Spacing.sm)

                    Spacer(minLength: DS.Spacing.lg)
                    centralContent
                    Spacer(minLength: DS.Spacing.lg)

                    if let accessory {
                        accessory
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.lg)
                    }

                    // La fila de abajo de la hoja B1, siempre en una línea: la fecha (la gestiona el grupo, no se toca)
                    // y la pieza que falta. Si no cabe, encoge la cuenta y trunca su nombre.
                    OneLineChipRow(spacing: DS.Spacing.sm) {
                        RecordDateValueChip(text: dateChipText) {}
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("group_draft_date_chip")
                        selector()
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)

                    if let footnote {
                        Label(footnote, systemImage: "arrow.down.left.circle")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.bottom, DS.Spacing.lg)
                            .accessibilityIdentifier("group_draft_footnote")
                    }

                    if let hint {
                        hintView(hint)
                            .padding(.bottom, DS.Spacing.md)
                    }
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.none) {
                YalaPrimaryButton(finalizeTitle ?? L10n.Inbox.GroupDraft.finalize, icon: "checkmark.circle.fill") {
                    onFinalize()
                }
                .disabled(finalizeDisabled)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, secondaryAction == nil ? DS.Spacing.xxl : DS.Spacing.sm)

                if let secondaryAction {
                    YalaSecondaryButton(secondaryAction.title) {
                        secondaryAction.action()
                    }
                    .accessibilityIdentifier("group_draft_secondary_button")
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxl)
                }
            }
            .padding(.top, DS.Spacing.sm)
            // Mismo fondo que la hoja (`.subtle`): lo que pasa por debajo al desplazarse no se lee a través de los botones.
            // Molde del pie de `GroupExpenseFormView`.
            .background(.thBackground)
        }
        // Sheet full-height (sin detents en InboxView) → .subtle, igual que
        // InboxDraftEditSheet. El `.partialSheet` (subtle solo si la ventana fuerza `.large`)
        // es solo para sheets con detents parciales.
        .yalaScreenBackground(.subtle)
    }

    // MARK: - Banner

    private var banner: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccentText)
            Text(bannerMessage)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("group_draft_banner")
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(.thCard))
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Central content (read-only)

    /// Como la hoja B1: la descripción, el monto con su cápsula de moneda (sin menú: la moneda la pone el grupo), la
    /// categoría que ya trae con su puntito o la subcategoría por elegir. La fecha va en la fila de abajo.
    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xl) {
            noteText
            amountDisplay
            if let category = categoryReadOnly {
                categoryLine(category)
            }
            if let categorySelector {
                categorySelector
                    .padding(.horizontal, DS.Spacing.lg)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var noteText: some View {
        Text(note.isEmpty ? "—" : note)
            .recordDescriptionStyle()
    }

    @ViewBuilder
    private var amountDisplay: some View {
        if let amount {
            // Formatea una sola vez por render (el font-size deriva de su longitud).
            let formatted = YalaFormatterStatic.number(value: abs(amount))
            let fontSize = amountFontSize(forLength: formatted.count)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                AmountCurrencyCapsule(
                    label: YalaFormatterStatic.currencyIdentifier(for: currencyCode),
                    options: [],
                    current: currencyCode,
                    identifierPrefix: "group_draft",
                    onChoose: { _ in }
                )
                Text(formatted)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(amountColor)
            }
        }
    }

    /// «● Categoría» de la hoja B1: el puntito de su color y el nombre, en `subheadline` secundario.
    private func categoryLine(_ category: (name: String, iconName: String, colorHex: String)) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(category.name)
                .lineLimit(1)
        }
        .font(DS.Typography.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
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
        Color.amountTint(isIncome: (amount ?? 0) >= 0)
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
