//
//  PlanningIntroPages.swift
//  Yala
//
//  Las páginas cortas (patrón E2 del prototipo oficial v35) de los pasos 3 y 4 de Primeros pasos 2.3: tres partes que
//  avanzan solas cada 3,4 s (quietas con Reducir movimiento o VoiceOver), con el botón para empezar y «Omitir este paso»
//  siempre a la vista. Los importes y nombres son de ejemplo (la ficha: los datos del prototipo son solo para mostrar) y
//  van en la moneda de la persona.
//

import SwiftData
import SwiftUI

/// Pie común: el botón de empezar y «Omitir este paso».
private struct PlanningIntroFooter: View {
    let start: String
    let startID: String
    let skipID: String
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            YalaPrimaryButton(start, action: onStart)
                .accessibilityIdentifier(startID)
                .primerosPasosButtonText()
            Button(L10n.PrimerosPasos23.Record.skipStep, action: onSkip)
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier(skipID)
        }
    }
}

/// Título y frase de una parte.
private struct PlanningIntroHeading: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.welcomeHeadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Un aviso de ejemplo de Yala (como una notificación).
private struct PlanningExamplePush: View {
    let text: String

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(theme.accent))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(verbatim: "Yala").font(DS.Typography.subheadline.weight(.semibold))
                Text(text)
                    .font(DS.Typography.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Paso 3 · Qué es un presupuesto

struct FirstBudgetIntroPage: View {
    @Binding var part: Int
    /// Las categorías de gasto de la persona: la primera es la de ejemplo y las seis primeras salen en la parte 2.
    let examples: [Category]
    let currencyCode: String
    let onBack: () -> Void
    let onStart: () -> Void
    let onSkip: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private typealias T = L10n.PrimerosPasos23.Budget

    var body: some View {
        TutorialStoryPage(
            eyebrow: L10n.PrimerosPasos23.Account.introEyebrow,
            count: 3,
            part: $part,
            onBack: onBack,
            content: { index in partView(index) },
            footer: {
                PlanningIntroFooter(
                    start: T.introCta, startID: "first_budget_start", skipID: "first_budget_skip_step",
                    onStart: onStart, onSkip: onSkip)
            }
        )
    }

    private var example: Category? { examples.first }
    private var exampleName: String { example?.name ?? T.nameFallback }
    private var exampleLook: (icon: String, color: Color) {
        (example?.iconName ?? "chart.pie.fill", example.map { Color(hex: $0.colorHex) } ?? theme.accent)
    }

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: currencyCode)
    }

    private func demoCard(spent: Double, limit: Double, header: String) -> some View {
        FirstBudgetCardPreview(
            name: exampleName,
            isNamePlaceholder: false,
            look: exampleLook,
            caption: L10n.PrimerosPasos23.Plan.spentOfLimit(money(spent), money(limit)),
            limit: limit,
            spent: spent,
            currencyCode: currencyCode,
            alert: nil,
            header: header
        )
    }

    @ViewBuilder
    private func partView(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            switch index {
            case 0:
                PlanningIntroHeading(title: T.introPart1Title, message: T.introPart1Message(money(600)))
                demoCard(spent: 386, limit: 600, header: T.introPart1Card)
            case 1:
                PlanningIntroHeading(title: T.introPart2Title, message: T.introPart2Message)
                categoriesExample
            default:
                PlanningIntroHeading(title: T.introPart3Title, message: T.introPart3Message)
                PlanningExamplePush(text: T.introPart3Push(exampleName, money(150)))
                demoCard(spent: 642, limit: 600, header: T.introPart3Card)
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    /// Unas categorías de gasto de la persona, con la primera, la tercera y la quinta marcadas: «tú eliges qué cuenta».
    private var categoriesExample: some View {
        let shown = Array(examples.prefix(6))
        return FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(Array(shown.enumerated()), id: \.offset) { offset, category in
                let isOn = offset % 2 == 0
                let color = Color(hex: category.colorHex)
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: category.iconName ?? "tag.fill").foregroundStyle(color).accessibilityHidden(true)
                    Text(category.name).font(DS.Typography.subheadline.weight(.semibold))
                    if isOn {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(color).accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule().fill(theme.card)
                        .overlay(Capsule().strokeBorder(isOn ? color : .clear, lineWidth: 1.5))
                )
            }
        }
    }
}

// MARK: - Paso 4 · Qué son los pagos planificados

struct FirstScheduledPaymentIntroPage: View {
    @Binding var part: Int
    let currencyCode: String
    let onBack: () -> Void
    let onStart: () -> Void
    let onSkip: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private typealias T = L10n.PrimerosPasos23.Payment

    var body: some View {
        TutorialStoryPage(
            eyebrow: L10n.PrimerosPasos23.Account.introEyebrow,
            count: 3,
            part: $part,
            onBack: onBack,
            content: { index in partView(index) },
            footer: {
                PlanningIntroFooter(
                    start: T.introCta, startID: "first_payment_start", skipID: "first_payment_skip_step",
                    onStart: onStart, onSkip: onSkip)
            }
        )
    }

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: currencyCode)
    }

    @ViewBuilder
    private func partView(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            switch index {
            case 0:
                PlanningIntroHeading(title: T.introPart1Title, message: T.introPart1Message)
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(T.introPart1Caption).font(DS.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
                    FirstPaymentRowPreview(name: T.exampleRent, icon: "key.fill", color: Color(hex: "#475569"),
                                           due: L10n.UXL10.stateInDays(22), amount: money(1200), isEstimate: false)
                    FirstPaymentRowPreview(name: T.exampleLight, icon: "bolt.fill", color: Color(hex: "#475569"),
                                           due: L10n.UXL10.stateInDays(3), amount: money(80), isEstimate: true)
                    FirstPaymentRowPreview(name: T.exampleMusic, icon: "play.circle.fill", color: Color(hex: "#A855F7"),
                                           due: L10n.UXL10.stateTomorrow, amount: money(19.9), isEstimate: false)
                }
            case 1:
                PlanningIntroHeading(title: T.introPart2Title, message: T.introPart2Message)
                VStack(spacing: DS.Spacing.sm) {
                    FirstPaymentRowPreview(name: T.exampleMusic, icon: "play.circle.fill", color: Color(hex: "#A855F7"),
                                           due: nil, amount: money(19.9), isEstimate: false)
                    HStack(spacing: DS.Spacing.sm) {
                        Text(T.inboxLater)
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Capsule().fill(theme.card))
                        Text(L10n.Action.save)
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(theme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Capsule().fill(theme.accent))
                    }
                    .accessibilityHidden(true)
                }
            default:
                PlanningIntroHeading(title: T.introPart3Title, message: T.introPart3Message)
                // El texto real de los avisos de pago (`notifications.scheduledPayment.*`).
                PlanningExamplePush(text: L10n.Notifications.ScheduledPayment.dueTomorrow(T.exampleMusic, money(19.9)))
                PlanningExamplePush(text: L10n.Notifications.ScheduledPayment.dueSoon(3, T.exampleRent, money(1200)))
            }
        }
        .padding(.top, DS.Spacing.md)
    }
}

/// La fila de un pago (como `ScheduledPaymentRowView`): icono, nombre, cuándo y el monto.
struct FirstPaymentRowPreview: View {
    let name: String
    let icon: String
    let color: Color
    let due: String?
    let amount: String
    let isEstimate: Bool

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        // A tamaños de accesibilidad el monto baja bajo el nombre (molde de `ScheduledPaymentRowView`).
        AdaptiveRowStack(spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(color))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name).font(DS.Typography.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let due {
                    Text(due).font(DS.Typography.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Text((isEstimate ? "≈ " : "") + "−" + amount)
                .font(DS.Typography.subheadline.weight(.semibold))
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityElement(children: .combine)
    }
}
