//
//  RecordsSelectionBar.swift
//  Yala
//
//  La barra de abajo del modo selección, la misma en Registros y en Estadísticas › Registros (auditoría UX 2.2, L8-12,
//  variante 1). Sin nada elegido dice qué hacer («Toca los registros que quieras»); con algo elegido, «Eliminar» y
//  «Editar» con su texto y cuántos van. Fondo de tarjeta (`thCard`) con borde: el material fino de antes dejaba ver
//  las filas de detrás y se leía mal.
//

import SwiftUI

struct RecordsSelectionBar: View {
    @Environment(\.yalaTheme) private var theme

    let selectedCount: Int
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack {
            Spacer()

            Group {
                if selectedCount == 0 {
                    hint
                } else {
                    actions
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Lo primero que se ve al entrar: qué hacer ahora.
    private var hint: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "hand.tap")
                .font(DS.Typography.label)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text(L10n.UXL8.selectHint)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Spacing.none)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(barBackground)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("records_selection_hint")
    }

    /// El recuento arriba y, debajo, Eliminar y Editar a lo ancho. En una sola fila los tres no cabían ni a tamaño
    /// normal («Elimi…», «2 selecciona…», medido en el iPhone 17 Pro el 17-oct), y menos en un SE o con texto grande.
    private var actions: some View {
        VStack(spacing: DS.Spacing.sm) {
            countLabel
            HStack(spacing: DS.Spacing.md) {
                deleteButton
                editButton
            }
        }
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.md)
        .background(barBackground)
    }

    private var countLabel: some View {
        Text(L10n.Records.selectedCount(selectedCount))
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .contentTransition(.numericText())
            .accessibilityIdentifier("records_selection_count")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            DS.Haptic.warning()
            onDelete()
        } label: {
            Label(L10n.Action.delete, systemImage: "trash")
                .font(DS.Typography.label)
                .foregroundStyle(DS.Semantic.errorForeground)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Semantic.errorBackgroundSubtle, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bulk_delete_button")
    }

    private var editButton: some View {
        Button {
            DS.Haptic.selection()
            onEdit()
        } label: {
            Label(L10n.Action.edit, systemImage: "pencil")
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(theme.accent, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bulk_edit_button")
    }

    /// Opaca: el fondo de la pantalla del tema y su tarjeta encima. La tarjeta sola (`thCard`) es translúcida en los
    /// temas oscuros y dejaba ver las filas de detrás (medido en el simulador el 17-oct), que es lo que L8-12 quita.
    private var barBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            .fill(theme.background)
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18))
            )
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

/// «Seleccionar» a la vista en la barra de arriba de Registros (L8-12): antes solo estaba dentro de «···». Sigue
/// también en el menú, que es lo que cuenta la ayuda.
struct RecordsSelectToolbarButton: View {
    let viewModel: RecordsViewModel

    var body: some View {
        Button(L10n.Action.select) {
            viewModel.enterSelectionMode()
        }
        .fontWeight(.semibold)
        .accessibilityIdentifier("records_select_visible")
    }
}
