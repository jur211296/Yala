//
//  AsistenteCreacionPiezas.swift
//  Yala
//
//  Las respuestas que reusan todos los asistentes de creación (`AsistenteCreacionView`): una opción que se marca (una
//  de varias), la tarjeta que agrupa campos y la fila del resumen que se toca para cambiar la respuesta. Lo elegido va
//  relleno de color, no solo con contorno (criterio permanente de Jürgen).
//

import SwiftUI

/// Una opción de una pregunta de «una de varias»: icono opcional, título, frase debajo y la marca. Tocarla la elige; no
/// avanza (eso es «Siguiente»).
struct AsistenteOpcion: View {
    let titulo: String
    var detalle: String? = nil
    var icono: String? = nil
    let elegida: Bool
    let id: String
    let accion: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            DS.Haptic.selection()
            accion()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // A tamaños de accesibilidad el icono se va: el texto necesita el ancho.
                if let icono, !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: icono)
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(elegida ? theme.onAccent : theme.accentText)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(elegida ? theme.accent : theme.accent.opacity(0.15)))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(titulo)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detalle {
                        Text(detalle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: elegida ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title3)
                    .foregroundStyle(elegida ? theme.accentText : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(elegida ? theme.accent.opacity(0.14) : theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(elegida ? theme.accent : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(id)
    }
}

/// La tarjeta de los campos de una pregunta (fechas, nombre, monto): el fondo de tarjeta del tema.
struct AsistenteTarjeta<Contenido: View>: View {
    @ViewBuilder let contenido: () -> Contenido

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { contenido() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
    }
}

/// Una respuesta del resumen: lo que se preguntó a la izquierda, lo que se contestó debajo o al lado, y el lápiz. Tocarla
/// vuelve a esa pregunta.
struct AsistenteResumenFila: View {
    let etiqueta: String
    let valor: String
    let id: String
    let accion: () -> Void

    var body: some View {
        Button {
            DS.Haptic.selection()
            accion()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(etiqueta)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(valor)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "pencil")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(AsistenteCreacionTexto.cambiarPista)
        .accessibilityIdentifier(id)
    }
}
