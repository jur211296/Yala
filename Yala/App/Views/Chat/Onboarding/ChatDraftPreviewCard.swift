//
//  ChatDraftPreviewCard.swift
//  Yala
//
//  Card preview read-only del draft de transacción para el Step 1 del onboarding
//  de Yala AI. Replica el layout visual de `ChatTransactionDraftCard.editableCard`
//  (propuesta A, 2026-10-04) sin dependencia de SwiftData (`@Query` de Account/Subcategory/Tag).
//
//  No es funcional — solo decorativo, parte de la animación dummy del chat preview.
//  Layout intencionalmente igual al real para coherencia al pasar al chat post-onboarding.
//

import SwiftUI

struct ChatDraftPreviewCard: View {

    @Environment(\.yalaTheme) private var theme

    // Misma forma que la card real desde el 2026-10-04 (propuesta A): la fila del registro, una píldora y el pie.
    // Todo es texto: aquí nada se toca. El importe sigue a lo que dice el mensaje del escenario («$12»).
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            HStack(spacing: DS.ListRow.spacing) {
                ZStack {
                    Circle().fill(DS.Semantic.successForeground)
                    Image(systemName: "fork.knife")
                        .font(DS.Typography.label)
                        .foregroundStyle(.white)
                }
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
                .accessibilityHidden(true)
                Text(L10n.YalaAI.Onboarding.step1DemoAmountLabel)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                Spacer(minLength: DS.Spacing.sm)
                Text(Decimal(12), format: .currency(code: "USD"))
                    .font(DS.Typography.headline)
                    .monospacedDigit()
            }
            .padding(.top, DS.ListRow.paddingV)
            .padding(.bottom, DS.Spacing.sm)
            .padding(.horizontal, DS.ListRow.paddingH)

            Text(L10n.Date.today)
                .font(DS.Typography.labelSmall)
                .padding(.horizontal, DS.Chip.paddingH)
                .padding(.vertical, DS.Chip.paddingV)
                .background(Capsule().fill(.quaternary))
                .padding(.leading, DS.ListRow.paddingH + DS.ListRow.iconSize + DS.ListRow.spacing)
                .padding(.bottom, DS.Spacing.md)

            Divider()

            HStack(spacing: DS.Spacing.md) {
                Text(L10n.Chat.Draft.discardButton)
                    .foregroundStyle(.secondary)
                Text(L10n.Chat.Draft.detailsButton)
                    .foregroundStyle(theme.accent)
                Spacer()
                Text(L10n.Chat.Draft.saveButton)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(theme.accent))
                    .foregroundStyle(Color.contrastingText(for: theme.accent))
            }
            .font(DS.Typography.label)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(.thCard))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
