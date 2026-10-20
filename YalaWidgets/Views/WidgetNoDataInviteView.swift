//
//  WidgetNoDataInviteView.swift
//  YalaWidgets
//
//  UX 2.2 · L15-2 (opción C, Jürgen 2026-10-18). Un widget añadido antes de abrir Yala pintaba «0» (en dólares si no
//  había preferencia guardada) y la persona creía que la app no funcionaba: ningún widget distinguía «Yala todavía no
//  me pasó datos» de «no hay movimientos». Ahora, sin datos de Yala en el App Group, el widget lo dice y el toque abre
//  la app, que es lo que escribe esos datos.
//
//  Mismo molde que `GroupsOnlyInviteModifier`: se aplica en el `Widget` (el cierre de su configuración), un solo sitio
//  por widget. Los placeholders y la galería (`isPlaceholder`) enseñan su ejemplo de siempre.
//

import SwiftUI
import WidgetKit

/// Sustituye el contenido de un widget de datos por «Abre Yala para ver…» mientras la app no haya escrito sus datos.
struct WidgetNoDataInviteModifier: ViewModifier {
    let isPlaceholder: Bool
    let message: LocalizedStringResource

    func body(content: Content) -> some View {
        if !isPlaceholder && !WidgetDataService.hasSnapshot {
            WidgetNoDataInviteView(message: message)
        } else {
            content
        }
    }
}

extension View {
    /// Sin datos de Yala todavía, el widget invita a abrir la app en vez de pintar ceros (UX 2.2 · L15-2).
    /// `message` por defecto: «Abre Yala para ver tus datos».
    func invitesToOpenYalaWithoutData(
        isPlaceholder: Bool,
        message: LocalizedStringResource = "widget.empty.openYala"
    ) -> some View {
        modifier(WidgetNoDataInviteModifier(isPlaceholder: isPlaceholder, message: message))
    }
}

struct WidgetNoDataInviteView: View {
    @Environment(\.widgetFamily) private var family
    let message: LocalizedStringResource

    var body: some View {
        content
            .widgetURL(WidgetURLHelper.url(for: "panel"))
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "arrow.up.forward.app")
                    .font(.title3) // A11Y-DT: icono único del widget circular de la pantalla bloqueada
                    .widgetAccentable()
            }
            .accessibilityLabel(Text(message))
        case .accessoryRectangular:
            Text(message)
                .font(WDS.Typography.label)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("widget.empty.openYalaShort", bundle: .main)
        default:
            VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.title2) // A11Y-DT: mismo tamaño que la invitación de solo grupos
                    .foregroundStyle(WidgetColors.primary)
                Spacer(minLength: 0)
                Text(message)
                    .font(WDS.Typography.title)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(WDS.Spacing.xs)
        }
    }
}

/// «Aún no tienes pagos planificados · Toca para crear uno» (y lo mismo con presupuestos): el estado vacío de un widget
/// cuando la persona todavía no creó ninguno. Antes salía «Sin pagos pendientes» con un ✓ verde, que se leía como
/// «estás al día» (UX 2.2 · L15-2).
struct WidgetCreateFirstView: View {
    let icon: String
    let message: LocalizedStringResource

    var body: some View {
        VStack(spacing: WDS.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2) // A11Y-DT: widget empty state icon
                .foregroundStyle(WidgetColors.primary)
            Text(message)
                .font(WDS.Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("widget.empty.createOne", bundle: .main)
                .font(WDS.Typography.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
