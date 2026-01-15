//
//  PlanningView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct PlanningView: View {

    // MARK: - State

    @State private var selectedTab: PlanningTab = .budgets
    @State private var isPresentingSettings = false
    @State private var showFavoritesSettings = false
    @Namespace private var tabAnimation

    // MARK: - Tab Types

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: 0) {
                    // Title
                    HStack {
                        Text(L10n.Planning.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Tab Chips
                    navigationChipsBar
                        .padding(.vertical, 12)

                    // Content
                    Group {
                        switch selectedTab {
                        case .budgets:
                            budgetsContent
                        case .scheduledPayments:
                            scheduledPaymentsContent
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Favorites button (only for budgets tab)
                        if selectedTab == .budgets {
                            Button {
                                showFavoritesSettings = true
                            } label: {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.yellow)
                            }
                        }

                        // Profile button
                        Button {
                            isPresentingSettings = true
                        } label: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.electricIndigo)
                        }
                    }
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
        }
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlanningTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func navigationChipButton(for tab: PlanningTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.subheadline)
                Text(tab.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.electricIndigo : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(Color.netoSecondaryText.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Views

    private var budgetsContent: some View {
        BudgetsListView()
    }

    private var scheduledPaymentsContent: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text(L10n.Planning.scheduledPayments)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(L10n.Planning.comingSoon)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}
