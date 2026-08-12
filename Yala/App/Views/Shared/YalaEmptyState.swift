import SwiftUI

/// Vista de estado vacío reutilizable
/// Uso: Listas vacías, sin resultados, sin datos
struct YalaEmptyState: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    enum Style { case standard, widget }

    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let actionAccessibilityIdentifier: String?
    let style: Style

    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        actionAccessibilityIdentifier: String? = nil,
        style: Style = .standard
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.actionAccessibilityIdentifier = actionAccessibilityIdentifier
        self.style = style
    }

    var body: some View {
        VStack(spacing: style == .widget ? DS.Spacing.md : DS.Spacing.lg) {
            Image(systemName: icon)
                .font(style == .widget ? DS.Typography.title : .system(size: heroIconSize, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .accessibilityHidden(true)

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
                let actionButton = Button(action: action) {
                    Text(actionTitle)
                        .font(DS.Typography.label)
                        .foregroundStyle(.thAccent)
                }
                .padding(.top, DS.Spacing.sm)

                // Byte-idéntico para los callers actuales: sin id ⇒ el botón queda EXACTAMENTE igual
                // (ningún modifier extra); solo `groupsSignedOut` pasa un id para el CTA de re-entrada.
                if let actionAccessibilityIdentifier {
                    actionButton.accessibilityIdentifier(actionAccessibilityIdentifier)
                } else {
                    actionButton
                }
            }
        }
        .padding(style == .widget ? DS.Spacing.lg : DS.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: style == .widget ? .infinity : nil)
    }
}

// MARK: - Convenience Initializers

extension YalaEmptyState {
    /// Empty state for no transactions
    static func noTransactions(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "list.bullet.rectangle",
            title: L10n.Empty.noTransactions,
            message: L10n.Statistics.noRecordsDescription,
            actionTitle: action != nil ? L10n.Transaction.new : nil,
            action: action
        )
    }

    /// Empty state for no search results
    static func noResults() -> YalaEmptyState {
        YalaEmptyState(
            icon: "magnifyingglass",
            title: L10n.Search.noResults,
            message: L10n.Search.tryAnotherTerm
        )
    }

    /// Empty state for no tags
    static func noTags(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "tag.fill",
            title: L10n.Empty.noTags,
            message: L10n.Empty.tagsDescription,
            actionTitle: action != nil ? L10n.Tag.new : nil,
            action: action
        )
    }

    /// Empty state for no accounts
    static func noAccounts(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "creditcard.fill",
            title: L10n.Empty.noAccounts,
            message: L10n.Empty.accountsDescription,
            actionTitle: action != nil ? L10n.Account.new : nil,
            action: action
        )
    }

    /// Empty state for no categories
    static func noCategories(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "folder.fill",
            title: L10n.Empty.noCategories,
            message: L10n.Empty.categoriesDescription,
            actionTitle: action != nil ? L10n.Category.new : nil,
            action: action
        )
    }

    /// Empty state for no budgets
    static func noBudgets(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "chart.pie",
            title: NSLocalizedString("budgets.empty.title", comment: ""),
            message: NSLocalizedString("budgets.empty.message", comment: ""),
            actionTitle: action != nil ? NSLocalizedString("budgets.new", comment: "") : nil,
            action: action
        )
    }

    /// Empty state for no favorites
    static func noFavorites(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "star",
            title: L10n.Empty.noFavorites,
            message: L10n.Favorites.createTemplate,
            actionTitle: action != nil ? L10n.Favorites.new : nil,
            action: action
        )
    }

    /// Empty state for no groups
    static func noGroups(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "person.2.fill",
            title: L10n.Groups.Empty.title,
            message: L10n.Groups.Empty.message,
            actionTitle: action != nil ? L10n.Groups.Empty.action : nil,
            action: action
        )
    }

    /// Empty state tras cerrar sesión solo-grupos (H-2026-07-18-7): la lista está vacía porque los grupos
    /// viven en la cuenta backend y no hay sesión. CTA re-entra por el sign-in solo-grupos.
    static func groupsSignedOut(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "person.crop.circle.badge.questionmark",
            title: L10n.Groups.Empty.SignedOut.title,
            message: L10n.Groups.Empty.SignedOut.message,
            actionTitle: action != nil ? L10n.Groups.Empty.SignedOut.action : nil,
            action: action,
            actionAccessibilityIdentifier: action != nil ? "groups_empty_signin_cta" : nil
        )
    }

    /// C2 · aún no vio ningún educativo de Grupos. Es el primer escalón de `GroupsGateLogic`, y el empty
    /// state lo anuncia con el mismo orden: primero se cuenta qué es un grupo, después se pide identidad.
    static func groupsNeedsEducational(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "sparkles",
            title: L10n.Groups.Empty.NeedsEducational.title,
            message: L10n.Groups.Empty.NeedsEducational.message,
            actionTitle: action != nil ? L10n.Groups.Empty.NeedsEducational.action : nil,
            action: action,
            actionAccessibilityIdentifier: action != nil ? "groups_empty_educational_cta" : nil
        )
    }

    /// C2 · nunca tuvo cuenta. Distinto de `groupsSignedOut` a propósito: a esta persona no le espera
    /// ningún grupo en ninguna cuenta, y la cuenta hay que CREARLA.
    static func groupsCreateAccount(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "person.crop.circle.badge.plus",
            title: L10n.Groups.Empty.CreateAccount.title,
            message: L10n.Groups.Empty.CreateAccount.message,
            actionTitle: action != nil ? L10n.Groups.Empty.CreateAccount.action : nil,
            action: action,
            actionAccessibilityIdentifier: action != nil ? "groups_empty_create_account_cta" : nil
        )
    }

    /// C2 · sesión viva sin consent. El tap de «crear grupo» acabaría en la pantalla de consentimiento;
    /// decirlo antes evita que aparezca como una sorpresa a mitad de camino.
    static func groupsNeedsConsent(action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: "checkmark.shield",
            title: L10n.Groups.Empty.NeedsConsent.title,
            message: L10n.Groups.Empty.NeedsConsent.message,
            actionTitle: action != nil ? L10n.Groups.Empty.NeedsConsent.action : nil,
            action: action,
            actionAccessibilityIdentifier: action != nil ? "groups_empty_consent_cta" : nil
        )
    }

    /// Empty state for no scheduled payments
    static func noScheduledPayments(icon: String = "calendar.badge.clock", action: (() -> Void)? = nil) -> YalaEmptyState {
        YalaEmptyState(
            icon: icon,
            title: NSLocalizedString("scheduled.empty.title", comment: ""),
            message: NSLocalizedString("scheduled.empty.message", comment: ""),
            actionTitle: action != nil ? NSLocalizedString("scheduled.new", comment: "") : nil,
            action: action
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DS.Spacing.xxxl + DS.Spacing.sm) {
            YalaEmptyState.noTransactions { }
            Divider()
            YalaEmptyState.noResults()
            Divider()
            YalaEmptyState.noTags { }
            Divider()
            YalaEmptyState(icon: "tag.fill", title: L10n.Empty.noData, style: .widget)
                .frame(height: 200)
                .background(.thCard)
        }
    }
    .background(.thBackground)
}
