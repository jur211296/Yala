//
//  GroupsOnlyInviteView.swift
//  YalaWidgets
//
//  Lo que pinta un widget de datos cuando la sesión de este teléfono es solo grupos: no hay finanzas personales que
//  enseñar, y el hueco se usa como puerta de entrada (decisión de Jürgen del 2026-09-09, ticket
//  `after-session-redesign-review-widgets-siri-applepay-and-web-copy`). Ni vacío ni un widget de grupos: dice que aún
//  no hay finanzas personales y lleva a activarlas.
//
//  El dato viene de la app por el App Group (`WidgetDataService.isGroupsOnlySession`). El toque abre
//  `yala://activate-full`, que la app resuelve con el eje VIVO: si ya se activó, lleva al Panel.
//

import SwiftUI
import WidgetKit

/// Sustituye el contenido de un widget de datos por la invitación cuando la sesión es solo grupos.
///
/// Se aplica en el `Widget` (el cierre de su configuración), no dentro de cada vista: un solo sitio por widget, y la
/// vista de datos no tiene que saber nada de sesiones. Los de entrada rápida no lo llevan: abren una acción, no datos.
struct GroupsOnlyInviteModifier: ViewModifier {
    func body(content: Content) -> some View {
        if WidgetDataService.isGroupsOnlySession {
            GroupsOnlyInviteView()
        } else {
            content
        }
    }
}

extension View {
    /// En una sesión solo grupos, el widget invita a activar Yala completo en vez de pintar datos que no existen.
    func invitesToActivateFullWhenGroupsOnly() -> some View {
        modifier(GroupsOnlyInviteModifier())
    }
}

struct GroupsOnlyInviteView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(WidgetURLHelper.url(for: "activate-full"))
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3) // A11Y-DT: icono único del widget circular de la pantalla bloqueada
                    .widgetAccentable()
            }
            .accessibilityLabel(Text("widget.groupsOnly.cta", bundle: .main))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                Text("widget.groupsOnly.title", bundle: .main)
                    .font(WDS.Typography.label)
                    .lineLimit(2)
                Text("widget.groupsOnly.cta", bundle: .main)
                    .font(WDS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("widget.groupsOnly.cta", bundle: .main)
        default:
            VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2) // A11Y-DT: icono de la invitación, mismo tamaño que el estado vacío de los widgets
                    .foregroundStyle(WidgetColors.primary)
                Spacer(minLength: 0)
                Text("widget.groupsOnly.title", bundle: .main)
                    .font(WDS.Typography.title)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                HStack(spacing: WDS.Spacing.xxs) {
                    Text("widget.groupsOnly.cta", bundle: .main)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.right")
                }
                .font(WDS.Typography.label)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(WDS.Spacing.xs)
        }
    }
}
