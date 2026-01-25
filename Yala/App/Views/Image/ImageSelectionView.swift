//
//  ImageSelectionView.swift
//  Yala
//
//  Placeholder view for image selection (Fase 8.4 - Imágenes MVP)
//

import SwiftUI

struct ImageSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.orange)

                Text("Selección de imagen")
                    .font(.title2.weight(.semibold))

                Text("Próximamente: Escanea capturas de pantalla o recibos para crear transacciones automáticamente.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)

                Spacer()
            }
            .padding(DS.Spacing.xl)
            .navigationTitle("Imagen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ImageSelectionView()
}
