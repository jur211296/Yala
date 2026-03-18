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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    private var otherResult: CashFlowOtherResult? {
        viewModel.projection?.months.first(where: \.isCurrent)?.otherExpenses
            ?? viewModel.projection?.months.first?.otherExpenses
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
            .navigationTitle(L10n.CashFlowPlan.othersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Description

    private var descriptionText: some View {
        Text(L10n.CashFlowPlan.othersDesc)
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
                        .frame(width: 24)

                    Text(item.categoryName)
                        .font(DS.Typography.body)

                    Spacer()

                    Text(YalaFormatter.currency(value: item.amount, currencyCode: currencyCode))
                        .font(DS.Typography.amountSmall)
                        .monospacedDigit()

                    Button {
                        promoteCategory(named: item.categoryName)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(theme.accent)
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
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    // MARK: - Hint

    private var hintText: some View {
        Text(L10n.CashFlowPlan.othersHint)
            .font(DS.Typography.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Promote

    private func promoteCategory(named name: String) {
        // Find the category from the plan's allExpenseCategories
        // We need to search in the model context
        guard let ctx = viewModel.plan?.modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Category>()
            let categories = try ctx.fetch(descriptor)
            if let category = categories.first(where: { $0.name == name }) {
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
