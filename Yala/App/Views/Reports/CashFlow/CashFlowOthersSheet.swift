//
//  CashFlowOthersSheet.swift
//  Yala
//
//  Sheet showing breakdown of "other expenses" categories not assigned to any line.
//

import SwiftData
import SwiftUI

struct CashFlowOthersSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    var isIncome: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var selectedDetent: PresentationDetent = .medium

    private var isLargeDetent: Bool { selectedDetent == .large }

    private var otherResult: CashFlowOtherResult? {
        Self.otherResult(
            in: viewModel.projection?.months ?? [],
            selectedMonthKey: viewModel.selectedMonthKey,
            isIncome: isIncome
        )
    }

    /// Lo no considerado del mes elegido en la tira, que es desde donde se abre la hoja. Antes leía siempre el mes en
    /// curso y, abierta desde otro mes, enseñaba lo de este (lote 08 de las necesarias 2.3). Un mes elegido sin nada
    /// no cae al mes en curso; solo si la clave ya no está en la proyección (cambió el horizonte) se enseña el actual.
    static func otherResult(in months: [CashFlowMonth], selectedMonthKey: String, isIncome: Bool) -> CashFlowOtherResult? {
        let month = months.first { $0.monthKey == selectedMonthKey }
            ?? months.first(where: \.isCurrent)
            ?? months.first
        return isIncome ? month?.otherIncome : month?.otherExpenses
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    descriptionText
                    if let other = otherResult {
                        categoryList(other)
                    }
                    hintText
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .yalaSafeBottomPadding()
            }
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(isIncome ? L10n.CashFlowPlan.othersIncomeTitle : L10n.CashFlowPlan.othersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
    }

    // MARK: - Description

    private var descriptionText: some View {
        Text(isIncome ? L10n.CashFlowPlan.othersIncomeDesc : L10n.CashFlowPlan.othersDesc)
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category List

    private func categoryList(_ other: CashFlowOtherResult) -> some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(other.categoryBreakdown, id: \.categoryName) { item in
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: item.iconName)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color(hex: item.colorHex))
                        .frame(width: DS.Icon.badgeSmall)

                    Text(item.categoryName)
                        .font(DS.Typography.body)

                    Spacer()

                    AmountText(
                        value: item.amount,
                        currencyCode: currencyCode,
                        font: DS.Typography.amountSmall.monospacedDigit()
                    )
                    .accessibilityIdentifier("cashflow_others_item_amount")

                    Button {
                        promoteCategory(named: item.categoryName)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(theme.accentText)
                            .font(DS.Typography.headline)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)

                if item.categoryName != other.categoryBreakdown.last?.categoryName {
                    Divider()
                        .padding(.leading, DS.Spacing.xxl + 24)
                }
            }
        }
        .solidCard()
    }

    // MARK: - Hint

    private var hintText: some View {
        Text(isIncome ? L10n.CashFlowPlan.othersIncomeHint : L10n.CashFlowPlan.othersHint)
            .font(DS.Typography.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Promote

    private func promoteCategory(named name: String) {
        guard let ctx = viewModel.plan?.modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Category>()
            let categories = try ctx.fetch(descriptor)
            if let category = categories.first(where: { $0.name == name && $0.isIncome == isIncome }) {
                viewModel.promoteFromOthers(category)
                dismiss()
            }
        } catch {
            #if DEBUG
            print("CashFlowOthersSheet: Error fetching category: \(error)")
            #endif
        }
    }
}
