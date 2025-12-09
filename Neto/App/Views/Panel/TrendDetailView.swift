//
//  TrendDetailView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

/// Vista de detalle de tendencias (Saldo o Gasto)
/// Recibe el tipo de tendencia seleccionado desde el Panel
struct TrendDetailView: View {
    let trendType: TrendType

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 24) {
                Text("Detalle de \(trendType.rawValue)")
                    .font(.title2.weight(.bold))

                Text(
                    "Esta vista mostrará análisis detallado de \(trendType == .balance ? "saldo" : "gastos")."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 40)
        }
        .navigationTitle(trendType == .balance ? "Detalle de Saldo" : "Detalle de Gastos")
        .navigationBarTitleDisplayMode(.inline)
    }
}
