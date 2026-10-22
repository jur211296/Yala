//
//  DowngradeResolutionSheet.swift
//  Yala
//
//  Sheet for resolving excess accounts/budgets after downgrade from Pro.
//

import SwiftData
import SwiftUI

/// Lo que sale al abrir Yala cuando Pro se acabó (UX 2.2 · L17-6 variante 2): UNA hoja. «Tu prueba de Pro terminó» (o
/// «Tu suscripción terminó» si se pagó), cuántos caben en el plan gratis, «Elegidos 3 de 3», qué pasa con el resto (no
/// se borra nada) y, al tocar uno de más, «Quita uno para elegir…». Antes eran dos hojas seguidas, la primera con un
/// triángulo de alarma. Si el icono de la app era de Pro, lo avisa aquí antes de devolverlo al original (L16-11).
struct DowngradeResolutionSheet: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(ThemeManager.self) private var themeManager

    // MARK: - Properties

    let accounts: [Account]
    let budgets: [Budget]
    /// El icono de la app es de Pro y vuelve al original al confirmar (L16-11).
    var iconWillReset: Bool = false
    /// El tema elegido es de Pro y vuelve a Liquid Glass al confirmar (decisión B de Jürgen, 2026-10-21).
    var themeWillReset: Bool = false
    let onComplete: () -> Void

    // MARK: - Computed

    private var activeAccounts: [Account] {
        accounts.billableUserAccounts
    }

    /// Las divisas de cada tarjeta, la principal primero: «PEN · USD» en la fila de una tarjeta con líneas, para que se
    /// vea que archivarla archiva también sus líneas.
    private var cardCurrencies: [PersistentIdentifier: String] {
        let cards = accounts.filter { !$0.isArchived && !$0.isSystemAccount }.accountCards(roles: accounts.lineRoles)
        var result: [PersistentIdentifier: String] = [:]
        for card in cards {
            result[card.head.persistentModelID] = card.members.map { normalizeCurrencyCode($0.currencyCode) }
                .joined(separator: " · ")
        }
        return result
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

    private var hasExcess: Bool { excessAccounts > 0 || excessBudgets > 0 }

    private var accountsToKeep: Int { ProFeature.accounts.freeLimit ?? Int.max }
    private var budgetsToKeep: Int { ProFeature.budgets.freeLimit ?? Int.max }

    /// La prueba o la suscripción: lo último activo que vio este dispositivo.
    private var endedWasTrial: Bool { ProPresentation.endedWasTrial }

    // MARK: - State

    @State private var selectedAccountIDs: Set<PersistentIdentifier> = []
    @State private var selectedBudgetIDs: Set<PersistentIdentifier> = []
    @State private var showSubscription = false
    /// «Quita uno para elegir «Movilidad».», al tocar uno de más con el cupo lleno. Antes no pasaba nada. Sale bajo la
    /// cabecera de su sección, a la vista: al pie de una lista larga quedaba tapado por los botones.
    @State private var fullHint: FullHint?

    private struct FullHint: Equatable {
        let inBudgets: Bool
        let text: String
    }

    private var canConfirm: Bool {
        let accountsOK = excessAccounts == 0 || selectedAccountIDs.count == accountsToKeep
        let budgetsOK = excessBudgets == 0 || selectedBudgetIDs.count == budgetsToKeep
        return accountsOK && budgetsOK
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection

                    if excessAccounts > 0 {
                        selectionSection(
                            title: L10n.FeatureGate.accounts,
                            chosen: L10n.UXPro.chosenAccounts(selectedAccountIDs.count, accountsToKeep),
                            hint: fullHint.flatMap { $0.inBudgets ? nil : $0.text },
                            identifier: "downgrade_accounts"
                        ) {
                            // En el orden en que llegan elegidas: por nombre (como la preselección).
                            ForEach(activeAccounts.sorted { $0.name < $1.name }, id: \.persistentModelID) { account in
                                accountRow(account)
                            }
                        }
                    }

                    if excessBudgets > 0 {
                        selectionSection(
                            title: L10n.FeatureGate.budgets,
                            chosen: L10n.UXPro.chosenBudgets(selectedBudgetIDs.count, budgetsToKeep),
                            hint: fullHint.flatMap { $0.inBudgets ? $0.text : nil },
                            identifier: "downgrade_budgets"
                        ) {
                            // En el orden en que llegan elegidos: los más recientes primero (como la preselección).
                            ForEach(activeBudgets.sorted { $0.createdAt > $1.createdAt }, id: \.persistentModelID) { budget in
                                budgetRow(budget)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.lg)
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) { buttons }
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

            // Una sola hoja (L17-6): con esta delante, «Prueba terminada» ya no sale después. Se quema al aparecer de
            // verdad, como el resto de avisos de una vez.
            ProUpsellService.shared.markTrialExpiredSheetShown()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Image(systemName: "hourglass")
                .font(DS.Typography.title)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(theme.accent))
                .accessibilityHidden(true)

            Text(endedWasTrial ? L10n.UXPro.endedTrialTitle : L10n.Subscription.Downgrade.title)
                .font(DS.Typography.title)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("downgrade_title")

            if let subtitle {
                Text(subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let keepNote {
                note(icon: "archivebox.fill", text: keepNote, identifier: "downgrade_keep_note")
            }

            if iconWillReset {
                note(icon: "app.fill", text: L10n.UXPro.iconResetNote, identifier: "downgrade_icon_note")
            }

            if themeWillReset {
                note(icon: "paintpalette.fill", text: L10n.UXL15.themeResetNote, identifier: "downgrade_theme_note")
            }
        }
    }

    private var subtitle: String? {
        switch (excessAccounts > 0, excessBudgets > 0) {
        case (true, true): return L10n.UXPro.endedChooseBoth(accountsToKeep, budgetsToKeep)
        case (true, false): return L10n.UXPro.endedChooseAccounts(accountsToKeep)
        case (false, true): return L10n.UXPro.endedChooseBudgets(budgetsToKeep)
        case (false, false): return nil
        }
    }

    private var keepNote: String? {
        switch (excessAccounts > 0, excessBudgets > 0) {
        case (true, true): return L10n.UXPro.endedNoteBoth
        case (true, false): return L10n.UXPro.endedNoteAccounts
        case (false, true): return L10n.UXPro.endedNoteBudgets
        case (false, false): return nil
        }
    }

    private var confirmTitle: String {
        switch (excessAccounts > 0, excessBudgets > 0) {
        case (true, true): return L10n.UXPro.keepBoth
        // El número del plan gratis, no el de elegidos: el botón solo se puede tocar con el cupo completo, y con uno
        // quitado decía «Conservar estos 2» apagado (review del lote decidido 06).
        case (true, false): return L10n.UXPro.keepAccounts(accountsToKeep)
        case (false, true): return L10n.UXPro.keepBudgets(budgetsToKeep)
        case (false, false): return L10n.Common.understood
        }
    }

    private func note(icon: String, text: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(Color.hotPink)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func selectionSection<Rows: View>(
        title: String,
        chosen: String,
        hint: String?,
        identifier: String,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                Text(chosen)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(Capsule().fill(theme.accent))
                    .accessibilityIdentifier("\(identifier)_chosen")
            }
            if let hint {
                Label(hint, systemImage: "info.circle.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(Color.hotPink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("downgrade_full_hint")
            }
            VStack(spacing: DS.Spacing.sm) {
                rows()
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaPrimaryButton(confirmTitle, isDisabled: !canConfirm) {
                confirm()
            }
            .accessibilityIdentifier("downgrade_confirm")

            Button(L10n.Subscription.Downgrade.reactivate) {
                showSubscription = true
            }
            .font(DS.Typography.bodyBold)
            .foregroundStyle(.thAccent)
            .accessibilityIdentifier("downgrade_reactivate")
        }
        .padding(DS.Spacing.lg)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }

    private func accountRow(_ account: Account) -> some View {
        let isSelected = selectedAccountIDs.contains(account.persistentModelID)
        return choiceRow(
            title: account.name,
            detail: cardCurrencies[account.persistentModelID] ?? account.currencyCode,
            isSelected: isSelected
        ) {
            toggleAccountSelection(account)
        }
    }

    private func budgetRow(_ budget: Budget) -> some View {
        let isSelected = selectedBudgetIDs.contains(budget.persistentModelID)
        return choiceRow(
            title: budget.name,
            detail: formatCurrency(budget.limitAmount, code: budget.currencyCode),
            isSelected: isSelected
        ) {
            toggleBudgetSelection(budget)
        }
    }

    /// Una fila para elegir: la elegida, rellena del color de acento con el texto en blanco; las demás, en tarjeta.
    private func choiceRow(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                    Text(detail)
                        .font(DS.Typography.caption)
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .symbolRenderingMode(isSelected ? .palette : .monochrome)
                    .foregroundStyle(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.primary.opacity(0.6)),
                                     Color.white)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thCard))
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Selection Logic

    private func toggleAccountSelection(_ account: Account) {
        let id = account.persistentModelID
        switch ProPlanStatusLogic.toggle(
            isSelected: selectedAccountIDs.contains(id), selectedCount: selectedAccountIDs.count, limit: accountsToKeep
        ) {
        case .selected: selectedAccountIDs.insert(id); fullHint = nil
        case .deselected: selectedAccountIDs.remove(id); fullHint = nil
        case .full: showFullHint(FullHint(inBudgets: false, text: L10n.UXPro.removeOneAccount(account.name)))
        }
    }

    private func toggleBudgetSelection(_ budget: Budget) {
        let id = budget.persistentModelID
        switch ProPlanStatusLogic.toggle(
            isSelected: selectedBudgetIDs.contains(id), selectedCount: selectedBudgetIDs.count, limit: budgetsToKeep
        ) {
        case .selected: selectedBudgetIDs.insert(id); fullHint = nil
        case .deselected: selectedBudgetIDs.remove(id); fullHint = nil
        case .full: showFullHint(FullHint(inBudgets: true, text: L10n.UXPro.removeOneBudget(budget.name)))
        }
    }

    private func showFullHint(_ hint: FullHint) {
        fullHint = hint
        AccessibilityNotification.Announcement(hint.text).post()
    }

    // MARK: - Confirm

    private func confirm() {
        if hasExcess {
            archiveExcessItems()
        }
        if iconWillReset {
            resetPremiumIcon()
        }
        if themeWillReset {
            resetProTheme()
        }
        // El downgrade queda resuelto también si solo había un icono que devolver: sin esto, `justDowngraded` seguía en
        // `true` y la hoja se volvía a pedir en cada arranque (review del lote decidido 06). Con exceso ya lo hace
        // `archiveExcessItems`.
        StoreKitManager.shared.wasProUser = false
        onComplete()
    }

    /// El tema vuelve a Liquid Glass DESPUÉS de avisarlo aquí, como el icono. Por `ThemeManager` y no escribiendo la key a
    /// pelo: así la app cambia de aspecto en el acto y no al arrancar la próxima vez.
    private func resetProTheme() {
        guard ProPlanStatusLogic.themeWillReset(
            isProUser: FeatureGateService.shared.isProUser, currentTheme: themeManager.userChoice) else { return }
        themeManager.userChoice = .liquidGlass
    }

    /// El icono vuelve al original DESPUÉS de avisarlo aquí (L16-11). Antes volvía en silencio al arrancar.
    private func resetPremiumIcon() {
        guard !FeatureGateService.shared.isProUser, UIApplication.shared.alternateIconName != nil else { return }
        UIApplication.shared.setAlternateIconName(nil) { error in
            #if DEBUG
            if let error {
                print("DowngradeResolutionSheet: Failed to reset app icon: \(error)")
            }
            #endif
        }
    }

    // MARK: - Archive Logic

    private func archiveExcessItems() {
        // Archive accounts not selected. Una tarjeta se archiva con sus líneas: si no, la línea pasa a leerse suelta,
        // cuenta para el límite y esta hoja vuelve a salir en el arranque siguiente (review de la entrega 1). Sin
        // excluir de estadísticas, como el resto de este archivado (`session-filters.md`).
        for account in activeAccounts {
            if !selectedAccountIDs.contains(account.persistentModelID) {
                AccountLineService.archiveLines(of: account, among: accounts, excludeFromStatistics: false)
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
    .environment(ThemeManager())
}
