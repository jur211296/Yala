//
//  PlanningView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

// MARK: - Planning Tab Enum

enum PlanningTab: String, CaseIterable, Identifiable {
    case budgets
    case scheduledPayments

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .budgets: return L10n.Planning.budgets
        case .scheduledPayments: return L10n.Planning.scheduledPayments
        }
    }

    var icon: String {
        switch self {
        case .budgets: return "chart.pie.fill"
        case .scheduledPayments: return "calendar.badge.clock"
        }
    }
}

// MARK: - Planning View

struct PlanningView: View {

    // MARK: - Environment

    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    // MARK: - State

    @State private var selectedTab: PlanningTab = .budgets
    @State private var isPresentingSettings = false
    @State private var showFavoritesSettings = false
    @Namespace private var tabAnimation

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                tabContent
                    .safeAreaInset(edge: .top) {
                        navigationChipsBar
                            .padding(.vertical, DS.Spacing.sm)
                    }
            }
            .navigationTitle(L10n.Planning.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Favorites button (only for budgets tab)
                if selectedTab == .budgets {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showFavoritesSettings = true
                        } label: {
                            Image(systemName: "star.fill")
                                .font(DS.Typography.body).fontWeight(.medium)
                                .foregroundStyle(DS.Semantic.favoriteIcon)
                        }
                        .accessibilityLabel(L10n.Accessibility.favoriteTemplates)
                    }

                    // iOS 26 spacer creates separate glass groups
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }

                // Profile button
                ProfileToolbarItem {
                    isPresentingSettings = true
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                ProfileView()
            }
            .sheet(isPresented: $showFavoritesSettings) {
                NavigationStack {
                    BudgetsFavoritesSettingsView()
                }
            }
            .onAppear {
                // Sync with SessionState on appear
                selectedTab = sessionState.selectedPlanningTab
            }
            .onChange(of: selectedTab) { _, newValue in
                // Keep SessionState in sync
                sessionState.selectedPlanningTab = newValue
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .budgets:
            budgetsContent
        case .scheduledPayments:
            scheduledPaymentsContent
        }
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(PlanningTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    @ViewBuilder
    private func navigationChipButton(for tab: PlanningTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            // Disable animations to prevent navigation title flickering
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(DS.Typography.subheadline)
                Text(tab.displayName)
                    .font(DS.Typography.label)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Views

    private var budgetsContent: some View {
        BudgetsListView()
    }

    private var scheduledPaymentsContent: some View {
        ScheduledPaymentsView()
    }
}
