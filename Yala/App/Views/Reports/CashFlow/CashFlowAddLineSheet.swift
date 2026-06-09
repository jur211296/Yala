//
//  CashFlowAddLineSheet.swift
//  Yala
//
//  Sheet for adding a new line to the cash flow plan.
//  3 flows: from expenses (subcategories), from scheduled payments, custom line.
//

import SwiftUI
import SwiftData

struct CashFlowAddLineSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    var transactions: [TransactionItem] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var isIncome: Bool = false

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(filter: #Predicate<ScheduledPayment> { $0.isActive }) private var scheduledPayments: [ScheduledPayment]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Type toggle
                    Picker("", selection: $isIncome) {
                        Text(L10n.CashFlowPlan.expenseSection).tag(false)
                        Text(L10n.CashFlowPlan.incomeSection).tag(true)
                    }
                    .pickerStyle(.segmented)

                    // 3 flow options
                    VStack(spacing: DS.Spacing.none) {
                        // Flow 1: From expenses
                        NavigationLink {
                            CashFlowAddFromExpensesView(
                                viewModel: viewModel,
                                currencyCode: currencyCode,
                                transactions: transactions,
                                isIncome: isIncome,
                                categories: sortedCategories
                            )
                        } label: {
                            flowRow(
                                icon: "chart.bar.fill",
                                title: L10n.CashFlowPlan.addFromExpenses,
                                subtitle: L10n.CashFlowPlan.addFromExpensesDesc,
                                trailing: nil
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, DS.Spacing.xxl)

                        // Flow 2: From scheduled payment
                        let available = availableScheduledPayments
                        NavigationLink {
                            CashFlowAddFromScheduledView(
                                viewModel: viewModel,
                                currencyCode: currencyCode,
                                payments: available
                            )
                        } label: {
                            flowRow(
                                icon: "calendar.badge.clock",
                                title: L10n.CashFlowPlan.addFromScheduled,
                                subtitle: L10n.CashFlowPlan.addFromScheduledDesc,
                                trailing: available.isEmpty ? nil : "\(available.count)"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, DS.Spacing.xxl)

                        // Flow 3: Custom line
                        NavigationLink {
                            CashFlowAddCustomLineView(
                                viewModel: viewModel,
                                currencyCode: currencyCode,
                                isIncome: isIncome
                            )
                        } label: {
                            flowRow(
                                icon: "pencil.line",
                                title: L10n.CashFlowPlan.addCustomLine,
                                subtitle: L10n.CashFlowPlan.addCustomLineDesc,
                                trailing: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .solidCard()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.CashFlowPlan.addLine)
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
        .onAppear {
            isIncome = viewModel.addLineIsIncome
        }
    }

    // MARK: - Flow Row

    private func flowRow(icon: String, title: String, subtitle: String, trailing: String?) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }

            Image(systemName: "chevron.right")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Computed

    private var sortedCategories: [Category] {
        let filtered = categories.filter { $0.isIncome == isIncome && $0.isVisible }
        if transactions.isEmpty { return filtered }
        let spending = categorySpending(for: filtered)
        return filtered.sorted { (spending[$0.persistentModelID] ?? 0) > (spending[$1.persistentModelID] ?? 0) }
    }

    private var availableScheduledPayments: [ScheduledPayment] {
        let linkedIDs = Set((viewModel.plan?.lines ?? []).compactMap { $0.scheduledPayment?.persistentModelID })
        return scheduledPayments.filter { !linkedIDs.contains($0.persistentModelID) }
    }

    private func categorySpending(for cats: [Category]) -> [PersistentIdentifier: Double] {
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: .now) ?? .now
        var totals: [PersistentIdentifier: Double] = [:]
        for tx in transactions where tx.date >= sixMonthsAgo {
            guard let cat = tx.category, cat.isIncome == isIncome else { continue }
            totals[cat.persistentModelID, default: 0] += abs(tx.amount)
        }
        for key in totals.keys { totals[key] = (totals[key] ?? 0) / 6 }
        return totals
    }
}

// MARK: - Flow 1: From Expenses

struct CashFlowAddFromExpensesView: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    let transactions: [TransactionItem]
    let isIncome: Bool
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: Subcategory?
    @State private var name: String = ""
    @State private var selectedMethod: EstimationMethod = .average6m

    private var isSaveDisabled: Bool {
        if name.isEmpty { return true }
        guard let cat = selectedCategory else { return false }
        let hasVisibleSubs = !(cat.subcategories ?? []).filter(\.isVisible).isEmpty
        return hasVisibleSubs && selectedSubcategory == nil
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    if categories.isEmpty {
                        YalaEmptyState(
                            icon: "chart.bar",
                            title: L10n.CashFlowPlan.noCategories
                        )
                    } else {
                        categoryList
                        if selectedCategory != nil {
                            nameField
                            methodSelector
                            previewCard
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .yalaSafeBottomPadding()
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.CashFlowPlan.addFromExpenses)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                YalaSaveButton(action: {
                    createLine()
                    dismiss()
                }, isDisabled: isSaveDisabled)
            }
        }
    }

    private var categoryList: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(categories, id: \.persistentModelID) { cat in
                let hasVisibleSubs = !(cat.subcategories ?? []).filter(\.isVisible).isEmpty
                VStack(spacing: DS.Spacing.none) {
                    // Category row
                    Button {
                        if selectedCategory?.persistentModelID == cat.persistentModelID {
                            selectedCategory = nil
                            selectedSubcategory = nil
                        } else {
                            selectedCategory = cat
                            selectedSubcategory = nil
                            if !hasVisibleSubs, name.isEmpty { name = cat.name }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: cat.colorHex))
                                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                                if let iconName = cat.iconName {
                                    Image(systemName: iconName)
                                        .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }

                            Text(cat.name)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            let avg = averageAmount(for: cat)
                            if avg > 0 {
                                Text(YalaFormatter.amountCompactTable(value: avg))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }

                            let isSelected = selectedCategory?.persistentModelID == cat.persistentModelID
                            if hasVisibleSubs {
                                Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(DS.Typography.caption)
                            } else {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? theme.accent : .secondary)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Subcategories (expanded when parent selected)
                    if selectedCategory?.persistentModelID == cat.persistentModelID,
                       let subs = cat.subcategories?.filter({ $0.isVisible }).sorted(by: { $0.sortOrder < $1.sortOrder }),
                       !subs.isEmpty {
                        ForEach(subs, id: \.persistentModelID) { sub in
                            Button {
                                if selectedSubcategory?.persistentModelID == sub.persistentModelID {
                                    selectedSubcategory = nil
                                    name = cat.name
                                } else {
                                    selectedSubcategory = sub
                                    name = sub.name
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.md) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: sub.colorHex ?? cat.colorHex))
                                            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                                        if let iconName = sub.iconName {
                                            Image(systemName: iconName)
                                                .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Text(sub.name)
                                        .font(DS.Typography.subheadline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Image(systemName: selectedSubcategory?.persistentModelID == sub.persistentModelID ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedSubcategory?.persistentModelID == sub.persistentModelID ? theme.accent : .secondary)
                                        .font(DS.Typography.caption)
                                }
                                .padding(.leading, DS.Spacing.xxl)
                                .padding(.trailing, DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if cat.persistentModelID != categories.last?.persistentModelID {
                        Divider().padding(.leading, DS.Spacing.xxl)
                    }
                }
            }
        }
        .solidCard()
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.CashFlowPlan.lineNameLabel)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.CashFlowPlan.lineNameHint)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
            TextField(L10n.CashFlowPlan.addLine, text: $name)
                .font(DS.Typography.body)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
        }
    }

    private var methodSelector: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.estimationMethod)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.sm) {
                ForEach([EstimationMethod.average6m, .average3m, .lastMonth], id: \.self) { method in
                    Button {
                        selectedMethod = method
                    } label: {
                        Text(method.displayName)
                            .font(DS.Typography.caption)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                selectedMethod == method
                                    ? AnyShapeStyle(theme.accent.opacity(0.15))
                                    : AnyShapeStyle(Color.clear)
                            )
                            .foregroundStyle(selectedMethod == method ? theme.accent : .secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(selectedMethod == method ? theme.accent.opacity(0.3) : theme.secondaryText.opacity(DS.Opacity.subtle), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var previewCard: some View {
        let amount = computePreview()
        return HStack {
            Text(L10n.CashFlowPlan.plan)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            AmountText(
                value: amount,
                currencyCode: currencyCode,
                font: DS.Typography.headline.weight(.semibold).monospacedDigit(),
                tint: .color(isIncome ? Color.electricIndigo : Color.hotPink)
            )
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    // MARK: - Helpers

    private func averageAmount(for category: Category) -> Double {
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: .now) ?? .now
        var total: Double = 0
        for tx in transactions where tx.date >= sixMonthsAgo {
            guard tx.category?.persistentModelID == category.persistentModelID else { continue }
            total += abs(tx.amount)
        }
        return total / 6
    }

    private func computePreview() -> Double {
        if let sub = selectedSubcategory {
            let calendar = Calendar.current
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: .now) ?? .now
            var total: Double = 0
            for tx in transactions where tx.date >= sixMonthsAgo {
                guard tx.subcategory?.persistentModelID == sub.persistentModelID else { continue }
                total += abs(tx.amount)
            }
            return total / 6
        }
        if let cat = selectedCategory {
            return averageAmount(for: cat)
        }
        return 0
    }

    private func createLine() {
        let maxOrder = (viewModel.plan?.lines ?? []).map(\.sortOrder).max() ?? 0
        let line = CashFlowLine(
            name: name,
            isIncome: isIncome,
            sortOrder: maxOrder + 1,
            estimationMethod: selectedMethod,
            category: selectedCategory,
            subcategory: selectedSubcategory
        )
        viewModel.addLine(line)
    }
}

// MARK: - Flow 2: From Scheduled Payment

struct CashFlowAddFromScheduledView: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    let payments: [ScheduledPayment]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var selectedPayment: ScheduledPayment?
    @State private var name: String = ""

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    if payments.isEmpty {
                        YalaEmptyState(
                            icon: "calendar.badge.clock",
                            title: L10n.CashFlowPlan.noScheduledPayments
                        )
                    } else {
                        paymentList
                        if selectedPayment != nil {
                            nameField
                            previewCard
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .yalaSafeBottomPadding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.CashFlowPlan.addFromScheduled)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                YalaSaveButton(action: {
                    createLine()
                    dismiss()
                }, isDisabled: name.isEmpty || selectedPayment == nil)
            }
        }
    }

    private var paymentList: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(payments, id: \.persistentModelID) { payment in
                Button {
                    if selectedPayment?.persistentModelID == payment.persistentModelID {
                        selectedPayment = nil
                    } else {
                        selectedPayment = payment
                        if name.isEmpty { name = payment.name }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        let iconName = payment.subcategory?.iconName ?? payment.subcategory?.category?.iconName ?? "calendar"
                        let colorHex = payment.subcategory?.colorHex ?? payment.subcategory?.category?.colorHex ?? AppConstants.defaultColorHex
                        ZStack {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                            Image(systemName: iconName)
                                .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(payment.name)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                            Text(payment.recurrenceType.capitalized)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        AmountText(
                            value: abs(payment.amount),
                            currencyCode: currencyCode,
                            font: DS.Typography.amountSmall.monospacedDigit(),
                            tint: .secondary,
                            isEstimate: payment.isVariableAmount
                        )

                        Image(systemName: selectedPayment?.persistentModelID == payment.persistentModelID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedPayment?.persistentModelID == payment.persistentModelID ? theme.accent : .secondary)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if payment.persistentModelID != payments.last?.persistentModelID {
                    Divider().padding(.leading, DS.Spacing.xxl)
                }
            }
        }
        .solidCard()
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.lineNameLabel)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            TextField(L10n.CashFlowPlan.addLine, text: $name)
                .font(DS.Typography.body)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
        }
    }

    private var previewCard: some View {
        let amount = abs(selectedPayment?.amount ?? 0)
        return HStack {
            Text(L10n.CashFlowPlan.plan)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            AmountText(
                value: amount,
                currencyCode: currencyCode,
                font: DS.Typography.headline.weight(.semibold).monospacedDigit()
            )
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    private func createLine() {
        guard let payment = selectedPayment else { return }
        let maxOrder = (viewModel.plan?.lines ?? []).map(\.sortOrder).max() ?? 0
        let line = CashFlowLine(
            name: name,
            isIncome: payment.transactionType == "income",
            sortOrder: maxOrder + 1,
            estimationMethod: .scheduled,
            category: payment.subcategory?.category,
            subcategory: payment.subcategory,
            scheduledPayment: payment
        )
        viewModel.addLine(line)
    }
}

// MARK: - Flow 3: Custom Line

struct CashFlowAddCustomLineView: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    let isIncome: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amountText: String = ""

    var body: some View {
        ZStack {
            VStack(spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.CashFlowPlan.lineNameLabel)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                    TextField(L10n.CashFlowPlan.addLine, text: $name)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .fill(.thCard)
                        )
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.CashFlowPlan.overrideAmount)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(DS.Typography.title)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .padding(DS.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .fill(.thCard)
                        )
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xl)
            .dismissKeyboardOnTap()
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.CashFlowPlan.addCustomLine)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                YalaSaveButton(action: {
                    createLine()
                    dismiss()
                }, isDisabled: name.isEmpty || amountText.isEmpty)
            }
        }
    }

    private func createLine() {
        let maxOrder = (viewModel.plan?.lines ?? []).map(\.sortOrder).max() ?? 0
        let amount = AmountInputHelper.parseDecimal(amountText)
        let line = CashFlowLine(
            name: name,
            isIncome: isIncome,
            sortOrder: maxOrder + 1,
            estimationMethod: .manual,
            manualAmount: amount
        )
        viewModel.addLine(line)
    }
}
