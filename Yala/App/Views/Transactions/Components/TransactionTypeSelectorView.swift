//
//  TransactionTypeSelectorView.swift
//  Yala
//
//  Extracted from NewTransactionView - Transaction type selector (Expense/Income/Transfer)
//

import SwiftUI

// MARK: - Transaction Type Selector

struct TransactionTypeSelectorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La cápsula elegida se desliza de un tipo al otro en vez de fundirse (card pjum).
    @Namespace private var selectionNamespace
    /// Alto de una etiqueta (texto + su padding) a tamaño normal, escalado con el texto: solo sirve para que el fondo
    /// sepa si los tipos van en fila o apilados (`TypeSelectorTrack`); no fija el tamaño de nada.
    @ScaledMetric(relativeTo: .subheadline) private var labelHeightEstimate: CGFloat = 20 + 2 * DS.Chip.paddingV
    @Binding var selectedType: TransactionType
    var availableTypes: [TransactionType] = TransactionType.allCases
    var onTypeChange: ((TransactionType) -> Void)?

    var body: some View {
        // Hide selector completely when only one type available
        if availableTypes.count <= 1 {
            EmptyView()
        } else {
            selectorContent
        }
    }

    /// En fila si cada tipo cabe entero en su parte; si no (texto grande), uno debajo del otro, para que «Transferencia»
    /// no se parta en tres líneas (decisión 64 de la revisión 2.3). Los mismos botones en las dos formas: la cápsula se
    /// sigue deslizando.
    private var selectorContent: some View {
        TypeSelectorLayout {
            ForEach(availableTypes) { type in
                Button {
                    // Tocar el tipo que ya está elegido no cambia nada. Antes volvía a llamar a
                    // `onTypeChange`, que borra la subcategoría (y con ella la necesidad): un toque
                    // de más sobre «Gasto» dejaba el formulario sin categoría y «Guardar» apagado.
                    // Auditoría UX 2.2, lote 2, B2.
                    guard type != selectedType else { return }
                    DS.Haptic.selection()
                    dsWithAnimation(reduceMotion, DS.Animation.selection) {
                        selectedType = type
                        onTypeChange?(type)
                    }
                } label: {
                    label(for: type)
                        .foregroundStyle(selectedType == type ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Chip.paddingV)
                        .background {
                            if selectedType == type {
                                Capsule()
                                    .fill(type.color)
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }
                        }
                }
                .accessibilityAddTraits(selectedType == type ? .isSelected : [])
                .accessibilityIdentifier("new_transaction_type_\(type.rawValue)")
            }
        }
        .padding(DS.Spacing.xs)
        .background(TypeSelectorTrack(labelHeightEstimate: labelHeightEstimate, inset: DS.Spacing.xs).fill(.thCard))
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// La etiqueta reserva el ancho de su versión en negrita (la elegida): así elegir un tipo no cambia si caben en
    /// fila, y la forma no salta de fila a pila al tocar «Transferencia».
    private func label(for type: TransactionType) -> some View {
        ZStack {
            Text(type.displayName)
                .font(.subheadline.weight(.semibold))
                .hidden()
                .accessibilityHidden(true)
            Text(type.displayName)
                .font(.subheadline.weight(selectedType == type ? .semibold : .regular))
        }
    }
}

// MARK: - Layout

/// Fila de partes iguales —lo mismo que el `HStack(spacing: 0)` de antes con hijos de ancho flexible— si la etiqueta de
/// cada hijo cabe entera en su parte; si alguna no cabe, los apila a todo el ancho.
struct TypeSelectorLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = proposal.width ?? widest * CGFloat(subviews.count)
        if Self.fitsInRow(width: width, widestIdeal: widest, count: subviews.count) {
            let part = ProposedViewSize(width: width / CGFloat(subviews.count), height: proposal.height)
            let height = subviews.map { $0.sizeThatFits(part).height }.max() ?? 0
            return CGSize(width: width, height: height)
        }
        let row = ProposedViewSize(width: width, height: nil)
        return CGSize(width: width, height: subviews.reduce(0) { $0 + $1.sizeThatFits(row).height })
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        if Self.fitsInRow(width: bounds.width, widestIdeal: widest, count: subviews.count) {
            let partWidth = bounds.width / CGFloat(subviews.count)
            let part = ProposedViewSize(width: partWidth, height: bounds.height)
            for (index, subview) in subviews.enumerated() {
                let center = CGPoint(x: bounds.minX + partWidth * (CGFloat(index) + 0.5), y: bounds.midY)
                subview.place(at: center, anchor: .center, proposal: part)
            }
            return
        }
        let row = ProposedViewSize(width: bounds.width, height: nil)
        var y = bounds.minY
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading, proposal: row)
            y += subview.sizeThatFits(row).height
        }
    }

    static func fitsInRow(width: CGFloat, widestIdeal: CGFloat, count: Int) -> Bool {
        guard count > 0 else { return true }
        return widestIdeal <= width / CGFloat(count)
    }
}

/// El fondo del selector: la cápsula de siempre en fila; apilado, un rectángulo cuyas esquinas siguen a la cápsula de
/// la primera y la última fila (mismo centro, `inset` más de radio), para que la cápsula elegida no asome por fuera.
struct TypeSelectorTrack: Shape {
    let labelHeightEstimate: CGFloat
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let content = max(rect.height - 2 * inset, 0)
        let rows = max(1, (content / max(labelHeightEstimate, 1)).rounded())
        guard rows > 1 else { return Capsule().path(in: rect) }
        let radius = content / rows / 2 + inset
        return RoundedRectangle(cornerRadius: min(radius, rect.width / 2, rect.height / 2), style: .continuous).path(in: rect)
    }
}
