//
//  ChatDraftPreviewCard.swift
//  Yala
//
//  Card preview read-only del draft de transacción para el Step 1 del onboarding
//  de Yala AI. Replica el layout visual de `ChatTransactionDraftCard.editableCard`
//  sin dependencia de SwiftData (`@Query` de Account/Subcategory/Tag).
//
//  No es funcional — solo decorativo, parte de la animación dummy del chat preview.
//  Layout intencionalmente igual al real para coherencia al pasar al chat post-onboarding.
//

import SwiftUI

struct ChatDraftPreviewCard: View {

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            Divider()
            rows
        }
        .padding(DS.Spacing.md)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header (chip Gasto + amount mock)

    private var header: some View {
        HStack {
            Text(L10n.Chat.Draft.chipExpense)
                .font(DS.Typography.labelSmall)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Semantic.errorBackground)
                .foregroundStyle(DS.Semantic.errorForeground)
                .clipShape(Capsule())

            Spacer()

            Text("12")
                .font(DS.Typography.title)
                .foregroundStyle(.thPrimaryText)

            Text("PEN")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.thSecondaryText)
        }
    }

    // MARK: - Mock rows (icon + label, read-only)

    private var rows: some View {
        VStack(spacing: DS.Spacing.sm) {
            row(icon: "tag.fill", text: L10n.YalaAI.Onboarding.step1DemoAmountLabel)
            row(icon: "calendar", text: dateLabel)
        }
    }

    private func row(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption) // A11Y-DT: decorative chip icon
                .foregroundStyle(.thSecondaryText)
                .frame(width: 18)
            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(.thPrimaryText)
            Spacer()
        }
    }

    private var dateLabel: String {
        Self.dateFormatter.string(from: .now)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
