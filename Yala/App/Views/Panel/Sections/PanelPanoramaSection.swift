//
//  PanelPanoramaSection.swift
//  Yala
//
//  `panelAccountsCollapsed` is reused as the storage key for the whole group
//  to preserve iCloud KV sync across devices; renaming it would orphan the
//  existing value.
//

import SwiftUI

struct PanelPanoramaSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let accountsSortOrderNames: [String]
    let accountsVisible: Bool
    let healthVisible: Bool
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var showUpgradeForAccounts: Bool

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Destino del CTA "Personaliza tu mensaje con IA". Free → upgrade sheet;
    /// Pro sin consent → alert que activa el consent y dispara la regeneración.
    private enum UpsellDestination: Identifiable {
        case upgrade
        case consent
        var id: String { String(describing: self) }
    }

    @State private var upsellDestination: UpsellDestination?

    var body: some View {
        let isExpanded = !appPreferences.panelAccountsCollapsed
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Spacing 0 ancla el motivational al subtítulo del header; el root .sm
            // preserva la separación con upsellCTA / content debajo.
            VStack(alignment: .leading, spacing: 0) {
                header

                if isExpanded, let motivationalLine {
                    Text(motivationalLine)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }

            if !isExpanded, showsUpsellCTA {
                upsellCTA
                    .padding(.vertical, DS.Spacing.xxs)
                    .transition(.opacity)
            }

            if isExpanded {
                content
                    .padding(.top, DS.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: Binding(
            get: { upsellDestination == .upgrade },
            set: { if !$0 { upsellDestination = nil } }
        )) {
            UpgradePromptSheet(
                feature: .smartInsightsAI,
                context: .proFeature,
                source: "panelHero"
            )
        }
        .alert(
            L10n.AIConsent.insightsTitle,
            isPresented: Binding(
                get: { upsellDestination == .consent },
                set: { if !$0 { upsellDestination = nil } }
            )
        ) {
            Button(L10n.AIConsent.accept) {
                appPreferences.acceptAIInsightsConsent()
                viewModel.retriggerHeroAI()
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.AIConsent.insightsMessage)
        }
    }

    // MARK: - Header (collapse toggle)

    private var header: some View {
        let expanded = !appPreferences.panelAccountsCollapsed
        return CollapsibleSectionHeader(
            title: L10n.Panel.panoramaTitle,
            subtitleAttributed: accountsSummaryAttributed,
            isExpanded: expanded,
            titleFont: DS.Typography.subheadlineEmphasized,
            subtitleFont: DS.Typography.subheadline,
            accessibilityValue: accessibilityValue(expanded: expanded),
            accessibilityHint: expanded ? L10n.Panel.panoramaCollapse : L10n.Panel.panoramaExpand
        ) {
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion) {
                appPreferences.panelAccountsCollapsed.toggle()
            }
        }
    }

    /// Conteo de cuentas del saldo total, coherente con `viewModel.panelTotalBalance`:
    /// excluye las cuentas sistema de grupos cuando `includeGroupsInPanelTotal` está OFF.
    private var totalAccountsCount: Int {
        let active = viewModel.accounts.filter { !$0.isArchived }
        return PanelTotalAccountsLogic.accountsForTotal(
            active,
            includeGroups: appPreferences.includeGroupsInPanelTotal,
            hasSelectedAccount: viewModel.selectedAccountID != nil
        ).count
    }

    private var accountsSummary: String? {
        let activeCount = totalAccountsCount
        guard activeCount > 0 else { return nil }
        let formattedBalance = appPreferences.currency(
            viewModel.panelTotalBalance,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
        return L10n.Panel.panoramaCollapsedSummary(formattedBalance, accounts: activeCount)
    }

    /// Versión atribuida de `accountsSummary`: monto con jerarquía (symbol y
    /// decimales en secondary tamaño caption, integer en subheadline) embebido
    /// dentro de "Tienes <amount> en N cuentas". Splittea el string L10n por
    /// el formattedBalance para concatenar el AttributedString del amount
    /// entre los fragmentos textuales — preserva la traducción cross-locale.
    private var accountsSummaryAttributed: AttributedString? {
        let activeCount = totalAccountsCount
        guard activeCount > 0 else { return nil }
        let formattedBalance = appPreferences.currency(
            viewModel.panelTotalBalance,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
        let full = L10n.Panel.panoramaCollapsedSummary(formattedBalance, accounts: activeCount)
        let parts = full.components(separatedBy: formattedBalance)

        var result = AttributedString()
        if let first = parts.first {
            result.append(AttributedString(first))
        }
        result.append(AmountText.attributedAmount(
            value: viewModel.panelTotalBalance,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
            prefs: appPreferences
        ))
        if parts.count > 1 {
            result.append(AttributedString(parts.dropFirst().joined(separator: formattedBalance)))
        }
        return result
    }

    /// Frase motivacional: aiSubtitle si lo hay, fallback rule-based si hay
    /// data del hero. Antes vivía debajo del saludo del Hero; ahora ancla
    /// el subtítulo de "Tus finanzas" para no duplicar mensaje en pantalla.
    private var motivationalLine: String? {
        guard let data = viewModel.heroWidget.data else { return nil }
        return HeroMonthView.kpiText(
            data: data,
            aiSubtitle: viewModel.heroAISubtitle,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
            appPreferences: appPreferences
        )
        .replacingOccurrences(of: "**", with: "")
    }

    private func accessibilityValue(expanded: Bool) -> String {
        var parts: [String] = []
        parts.append(expanded ? L10n.Panel.panoramaExpandedValue : L10n.Panel.panoramaCollapsedValue)
        if let accountsSummary {
            parts.append(accountsSummary)
        }
        if expanded, let motivationalLine {
            parts.append(motivationalLine)
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - UpsellCTA "Personaliza tu mensaje con IA"

    private var showsUpsellCTA: Bool {
        let isPro = FeatureGateService.shared.isProUser
        let hasConsent = appPreferences.aiInsightsConsentAccepted
        return viewModel.heroAISubtitle == nil && (!isPro || !hasConsent)
    }

    private var upsellCTA: some View {
        Button {
            TelemetryService.track(.panelHeroCTATap)
            upsellDestination = FeatureGateService.shared.isProUser ? .consent : .upgrade
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "sparkle")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(
                        LinearGradient(
                            colors: DS.Gradients.proBadge,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(L10n.Panel.Hero.upsellCTA)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .glassEffect(.regular.interactive(), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onAppear {
            TelemetryService.trackOnce(.panelHeroCTAImpression, key: "panelHero")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if accountsVisible {
                PanelAccountsSection(
                    viewModel: viewModel,
                    sessionState: sessionState,
                    accountsSortOrderNames: accountsSortOrderNames,
                    accountFormSheet: $accountFormSheet,
                    showUpgradeForAccounts: $showUpgradeForAccounts
                )
            }
            if healthVisible {
                PanelHealthSection(
                    viewModel: viewModel,
                    sessionState: sessionState
                )
            }
        }
    }
}
