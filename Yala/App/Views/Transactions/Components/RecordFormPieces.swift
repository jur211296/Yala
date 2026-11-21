//
//  RecordFormPieces.swift
//  Yala
//
//  Las piezas que comparten los tres formularios de registro: Nuevo registro, la aprobación de un borrador de la Bandeja
//  (`InboxDraftEditSheet`) y Nuevo gasto de Grupos. Registro unificado, opción A de Jürgen (31-oct-2026, «Va la A»): la
//  aprobación copia a Nuevo registro y Grupos se adapta. Antes cada pantalla pintaba la fecha, la descripción, los chips
//  bajo el monto y los selectores de abajo a su manera; con estas piezas, cambiar una cambia las tres.
//
//  Propuestas y capturas: `docs/disenos/registro-unificado-2-2/`.
//

import SwiftUI

// MARK: - Pastilla grande (fecha y grupo)

/// La pastilla grande con el grupo arriba de Nuevo gasto de Grupos. Desde la hoja B1 (2026-11-20) la fecha ya no la usa:
/// va como valor puesto en la fila de abajo (`RecordDateValueChip`).
struct RecordPillLabel: View {
    let icon: String
    /// Color del icono (el del grupo). Sin él, el del texto.
    var iconColor: Color? = nil
    let text: String
    /// Se puede cambiar desde aquí (el grupo, al crear desde la pestaña).
    var showsChevron: Bool = false
    /// Con cápsula. Sin ella, para lo que es solo contexto y no se toca (el grupo dentro de su detalle): el mismo tamaño,
    /// sin parecer un botón.
    var filled: Bool = true

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.label)
                .foregroundStyle(iconColor ?? Color.primary)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(Capsule().fill(Color.primary.opacity(filled ? 0.08 : 0)))
        .contentShape(Capsule())
    }
}

// MARK: - Descripción

extension View {
    /// La descripción del registro: el mismo tamaño, color y ancho en las tres pantallas (la aprobación la pintaba en
    /// `headline`, más pequeña que Nuevo registro y Grupos).
    func recordDescriptionStyle() -> some View {
        self
            .font(DS.Typography.title)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .textContentType(.none)
            .frame(maxWidth: 280)
            .tint(Color.primary)
    }
}

// MARK: - Selectores de abajo

/// Los selectores de abajo (cuenta y sus líneas, categoría, etiquetas) en filas que bajan cuando no caben, alineadas a la
/// izquierda, como Nuevo registro. Tras un hijo marcado con `endsSelectorRow()` se empieza fila nueva: la última línea de
/// una tarjeta lo lleva, y así quedan «Cuenta + Línea» en una fila y «Categoría + Etiqueta» en otra (opción A); una línea
/// de moneda nunca cae junto a la categoría, donde parecía un campo por rellenar. Sin líneas, todo fluye como siempre.
///
/// Una pastilla más ancha que la fila (un nombre largo, el texto de accesibilidad) se ajusta al ancho y trunca su texto,
/// en vez de salirse por el borde. `alignment: .center` centra cada fila (las hojas que completan un borrador de grupo,
/// con una o dos pastillas bajo un monto centrado).
struct RecordSelectorChips: Layout {
    var spacing: CGFloat = DS.Spacing.sm
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, maxWidth: width)
        return CGSize(width: width.isFinite ? width : rows.contentWidth, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, maxWidth: bounds.width)
        let offsets = alignment == .center
            ? RecordSelectorRowsLogic.centeringOffsets(rows, maxWidth: bounds.width)
            : Array(repeating: 0, count: rows.origins.count)
        for (index, subview) in subviews.enumerated() {
            let origin = rows.origins[index]
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x + offsets[index], y: bounds.minY + origin.y),
                proposal: ProposedViewSize(rows.sizes[index])
            )
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> RecordSelectorRowsLogic.Rows {
        let sizes = subviews.map { subview -> CGSize in
            let ideal = subview.sizeThatFits(.unspecified)
            guard maxWidth.isFinite, ideal.width > maxWidth else { return ideal }
            // Más ancha que la fila: se le propone el ancho de la fila, y su texto trunca.
            return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        }
        return RecordSelectorRowsLogic.arrange(
            sizes: sizes,
            endsRow: subviews.map { $0[RecordSelectorRowEndKey.self] },
            maxWidth: maxWidth,
            spacing: spacing
        )
    }
}

nonisolated private struct RecordSelectorRowEndKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// En `RecordSelectorChips`, este selector cierra su fila: el siguiente empieza otra.
    func endsSelectorRow(_ ends: Bool = true) -> some View {
        layoutValue(key: RecordSelectorRowEndKey.self, value: ends)
    }
}

/// El reparto en filas de `RecordSelectorChips`, sin vistas, para fijarlo con tests.
enum RecordSelectorRowsLogic {
    struct Rows: Equatable {
        /// Esquina superior izquierda de cada hijo.
        var origins: [CGPoint]
        var height: CGFloat
        /// El ancho de la fila más ancha.
        var contentWidth: CGFloat
        /// La fila (0, 1…) de cada hijo.
        var rowIndices: [Int]
        /// El tamaño con el que se coloca cada hijo.
        var sizes: [CGSize]
    }

    /// Lo que hay que desplazar cada hijo para centrar su fila en `maxWidth`.
    static func centeringOffsets(_ rows: Rows, maxWidth: CGFloat) -> [CGFloat] {
        var rowWidths: [Int: CGFloat] = [:]
        for index in rows.origins.indices {
            let row = rows.rowIndices[index]
            rowWidths[row] = max(rowWidths[row] ?? 0, rows.origins[index].x + rows.sizes[index].width)
        }
        return rows.origins.indices.map { index in
            max(0, (maxWidth - (rowWidths[rows.rowIndices[index]] ?? 0)) / 2)
        }
    }

    static func arrange(sizes: [CGSize], endsRow: [Bool], maxWidth: CGFloat, spacing: CGFloat) -> Rows {
        var origins: [CGPoint] = []
        var rowIndices: [Int] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var row = 0
        var contentWidth: CGFloat = 0
        var forced = false
        for (index, size) in sizes.enumerated() {
            if x > 0 && (forced || x + size.width > maxWidth) {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
                row += 1
            }
            origins.append(CGPoint(x: x, y: y))
            rowIndices.append(row)
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, x + size.width)
            x += size.width + spacing
            forced = index < endsRow.count && endsRow[index]
        }
        return Rows(
            origins: origins,
            height: sizes.isEmpty ? 0 : y + rowHeight,
            contentWidth: contentWidth,
            rowIndices: rowIndices,
            sizes: sizes
        )
    }
}
