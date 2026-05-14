//
//  GroupDraftReadOnlyHeader.swift
//  Yala
//
//  Componente compartido entre GroupExpenseDraftFinalizationSheet y
//  GroupSettlementDraftFinalizationSheet. Renderea el header read-only:
//  badge "Grupo: %@", note headline, monto + fecha.
//

import SwiftUI

struct GroupDraftReadOnlyHeader: View {

    let groupName: String
    let note: String
    let amount: Double?
    let currencyCode: String
    let date: Date
    let iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: iconName)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.thAccent)
                Text(String(format: L10n.Inbox.GroupDraft.fromGroup, groupName))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Text(note.isEmpty ? "—" : note)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            HStack {
                if let amount {
                    Text(YalaFormatterStatic.currency(
                        value: abs(amount),
                        currencyCode: currencyCode
                    ))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                }
                Spacer()
                Text(date, format: .dateTime.day().month().year())
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
        .padding(.horizontal, DS.Spacing.lg)
    }
}
