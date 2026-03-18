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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @State private var name: String = ""
    @State private var isIncome: Bool = false
    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: Subcategory?
    @State private var manualAmount: String = ""
    @State private var selectedMethod: EstimationMethod = .average6m

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var scheduledPayments: [ScheduledPayment]

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView().dismissKeyboardOnTap()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        typeToggle
                        nameField
                        categoryPicker
                        if selectedCategory == nil {
                            amountField
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
        let filteredCategories = categories.filter { $0.isIncome == isIncome && $0.isVisible }

        return VStack(spacing: DS.Spacing.none) {
            ForEach(filteredCategories, id: \.persistentModelID) { cat in
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
                        Image(systemName: selectedCategory?.persistentModelID == cat.persistentModelID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedCategory?.persistentModelID == cat.persistentModelID ? theme.accent : .secondary)
                        if let iconName = cat.iconName {
                            Image(systemName: iconName)
                                .foregroundStyle(Color(hex: cat.colorHex))
                                .frame(width: 20)
                        }
                        Text(cat.name)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Subcategories (indented) when this category is selected
                if selectedCategory?.persistentModelID == cat.persistentModelID,
                   let subcategories = cat.subcategories?.filter({ $0.isVisible }),
                   !subcategories.isEmpty {
                    ForEach(subcategories.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.persistentModelID) { sub in
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
                                Image(systemName: selectedSubcategory?.persistentModelID == sub.persistentModelID ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedSubcategory?.persistentModelID == sub.persistentModelID ? theme.accent : .secondary)
                                    .font(DS.Typography.caption)
                                if let iconName = sub.iconName {
                                    Image(systemName: iconName)
                                        .foregroundStyle(Color(hex: sub.colorHex ?? sub.category?.colorHex ?? AppConstants.defaultColorHex))
                                        .frame(width: 20)
                                }
                                Text(sub.name)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.leading, DS.Spacing.xxl)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if cat.persistentModelID != filteredCategories.last?.persistentModelID {
                    Divider().padding(.leading, DS.Spacing.xxl)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    // MARK: - Amount

    private var amountField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.manual)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            TextField("0", text: $manualAmount)
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

    // MARK: - Create

    private func createLine() {
        let maxOrder = (viewModel.plan?.lines ?? []).map(\.sortOrder).max() ?? 0
        let amount = Double(manualAmount.replacing(",", with: "."))
        let method: EstimationMethod = selectedCategory != nil ? .average6m : .manual

        let line = CashFlowLine(
            name: name,
            isIncome: isIncome,
            sortOrder: maxOrder + 1,
            estimationMethod: method,
            manualAmount: amount,
            category: selectedCategory,
            subcategory: selectedSubcategory
        )
        viewModel.addLine(line)
    }
}
