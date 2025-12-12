//
//  StatisticsView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct StatisticsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Estadísticas")
                    .font(.title3)
                    .foregroundStyle(Color.netoSecondaryText)
            }
            .navigationTitle("Estadísticas")
        }
    }
}
