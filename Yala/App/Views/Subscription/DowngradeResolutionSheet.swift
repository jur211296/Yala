//
//  DowngradeResolutionSheet.swift
//  Yala
//
//  Sheet for resolving excess accounts/budgets after downgrade from Pro.
//

import SwiftData
import SwiftUI

struct DowngradeResolutionSheet: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    // MARK: - Properties

    let accounts: [Account]
    let budgets: [Budget]
    let onComplete: () -> Void

    // MARK: - Computed

    private var activeAccounts: [Account] {
        accounts.billableUserAccounts
    }

    private var activeBudgets: [Budget] {
        budgets.filter { $0.isActive }
    }

    private var excessAccounts: Int {
        max(0, activeAccounts.count - (ProFeature.accounts.freeLimit ?? Int.max))
    }

    private var excessBudgets: Int {
        max(0, activeBudgets.count - (ProFeature.budgets.freeLimit ?? Int.max))
    }

    private var accountsToKeep: Int { ProFeature.accounts.freeLimit ?? Int.max }
    private var budgetsToKeep: Int { ProFeature.budgets.freeLimit ?? Int.max }

    // MARK: - State

    @State private var selectedAccountIDs: Set<PersistentIdentifier> = []
    @State private var selectedBudgetIDs: Set<PersistentIdentifier> = []
    @State private var showSubscription = false

    private var canConfirm: Bool {
        let accountsOK = excessAccounts == 0 || selectedAccountIDs.count == accountsToKeep
        let budgetsOK = excessBudgets == 0 || selectedBudgetIDs.count == budgetsToKeep
        return accountsOK && budgetsOK
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    headerSection

                    // Account selection (if excess)
                    if excessAccounts > 0 {
                        accountSelectionSection
                    }

                    // Budget selection (if excess)
                    if excessBudgets > 0 {
                        budgetSelectionSection
                    }

                    // Buttons
                    VStack(spacing: DS.Spacing.md) {
                        YalaPrimaryButton(
                            L10n.Subscription.Downgrade.confirm,
                            isDisabled: !canConfirm
                        ) {
                            archiveExcessItems()
                            onComplete()
                        }

                        Button(L10n.Subscription.Downgrade.reactivate) {
                            showSubscription = true
                        }
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thAccent)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()  // Cannot dismiss without resolving
        }
        .sheet(isPresented: $showSubscription, onDismiss: {
            if StoreKitManager.shared.isProUser {
                onComplete()
            }
        }) {
            NavigationStack {
                SubscriptionView(source: "downgrade")
            }
        }
        .onAppear {
            // Pre-select first N accounts by name alphabetically
            let sortedAccounts = activeAccounts.sorted { $0.name < $1.name }
            selectedAccountIDs = Set(sortedAccounts.prefix(accountsToKeep).map { $0.persistentModelID })

            // Pre-select budgets by most recently created first
            let sortedBudgets = activeBudgets.sorted { $0.createdAt > $1.createdAt }
            selectedBudgetIDs = Set(sortedBudgets.prefix(budgetsToKeep).map { $0.persistentModelID })
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: heroIconSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(
                    LinearGradient(
                        colors: DS.Gradients.warning,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .accessibilityHidden(true)

            Text(L10n.Subscription.Downgrade.title)
                .font(.title2.bold())
                .foregroundStyle(.thPrimaryText)
                .multilineTextAlignment(.center)

            Text(L10n.Subscription.Downgrade.subtitle)
                .font(DS.Typography.body)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private var accountSelectionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Subscription.Downgrade.selectAccounts(accountsToKeep))
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .padding(.horizontal, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.none) {
                ForEach(activeAccounts, id: \.persistentModelID) { account in
                    accountRow(account)

                    if account.persistentModelID != activeAccounts.last?.persistentModelID {
                        Divider()
                            .padding(.leading, DS.Icon.badgeLarge + DS.Spacing.xl)
                    }
                }
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.horizontal, DS.Spacing.lg)

            // Selection count
            Text(L10n.FeatureGate.limitInfo(selectedAccountIDs.count, accountsToKeep))
                .font(DS.Typography.caption)
                .foregroundStyle(selectedAccountIDs.count == accountsToKeep ? DS.Semantic.successForeground : DS.Semantic.warningForeground)
                .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private func accountRow(_ account: Account) -> some View {
        let isSelected = selectedAccountIDs.contains(account.persistentModelID)

        return Button {
            toggleAccountSelection(account)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Account icon
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(colorForHex(account.colorHex))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    .overlay(
                        Image(systemName: account.iconName)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(account.name)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)

                    Text(account.currencyCode)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .foregroundStyle(isSelected ? theme.accent : theme.secondaryText.opacity(0.3))
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var budgetSelectionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Subscription.Downgrade.selectBudgets(budgetsToKeep))
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .padding(.horizontal, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.none) {
                ForEach(activeBudgets, id: \.persistentModelID) { budget in
                    budgetRow(budget)

                    if budget.persistentModelID != activeBudgets.last?.persistentModelID {
                        Divider()
                            .padding(.leading, DS.Icon.badgeLarge + DS.Spacing.xl)
                    }
                }
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.horizontal, DS.Spacing.lg)

            // Selection count
            Text(L10n.FeatureGate.limitInfo(selectedBudgetIDs.count, budgetsToKeep))
                .font(DS.Typography.caption)
                .foregroundStyle(selectedBudgetIDs.count == budgetsToKeep ? DS.Semantic.successForeground : DS.Semantic.warningForeground)
                .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private func budgetRow(_ budget: Budget) -> some View {
        let isSelected = selectedBudgetIDs.contains(budget.persistentModelID)

        return Button {
            toggleBudgetSelection(budget)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Budget icon
                Circle()
                    .fill(theme.accent)
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    .overlay(
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(budget.name)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)

                    Text(formatCurrency(budget.limitAmount, code: budget.currencyCode))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .foregroundStyle(isSelected ? theme.accent : theme.secondaryText.opacity(0.3))
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection Logic

    private func toggleAccountSelection(_ account: Account) {
        let id = account.persistentModelID

        if selectedAccountIDs.contains(id) {
            selectedAccountIDs.remove(id)
        } else if selectedAccountIDs.count < accountsToKeep {
            selectedAccountIDs.insert(id)
        }
        // If already at limit, tapping another item does nothing
    }

    private func toggleBudgetSelection(_ budget: Budget) {
        let id = budget.persistentModelID

        if selectedBudgetIDs.contains(id) {
            selectedBudgetIDs.remove(id)
        } else if selectedBudgetIDs.count < budgetsToKeep {
            selectedBudgetIDs.insert(id)
        }
    }

    // MARK: - Archive Logic

    private func archiveExcessItems() {
        // Archive accounts not selected
        for account in activeAccounts {
            if !selectedAccountIDs.contains(account.persistentModelID) {
                account.isArchived = true
            }
        }

        // Deactivate budgets not selected
        for budget in activeBudgets {
            if !selectedBudgetIDs.contains(budget.persistentModelID) {
                budget.isActive = false
            }
        }

        // Save changes
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("DowngradeResolutionSheet: Error saving: \(error)")
            #endif
        }

        // Clear wasProUser flag since we've resolved the downgrade
        StoreKitManager.shared.wasProUser = false
    }

    // MARK: - Static Formatters

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double, code: String) -> String {
        Self.currencyFormatter.currencyCode = code
        return Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - L10n Extension

extension L10n.Subscription {
    enum Downgrade {
        static var title: String {
            NSLocalizedString("subscription.downgrade.title", comment: "Downgrade sheet title")
        }
        static var subtitle: String {
            NSLocalizedString("subscription.downgrade.subtitle", comment: "Downgrade sheet subtitle")
        }
        static func selectAccounts(_ count: Int) -> String {
            String(format: NSLocalizedString("subscription.downgrade.selectAccounts", comment: ""), count)
        }
        static func selectBudgets(_ count: Int) -> String {
            String(format: NSLocalizedString("subscription.downgrade.selectBudgets", comment: ""), count)
        }
        static var confirm: String {
            NSLocalizedString("subscription.downgrade.confirm", comment: "Confirm button")
        }
        static var reactivate: String {
            NSLocalizedString("subscription.downgrade.reactivate", comment: "Reactivate Pro button")
        }
    }
}

// MARK: - Preview

#Preview {
    DowngradeResolutionSheet(
        accounts: [],
        budgets: []
    ) {}
}
