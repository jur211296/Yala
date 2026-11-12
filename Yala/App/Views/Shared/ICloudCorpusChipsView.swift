//
//  ICloudCorpusChipsView.swift
//  Yala
//
//  Las píldoras con las cifras del aviso tardío de iCloud (UX 2.2 · L6-6). Relleno índigo SÓLIDO con el texto en
//  blanco (AA): sin degradado y sin borde de cristal, que es lo que jerarquiza las cifras frente al resto del aviso.
//  Saltan de línea con el texto grande (`FlowLayout`) en vez de recortarse.
//

import SwiftUI

struct ICloudCorpusChipsView: View {
    let chips: [ICloudCorpusChipsLogic.Chip]

    var body: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(chips, id: \.self) { chip in
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: chip.icon)
                        .font(DS.Typography.caption.weight(.semibold))
                        .accessibilityHidden(true)
                    Text(chip.text)
                        .font(DS.Typography.subheadlineEmphasized)
                }
                // A11Y-DM: blanco fijo sobre el relleno índigo sólido (AA en claro y en oscuro).
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(Color.selectedIndigoFill))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("late_icloud_counts")
    }
}
