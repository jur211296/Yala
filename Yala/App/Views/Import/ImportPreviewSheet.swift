//
//  ImportPreviewSheet.swift
//  Yala
//
//  «Revisa antes de importar» (auditoría UX 2.2, lote 7, L7-15): qué va a entrar, en qué cuenta, entre qué
//  fechas y cuánto suma, las primeras filas y las que no van a entrar (L7-17). Nada se guarda hasta «Importar».
//

import SwiftUI

struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: ImportPreview
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                        summaryCard
                        if !preview.sampleRows.isEmpty {
                            sampleSection
                        }
                        if !preview.failures.isEmpty || preview.ignoredFutureCount > 0 {
                            failuresSection
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.lg)
                }

                VStack(spacing: DS.Spacing.sm) {
                    if preview.canImport {
                        YalaPrimaryButton(L10n.UXL7.ImportReview.importButton(preview.count), icon: "square.and.arrow.down") {
                            dismiss()
                            onImport()
                        }
                        .accessibilityIdentifier("import_preview_confirm")
                    }
                    Button(preview.canImport ? L10n.Common.cancel : L10n.Action.close) {
                        dismiss()
                    }
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DS.Spacing.sm)
                    .accessibilityIdentifier("import_preview_cancel")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.UXL7.ImportReview.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }

    // MARK: - Resumen

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if preview.canImport {
                Text(L10n.UXL7.ImportReview.summary(preview.count, accountsText))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("import_preview_summary")

                if let first = preview.firstDate, let last = preview.lastDate {
                    Label(rangeText(first, last), systemImage: "calendar")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !preview.totals.isEmpty {
                    Label(L10n.UXL7.ImportReview.total(totalsText), systemImage: "sum")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("import_preview_total")
                }
                Text(L10n.UXL7.ImportReview.reviewHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(L10n.UXL7.ImportReview.nothingToImport)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("import_preview_nothing")
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(Color.electricIndigo.opacity(0.12))
        )
    }

    // MARK: - Primeras filas

    private var sampleSection: some View {
        SectionBox(title: L10n.UXL7.ImportReview.sampleHeader) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(preview.sampleRows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { SubsectionDivider() }
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("\(row.categoryName) › \(row.subcategoryName)")
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(row.date.formatted(Self.dateStyle))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: DS.Spacing.sm)
                        Text(format(row.amount, row.currencyCode))
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(Color.amountTint(isIncome: row.amount >= 0))
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Lo que no entra

    private var failuresSection: some View {
        let listed = ImportPreviewLogic.listedFailures(preview.failures)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !preview.failures.isEmpty {
                Label(L10n.UXL7.ImportReview.failuresHeader(preview.failures.count), systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(DS.Semantic.warningForeground)
                    .accessibilityIdentifier("import_preview_failures")
                ForEach(Array(listed.shown.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if listed.hidden > 0 {
                    Text(L10n.UXL7.ImportReview.more(listed.hidden))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if preview.ignoredFutureCount > 0 {
                Text(L10n.UXL7.ImportReview.futureIgnored(preview.ignoredFutureCount))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Semantic.warningBackground)
        )
    }

    // MARK: - Formato

    private static let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)
        .locale(AppLocale.current)

    private var accountsText: String {
        preview.accountNames.formatted(.list(type: .and).locale(AppLocale.current))
    }

    private var totalsText: String {
        preview.totals.map { format($0.amount, $0.currencyCode) }.joined(separator: " · ")
    }

    private func rangeText(_ first: Date, _ last: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(first, inSameDayAs: last) {
            return L10n.UXL7.ImportReview.singleDay(first.formatted(Self.dateStyle))
        }
        return L10n.UXL7.ImportReview.range(first.formatted(Self.dateStyle), last.formatted(Self.dateStyle))
    }

    private func format(_ amount: Double, _ code: String) -> String {
        CurrencyFormattingHelper.currency(
            amount,
            decimals: AccountCurrencyPlanLogic.fractionDigits(for: code),
            identifier: code,
            forceSign: false,
            isEstimate: false
        )
    }
}
