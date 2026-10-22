//
//  AdaptiveRowStack.swift
//  Yala
//
//  Fila que se reorganiza con el tamaño de texto: en horizontal a los tamaños normales, en
//  vertical a los de accesibilidad (AX1–AX5). Es lo que recomienda Apple para que un concepto
//  largo no empuje fuera ni corte el importe que va a su lado.
//

import SwiftUI

/// `HStack` a los tamaños de texto normales y `VStack` a los de accesibilidad.
///
/// **A tamaño normal pinta EXACTAMENTE el `HStack` plano que sustituye**, con los mismos hijos en el mismo orden.
/// No es un detalle: medido el 2026-09-28 en un iPhone SE, meter el icono y el texto en un `HStack` anidado
/// cambiaba cómo se repartía el ancho cuando la fila iba justa (la tarjeta de grupo pasaba a truncar el nombre
/// para no encoger el importe). Por eso la forma se elige con `if` y no con `AnyLayout`, que obligaría a compartir
/// una sola jerarquía entre las dos formas. El coste es que al cambiar el tamaño de texto con la fila en pantalla
/// SwiftUI la trata como una vista nueva; estas filas no guardan estado propio.
///
/// Se elige por el tamaño de texto y no por el contenido (`ViewThatFits`): dos filas vecinas de una lista nunca
/// salen distintas.
struct AdaptiveRowStack<Leading: View, Trailing: View>: View {
    private let alignment: VerticalAlignment
    private let stackedAlignment: HorizontalAlignment
    private let spacing: CGFloat?
    private let stackedSpacing: CGFloat?
    private let splitsIntoRow: Bool
    private let leading: Leading
    private let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fila de concepto + importe: en horizontal es `HStack { leading; Spacer(); trailing }`, la fila de siempre;
    /// apilada, `leading` queda en su propia fila (icono y texto juntos) y `trailing` debajo, al inicio.
    init(
        spacing: CGFloat? = nil,
        stackedSpacing: CGFloat? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.alignment = .center
        self.stackedAlignment = .leading
        self.spacing = spacing
        self.stackedSpacing = stackedSpacing ?? spacing
        self.splitsIntoRow = true
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Apilada ocupa el ancho entero: en fila lo conseguía el `Spacer()`, que en vertical ya no ensancha, y
            // sin esto el contenedor centraba la columna y el valor salía suelto en medio de la tarjeta.
            VStack(alignment: stackedAlignment, spacing: stackedSpacing) {
                if splitsIntoRow {
                    HStack(spacing: spacing) { leading }
                } else {
                    leading
                }
                trailing
            }
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: stackedAlignment, vertical: .center))
        } else if splitsIntoRow {
            HStack(alignment: alignment, spacing: spacing) {
                leading
                Spacer()
                trailing
            }
        } else {
            HStack(alignment: alignment, spacing: spacing) { leading }
        }
    }
}

extension AdaptiveRowStack where Trailing == EmptyView {
    /// Grupo de piezas del mismo rango (dos importes, dos cifras): en horizontal, `HStack { content }` tal cual;
    /// apiladas, una bajo otra.
    init(
        alignment: VerticalAlignment = .center,
        stackedAlignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = nil,
        stackedSpacing: CGFloat? = nil,
        @ViewBuilder content: () -> Leading
    ) {
        self.alignment = alignment
        self.stackedAlignment = stackedAlignment
        self.spacing = spacing
        self.stackedSpacing = stackedSpacing ?? spacing
        self.splitsIntoRow = false
        self.leading = content()
        self.trailing = EmptyView()
    }
}

extension HorizontalAlignment {
    /// La alineación de una columna que va a la derecha de la fila (el importe): al final en horizontal,
    /// al inicio cuando la fila se apila, para que el importe quede bajo el concepto y no suelto a la derecha.
    static func trailingUnlessStacked(_ size: DynamicTypeSize) -> HorizontalAlignment {
        size.isAccessibilitySize ? .leading : .trailing
    }
}
