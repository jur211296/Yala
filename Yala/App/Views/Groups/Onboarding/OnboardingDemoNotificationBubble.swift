//
//  OnboardingDemoNotificationBubble.swift
//  Yala
//
//  Mock estilo iOS push notification para el Step 1 del onboarding de Grupos.
//  Read-only: cuerpo construido con String(format:) sobre key positional
//  `step1DemoNotifTemplate` para permitir reorder por locale.
//

import SwiftUI

struct OnboardingDemoNotificationBubble: View {

    let memberName: String
    let formattedAmount: String
    let groupName: String

    @Environment(\.yalaTheme) private var theme

    private var notificationBody: String {
        String(format: L10n.Groups.Onboarding.step1DemoNotifTemplate,
               memberName, formattedAmount, groupName)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image("YalaIconBranded")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Yala")
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.thPrimaryText)
                Text(notificationBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: 0, radius: DS.Radius.lg)
        .accessibilityElement(children: .combine)
    }
}
