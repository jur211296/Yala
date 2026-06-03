//
//  MoreView.swift
//  Yala
//
//  Dashboard de navegación de la tab "Más": muestra TODAS las páginas de la app
//  (las del tab bar + las ocultas) y sus sub-tabs como mini-cards agrupadas en
//  secciones temáticas (lenguaje visual tipo Oura). En modo `groupInvite` solo
//  muestra el CTA "Activar Yala completo".
//

import SwiftUI

struct MoreView: View {
    @Environment(\.yalaTheme) private var theme
    @State private var showProfile = false

    /// GC-08: en modo groupInvite solo Grupos es accesible; el dashboard se oculta.
    private var isGroupInviteMode: Bool { SessionState.shared.isGroupInviteMode }

    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        if isGroupInviteMode {
                            activateFullYalaButton
                        } else {
                            dashboardContent
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Tab.more)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .transaction { $0.animation = nil }
        }
    }

    // MARK: - Dashboard

    @ViewBuilder
    private var dashboardContent: some View {
        heroPanelCard

        ForEach(dashboardSections) { section in
            sectionView(section)
        }
    }

    /// Card destacada de Panel (full-width, layout horizontal).
    private var heroPanelCard: some View {
        Button {
            RouterEntryGate.shared.submit(.navigate(.panel))
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: ConfigurableTab.panel.iconName)
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accent)
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(theme.accent.opacity(0.12))
                    )

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

    private func sectionView(_ section: NavSection) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: section.icon)
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accent)
                Text(section.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
                ForEach(section.items) { item in
                    MoreNavCard(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        identifier: "more_card_\(item.id)",
                        action: item.action
                    )
                }
            }
        }
    }

    // MARK: - Section data (orden fijo en Fase 1; reordenable en Fase 2)

    private var dashboardSections: [NavSection] {
        [
            NavSection(id: "statistics", title: L10n.Tab.statistics, icon: ConfigurableTab.statistics.iconName, items: [
                NavItem(id: "insights", icon: DetailViewTab.insights.icon, title: DetailViewTab.insights.title, subtitle: L10n.More.Subtitle.insights) {
                    SessionState.shared.navigateToDetail(.insights)
                },
                NavItem(id: "trends", icon: DetailViewTab.trends.icon, title: DetailViewTab.trends.title, subtitle: L10n.More.Subtitle.trends) {
                    SessionState.shared.navigateToDetail(.trends)
                },
                NavItem(id: "categories", icon: DetailViewTab.categories.icon, title: DetailViewTab.categories.title, subtitle: L10n.More.Subtitle.distribution) {
                    SessionState.shared.navigateToDetail(.categories)
                },
            ]),
            NavSection(id: "planning", title: L10n.Tab.planning, icon: ConfigurableTab.planning.iconName, items: [
                NavItem(id: "budgets", icon: PlanningTab.budgets.icon, title: PlanningTab.budgets.displayName, subtitle: L10n.More.Subtitle.budgets) {
                    SessionState.shared.navigateToBudgets()
                },
                NavItem(id: "scheduledPayments", icon: PlanningTab.scheduledPayments.icon, title: PlanningTab.scheduledPayments.displayName, subtitle: L10n.More.Subtitle.scheduledPayments) {
                    SessionState.shared.navigateToScheduledPayments()
                },
            ]),
            NavSection(id: "reports", title: L10n.Tab.reports, icon: ConfigurableTab.reports.iconName, items: [
                NavItem(id: "comparativa", icon: ReportTab.comparativa.icon, title: ReportTab.comparativa.title, subtitle: L10n.More.Subtitle.comparative) {
                    SessionState.shared.navigateToReport(.comparativa)
                },
                NavItem(id: "flujoDeCaja", icon: ReportTab.flujoDeCaja.icon, title: ReportTab.flujoDeCaja.title, subtitle: L10n.More.Subtitle.cashFlow) {
                    SessionState.shared.navigateToReport(.flujoDeCaja)
                },
            ]),
            NavSection(id: "tools", title: L10n.More.toolsSection, icon: "wrench.and.screwdriver", items: [
                NavItem(id: "records", icon: ConfigurableTab.records.iconName, title: ConfigurableTab.records.displayName, subtitle: L10n.More.Subtitle.records) {
                    RouterEntryGate.shared.submit(.navigate(.recordsStandalone))
                },
                NavItem(id: "groups", icon: ConfigurableTab.groups.iconName, title: ConfigurableTab.groups.displayName, subtitle: L10n.More.Subtitle.groups) {
                    RouterEntryGate.shared.submit(.navigate(.groups))
                },
                NavItem(id: "profile", icon: "person.crop.circle.fill", title: L10n.Profile.title, subtitle: L10n.More.Subtitle.profile) {
                    showProfile = true
                },
            ]),
        ]
    }

    // MARK: - Activate Full Yala (GC-08)

    private var activateFullYalaButton: some View {
        VStack(spacing: DS.Spacing.none) {
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
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
        )
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
    let action: () -> Void
}

/// Una sección del dashboard "Más" (header + grid de cards).
private struct NavSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let items: [NavItem]
}
