//
//  StatisticsView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftUI

struct StatisticsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Estadísticas")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Estadísticas")
        }
    }
}
