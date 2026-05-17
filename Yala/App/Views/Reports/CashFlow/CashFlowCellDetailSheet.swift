//
//  CashFlowCellDetailSheet.swift
//  Yala
//
//  Rich detail sheet for a cash flow line cell.
//  3 variants: current month (chart + transactions), past month (comparison),
//  future month (estimation + adjust). Timeline navigable within sheet.
//

import Charts
import SwiftData
import SwiftUI

struct CashFlowCellDetailSheet: View {
    let lineResult: CashFlowLineResult
    let line: CashFlowLine?
    let month: CashFlowMonth
    let currencyCode: String
    let transactions: [TransactionItem]
    @Bindable var viewModel: CashFlowPlanViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    // Local navigation state (resets on dismiss)
    @State private var activeMonthKey: String = ""

    @State private var showAdjustAmount = false
    @State private var adjustAmountText = ""
    @State private var adjustNote = ""

    @State private var showOverrideScopeAlert = false
    @State private var pendingOverrideAmount: Double = 0
    @State private var pendingOverrideNote: String = ""
    @State private var pendingOverrideLine: CashFlowLine?
    @State private var pendingOverrideMonthKey: String = ""

    // Derived from activeMonthKey
    private var activeMonth: CashFlowMonth? {
        viewModel.projection?.months.first { $0.monthKey == activeMonthKey }
    }

    private var activeLineResult: CashFlowLineResult? {
        guard let m = activeMonth else { return nil }
        let all = m.incomeLines + m.expenseLines
        return all.first { $0.lineID == lineResult.lineID }
    }

    private var activeTransactions: [TransactionItem] {
        guard let m = activeMonth else { return [] }
        let calendar = Calendar.current
        return transactions
            .filter { tx in
                let txKey = CashFlowProjectionCalculator.monthKey(for: tx.date, calendar: calendar)
                guard txKey == m.monthKey else { return false }
                if let sub = line?.subcategory {
                    return tx.subcategory?.persistentModelID == sub.persistentModelID
                }
                if let cat = line?.category {
                    return tx.category?.persistentModelID == cat.persistentModelID
                }
                return false
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView(.vertical, showsIndicators: false) {
                    if let m = activeMonth, let lr = activeLineResult {
                        VStack(spacing: DS.Spacing.xl) {
                            if m.isCurrent {
                                currentMonthContent(m: m, lr: lr)
                            } else if m.isPast {
                                pastMonthContent(m: m, lr: lr)
                            } else {
                                futureMonthContent(m: m, lr: lr)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.xl)
                        .yalaSafeBottomPadding()
                        .dismissKeyboardOnTap()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(lineResult.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { activeMonthKey = month.monthKey }
        .alert(L10n.CashFlowPlan.overrideScopeTitle, isPresented: $showOverrideScopeAlert) {
            Button(L10n.CashFlowPlan.overrideScopeThisMonth) {
                if let line = pendingOverrideLine {
                    viewModel.setOverride(line: line, monthKey: pendingOverrideMonthKey, amount: pendingOverrideAmount, note: pendingOverrideNote)
                }
                dismiss()
            }
            Button(L10n.CashFlowPlan.overrideScopeThisAndFuture) {
                if let line = pendingOverrideLine {
                    viewModel.setOverrideAndUpdateFuture(line: line, monthKey: pendingOverrideMonthKey, amount: pendingOverrideAmount, note: pendingOverrideNote)
                }
                dismiss()
            }
            Button(L10n.Action.cancel, role: .cancel) { }
        } message: {
            Text(L10n.CashFlowPlan.overrideScopeMessage)
        }
    }

    // MARK: - Header

    private func headerInfo(m: CashFlowMonth) -> some View {
        HStack(spacing: DS.Spacing.md) {
            categoryIcon
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(lineResult.name)
                    .font(DS.Typography.headline)
                Text(m.date.formatted(.dateTime.month(.wide).year()))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var categoryIcon: some View {
        let iconName = line?.subcategory?.iconName ?? line?.category?.iconName
        let colorHex = line?.subcategory?.colorHex ?? line?.category?.colorHex

        return Group {
            if let iconName, let colorHex {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    Image(systemName: iconName)
                        .font(.system(size: DS.Icon.sizeLarge, weight: .semibold))
                        .foregroundStyle(.white)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    Image(systemName: "questionmark")
                        .font(.system(size: DS.Icon.sizeLarge, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Current Month

    private func currentMonthContent(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            currentProgressCard(m: m, lr: lr)

            if !activeTransactions.isEmpty {
                CashFlowCellMiniChart(
                    transactions: activeTransactions,
                    plannedAmount: lr.plannedAmount,
                    month: m,
                    currencyCode: currencyCode
                )
                .solidCard()
            }

            monthTimeline

            if !activeTransactions.isEmpty {
                recentTransactionsCard
            }

            adjustAmountButton(m: m, lr: lr)
        }
    }

    private func currentProgressCard(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.md) {
            headerInfo(m: m)

            Divider()

            HStack(alignment: .firstTextBaseline) {
                AmountText(
                    value: lr.realAmount ?? 0,
                    currencyCode: currencyCode,
                    font: DS.Typography.title.weight(.bold).monospacedDigit()
                )
                Text(L10n.CashFlowPlan.cellDetailOf)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                AmountText(
                    value: lr.plannedAmount,
                    currencyCode: currencyCode,
                    font: DS.Typography.body.monospacedDigit(),
                    tint: .secondary
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress = lr.progress {
                VStack(spacing: DS.Spacing.xs) {
                    GeometryReader { geo in
                        let clamped = min(1.0, max(0, progress))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DS.Semantic.neutralBackground)
                                .frame(height: 8)
                            Capsule()
                                .fill(progress > 1.0 ? Color.hotPink : theme.accent)
                                .frame(width: max(8, geo.size.width * clamped), height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(Int(min(progress, 9.99) * 100))%")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        let remaining = lr.plannedAmount - (lr.realAmount ?? 0)
                        if remaining > 0 {
                            Text(L10n.CashFlowPlan.cellDetailRemaining(appPreferences.currency(remaining, currencyCode: currencyCode)))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.CashFlowPlan.estimationMethod)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(lr.estimationMethod.displayName)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    // MARK: - Past Month

    private func pastMonthContent(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                headerInfo(m: m)

                Divider()

                if let real = lr.realAmount, let diff = lr.difference {
                    let isGood = lr.isIncome ? diff >= 0 : diff <= 0
                    let verb = lr.isIncome ? L10n.CashFlowPlan.cellDetailEarned : L10n.CashFlowPlan.cellDetailSpent
                    let diffAbs = abs(diff)
                    let percent = lr.differencePercent.map { abs($0) } ?? 0

                    VStack(spacing: DS.Spacing.sm) {
                        Text("\(verb) \(appPreferences.currency(real, currencyCode: currencyCode)) vs \(L10n.CashFlowPlan.plan.lowercased()) \(appPreferences.currency(lr.plannedAmount, currencyCode: currencyCode))")
                            .font(DS.Typography.body)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(isGood ? Color.electricIndigo : Color.hotPink)
                            Text("\(appPreferences.currency(diffAbs, currencyCode: currencyCode)) \(diff > 0 ? L10n.CashFlowPlan.cellDetailMore : L10n.CashFlowPlan.cellDetailLess) (\(String(format: "%.1f", percent))%)")
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(isGood ? Color.electricIndigo : Color.hotPink)
                            Spacer()
                        }
                    }

                    Divider()

                    detailRow(label: L10n.CashFlowPlan.plan, value: lr.plannedAmount)
                    detailRow(label: lr.isIncome ? L10n.CashFlowPlan.realIncome : L10n.CashFlowPlan.real, value: real)
                    detailRow(label: L10n.CashFlowPlan.difference, value: diff, color: isGood ? Color.electricIndigo : Color.hotPink)
                }

                Divider()

                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.CashFlowPlan.estimationMethod)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(lr.estimationMethod.displayName)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.Spacing.lg)
            .solidCard()

            // Chart for past months (they have real data)
            if !activeTransactions.isEmpty {
                CashFlowCellMiniChart(
                    transactions: activeTransactions,
                    plannedAmount: lr.plannedAmount,
                    month: m,
                    currencyCode: currencyCode
                )
                .solidCard()
            }

            monthTimeline

            // Transactions for past months
            if !activeTransactions.isEmpty {
                recentTransactionsCard
            }
        }
    }

    // MARK: - Future Month

    private func futureMonthContent(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                headerInfo(m: m)

                Divider()

                HStack {
                    Text(L10n.CashFlowPlan.plan)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    AmountText(
                        value: lr.plannedAmount,
                        currencyCode: currencyCode,
                        font: DS.Typography.title.weight(.bold).monospacedDigit()
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.CashFlowPlan.estimationMethod)
                            .font(DS.Typography.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lr.estimationMethod.displayName)
                            .font(DS.Typography.label)
                            .foregroundStyle(theme.accent)
                    }
                    Text(lr.estimationMethod.descriptionText)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }

                if lr.isOverride {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(theme.accent)
                        Text(L10n.CashFlowPlan.cellDetailOverrideActive)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .solidCard()

            monthTimeline

            adjustAmountButton(m: m, lr: lr)
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.cellDetailRecentTransactions)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.none) {
                let recent = Array(activeTransactions.prefix(5))
                ForEach(recent, id: \.persistentModelID) { tx in
                    HStack(spacing: DS.Spacing.md) {
                        let iconName = tx.subcategory?.iconName ?? tx.category?.iconName ?? "questionmark"
                        let colorHex = tx.subcategory?.colorHex ?? tx.category?.colorHex ?? AppConstants.defaultColorHex
                        ZStack {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                            Image(systemName: iconName)
                                .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Text(tx.note ?? tx.subcategory?.name ?? tx.category?.name ?? "")
                            .font(DS.Typography.subheadline)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                            AmountText(
                                value: abs(tx.amount),
                                currencyCode: tx.currencyCode,
                                font: DS.Typography.amountSmall.monospacedDigit(),
                                forceFullPrecision: true
                            )
                            Text(tx.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)

                    if tx.persistentModelID != recent.last?.persistentModelID {
                        Divider().padding(.leading, DS.Spacing.xxl)
                    }
                }
            }
            .solidCard()
        }
    }

    // MARK: - Adjust Amount

    private func adjustAmountButton(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.md) {
            if showAdjustAmount {
                VStack(spacing: DS.Spacing.md) {
                    TextField("0", text: $adjustAmountText)
                        .keyboardType(.decimalPad)
                        .font(DS.Typography.headline)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .padding(DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .fill(.thCard)
                        )

                    TextField(L10n.CashFlowPlan.cellDetailNote, text: $adjustNote)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .fill(.thCard)
                        )

                    YalaPrimaryButton(L10n.CashFlowPlan.cellDetailSaveAdjustment, icon: "checkmark.circle.fill") {
                        let amount = AmountInputHelper.parseDecimal(adjustAmountText)
                        if let line, amount > 0 {
                            pendingOverrideAmount = amount
                            pendingOverrideNote = adjustNote
                            pendingOverrideLine = line
                            pendingOverrideMonthKey = m.monthKey
                            showOverrideScopeAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                .padding(DS.Spacing.lg)
                .solidCard()
            } else {
                Button {
                    adjustAmountText = String(format: "%.0f", lr.plannedAmount)
                    showAdjustAmount = true
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "pencil.line")
                        Text(L10n.CashFlowPlan.adjustAmount)
                    }
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Month Timeline

    private var monthTimeline: some View {
        let snapshots = timelineSnapshots
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if snapshots.count > 1 {
                HStack(spacing: DS.Spacing.none) {
                    ForEach(snapshots, id: \.monthKey) { snap in
                        Button {
                            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                                activeMonthKey = snap.monthKey
                                showAdjustAmount = false
                            }
                        } label: {
                            VStack(spacing: DS.Spacing.xs) {
                                Text(snap.label)
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(snap.isActive ? .primary : .tertiary)
                                    .fontWeight(snap.isActive ? .semibold : .regular)

                                Text(YalaFormatter.amountCompactTable(value: snap.amount))
                                    .font(snap.isActive ? DS.Typography.label : DS.Typography.captionSmall)
                                    .fontWeight(snap.isActive ? .bold : .regular)
                                    .foregroundStyle(snap.isActive ? .primary : .secondary)
                                    .monospacedDigit()

                                Circle()
                                    .fill(snap.dotColor)
                                    .frame(width: snap.isActive ? 8 : 5, height: snap.isActive ? 8 : 5)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DS.Spacing.lg)
                .solidCard()
            }
        }
    }

    private struct TimelineSnapshot {
        let monthKey: String
        let label: String
        let amount: Double
        let plannedAmount: Double
        let isActive: Bool
        let isPastOrCurrent: Bool
        let isIncome: Bool
        let dotColor: Color
    }

    private var timelineSnapshots: [TimelineSnapshot] {
        guard let projection = viewModel.projection else { return [] }

        let allMonths = projection.months
        guard let originIdx = allMonths.firstIndex(where: { $0.monthKey == month.monthKey }) else { return [] }

        let startIdx = max(0, originIdx - 2)
        let endIdx = min(allMonths.count - 1, originIdx + 2)

        var snapshots: [TimelineSnapshot] = []
        for i in startIdx...endIdx {
            let m = allMonths[i]
            let allLines = m.incomeLines + m.expenseLines
            let lineData = allLines.first { $0.lineID == lineResult.lineID }
            let planned = lineData?.plannedAmount ?? 0
            let real = lineData?.realAmount
            let displayAmount: Double
            if let real, m.isPast || m.isCurrent {
                displayAmount = real
            } else {
                displayAmount = planned
            }

            // Dot color: past/current with real data → indigo if on track, hotPink if over
            let dotColor: Color
            if let real, (m.isPast || m.isCurrent), planned > 0 {
                let isIncome = lineData?.isIncome ?? false
                if isIncome {
                    dotColor = real >= planned ? .electricIndigo : .hotPink
                } else {
                    dotColor = real <= planned ? .electricIndigo : .hotPink
                }
            } else {
                dotColor = .secondary.opacity(0.3)
            }

            snapshots.append(TimelineSnapshot(
                monthKey: m.monthKey,
                label: m.date.formatted(.dateTime.month(.abbreviated)),
                amount: displayAmount,
                plannedAmount: planned,
                isActive: m.monthKey == activeMonthKey,
                isPastOrCurrent: m.isPast || m.isCurrent,
                isIncome: lineData?.isIncome ?? false,
                dotColor: dotColor
            ))
        }
        return snapshots
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: Double, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: DS.Typography.amountSmall.weight(.semibold).monospacedDigit(),
                tint: color.map { .color($0) } ?? .primary
            )
        }
    }
}
