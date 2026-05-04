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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            header

            if appPreferences.panelAccountsCollapsed, showsUpsellCTA {
                upsellCTA
                    .padding(.vertical, DS.Spacing.xxs)
                    .transition(.opacity)
            }

            if !appPreferences.panelAccountsCollapsed {
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
        return Button {
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion) {
                appPreferences.panelAccountsCollapsed.toggle()
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Panel.panoramaTitle)
                        .font(DS.Typography.title)
                        .foregroundStyle(Color.primary)
                    if !expanded, let summary = collapsedSubtitle {
                        Text(summary)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: expanded ? "minus" : "plus")
                    .font(DS.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .frame(width: DS.Panel.headerAccessorySize, height: DS.Panel.headerAccessorySize)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Panel.panoramaTitle)
        .accessibilityValue(accessibilityValue(expanded: expanded))
        .accessibilityHint(
            expanded ? L10n.Panel.panoramaCollapse : L10n.Panel.panoramaExpand
        )
        .accessibilityAddTraits(.isButton)
    }

    /// Subtítulo único mostrado solo cuando la sección está colapsada:
    /// "Tienes X en N cuentas. Buen mes…". Concatena saldo + frase motivacional
    /// para que ambos sean legibles en una sola unidad visual. Devuelve `nil`
    /// si no hay nada útil que mostrar (sin cuentas activas y sin data del hero).
    private var collapsedSubtitle: String? {
        let parts = [accountsSummary, motivationalLine].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ". ")
    }

    private var accountsSummary: String? {
        let activeCount = viewModel.accounts.count(where: { !$0.isArchived })
        guard activeCount > 0 else { return nil }
        let formattedBalance = appPreferences.currency(
            viewModel.currentBalance,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
        return L10n.Panel.panoramaCollapsedSummary(formattedBalance, accounts: activeCount)
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
        if !expanded, let collapsedSubtitle {
            parts.append(collapsedSubtitle)
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
