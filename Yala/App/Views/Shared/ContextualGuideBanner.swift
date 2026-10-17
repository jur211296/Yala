//
//  ContextualGuideBanner.swift
//  Yala
//
//  Educational banner shown on first visit to each view.
//  Helps users with low financial literacy understand each section.
//  Dismissible permanently with "Entendido".
//

import SwiftUI

struct ContextualGuideBanner: View {

    // MARK: - Properties

    let icon: String
    let title: String
    let message: String
    let isDismissible: Bool

    @AppStorage private var dismissed: Bool
    @Environment(\.yalaTheme) private var theme

    // MARK: - Init

    init(
        guideID: String,
        icon: String = "lightbulb.fill",
        isDismissible: Bool = true,
        title: String,
        message: String
    ) {
        self.icon = icon
        self.isDismissible = isDismissible
        self.title = title
        self.message = message
        self._dismissed = AppStorage(wrappedValue: false, "guide.\(guideID).dismissed")
    }

    // MARK: - Body

    var body: some View {
        if !UITestHooks.isActive, !isDismissible || !dismissed {
            if isDismissible {
                guideCard
            } else {
                infoCard
            }
        }
    }

    /// UX 2.2 · L5-8 (variante 2, decisión de Jürgen): barra lateral del color de la app, rótulo «GUÍA» y una X para
    /// cerrar. Antes era el mismo cristal gris que cualquier tarjeta, con «Entendido» en texto pequeño, y no se leía
    /// como ayuda.
    private var guideCard: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.accent)
                .frame(width: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .font(DS.Typography.labelTiny)
                        .accessibilityHidden(true)
                    Text(L10n.ContextualGuide.label)
                        .font(DS.Typography.labelTiny.weight(.bold))
                        .tracking(0.8)
                    Spacer(minLength: DS.Spacing.xs)
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) {
                            dismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(DS.Typography.labelSmall.weight(.semibold))
                            .foregroundStyle(.thSecondaryText)
                            .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -DS.Spacing.sm)
                    .accessibilityLabel(L10n.ContextualGuide.dismiss)
                    .accessibilityIdentifier("contextual_guide_dismiss")
                }
                .foregroundStyle(theme.accent)

                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                Text(message)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .yalaCard(padding: DS.Spacing.md, radius: DS.Radius.md, shadow: false)
        .accessibilityElement(children: .contain)
        .transition(.asymmetric(
            insertion: .opacity,
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
    }

    /// El aviso fijo (no se cierra), como el resumen del filtro de un presupuesto: sigue con su molde.
    private var infoCard: some View {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: icon)
                        .font(DS.Typography.body)
                        .foregroundStyle(isDismissible ? AnyShapeStyle(.thAccent) : AnyShapeStyle(DS.Semantic.infoForeground))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(title)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.thPrimaryText)

                        Text(message)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
            .yalaCard(padding: DS.Spacing.md, radius: DS.Radius.md, shadow: false)
    }
}

// MARK: - L10n Extension

extension L10n {
    enum ContextualGuide {
        static var dismiss: String {
            NSLocalizedString("contextualGuide.dismiss", comment: "Dismiss contextual guide")
        }
        /// Rótulo «GUÍA» de la tarjeta de ayuda (UX 2.2 · L5-8).
        static var label: String {
            NSLocalizedString("contextualGuide.label", comment: "Small uppercase label on a guide card")
        }
    }
}

// MARK: - Convenience Factories

extension ContextualGuideBanner {

    static func panel() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "panel",
            icon: "house.fill",
            title: L10n.ContextualGuide.Panel.title,
            message: L10n.ContextualGuide.Panel.message
        )
    }

    static func trends() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "trends",
            icon: "chart.line.uptrend.xyaxis",
            title: L10n.ContextualGuide.Trends.title,
            message: L10n.ContextualGuide.Trends.message
        )
    }

    static func categories() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "categories",
            icon: "chart.pie.fill",
            title: L10n.ContextualGuide.Categories.title,
            message: L10n.ContextualGuide.Categories.message
        )
    }

    static func records() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "records",
            icon: "list.bullet.rectangle.portrait",
            title: L10n.ContextualGuide.Records.title,
            message: L10n.ContextualGuide.Records.message
        )
    }

    static func budgets() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "budgets",
            icon: "chart.pie.fill",
            title: L10n.ContextualGuide.Budgets.title,
            message: L10n.ContextualGuide.Budgets.message
        )
    }

    static func scheduledPayments() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "scheduled",
            icon: "calendar.badge.clock",
            title: L10n.ContextualGuide.Scheduled.title,
            message: L10n.ContextualGuide.Scheduled.message
        )
    }

    static func accounts() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "accounts",
            icon: "creditcard.fill",
            title: L10n.ContextualGuide.Accounts.title,
            message: L10n.ContextualGuide.Accounts.message
        )
    }

    static func transaction() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "transaction",
            icon: "plus.circle.fill",
            title: L10n.ContextualGuide.Transaction.title,
            message: L10n.ContextualGuide.Transaction.message
        )
    }

    static func comparative() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "comparative",
            icon: "arrow.left.arrow.right",
            title: L10n.ContextualGuide.Comparative.title,
            message: L10n.ContextualGuide.Comparative.message
        )
    }

    static func insights() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "insights",
            icon: "sparkles",
            title: L10n.ContextualGuide.Insights.title,
            message: L10n.ContextualGuide.Insights.message
        )
    }

    static func inbox() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "inbox",
            icon: "tray.fill",
            title: L10n.ContextualGuide.Inbox.title,
            message: L10n.ContextualGuide.Inbox.message
        )
    }

    static func accountForm(accountType: AccountType) -> ContextualGuideBanner {
        let message: String
        switch accountType {
        case .general: message = L10n.ContextualGuide.AccountForm.messageGeneral
        case .cash: message = L10n.ContextualGuide.AccountForm.messageCash
        case .checking: message = L10n.ContextualGuide.AccountForm.messageChecking
        case .savings: message = L10n.ContextualGuide.AccountForm.messageSavings
        case .creditCard: message = L10n.ContextualGuide.AccountForm.messageCreditCard
        }
        return ContextualGuideBanner(
            guideID: "accountForm",
            icon: "info.circle.fill",
            title: L10n.ContextualGuide.AccountForm.title,
            message: message
        )
    }

    static func categoriesSettings() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "categoriesSettings",
            icon: "folder.fill",
            title: L10n.ContextualGuide.CategoriesSettings.title,
            message: L10n.ContextualGuide.CategoriesSettings.message
        )
    }

    static func tagsSettings() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "tagsSettings",
            icon: "number",
            title: L10n.ContextualGuide.TagsSettings.title,
            message: L10n.ContextualGuide.TagsSettings.message
        )
    }

    static func favoritesManage() -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "favoritesManage",
            icon: "star.fill",
            title: L10n.ContextualGuide.FavoritesManage.title,
            message: L10n.ContextualGuide.FavoritesManage.message
        )
    }

    static func budgetFilterInfo(message: String) -> ContextualGuideBanner {
        ContextualGuideBanner(
            guideID: "budgetFilterInfo",
            icon: "line.3.horizontal.decrease.circle",
            isDismissible: false,
            title: L10n.ContextualGuide.BudgetFilter.title,
            message: message
        )
    }
}

// MARK: - L10n Guide Strings

extension L10n.ContextualGuide {

    enum Panel {
        static var title: String {
            NSLocalizedString("guide.panel.title", comment: "Panel guide title")
        }
        static var message: String {
            NSLocalizedString("guide.panel.message", comment: "Panel guide message")
        }
    }

    enum Trends {
        static var title: String {
            NSLocalizedString("guide.trends.title", comment: "Trends guide title")
        }
        static var message: String {
            NSLocalizedString("guide.trends.message", comment: "Trends guide message")
        }
    }

    enum Categories {
        static var title: String {
            NSLocalizedString("guide.categories.title", comment: "Categories guide title")
        }
        static var message: String {
            NSLocalizedString("guide.categories.message", comment: "Categories guide message")
        }
    }

    enum Records {
        static var title: String {
            NSLocalizedString("guide.records.title", comment: "Records guide title")
        }
        static var message: String {
            NSLocalizedString("guide.records.message", comment: "Records guide message")
        }
    }

    enum Budgets {
        static var title: String {
            NSLocalizedString("guide.budgets.title", comment: "Budgets guide title")
        }
        static var message: String {
            NSLocalizedString("guide.budgets.message", comment: "Budgets guide message")
        }
    }

    enum Scheduled {
        static var title: String {
            NSLocalizedString("guide.scheduled.title", comment: "Scheduled guide title")
        }
        static var message: String {
            NSLocalizedString("guide.scheduled.message", comment: "Scheduled guide message")
        }
    }

    enum Accounts {
        static var title: String {
            NSLocalizedString("guide.accounts.title", comment: "Accounts guide title")
        }
        static var message: String {
            NSLocalizedString("guide.accounts.message", comment: "Accounts guide message")
        }
    }

    enum Transaction {
        static var title: String {
            NSLocalizedString("guide.transaction.title", comment: "Transaction guide title")
        }
        static var message: String {
            NSLocalizedString("guide.transaction.message", comment: "Transaction guide message")
        }
    }

    enum Comparative {
        static var title: String {
            NSLocalizedString("guide.comparative.title", comment: "Comparative guide title")
        }
        static var message: String {
            NSLocalizedString("guide.comparative.message", comment: "Comparative guide message")
        }
    }

    enum Insights {
        static var title: String {
            NSLocalizedString("guide.insights.title", comment: "Insights guide title")
        }
        static var message: String {
            NSLocalizedString("guide.insights.message", comment: "Insights guide message")
        }
    }

    enum Inbox {
        static var title: String {
            NSLocalizedString("guide.inbox.title", comment: "Inbox guide title")
        }
        static var message: String {
            NSLocalizedString("guide.inbox.message", comment: "Inbox guide message")
        }
    }

    enum BudgetFilter {
        static var title: String {
            NSLocalizedString("guide.budgetFilter.title", comment: "Budget filter info title")
        }
        static var allExpenses: String {
            NSLocalizedString("guide.budgetFilter.allExpenses", comment: "Budget filter default: all expenses")
        }
    }

    enum AccountForm {
        static var title: String {
            NSLocalizedString("guide.accountForm.title", comment: "Account form guide title")
        }
        static var messageGeneral: String {
            NSLocalizedString("guide.accountForm.messageGeneral", comment: "Account form guide - general")
        }
        static var messageCash: String {
            NSLocalizedString("guide.accountForm.messageCash", comment: "Account form guide - cash")
        }
        static var messageChecking: String {
            NSLocalizedString("guide.accountForm.messageChecking", comment: "Account form guide - checking")
        }
        static var messageSavings: String {
            NSLocalizedString("guide.accountForm.messageSavings", comment: "Account form guide - savings")
        }
        static var messageCreditCard: String {
            NSLocalizedString("guide.accountForm.messageCreditCard", comment: "Account form guide - credit card")
        }
    }

    enum CategoriesSettings {
        static var title: String {
            NSLocalizedString("guide.categoriesSettings.title", comment: "Categories settings guide title")
        }
        static var message: String {
            NSLocalizedString("guide.categoriesSettings.message", comment: "Categories settings guide message")
        }
    }

    enum TagsSettings {
        static var title: String {
            NSLocalizedString("guide.tagsSettings.title", comment: "Tags settings guide title")
        }
        static var message: String {
            NSLocalizedString("guide.tagsSettings.message", comment: "Tags settings guide message")
        }
    }

    enum FavoritesManage {
        static var title: String {
            NSLocalizedString("guide.favoritesManage.title", comment: "Favorites manage guide title")
        }
        static var message: String {
            NSLocalizedString("guide.favoritesManage.message", comment: "Favorites manage guide message")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.md) {
        ContextualGuideBanner.budgets()
        ContextualGuideBanner.trends()
        ContextualGuideBanner.budgetFilterInfo(message: "2 cuentas, Alimentación +3, Fijo")
    }
    .padding()
}
