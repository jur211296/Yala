//
//  PlanningView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct PlanningView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Planificación")
                    .font(.title3)
                    .foregroundStyle(Color.netoSecondaryText)
            }
            .navigationTitle("Planificación")
        }
    }
}
