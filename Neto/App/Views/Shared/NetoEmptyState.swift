import SwiftUI

/// Vista de estado vacío reutilizable
/// Uso: Listas vacías, sin resultados, sin datos
struct NetoEmptyState: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.6))

            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                if let message {
                    Text(message)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.electricIndigo)
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Convenience Initializers

extension NetoEmptyState {
    /// Empty state for no transactions
    static func noTransactions(action: (() -> Void)? = nil) -> NetoEmptyState {
        NetoEmptyState(
            icon: "list.bullet.rectangle",
            title: L10n.Empty.noTransactions,
            message: L10n.Statistics.noRecordsDescription,
            actionTitle: action != nil ? L10n.Transaction.new : nil,
            action: action
        )
    }

    /// Empty state for no search results
    static func noResults() -> NetoEmptyState {
        NetoEmptyState(
            icon: "magnifyingglass",
            title: L10n.Search.noResults,
            message: L10n.Search.tryAnotherTerm
        )
    }

    /// Empty state for no tags
    static func noTags(action: (() -> Void)? = nil) -> NetoEmptyState {
        NetoEmptyState(
            icon: "tag.fill",
            title: L10n.Empty.noTags,
            message: L10n.Empty.tagsDescription,
            actionTitle: action != nil ? L10n.Tag.new : nil,
            action: action
        )
    }

    /// Empty state for no accounts
    static func noAccounts(action: (() -> Void)? = nil) -> NetoEmptyState {
        NetoEmptyState(
            icon: "creditcard.fill",
            title: L10n.Empty.noAccounts,
            message: L10n.Empty.accountsDescription,
            actionTitle: action != nil ? L10n.Account.new : nil,
            action: action
        )
    }

    /// Empty state for no categories
    static func noCategories(action: (() -> Void)? = nil) -> NetoEmptyState {
        NetoEmptyState(
            icon: "folder.fill",
            title: L10n.Empty.noCategories,
            message: L10n.Empty.categoriesDescription,
            actionTitle: action != nil ? L10n.Category.new : nil,
            action: action
        )
    }

    /// Empty state for no budgets
    static func noBudgets(action: (() -> Void)? = nil) -> NetoEmptyState {
        NetoEmptyState(
            icon: "chart.pie",
            title: NSLocalizedString("budgets.empty.title", comment: ""),
            message: NSLocalizedString("budgets.empty.message", comment: ""),
            actionTitle: action != nil ? NSLocalizedString("budgets.new", comment: "") : nil,
            action: action
        )
    }

    /// Empty state for no favorites
    static func noFavorites(action: (() -> Void)? = nil) -> NetoEmptyState {
        NetoEmptyState(
            icon: "star",
            title: L10n.Empty.noFavorites,
            message: L10n.Favorites.createTemplate,
            actionTitle: action != nil ? L10n.Favorites.new : nil,
            action: action
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DS.Spacing.xxxl + DS.Spacing.sm) {
            NetoEmptyState.noTransactions { }
            Divider()
            NetoEmptyState.noResults()
            Divider()
            NetoEmptyState.noTags { }
        }
    }
    .background(Color.netoBackground)
}
