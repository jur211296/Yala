//
//  CashFlowLineConfigSheet.swift
//  Yala
//
//  Configuration sheet for a cash flow line: estimation method with preview amounts,
//  historical context, overrides management, delete.
//

import SwiftData
import SwiftUI

struct CashFlowLineConfigSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let line: CashFlowLine
    let currencyCode: String
    var transactions: [TransactionItem] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    @State private var selectedMethod: EstimationMethod
    @State private var manualAmount: String
    @State private var showDeleteConfirmation = false
    @State private var showAddOverride = false
    @State private var newOverrideMonth: Date = .now
    @State private var newOverrideAmount: String = ""
    @State private var newOverrideNote: String = ""

    init(viewModel: CashFlowPlanViewModel, line: CashFlowLine, currencyCode: String, transactions: [TransactionItem] = []) {
        self.viewModel = viewModel
        self.line = line
        self.currencyCode = currencyCode
        self.transactions = transactions
        _selectedMethod = State(initialValue: line.method)
        _manualAmount = State(initialValue: line.manualAmount.map { String(format: "%.0f", $0) } ?? "")
    }

    private var isPro: Bool {
        FeatureGateService.shared.canAccess(.cashFlowAdvanced)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        categorySection
                        if !transactions.isEmpty {
                            contextSection
                        }
                        methodSection
                        overridesSection
                        deleteSection
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                    .yalaSafeBottomPadding()
                    .dismissKeyboardOnTap()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(line.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: {
                        applyChanges()
                        dismiss()
                    })
                }
            }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog(
            L10n.CashFlowPlan.deleteLineConfirmation,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Action.delete, role: .destructive) {
                viewModel.removeLine(line)
                dismiss()
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.contextLabel)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            if line.subcategory != nil || line.category != nil {
                let displayName = line.subcategory?.name ?? line.category?.name ?? line.name
                let iconName = line.subcategory?.iconName ?? line.category?.iconName
                let colorHex = line.subcategory?.colorHex ?? line.category?.colorHex ?? AppConstants.defaultColorHex

                HStack(spacing: DS.Spacing.md) {
                    if let iconName {
                        Image(systemName: iconName)
                            .foregroundStyle(Color(hex: colorHex))
                    }
                    Text(displayName)
                        .font(DS.Typography.body)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
            }
        }
    }

    // MARK: - Historical Context

    private var contextSection: some View {
        let stats = computeHistoricalStats()

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.contextHistory)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.sm) {
                // Trend
                HStack {
                    Text(L10n.CashFlowPlan.trendLabel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: stats.trendDirection >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(stats.trendDirection >= 0 ? Color.hotPink : Color.electricIndigo)
                        Text(String(format: "%+.0f%%", stats.trendDirection * 100))
                            .font(DS.Typography.caption)
                            .monospacedDigit()
                    }
                }

                Divider()

                // Range
                HStack {
                    Text(L10n.CashFlowPlan.rangeLabel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(YalaFormatter.amountCompactTable(value: stats.minAmount)) – \(YalaFormatter.amountCompactTable(value: stats.maxAmount))")
                        .font(DS.Typography.caption)
                        .monospacedDigit()
                }

                Divider()

                // Months with activity
                HStack {
                    Text(L10n.CashFlowPlan.monthsActive)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(L10n.CashFlowPlan.monthsWithActivity(stats.monthsActive))
                        .font(DS.Typography.caption)
                        .monospacedDigit()
                }
            }
            .padding(DS.Spacing.lg)
            .solidCard()
        }
    }

    // MARK: - Method Selection

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.estimationMethod)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.none) {
                methodRow(.average6m, label: L10n.CashFlowPlan.average6m)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.average3m, label: L10n.CashFlowPlan.average3m)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.average12m, label: L10n.CashFlowPlan.average12m)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.lastMonth, label: L10n.CashFlowPlan.lastMonth)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.manual, label: L10n.CashFlowPlan.manual)
                if selectedMethod == .manual {
                    manualAmountField
                }
                if line.scheduledPayment != nil {
                    Divider().padding(.leading, DS.Spacing.xxl)
                    methodRow(.scheduled, label: L10n.CashFlowPlan.scheduled)
                }
            }
            .solidCard()
        }
    }

    private func methodRow(_ method: EstimationMethod, label: String, proOnly: Bool = false, enabled: Bool = true) -> some View {
        Button {
            if proOnly && !isPro { return }
            if !enabled { return }
            selectedMethod = method
        } label: {
            HStack {
                Image(systemName: selectedMethod == method ? "circle.inset.filled" : "circle")
                    .foregroundStyle(selectedMethod == method ? theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(DS.Typography.body)
                        .foregroundStyle(enabled ? .primary : .secondary)
                    Text(method.descriptionText)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Preview amount
                if method != .manual {
                    let preview = previewForMethod(method)
                    if preview > 0 {
                        Text(YalaFormatter.amountCompactTable(value: preview))
                            .font(DS.Typography.caption)
                            .foregroundStyle(selectedMethod == method ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.secondary))
                            .monospacedDigit()
                    }
                }
                if proOnly && !isPro {
                    Image(systemName: "lock.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1.0 : 0.5)
    }

    private var manualAmountField: some View {
        HStack {
            TextField("0", text: $manualAmount)
                .keyboardType(.decimalPad)
                .font(DS.Typography.amount)
                .monospacedDigit()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Overrides

    private var overrides: [CashFlowOverride] {
        (line.overrides ?? []).sorted { $0.monthKey < $1.monthKey }
    }

    private var overridesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.CashFlowPlan.adjustAmount)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddOverride.toggle()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus.circle")
                            .font(DS.Typography.caption)
                        Text(L10n.CashFlowPlan.addOverride)
                            .font(DS.Typography.caption)
                    }
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            if showAddOverride {
                addOverrideCard
            }

            if !overrides.isEmpty {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(overrides, id: \.monthKey) { override in
                        HStack {
                            Text(formatMonthKey(override.monthKey))
                                .font(DS.Typography.body)
                            Spacer()
                            Text(YalaFormatter.currency(value: override.amount, currencyCode: currencyCode))
                                .font(DS.Typography.amountSmall)
                                .monospacedDigit()
                            if !override.note.isEmpty {
                                Text("(\(override.note))")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                viewModel.removeOverride(line: line, monthKey: override.monthKey)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                }
                .solidCard()
            }
        }
    }

    private var addOverrideCard: some View {
        VStack(spacing: DS.Spacing.md) {
            DatePicker(
                L10n.CashFlowPlan.overrideMonth,
                selection: $newOverrideMonth,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(DS.Typography.body)

            TextField(L10n.CashFlowPlan.overrideAmount, text: $newOverrideAmount)
                .keyboardType(.decimalPad)
                .font(DS.Typography.headline)
                .monospacedDigit()
                .padding(DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(.thCard)
                )

            TextField(L10n.CashFlowPlan.cellDetailNote, text: $newOverrideNote)
                .font(DS.Typography.body)
                .padding(DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(.thCard)
                )

            YalaPrimaryButton(L10n.CashFlowPlan.cellDetailSaveAdjustment, icon: "checkmark.circle.fill") {
                let amount = AmountInputHelper.parseDecimal(newOverrideAmount)
                if amount > 0 {
                    let calendar = Calendar.current
                    let monthKey = CashFlowProjectionCalculator.monthKey(for: newOverrideMonth, calendar: calendar)
                    viewModel.setOverride(line: line, monthKey: monthKey, amount: amount, note: newOverrideNote)
                    newOverrideAmount = ""
                    newOverrideNote = ""
                    showAddOverride = false
                }
            }
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Text(L10n.Action.delete)
                .font(DS.Typography.label)
                .foregroundStyle(DS.Semantic.errorForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private static let monthKeyParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private func formatMonthKey(_ key: String) -> String {
        guard let date = Self.monthKeyParser.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func previewForMethod(_ method: EstimationMethod) -> Double {
        let suggestedLine = SuggestedLine(
            category: line.category,
            subcategory: line.subcategory,
            scheduledPayment: line.scheduledPayment,
            name: line.name,
            isIncome: line.isIncome,
            suggestedAmount: 0,
            estimationMethod: method,
            monthsWithActivity: 0,
            isSelected: false
        )
        return viewModel.previewAmount(for: suggestedLine, method: method)
    }

    private struct HistoricalStats {
        let trendDirection: Double
        let minAmount: Double
        let maxAmount: Double
        let monthsActive: Int
    }

    private func computeHistoricalStats() -> HistoricalStats {
        let calendar = Calendar.current
        var monthlyTotals: [String: Double] = [:]

        for tx in transactions {
            let matches: Bool
            if let sub = line.subcategory {
                matches = tx.subcategory?.persistentModelID == sub.persistentModelID
            } else if let cat = line.category {
                matches = tx.category?.persistentModelID == cat.persistentModelID
            } else {
                matches = false
            }
            guard matches else { continue }

            let monthKey = CashFlowProjectionCalculator.monthKey(for: tx.date, calendar: calendar)
            monthlyTotals[monthKey, default: 0] += abs(tx.amount)
        }

        let amounts = Array(monthlyTotals.values)
        guard !amounts.isEmpty else {
            return HistoricalStats(trendDirection: 0, minAmount: 0, maxAmount: 0, monthsActive: 0)
        }

        let sortedKeys = monthlyTotals.keys.sorted()
        let trend: Double
        if sortedKeys.count >= 2,
           let first = monthlyTotals[sortedKeys[0]], first > 0,
           let last = monthlyTotals[sortedKeys[sortedKeys.count - 1]] {
            trend = (last - first) / first
        } else {
            trend = 0
        }

        return HistoricalStats(
            trendDirection: trend,
            minAmount: amounts.min() ?? 0,
            maxAmount: amounts.max() ?? 0,
            monthsActive: monthlyTotals.count
        )
    }

    // MARK: - Apply

    private func applyChanges() {
        line.estimationMethod = selectedMethod.rawValue
        if selectedMethod == .manual {
            line.manualAmount = AmountInputHelper.parseDecimal(manualAmount)
        }
        do {
            try viewModel.plan?.modelContext?.save()
        } catch {
            #if DEBUG
            print("CashFlowLineConfigSheet: Error saving: \(error)")
            #endif
        }
    }
}
