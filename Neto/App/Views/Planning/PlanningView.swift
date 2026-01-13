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
    @Namespace private var tabAnimation

    // MARK: - Tab Types

    enum PlanningTab: String, CaseIterable, Identifiable {
        case budgets = "Presupuestos"
        case scheduledPayments = "Pagos planificados"

        var id: String { rawValue }

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
                        Text("Planificación")
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
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.electricIndigo)
                    }
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                ProfileView()
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
                Text(tab.rawValue)
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
                Text("Pagos planificados")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Próximamente")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}
