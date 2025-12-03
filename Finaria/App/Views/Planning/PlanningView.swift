//
//  PlanningView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftUI

struct PlanningView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Planificación")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Planificación")
        }
    }
}
