//
//  MoreView.swift
//  Yala
//
//  Dashboard de navegación de la tab "Más": muestra TODAS las páginas de la app
//  (las del tab bar + las ocultas) y sus sub-tabs como mini-cards agrupadas en
//  secciones temáticas (lenguaje visual tipo Oura). El orden de las secciones es
//  configurable desde el editor del toolbar. En modo `groupInvite` solo muestra
//  el CTA "Activar Yala completo".
//

import SwiftUI

/// Secciones reordenables del dashboard "Más" (Panel es la card hero fija aparte).
enum MoreSectionKind: String, CaseIterable, Identifiable {
    case statistics
    case planning
    case reports
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .statistics: return L10n.Tab.statistics
        case .planning: return L10n.Tab.planning
        case .reports: return L10n.Tab.reports
        case .tools: return L10n.More.toolsSection
        }
    }

    var icon: String {
        switch self {
        case .statistics: return ConfigurableTab.statistics.iconName
        case .planning: return ConfigurableTab.planning.iconName
        case .reports: return ConfigurableTab.reports.iconName
        case .tools: return "wrench.and.screwdriver"
        }
    }

    /// Resuelve el orden custom guardado, añadiendo al final las secciones que falten.
    static func ordered(from stored: [String]) -> [MoreSectionKind] {
        let resolved = stored.compactMap { MoreSectionKind(rawValue: $0) }
        let missing = allCases.filter { !resolved.contains($0) }
        return resolved + missing
    }
}

struct MoreView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showProfile = false
    @State private var showEditor = false

    /// GC-08 + D1: en shell reducida (group-invite O usageFocus == .groupsOnly) solo Grupos es
    /// accesible; el dashboard personal se oculta y se muestra el CTA «Activar Yala completo».
    /// Reactivo a `usageFocus` vía `appPreferences` (NO el point-read de SessionState).
    private var isGroupsFocusedShell: Bool {
        ShellModeLogic.effective(
            onboardingMode: SessionState.shared.onboardingMode,
            usageFocus: appPreferences.usageFocus) == .groupsFocused
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md),
    ]

    private var orderedSectionKinds: [MoreSectionKind] {
        MoreSectionKind.ordered(from: appPreferences.moreSectionOrder)
    }

    /// Mismo criterio que `ProfileView.effectiveColorfulIcons`: el toggle de
    /// Ajustes manda salvo que el tema fuerce monocromo (solo Minimalista).
    private var effectiveColorfulIcons: Bool {
        theme.forcesMonochromeIcons ? false : appPreferences.colorfulIcons
    }

    /// Color del badge de icono: el color propio del item si "Iconos coloridos"
    /// está activo, o `.primary` si está apagado (o el tema fuerza monocromo).
    private func iconColor(_ colorful: Color) -> Color {
        effectiveColorfulIcons ? colorful : .primary
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                        if isGroupsFocusedShell {
                            activateFullYalaButton
                        } else {
                            dashboardContent
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
            }
            .navigationTitle(L10n.Tab.more)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.panel)
            .toolbar {
                if !isGroupsFocusedShell {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showEditor = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel(L10n.More.Editor.title)
                        .accessibilityIdentifier("more_editor_button")
                    }
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .transaction { $0.animation = nil }
        }
        .sheet(isPresented: $showEditor) {
            MoreEditorSheet()
        }
    }

    // MARK: - Dashboard

    @ViewBuilder
    private var dashboardContent: some View {
        heroPanelCard

        ForEach(orderedSectionKinds) { kind in
            sectionView(kind)
        }
    }

    /// Card destacada de Panel (full-width, layout horizontal).
    private var heroPanelCard: some View {
        Button {
            RouterEntryGate.shared.submit(.navigate(.panel))
        } label: {
            HStack(spacing: DS.Spacing.md) {
                AccentIconBadge(systemName: ConfigurableTab.panel.iconName, font: DS.Typography.headline, tint: iconColor(.electricIndigo))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Tab.panel)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                    Text(L10n.More.Subtitle.panel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard(small: true)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("more_card_panel")
        .accessibilityElement(children: .combine)
    }

    private func sectionView(_ kind: MoreSectionKind) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: kind.icon)
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accent)
                Text(kind.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
                ForEach(items(for: kind)) { item in
                    MoreNavCard(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        identifier: "more_card_\(item.id)",
                        badge: item.badge,
                        iconColor: item.iconColor,
                        action: item.action
                    )
                }
            }
        }
    }

    private func items(for kind: MoreSectionKind) -> [NavItem] {
        switch kind {
        case .statistics:
            return [
                NavItem(id: "insights", icon: DetailViewTab.insights.icon, title: DetailViewTab.insights.title, subtitle: L10n.More.Subtitle.insights, iconColor: iconColor(.blue)) {
                    SessionState.shared.navigateToDetail(.insights)
                },
                NavItem(id: "trends", icon: DetailViewTab.trends.icon, title: DetailViewTab.trends.title, subtitle: L10n.More.Subtitle.trends, iconColor: iconColor(.green)) {
                    SessionState.shared.navigateToDetail(.trends)
                },
                NavItem(id: "categories", icon: DetailViewTab.categories.icon, title: DetailViewTab.categories.title, subtitle: L10n.More.Subtitle.distribution, iconColor: iconColor(.orange)) {
                    SessionState.shared.navigateToDetail(.categories)
                },
            ]
        case .planning:
            return [
                NavItem(id: "budgets", icon: PlanningTab.budgets.icon, title: PlanningTab.budgets.displayName, subtitle: L10n.More.Subtitle.budgets, iconColor: iconColor(.purple)) {
                    SessionState.shared.navigateToBudgets()
                },
                NavItem(id: "scheduledPayments", icon: PlanningTab.scheduledPayments.icon, title: PlanningTab.scheduledPayments.displayName, subtitle: L10n.More.Subtitle.scheduledPayments, iconColor: iconColor(.mint)) {
                    SessionState.shared.navigateToScheduledPayments()
                },
            ]
        case .reports:
            var reports: [NavItem] = [
                NavItem(id: "comparativa", icon: ReportTab.comparativa.icon, title: ReportTab.comparativa.title, subtitle: L10n.More.Subtitle.comparative, iconColor: iconColor(.brown)) {
                    SessionState.shared.navigateToReport(.comparativa)
                },
            ]
            // En Solo Gastos, Flujo de Caja se oculta (SSOT compartido con el chip de Reportes).
            if ReportTab.visibleTabs(expensesOnly: SessionState.shared.isExpensesOnlyMode).contains(.flujoDeCaja) {
                reports.append(
                    NavItem(id: "flujoDeCaja", icon: ReportTab.flujoDeCaja.icon, title: ReportTab.flujoDeCaja.title, subtitle: L10n.More.Subtitle.cashFlow, iconColor: iconColor(.cyan)) {
                        SessionState.shared.navigateToReport(.flujoDeCaja)
                    }
                )
            }
            return reports
        case .tools:
            return [
                NavItem(id: "records", icon: ConfigurableTab.records.iconName, title: ConfigurableTab.records.displayName, subtitle: L10n.More.Subtitle.records, iconColor: iconColor(.yellow)) {
                    RouterEntryGate.shared.submit(.navigate(.recordsStandalone))
                },
                NavItem(id: "groups", icon: ConfigurableTab.groups.iconName, title: ConfigurableTab.groups.displayName, subtitle: L10n.More.Subtitle.groups, iconColor: iconColor(.hotPink)) {
                    RouterEntryGate.shared.submit(.navigate(.groups))
                },
                NavItem(id: "profile", icon: "person.crop.circle.fill", title: L10n.Profile.title, subtitle: L10n.More.Subtitle.profile, iconColor: iconColor(.gray)) {
                    showProfile = true
                },
            ]
        }
    }

    // MARK: - Activate Full Yala (GC-08)

    private var activateFullYalaButton: some View {
        Button {
            RouterEntryGate.shared.submit(.presentFullModeActivation)
        } label: {
            HStack(spacing: DS.FormRow.iconSpacing) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
                    .frame(width: DS.FormRow.iconWidth, height: DS.FormRow.iconWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.accent)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Groups.Activate.title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(L10n.Groups.Activate.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .solidCard(radius: DS.Radius.xl)
        .dsSubtleShadow()
    }
}

// MARK: - Navigation model

/// Una card del dashboard "Más" (página o sub-tab) con su acción de navegación.
private struct NavItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    var badge: String? = nil
    var iconColor: Color? = nil
    let action: () -> Void
}
