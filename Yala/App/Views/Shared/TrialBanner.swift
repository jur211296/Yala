//
//  TrialBanner.swift
//  Yala
//
//  Banner showing trial status and days remaining.
//

import StoreKit
import SwiftUI

struct TrialBanner: View {

    // MARK: - Properties

    let daysRemaining: Int

    @State private var showManageSubscription = false

    /// «Te quedan 3 días de prueba · después $29.99 al año». Sin precio cargado, o con la renovación apagada (entonces
    /// no se cobra nada después), solo los días.
    private var line: String {
        let store = StoreKitManager.shared
        let days = L10n.UXPro.bannerDaysLeft(daysRemaining)
        guard let plan = store.activePlan, plan.willAutoRenew != false,
              let price = store.displayPrice(yearly: plan.nextChargeIsYearly) else { return days }
        let then = plan.nextChargeIsYearly ? L10n.UXPro.bannerThenYearly(price) : L10n.UXPro.bannerThenMonthly(price)
        return days + " · " + then
    }

    // MARK: - Body

    /// Una línea, solo los últimos 5 días, con «Gestionar» (UX 2.2 · L17-7). Antes salía los 30 días con
    /// «Suscribirse», un botón que a quien ya está suscrito (la prueba de Apple ya es la suscripción) le llevaba a
    /// «Eres Yala Pro». «Gestionar» abre la hoja de Apple, donde se cambia de plan o se cancela.
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "clock")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(line)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("trial_banner_line")

            Spacer(minLength: DS.Spacing.sm)

            Button {
                showManageSubscription = true
            } label: {
                Text(L10n.UXPro.bannerManage)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thAccent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trial_banner_manage")
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
    }
}

// MARK: - L10n Extension for Trial

extension L10n.Subscription {
    enum Trial {
        static var title: String {
            NSLocalizedString("subscription.trial.title", comment: "Trial banner title")
        }
        static var endsToday: String {
            NSLocalizedString("subscription.trial.endsToday", comment: "Trial ends today")
        }
        static var endsTomorrow: String {
            NSLocalizedString("subscription.trial.endsTomorrow", comment: "Trial ends tomorrow")
        }
        static func daysRemaining(_ days: Int) -> String {
            String(
                format: NSLocalizedString("subscription.trial.daysRemaining", comment: ""),
                days
            )
        }
        static var subscribe: String {
            NSLocalizedString("subscription.trial.subscribe", comment: "Subscribe button")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        TrialBanner(daysRemaining: 5)
        TrialBanner(daysRemaining: 1)
        TrialBanner(daysRemaining: 0)
    }
    .padding()
}
