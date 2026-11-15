//
//  GroupDraftLinkCandidatesView.swift
//  Yala
//
//  UX 2.2 · L13-15 (decisión B de Jürgen, 2026-10-18): «¿Ya lo apuntaste?» con los movimientos del mismo día, divisa e
//  importe que el gasto de grupo (`DraftService.groupExpenseLinkCandidates`). Tocar uno lo enlaza con el gasto.
//  Va dentro de las hojas que piden la cuenta de un gasto que pagaste tú; sin candidatos no se pinta.
//

import SwiftUI
import SwiftData

struct GroupDraftLinkCandidatesView: View {

    let candidates: [TransactionItem]
    let onPick: (TransactionItem) -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Inbox.GroupDraft.linkTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.Inbox.GroupDraft.linkHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.sm) {
                ForEach(candidates, id: \.persistentModelID) { tx in
                    row(tx)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_draft_link_candidates")
    }

    private func row(_ tx: TransactionItem) -> some View {
        let accountName = tx.account?.name ?? ""
        let title = tx.note.flatMap { $0.isEmpty ? nil : $0 } ?? tx.subcategory?.name ?? accountName
        let time = tx.date.formatted(date: .omitted, time: .shortened)
        let detail = [accountName, time].filter { !$0.isEmpty }.joined(separator: " · ")
        let amount = appPreferences.currency(abs(tx.amount), currencyCode: tx.currencyCode)
        return Button {
            onPick(tx)
        } label: {
            rowContent(title: title, detail: detail, amount: amount)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(.thCard))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L10n.Inbox.GroupDraft.linkRowHint)
        .accessibilityIdentifier("group_draft_link_candidate")
    }

    /// Con texto de accesibilidad el importe baja bajo el nombre: a su lado se partía en tres líneas («S/ / 120.0 / 0»)
    /// y el nombre quedaba en «La Luc…» (lote 05 de 2.3, zona 38 P7). A tamaño normal, la fila de siempre.
    @ViewBuilder
    private func rowContent(title: String, detail: String, amount: String) -> some View {
        let icon = Image(systemName: "link")
            .font(DS.Typography.subheadline)
            .foregroundStyle(.thAccentText)
            .accessibilityHidden(true)
        let amountText = Text(amount)
            .font(DS.Typography.headline)
            .foregroundStyle(.primary)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.md) {
                    icon
                    // Con la fila entera para el nombre, que use dos líneas antes que cortarse («La Lucha Sang…»).
                    labels(title: title, detail: detail, lineLimit: 2)
                }
                amountText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS.Spacing.md) {
                icon
                labels(title: title, detail: detail, lineLimit: 1)
                Spacer(minLength: DS.Spacing.sm)
                amountText
            }
        }
    }

    private func labels(title: String, detail: String, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
            Text(detail)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
        }
    }
}
