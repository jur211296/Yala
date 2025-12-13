//
//  ContentView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - ContentView (Punto de entrada principal)

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - TabView Principal

struct MainTabView: View {
    var body: some View {
        TabView {
            PanelView()
                .tabItem {
                    Label("Panel", systemImage: "rectangle.grid.2x2.fill")
                }

            PlanningView()
                .tabItem {
                    Label("Planificación", systemImage: "calendar")
                }

            StatisticsView()
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.bar.fill")
                }
        }
        .tint(Color.electricIndigo)
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Account.self,
                TransactionItem.self,
                Category.self,
                Subcategory.self,
                Tag.self,
                Budget.self,
                ExchangeRate.self,
            ], inMemory: true)
}
