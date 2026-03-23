//
//  CashFlowTableView.swift
//  Yala
//
//  Main table view for cash flow plan with sticky name column and horizontal month scroll.
//  Layout mirrors PivotRowView: .subheadline names, vertical divider, DS.Spacing.lg padding.
//

import SwiftUI
import SwiftData

struct CashFlowTableView: View {

    // MARK: - Properties

    @Bindable var viewModel: CashFlowPlanViewModel
    let transactions: [TransactionItem]
    let categories: [Category]
    let scheduledPayments: [ScheduledPayment]
    let currencyCode: String
    let compactMode: Bool

    // MARK: - State

    @State private var incomeCollapsed = false
    @State private var expenseCollapsed = false

    // Tour
    @AppStorage("hasSeenCashFlowTableTour") private var hasSeenTour = false
    @State private var showTour = false
    @State private var tourIndex = 0
    @State private var tableScrollProxy: ScrollViewProxy?
    @State private var monthScrollProxy: ScrollViewProxy?

    @Environment(\.yalaTheme) private var theme

    // MARK: - Constants

    private var nameColumnWidth: CGFloat { compactMode ? 52 : 170 }
    private let rowHeight: CGFloat = 44
    private let summaryRowHeight: CGFloat = 36

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let visibleMonths: CGFloat = compactMode ? 3 : 2
            let monthColumnWidth = max(70, (geo.size.width - DS.Spacing.lg * 2 - nameColumnWidth) / visibleMonths)

            VStack(spacing: DS.Spacing.none) {
                if let projection = viewModel.projection {
                    monthSummaryBanner(projection)
                    tableContent(projection, monthWidth: monthColumnWidth)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .coachMarkOverlay(
            steps: CashFlowTableTourSteps.steps,
            isPresented: $showTour,
            currentIndex: $tourIndex,
            scrollProxy: tableScrollProxy
        ) {
            hasSeenTour = true
        }
        .onAppear {
            recalculate()
        }
        .task {
            try? await Task.sleep(for: .seconds(0.5))
            if viewModel.projection != nil && !hasSeenTour {
                showTour = true
            }
        }
        .sheet(isPresented: $viewModel.showLineConfig) {
            if let line = viewModel.selectedLine {
                CashFlowLineConfigSheet(
                    viewModel: viewModel,
                    line: line,
                    currencyCode: currencyCode
                )
            }
        }
        .sheet(isPresented: $viewModel.showOthersBreakdown) {
            CashFlowOthersSheet(
                viewModel: viewModel,
                currencyCode: currencyCode
            )
        }
        .sheet(isPresented: $viewModel.showAddLine) {
            CashFlowAddLineSheet(
                viewModel: viewModel,
                currencyCode: currencyCode,
                transactions: transactions
            )
        }
        .onChange(of: viewModel.showLineConfig) { _, showing in
            if !showing { recalculate() }
        }
        .onChange(of: viewModel.showOthersBreakdown) { _, showing in
            if !showing { recalculate() }
        }
        .onChange(of: viewModel.showAddLine) { _, showing in
            if !showing { recalculate() }
        }
        .sheet(isPresented: $viewModel.showEditStartingBalance) {
            editStartingBalanceSheet
        }
        .onChange(of: viewModel.showEditStartingBalance) { _, showing in
            if !showing { recalculate() }
        }
        .onChange(of: compactMode) { _, isCompact in
            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                monthScrollProxy?.scrollTo(currentMonthKey, anchor: isCompact ? .center : .leading)
            }
        }
    }

    // MARK: - Table Content

    private var currentMonthKey: String {
        CashFlowProjectionCalculator.monthKey(for: .now, calendar: .current)
    }

    private func tableContent(_ projection: CashFlowProjection, monthWidth: CGFloat) -> some View {
        let hasOthers = projection.months.first?.otherExpenses != nil

        return ScrollViewReader { verticalProxy in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Spacing.none) {
                    // Sticky name column
                    nameColumn(projection, hasOtherExpenses: hasOthers)
                        .frame(width: nameColumnWidth)

                    // Vertical divider (like Comparativa)
                    Divider()

                    // Scrollable month columns
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            HStack(spacing: DS.Spacing.none) {
                                ForEach(projection.months, id: \.monthKey) { month in
                                    CashFlowMonthColumn(
                                        month: month,
                                        incomeCollapsed: incomeCollapsed,
                                        expenseCollapsed: expenseCollapsed,
                                        currencyCode: currencyCode,
                                        columnWidth: monthWidth,
                                        rowHeight: rowHeight,
                                        hasOtherExpenses: hasOthers,
                                        compactMode: compactMode
                                    )
                                    .id(month.monthKey)
                                }
                            }
                            .onAppear {
                                monthScrollProxy = proxy
                                proxy.scrollTo(currentMonthKey, anchor: compactMode ? .center : .leading)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                .yalaCard(padding: 0)
                .padding(.horizontal, DS.Spacing.lg)
                .yalaSafeBottomPadding()
            }
            .scrollDisabled(showTour)
            .onAppear { tableScrollProxy = verticalProxy }
        }
    }

    // MARK: - Name Column

    private func nameColumn(_ projection: CashFlowProjection, hasOtherExpenses: Bool) -> some View {
        VStack(spacing: DS.Spacing.none) {
            // Header spacer (aligns with month headers)
            Color.clear.frame(height: rowHeight)

            // Income section
            CashFlowHeaderRow(
                title: L10n.CashFlowPlan.incomeSection,
                isIncome: true,
                isCollapsed: $incomeCollapsed,
                compactMode: compactMode
            )
            .frame(height: rowHeight)

            if !incomeCollapsed {
                let incomeLines = projection.months.first?.incomeLines ?? []
                ForEach(incomeLines, id: \.lineID) { lineResult in
                    let line = viewModel.plan?.lines?.first { $0.id == lineResult.lineID }
                    CashFlowLineNameRow(
                        lineResult: lineResult,
                        line: line,
                        isOtherExpenses: false,
                        height: rowHeight,
                        compactMode: compactMode
                    )
                    .onTapGesture {
                        if let line {
                            viewModel.selectedLine = line
                            viewModel.showLineConfig = true
                        }
                    }
                }

                // Add income line button
                addLineButton(isIncome: true)
            }

            // Expense section
            CashFlowHeaderRow(
                title: L10n.CashFlowPlan.expenseSection,
                isIncome: false,
                isCollapsed: $expenseCollapsed,
                compactMode: compactMode
            )
            .frame(height: rowHeight)
            .coachMarkAnchor("cfTableCell")

            if !expenseCollapsed {
                let expenseLines = projection.months.first?.expenseLines ?? []
                ForEach(expenseLines, id: \.lineID) { lineResult in
                    let line = viewModel.plan?.lines?.first { $0.id == lineResult.lineID }
                    CashFlowLineNameRow(
                        lineResult: lineResult,
                        line: line,
                        isOtherExpenses: false,
                        height: rowHeight,
                        compactMode: compactMode
                    )
                    .onTapGesture {
                        if let line {
                            viewModel.selectedLine = line
                            viewModel.showLineConfig = true
                        }
                    }

                    // Subcategory breakdown
                    if !compactMode, let subs = lineResult.subcategoryBreakdown {
                        ForEach(subs, id: \.subcategoryName) { sub in
                            HStack(spacing: DS.Spacing.sm) {
                                Color.clear.frame(width: DS.Icon.badgeSmall)
                                Text(sub.subcategoryName)
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .frame(height: rowHeight)
                        }
                    }
                }

                // Add expense line button
                addLineButton(isIncome: false)
                    .coachMarkAnchor("cfTableAdd")

                // Other expenses
                if hasOtherExpenses {
                    Divider()
                        .padding(.horizontal, compactMode ? DS.Spacing.sm : DS.Spacing.lg)
                        .dashPattern()

                    Button {
                        viewModel.showOthersBreakdown = true
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            if compactMode {
                                ZStack {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Image(systemName: "ellipsis.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: DS.Chip.dotSize)
                                Text(L10n.CashFlowPlan.otherExpensesLabel)
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, compactMode ? DS.Spacing.sm : DS.Spacing.lg)
                        .frame(height: rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Summary
            Divider()

            if compactMode {
                summaryIconRow(systemName: "equal", color: .secondary)
                    .coachMarkAnchor("cfTableAvailable")
                summaryIconRow(systemName: "sum", color: .secondary)
            } else {
                summaryLabel(
                    text: L10n.CashFlowPlan.available,
                    hintTitle: L10n.CashFlowPlan.availableHintTitle,
                    hintMessage: L10n.CashFlowPlan.availableHintMessage
                )
                .coachMarkAnchor("cfTableAvailable")
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.CashFlowPlan.accumulated)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                    InfoHintButton(
                        title: L10n.CashFlowPlan.accumulatedHintTitle,
                        message: L10n.CashFlowPlan.accumulatedHintMessage
                    )
                    Spacer()
                    Button {
                        viewModel.showEditStartingBalance = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .frame(height: summaryRowHeight)
            }
        }
    }

    // MARK: - Summary Label

    private func summaryLabel(text: String, hintTitle: String? = nil, hintMessage: String? = nil) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(text)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
            if let hintTitle, let hintMessage {
                InfoHintButton(title: hintTitle, message: hintMessage)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(height: summaryRowHeight)
    }

    // MARK: - Add Line Button

    private func addLineButton(isIncome: Bool) -> some View {
        Button {
            viewModel.addLineIsIncome = isIncome
            viewModel.showAddLine = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if compactMode {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.15))
                            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                        Image(systemName: "plus")
                            .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                } else {
                    Image(systemName: "plus.circle")
                        .font(DS.Typography.caption)
                    Text(L10n.CashFlowPlan.addLine)
                        .font(DS.Typography.caption)
                }
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, compactMode ? DS.Spacing.sm : DS.Spacing.lg)
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func summaryIconRow(systemName: String, color: Color) -> some View {
        HStack {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                Image(systemName: systemName)
                    .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.sm)
        .frame(height: summaryRowHeight)
    }

    // MARK: - Month Summary Banner

    private func monthSummaryBanner(_ projection: CashFlowProjection) -> some View {
        let currentMonth = projection.months.first { $0.isCurrent }

        let (totalEstimated, totalReal) = (currentMonth?.expenseLines ?? [])
            .reduce((0.0, 0.0)) { acc, line in
                (acc.0 + line.plannedAmount, acc.1 + (line.realAmount ?? 0))
            }

        let percent: Int = totalEstimated > 0 ? Int((totalReal / totalEstimated) * 100) : 0
        let isOver = totalReal > totalEstimated && totalEstimated > 0
        let overPercent = totalEstimated > 0 ? Int(((totalReal - totalEstimated) / totalEstimated) * 100) : 0

        let text: String
        let color: Color
        if currentMonth == nil || totalEstimated == 0 {
            text = ""
            color = .secondary
        } else if isOver {
            text = L10n.CashFlowPlan.monthSummaryOver(overPercent)
            color = Color.hotPink
        } else if percent <= 60 {
            text = L10n.CashFlowPlan.monthSummaryUnder(percent)
            color = Color.electricIndigo
        } else {
            text = L10n.CashFlowPlan.monthSummaryOnTrack(percent)
            color = Color.electricIndigo
        }

        return Group {
            if !text.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: isOver ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(color)
                    Text(text)
                        .font(DS.Typography.caption)
                        .foregroundStyle(color)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Edit Starting Balance Sheet

    @ViewBuilder
    private var editStartingBalanceSheet: some View {
        EditStartingBalanceSheet(viewModel: viewModel, currencyCode: currencyCode)
    }

    // MARK: - Recalculate

    private func recalculate() {
        let expenseCategories = categories.filter { !$0.isIncome }
        viewModel.recalculate(
            transactions: transactions,
            allExpenseCategories: expenseCategories,
            scheduledPayments: scheduledPayments,
            currencyCode: currencyCode,
            converter: CurrencyConverter.shared
        )
    }
}

// MARK: - Edit Starting Balance Sheet

private struct EditStartingBalanceSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    @State private var balanceText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Text(L10n.CashFlowPlan.editStartingBalance)
                    .font(DS.Typography.headline)

                TextField("0", text: $balanceText)
                    .keyboardType(.decimalPad)
                    .font(DS.Typography.title)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .padding(DS.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(.thCard)
                    )

                YalaPrimaryButton(L10n.CashFlowPlan.editStartingBalanceSave, icon: "checkmark.circle.fill") {
                    let value = AmountInputHelper.parseDecimal(balanceText)
                    viewModel.updateStartingBalance(value)
                    dismiss()
                }
            }
            .padding(DS.Spacing.xl)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            balanceText = String(format: "%.0f", viewModel.plan?.startingBalance ?? 0)
        }
    }
}

// MARK: - Dash Pattern Extension

private extension View {
    func dashPattern() -> some View {
        self.overlay(
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                .foregroundStyle(.quaternary)
            }
        )
    }
}
