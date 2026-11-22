//
//  EstoLeiPhotoViewer.swift
//  Yala
//
//  Las fotos leídas a pantalla completa, desde las miniaturas de la barra de «Esto leí» (opción A, Jürgen 2026-11-22: «a
//  la derecha, la foto para volver a verla»). Una página por foto; la X cierra.
//

import SwiftUI

struct EstoLeiPhotoViewer: View {
    let images: [UIImage]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFit()
                        .padding(DS.Spacing.lg)
                        .accessibilityHidden(true)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                        .accessibilityIdentifier("esto_lei_photos_close")
                }
            }
            .yalaScreenBackground(.subtle)
        }
    }
}
