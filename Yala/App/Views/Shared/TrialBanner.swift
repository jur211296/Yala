//
//  TrialBanner.swift
//  Yala
//
//  Banner showing trial status and days remaining.
//

import SwiftUI

struct TrialBanner: View {

    // MARK: - Properties

    let daysRemaining: Int
    let onUpgrade: () -> Void

    // MARK: - Computed

    private var isUrgent: Bool {
        daysRemaining <= 2
    }

    private var iconName: String {
        isUrgent ? "exclamationmark.circle.fill" : "clock.fill"
    }

    private var iconColor: Color {
        isUrgent ? .orange : .blue
    }

    private var daysText: String {
        switch daysRemaining {
        case 0:
            return L10n.Subscription.Trial.endsToday
        case 1:
            return L10n.Subscription.Trial.endsTomorrow
        default:
            return L10n.Subscription.Trial.daysRemaining(daysRemaining)
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: iconName)
                .font(DS.Typography.title)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Subscription.Trial.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.yalaPrimaryText)

                Text(daysText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.yalaSecondaryText)
            }

            Spacer()

            Button {
                onUpgrade()
            } label: {
                Text(L10n.Subscription.Trial.subscribe)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(Color.brandPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(DS.Spacing.md)
        .background(isUrgent ? DS.Semantic.warningBackground : DS.Semantic.infoBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
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
        TrialBanner(daysRemaining: 5) {
            print("Upgrade tapped")
        }

        TrialBanner(daysRemaining: 2) {
            print("Upgrade tapped")
        }

        TrialBanner(daysRemaining: 1) {
            print("Upgrade tapped")
        }

        TrialBanner(daysRemaining: 0) {
            print("Upgrade tapped")
        }
    }
    .padding()
}
