//
//  FilterBand.swift
//  Yala
//
//  Revisión 2.3, decisión 16 (L1, 9-nov). Los filtros aplicados iban en una fila horizontal que no cabía: con tres, el
//  de la nota —el que dejaba la lista en cero— quedaba cortado a la derecha. La banda los parte en líneas para que se
//  vean todos y trae siempre «Quitar todo». La usan las barras de Panel, Estadísticas, Registros e Informes.
//

import SwiftUI

/// Las cápsulas de la banda, partidas en líneas. A diferencia del `FlowLayout` de etiquetas, una cápsula más ancha que la
/// banda (una nota larga) se mide con el ancho disponible, así que se recorta en vez de salirse por el borde.
struct FilterBandLayout: Layout {
    var spacing: CGFloat = DS.Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(maxWidth: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(maxWidth proposed: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposed ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }

        let width = maxWidth.isFinite ? maxWidth : widest
        return (CGSize(width: width, height: y + lineHeight), frames)
    }
}

/// La banda entera: las cápsulas en líneas y, si hay alguna, «Quitar todo» al final, con su propia zona de 44 pt.
struct FilterBand<Chips: View>: View {
    var showsRemoveAll: Bool
    var onRemoveAll: () -> Void
    @ViewBuilder var chips: () -> Chips

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        FilterBandLayout(spacing: DS.Spacing.sm) {
            chips()
            if showsRemoveAll {
                Button {
                    // En seco, como quitar una cápsula: quitar los filtros reemplaza la página (card oxyr).
                    onRemoveAll()
                } label: {
                    Text(L10n.RecordsQuickFilters23.removeAll)
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accentText)
                        .lineLimit(1)
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(minHeight: FilterChipView.closeHitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter_band_remove_all")
            }
        }
        // Sin identificador en el contenedor: pisaría los de las cápsulas y el de «Quitar todo» (testing.md).
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
