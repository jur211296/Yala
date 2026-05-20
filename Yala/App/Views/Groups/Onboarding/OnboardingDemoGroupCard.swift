//
//  OnboardingDemoGroupCard.swift
//  Yala
//
//  Mock visual de un GroupCardView para el Step 1 del onboarding de Grupos.
//  Read-only: no usa SwiftData ni @Query. La narrativa "debes" la da el label,
//  no el signo del monto — el balance se pasa siempre positivo (abs).
//

import SwiftUI

enum OnboardingDemoBalanceState: Equatable {
    /// "Saldo: S/ 0" — gris neutro.
    case initial
    /// "Debes S/ 25" — destacado en essentialNeed amber.
    case debt
}

struct OnboardingDemoGroupCard: View {

    let balance: Double
    let currencyCode: String
    let state: OnboardingDemoBalanceState

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private var formattedAmount: String {
        appPreferences.currency(abs(balance), currencyCode: currencyCode)
    }

    private var balanceLabel: String {
        switch state {
        case .initial: String(format: L10n.Groups.Onboarding.step1DemoBalanceLabelInitial, formattedAmount)
        case .debt:    String(format: L10n.Groups.Onboarding.step1DemoBalanceLabelDebt, formattedAmount)
        }
    }

    private var amountForegroundStyle: AnyShapeStyle {
        state == .debt
            ? AnyShapeStyle(Color.essentialNeed)
            : AnyShapeStyle(ThemeColor.thPrimaryText)
    }

    private func amountText(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.headline)
            .foregroundStyle(amountForegroundStyle)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .semibold)) // A11Y-DT: mock icon
                    .foregroundStyle(Color.hotPink)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L10n.Groups.Onboarding.step1DemoGroupName)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Text(L10n.Groups.Member.activeCount(3))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: DS.Spacing.sm)

            amountText(balanceLabel)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: 0, radius: DS.Radius.lg)
        .accessibilityElement(children: .combine)
    }
}
