//
//  CashFlowAddLineSheet.swift
//  Yala
//
//  Sheet for adding a new line to the cash flow plan.
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

    @State private var name: String = ""
    @State private var isIncome: Bool = false
    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedMethod: EstimationMethod = .average6m
    @State private var manualAmountText: String = ""

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // MARK: - Computed

    /// Categories sorted by total spending (descending)
    private var sortedCategories: [Category] {
        let filtered = categories.filter { $0.isIncome == isIncome && $0.isVisible }
        if transactions.isEmpty {
            return filtered
        }
        let spending = categorySpending(for: filtered)
        return filtered.sorted { (spending[$0.persistentModelID] ?? 0) > (spending[$1.persistentModelID] ?? 0) }
    }

    /// Average monthly spending per category (last 6 months)
    private func categorySpending(for cats: [Category]) -> [PersistentIdentifier: Double] {
        let calendar = Calendar.current
        let now = Date.now
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now

        var totals: [PersistentIdentifier: Double] = [:]
        for tx in transactions where tx.date >= sixMonthsAgo {
            guard let cat = tx.category, cat.isIncome == isIncome else { continue }
            totals[cat.persistentModelID, default: 0] += abs(tx.amount)
        }
        // Average per month
        for key in totals.keys {
            totals[key] = (totals[key] ?? 0) / 6
        }
        return totals
    }

    private func averageAmount(for category: Category) -> Double {
        let spending = categorySpending(for: [category])
        return spending[category.persistentModelID] ?? 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView().dismissKeyboardOnTap()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        // 1. Segmented picker (pre-selected from context)
                        typeToggle

                        // 2. Category cards with circled icons + average
                        categoryPicker

                        // 3. Subcategories when category selected
                        if let cat = selectedCategory,
                           let subs = cat.subcategories?.filter({ $0.isVisible }),
                           !subs.isEmpty {
                            subcategorySection(subs.sorted(by: { $0.sortOrder < $1.sortOrder }), parentCategory: cat)
                        }

                        // 4. Editable name
                        nameField

                        // 5. Method selector inline
                        methodSelector

                        // 6. Preview amount or manual field
                        if selectedCategory != nil {
                            previewAmountSection
                        } else {
                            manualAmountField
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                    .yalaSafeBottomPadding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(L10n.CashFlowPlan.addLine)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: {
                        createLine()
                        dismiss()
                    }, isDisabled: name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            isIncome = viewModel.addLineIsIncome
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        Picker("", selection: $isIncome) {
            Text(L10n.CashFlowPlan.expenseSection).tag(false)
            Text(L10n.CashFlowPlan.incomeSection).tag(true)
        }
        .pickerStyle(.segmented)
        .onChange(of: isIncome) {
            selectedCategory = nil
            selectedSubcategory = nil
        }
    }

    // MARK: - Name

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

    // MARK: - Category Picker

    private var categoryPicker: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(sortedCategories, id: \.persistentModelID) { cat in
                Button {
                    if selectedCategory?.persistentModelID == cat.persistentModelID {
                        selectedCategory = nil
                        selectedSubcategory = nil
                    } else {
                        selectedCategory = cat
                        selectedSubcategory = nil
                        if name.isEmpty { name = cat.name }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        // Circled icon
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

                        // Monthly average
                        let avg = averageAmount(for: cat)
                        if avg > 0 {
                            Text(YalaFormatter.amountCompactTable(value: avg))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }

                        // Selection indicator
                        Image(systemName: selectedCategory?.persistentModelID == cat.persistentModelID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedCategory?.persistentModelID == cat.persistentModelID ? theme.accent : .secondary)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if cat.persistentModelID != sortedCategories.last?.persistentModelID {
                    Divider().padding(.leading, DS.Spacing.xxl)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    // MARK: - Subcategory Section

    private func subcategorySection(_ subcategories: [Subcategory], parentCategory: Category) -> some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(subcategories, id: \.persistentModelID) { sub in
                Button {
                    if selectedSubcategory?.persistentModelID == sub.persistentModelID {
                        selectedSubcategory = nil
                        name = parentCategory.name
                    } else {
                        selectedSubcategory = sub
                        name = sub.name
                    }
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: sub.colorHex ?? parentCategory.colorHex))
                                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                            if let iconName = sub.iconName {
                                Image(systemName: iconName)
                                    .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text(sub.name)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: selectedSubcategory?.persistentModelID == sub.persistentModelID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedSubcategory?.persistentModelID == sub.persistentModelID ? theme.accent : .secondary)
                            .font(DS.Typography.caption)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if sub.persistentModelID != subcategories.last?.persistentModelID {
                    Divider().padding(.leading, DS.Spacing.xxl)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    // MARK: - Method Selector

    private var availableMethods: [EstimationMethod] {
        [.average6m, .average3m, .lastMonth, .manual]
    }

    private var methodSelector: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.estimationMethod)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.sm) {
                ForEach(availableMethods, id: \.self) { method in
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
                                Capsule().stroke(selectedMethod == method ? theme.accent.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(selectedMethod.descriptionText)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Preview Amount

    // MARK: - Manual Amount Field

    private var manualAmountField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.manual)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            TextField("0", text: $manualAmountText)
                .keyboardType(.decimalPad)
                .font(DS.Typography.headline)
                .monospacedDigit()
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
        }
    }

    // MARK: - Subcategory Average

    private func averageSubcategoryAmount(for subcategory: Subcategory) -> Double {
        let calendar = Calendar.current
        let now = Date.now
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now

        var total: Double = 0
        for tx in transactions where tx.date >= sixMonthsAgo {
            guard tx.subcategory?.persistentModelID == subcategory.persistentModelID else { continue }
            total += abs(tx.amount)
        }
        return total / 6
    }

    private var previewAmountSection: some View {
        let amount: Double = if let sub = selectedSubcategory {
            averageSubcategoryAmount(for: sub)
        } else {
            averageAmount(for: selectedCategory!)
        }
        return HStack {
            Text(L10n.CashFlowPlan.plan)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(YalaFormatter.currency(value: amount, currencyCode: currencyCode))
                .font(DS.Typography.headline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(isIncome ? Color.electricIndigo : Color.hotPink)
        }
        .padding(DS.Spacing.lg)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    // MARK: - Create

    private func createLine() {
        let maxOrder = (viewModel.plan?.lines ?? []).map(\.sortOrder).max() ?? 0
        let method: EstimationMethod = selectedCategory != nil ? selectedMethod : .manual
        let manualAmount: Double? = selectedCategory == nil
            ? Double(manualAmountText.replacing(",", with: "."))
            : nil

        let line = CashFlowLine(
            name: name,
            isIncome: isIncome,
            sortOrder: maxOrder + 1,
            estimationMethod: method,
            manualAmount: manualAmount,
            category: selectedCategory,
            subcategory: selectedSubcategory
        )
        viewModel.addLine(line)
    }
}
