//
//  FavoritesSheet.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftUI

// MARK: - Favorites Sheet

/// Sheet placeholder para pagos favoritos (próximamente)
struct FavoritesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: 24) {
                    Spacer()

                    // Ícono animado
                    ZStack {
                        Circle()
                            .fill(Color.electricIndigo.opacity(0.1))
                            .frame(width: 100, height: 100)

                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.electricIndigo, Color.hotPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Pagos favoritos")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Próximamente")
                            .font(.headline)
                            .foregroundStyle(Color.electricIndigo)

                        Text("Guarda tus pagos recurrentes para registrarlos con un solo toque.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Entendido")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.electricIndigo)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Favoritos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetTopButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FavoritesSheet()
}
