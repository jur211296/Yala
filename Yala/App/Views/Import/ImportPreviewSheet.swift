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

    /// Lo que devolvió el import con TODAS las cuentas nuevas.
    let fullPreview: ImportPreview
    /// «Importar», con las cuentas nuevas que se crean (sus claves).
    let onImport: (Set<String>) -> Void

    /// Las cuentas nuevas que se crean. Sin límite, todas; con el plan gratuito lleno, las que la persona elige.
    @State private var chosenAccounts: Set<String> = []
    @State private var isShowingProOffer = false

    init(preview: ImportPreview, onImport: @escaping (Set<String>) -> Void) {
        self.fullPreview = preview
        self.onImport = onImport
        let slots = ImportPreviewLogic.newAccountSlots(
            isPro: FeatureGateService.shared.isProUser, existingBillableAccounts: preview.existingBillableAccounts)
        _chosenAccounts = State(initialValue: ImportPreviewLogic.defaultChosenAccounts(preview.newAccounts, slots: slots))
    }

    /// Cuántas cuentas nuevas caben; `nil` sin límite. Se lee en cada pintado: si la persona se hace Pro aquí, cambia.
    private var slots: Int? {
        ImportPreviewLogic.newAccountSlots(
            isPro: FeatureGateService.shared.isProUser, existingBillableAccounts: fullPreview.existingBillableAccounts)
    }

    /// Las cuentas nuevas que se crean de verdad: sin límite (Pro, también si llegó desde fuera de esta hoja), todas.
    private var effectiveChosenAccounts: Set<String> {
        slots == nil ? Set(fullPreview.newAccounts.map(\.key)) : chosenAccounts
    }

    /// La vista previa con las cuentas elegidas.
    private var preview: ImportPreview {
        ImportPreviewLogic.applying(chosen: effectiveChosenAccounts, to: fullPreview)
    }

    /// El plan gratuito no deja crear todas: la persona elige.
    private var choosesAccounts: Bool {
        guard let slots else { return false }
        return fullPreview.newAccounts.count > slots
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                        summaryCard
                        if !fullPreview.newAccounts.isEmpty {
                            newAccountsSection
                        }
                        if !preview.doubtfulAmounts.isEmpty {
                            doubtfulSection
                        }
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
                            let chosen = effectiveChosenAccounts
                            dismiss()
                            onImport(chosen)
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
        .proUpgradeSheet(isPresented: $isShowingProOffer, feature: .accounts, context: .limitReached) {
            chosenAccounts = Set(fullPreview.newAccounts.map(\.key))
        }
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
                if !preview.ignoredColumns.isEmpty {
                    Label(L10n.UXL7.ImportReview.ignoredColumns(preview.ignoredColumns.joined(separator: ", ")),
                          systemImage: "eye.slash")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("import_preview_ignored_columns")
                }
                if let readSheet = preview.readSheet, !preview.skippedSheets.isEmpty {
                    Label(L10n.UXL7.ImportReview.skippedSheets(readSheet, preview.skippedSheets.joined(separator: ", ")),
                          systemImage: "tablecells")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("import_preview_skipped_sheets")
                }
                if preview.groupRowCount > 0 {
                    Label(L10n.UXL7.ImportReview.groupRows(preview.groupRowCount), systemImage: "person.2")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("import_preview_group_rows")
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

    // MARK: - Cuentas nuevas (H7)

    private var newAccountsSection: some View {
        SectionBox(title: L10n.UXL7.ImportReview.newAccountsHeader) {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                Text(choosesAccounts
                     ? L10n.UXL7.ImportReview.newAccountsLimit(slots ?? 0)
                     : L10n.UXL7.ImportReview.newAccountsHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                ForEach(fullPreview.newAccounts, id: \.key) { account in
                    SubsectionDivider()
                    newAccountRow(account)
                }
                if choosesAccounts {
                    SubsectionDivider()
                    Button {
                        isShowingProOffer = true
                    } label: {
                        Label(L10n.FeatureGate.upgradeToPro, systemImage: "crown")
                            .font(DS.Typography.bodyBold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("import_preview_new_accounts_pro")
                }
            }
        }
        .accessibilityIdentifier("import_preview_new_accounts")
    }

    @ViewBuilder
    private func newAccountRow(_ account: ImportNewAccountSummary) -> some View {
        let label = HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            if choosesAccounts {
                Image(systemName: chosenAccounts.contains(account.key) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(chosenAccounts.contains(account.key) ? AnyShapeStyle(.thAccentText) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(account.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("\(account.currencyCode) · \(L10n.UXL7.recordsCount(account.rowCount))")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
        }
        .padding()
        .contentShape(Rectangle())

        if choosesAccounts {
            let isChosen = chosenAccounts.contains(account.key)
            Button {
                if isChosen {
                    chosenAccounts.remove(account.key)
                } else if ImportPreviewLogic.canChoose(account.key, chosen: chosenAccounts, slots: slots) {
                    chosenAccounts.insert(account.key)
                }
            } label: {
                label
            }
            .buttonStyle(.plain)
            .disabled(!isChosen && !ImportPreviewLogic.canChoose(account.key, chosen: chosenAccounts, slots: slots))
            .accessibilityAddTraits(isChosen ? .isSelected : [])
            .accessibilityHint(isChosen || ImportPreviewLogic.canChoose(account.key, chosen: chosenAccounts, slots: slots)
                               ? "" : L10n.UXL7.ImportReview.newAccountsLimit(slots ?? 0))
            .accessibilityIdentifier("import_preview_new_account_\(account.key)")
        } else {
            label
                .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Importes dudosos (H1)

    private var doubtfulSection: some View {
        let listed = Array(preview.doubtfulAmounts.prefix(ImportPreviewLogic.failureListLimit))
        let hidden = preview.doubtfulAmounts.count - listed.count
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label(L10n.UXL7.ImportReview.doubtfulHeader, systemImage: "questionmark.circle.fill")
                .font(DS.Typography.bodyBold)
                .foregroundStyle(DS.Semantic.warningForeground)
                .accessibilityIdentifier("import_preview_doubtful")
            Text(L10n.UXL7.ImportReview.doubtfulHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(listed.enumerated()), id: \.offset) { _, item in
                Text(L10n.UXL7.ImportReview.doubtfulLine(item.rowNumber, item.raw, format(item.amount, item.currencyCode)))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hidden > 0 {
                Text(L10n.UXL7.ImportReview.more(hidden))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Semantic.warningBackground)
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
