//
//  MinimalSuccessParts.swift
//  Yala
//
//  Las piezas del éxito minimalista (el de Nuevo registro, elegido por Jürgen el 2026-11-20) para las pantallas de éxito
//  de Grupos y de la Bandeja (encargo del 2026-11-24). Copian el patrón de `TransactionSuccessView`, que no las usa
//  todavía: el encargo no dejaba tocarla. Refactor pendiente (anotado en el ticket): que la personal también las use.
//

import SwiftUI

/// El esqueleto: «Editar» arriba (si lo hay), el centro que solo se desplaza si no cabe y los botones al pie, siempre a la
/// vista (molde de `TransactionSuccessView`, también en un iPhone SE o girado).
struct MinimalSuccessLayout<Center: View, Footer: View>: View {
    var onEdit: (() -> Void)? = nil
    var editIdentifier: String = ""
    var footerVisible: Bool = true
    @ViewBuilder var center: () -> Center
    @ViewBuilder var footer: () -> Footer

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.none) {
                if let onEdit {
                    HStack {
                        Spacer()
                        Button(L10n.Action.edit, action: onEdit)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(editIdentifier)
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.lg)
                }

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: DS.Spacing.none) {
                            Spacer()
                            center()
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.lg)
                        .frame(minHeight: proxy.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                }

                footer()
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xxxl)
                    .opacity(footerVisible ? 1.0 : 0.0)
                    .offset(y: footerVisible ? 0 : 10)
            }
        }
    }
}

/// Un check pequeño en el color del tipo junto al título («Gasto agregado»). Es la cabecera para VoiceOver.
struct MinimalSuccessTitle: View {
    let title: String
    var icon: String = "checkmark.circle.fill"
    let tint: Color
    var bounces: Bool = false
    let identifier: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.headline)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: bounces)
                .accessibilityHidden(true)
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(identifier)
    }
}

/// La descripción suelta, sobre el monto.
struct MinimalSuccessDescription: View {
    let text: String
    let identifier: String

    var body: some View {
        Text(text)
            .font(DS.Typography.bodyLarge)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, DS.Spacing.xl)
            .accessibilityIdentifier(identifier)
    }
}

/// La tarjeta sin rótulos de los datos, en el orden de importancia que le dé quien la monta.
struct MinimalSuccessCard<Rows: View>: View {
    @ViewBuilder var rows: () -> Rows

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            rows()
        }
        .padding(.vertical, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }
}

/// Una fila sin rótulo a la vista: icono y valor. El rótulo lo lee VoiceOver.
struct MinimalSuccessRow<Value: View>: View {
    let icon: String
    var iconTint: Color? = nil
    let label: String
    let spoken: String
    let identifier: String
    @ViewBuilder var value: () -> Value

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(iconTint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
                .frame(width: 20)
                .accessibilityHidden(true)
            value()
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                // `.combine` y no `.ignore`: el valor sigue siendo un texto para VoiceOver y para las pruebas.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(label)
                .accessibilityValue(spoken)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }
}

/// Un nombre con su punto de color (cuenta, grupo, categoría).
struct MinimalSuccessDotted: View {
    let text: String
    let colorHex: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(text)
        }
    }
}

/// Los botones del pie lado a lado (B1); si no caben (idioma largo, texto grande), uno debajo del otro.
struct MinimalSuccessFooter: View {
    struct Action {
        let title: String
        let identifier: String
        let action: () -> Void
    }

    var secondary: Action? = nil
    let primary: Action

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.sm) {
                if let secondary { secondaryButton(secondary, lineLimit: 1) }
                primaryButton
            }
            VStack(spacing: DS.Spacing.sm) {
                primaryButton
                if let secondary { secondaryButton(secondary, lineLimit: nil) }
            }
        }
    }

    private var primaryButton: some View {
        YalaPrimaryButton(primary.title, action: primary.action)
            .accessibilityIdentifier(primary.identifier)
    }

    private func secondaryButton(_ item: Action, lineLimit: Int?) -> some View {
        Button(action: item.action) {
            Text(item.title)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: lineLimit != nil, vertical: false)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier(item.identifier)
    }
}
