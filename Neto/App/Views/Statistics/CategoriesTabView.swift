//
//  CategoriesTabView.swift
//  Neto
//
//  Categories tab placeholder view from DetailContainerView.
//

import SwiftUI

/// Categories tab content view.
/// Currently a placeholder for future implementation.
struct CategoriesTabView: View {

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("Categorías")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.netoPrimaryText)

            Text("El análisis por categorías estará disponible próximamente")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
