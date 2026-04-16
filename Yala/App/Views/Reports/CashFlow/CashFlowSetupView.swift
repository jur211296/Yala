//
//  CashFlowSetupView.swift
//  Yala
//
//  Setup view for creating a cash flow plan from suggested lines.
//

import SwiftUI
import SwiftData

struct CashFlowSetupView: View {

    // MARK: - Properties

    @Bindable var viewModel: CashFlowPlanViewModel
    let transactions: [TransactionItem]
    let scheduledPayments: [ScheduledPayment]
    let categories: [Category]
    let currencyCode: String

    @State private var startingBalance: String = ""
    @State private var editingLine: SuggestedLine?

    // Tour
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showTour = false
    @State private var tourIndex = 0
    @State private var setupScrollProxy: ScrollViewProxy?

    @Environment(\.yalaTheme) private var theme

    // MARK: - Computed

    private var selectedIncome: Double {
        viewModel.suggestedLines
            .filter { $0.isSelected && $0.isIncome }
            .reduce(0) { $0 + $1.suggestedAmount }
    }

    private var selectedExpense: Double {
        viewModel.suggestedLines
            .filter { $0.isSelected && !$0.isIncome }
            .reduce(0) { $0 + $1.suggestedAmount }
    }

    private var netFlow: Double { selectedIncome - selectedExpense }

    private var allSelected: Bool {
        viewModel.suggestedLines.allSatisfy(\.isSelected)
    }

    private var incomeLines: [SuggestedLine] {
        viewModel.suggestedLines.filter(\.isIncome)
    }

    private var expenseLines: [SuggestedLine] {
        viewModel.suggestedLines.filter { !$0.isIncome }
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Spacing.xl) {
                    headerSection
                    if viewModel.suggestedLines.isEmpty {
                        emptyState
                    } else {
                        bannerSection
                            .coachMarkAnchor("cfSetupBanner")
                        if !allSelected {
                            selectAllButton
                        }
                        if !incomeLines.isEmpty {
                            lineSection(
                                title: L10n.CashFlowPlan.incomeSection,
                                lines: incomeLines,
                                isIncome: true
                            )
                            .coachMarkAnchor("cfSetupLine")
                        }
                        if !expenseLines.isEmpty {
                            lineSection(
                                title: L10n.CashFlowPlan.expenseSection,
                                lines: expenseLines,
                                isIncome: false
                            )
                        }
                        startingBalanceSection
                            .coachMarkAnchor("cfSetupStarting")
                        summarySection
                        createButton
                            .coachMarkAnchor("cfSetupCreate")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .yalaSafeBottomPadding()
            }
            .scrollDisabled(showTour)
            .onAppear { setupScrollProxy = scrollProxy }
        }
        .onAppear {
            viewModel.generateSuggestions(
                transactions: transactions,
                scheduledPayments: scheduledPayments,
                categories: categories,
                currencyCode: currencyCode
            )
        }
        .sheet(item: $editingLine) { line in
            CashFlowMethodPickerSheet(
                line: line,
                currencyCode: currencyCode,
                viewModel: viewModel
            )
        }
        .coachMarkOverlay(
            steps: CashFlowSetupTourSteps.steps,
            isPresented: $showTour,
            currentIndex: $tourIndex,
            scrollProxy: setupScrollProxy
        ) {
            appPreferences.hasSeenCashFlowSetupTour = true
        }
        .task {
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            if !viewModel.suggestedLines.isEmpty && !appPreferences.hasSeenCashFlowSetupTour {
                showTour = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Text(L10n.CashFlowPlan.title)
            .font(DS.Typography.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Banner

    private var bannerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(theme.accent)
                .font(DS.Typography.headline)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L10n.CashFlowPlan.bannerTitle)
                    .font(DS.Typography.subheadline)
                    .fontWeight(.semibold)
                Text(L10n.CashFlowPlan.bannerBody)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Semantic.infoBackground)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState(
            icon: "arrow.left.arrow.right",
            title: L10n.CashFlowPlan.emptyState,
            message: L10n.CashFlowPlan.emptyStateMessage
        )
        .padding(.top, DS.Spacing.xxl)
    }

    // MARK: - Select All

    private var selectAllButton: some View {
        Button {
            viewModel.selectAllSuggestedLines()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.body)
                Text(L10n.CashFlowPlan.selectAll)
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Line Section

    private func lineSection(title: String, lines: [SuggestedLine], isIncome: Bool) -> some View {
        VStack(spacing: DS.Spacing.none) {
            Text(title.uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(lines) { line in
                    suggestedLineRow(line)
                    if line.id != lines.last?.id {
                        Divider()
                            .padding(.leading, DS.Spacing.xxl)
                    }
                }
            }
            .solidCard()
        }
    }

    // MARK: - Line Row

    private func suggestedLineRow(_ line: SuggestedLine) -> some View {
        let index = viewModel.suggestedLines.firstIndex(where: { $0.id == line.id })
        let iconName = line.subcategory?.iconName ?? line.category?.iconName ?? "tag.fill"
        let colorHex = line.subcategory?.colorHex ?? line.category?.colorHex ?? AppConstants.defaultColorHex

        return HStack(spacing: DS.Spacing.md) {
            Button {
                if let index {
                    viewModel.suggestedLines[index].isSelected.toggle()
                }
            } label: {
                Image(systemName: line.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(line.isSelected ? theme.accent : .secondary)
                    .font(DS.Typography.headline)
            }
            .buttonStyle(.plain)

            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                Image(systemName: iconName)
                    .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(line.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                if line.scheduledPayment != nil {
                    Text(L10n.CashFlowPlan.scheduled)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(L10n.CashFlowPlan.suggestedSource(line.monthsWithActivity))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(YalaFormatter.currency(value: line.suggestedAmount, currencyCode: currencyCode))
                .font(DS.Typography.body)
                .foregroundStyle(line.isIncome ? Color.electricIndigo : .primary)
                .monospacedDigit()

            Button {
                editingLine = line
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(DS.Typography.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            editingLine = line
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: DS.Spacing.sm) {
            summaryRow(label: L10n.CashFlow.income, amount: selectedIncome, color: Color.electricIndigo)
            summaryRow(label: L10n.CashFlow.expense, amount: -selectedExpense, color: Color.hotPink)
            Divider()
            summaryRow(
                label: L10n.CashFlowPlan.available,
                amount: netFlow,
                color: netFlow >= 0 ? Color.electricIndigo : Color.hotPink,
                isBold: true
            )
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    private func summaryRow(label: String, amount: Double, color: Color, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? DS.Typography.headline : DS.Typography.body)
            Spacer()
            Text(YalaFormatter.currency(value: amount, currencyCode: currencyCode))
                .font(isBold ? DS.Typography.headline : DS.Typography.body)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    // MARK: - Starting Balance

    private var startingBalanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.startingBalance)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            TextField("0", text: $startingBalance)
                .keyboardType(.decimalPad)
                .font(DS.Typography.headline)
                .monospacedDigit()
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
            Text(L10n.CashFlowPlan.startingBalanceHelper)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        YalaPrimaryButton(
            L10n.CashFlowPlan.createButton,
            icon: "plus.circle.fill",
            isDisabled: viewModel.suggestedLines.filter(\.isSelected).isEmpty
        ) {
            let balance = AmountInputHelper.parseDecimal(startingBalance)
            viewModel.createPlan(startingBalance: balance)
        }
    }
}

// MARK: - Method Picker Sheet

struct CashFlowMethodPickerSheet: View {
    let line: SuggestedLine
    let currencyCode: String
    @Bindable var viewModel: CashFlowPlanViewModel

    @State private var selectedMethod: EstimationMethod
    @State private var manualAmountText: String = ""
    @State private var previewAmount: Double

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    init(line: SuggestedLine, currencyCode: String, viewModel: CashFlowPlanViewModel) {
        self.line = line
        self.currencyCode = currencyCode
        self.viewModel = viewModel
        self._selectedMethod = State(initialValue: line.estimationMethod)
        self._previewAmount = State(initialValue: line.suggestedAmount)
        if line.estimationMethod == .manual {
            self._manualAmountText = State(initialValue: String(format: "%.0f", line.suggestedAmount))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        // Live amount preview
                        VStack(spacing: DS.Spacing.xs) {
                            Text(line.name)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            Text(YalaFormatter.currency(value: previewAmount, currencyCode: currencyCode))
                                .font(DS.Typography.title)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.default, value: previewAmount)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.md)

                        // Methods
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(availableMethods, id: \.self) { method in
                                methodRow(method: method)
                                if method != availableMethods.last {
                                    Divider().padding(.leading, DS.Spacing.xxl)
                                }
                            }
                        }
                        .solidCard()

                        // Manual amount field
                        if selectedMethod == .manual {
                            TextField("0", text: $manualAmountText)
                                .keyboardType(.decimalPad)
                                .font(DS.Typography.headline)
                                .monospacedDigit()
                                .padding(DS.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                        .fill(.thCard)
                                )
                                .onChange(of: manualAmountText) {
                                    let parsed = AmountInputHelper.parseDecimal(manualAmountText)
                                    previewAmount = parsed
                                }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                    .yalaSafeBottomPadding()
                    .dismissKeyboardOnTap()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(L10n.CashFlowPlan.calculationMethodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { applyAndDismiss() })
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private var availableMethods: [EstimationMethod] {
        var methods: [EstimationMethod] = [.average6m, .average3m, .lastMonth, .manual]
        if line.scheduledPayment != nil {
            methods.insert(.scheduled, at: 0)
        }
        return methods
    }

    private func methodRow(method: EstimationMethod) -> some View {
        Button {
            selectedMethod = method
            recalculatePreview()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedMethod == method ? theme.accent : .secondary)
                    .font(DS.Typography.headline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(methodDisplayName(method))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(method.descriptionText)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func recalculatePreview() {
        if selectedMethod == .manual {
            let parsed = AmountInputHelper.parseDecimal(manualAmountText)
            previewAmount = parsed
        } else {
            previewAmount = viewModel.previewAmount(for: line, method: selectedMethod)
        }
    }

    private func methodDisplayName(_ method: EstimationMethod) -> String {
        method.displayName
    }

    private func applyAndDismiss() {
        let manualAmount: Double? = manualAmountText.isEmpty ? nil : AmountInputHelper.parseDecimal(manualAmountText)
        viewModel.updateEstimationMethod(for: line.id, to: selectedMethod, manualAmount: manualAmount)
        dismiss()
    }
}
