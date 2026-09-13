//
//  GroupsOnlyVisibilityPolicy.swift
//  Yala
//
//  Pure decision logic para qué opciones de Perfil/Ajustes ve quien usa Yala SOLO para
//  grupos — o sea, quien no tiene sesión privada en este teléfono (el eje 1,
//  `PrivateSessionMark`). Centraliza las reglas de filtrado que consumen ProfileView,
//  ThemeSettingsView y NotificationsSettingsView para tener una sola fuente de verdad
//  y tests sin SwiftData ni UI (sin flake R8).
//
//  Criterio: en solo-grupos no se muestra nada Pro (no hay venta de Pro en ese
//  modo) ni nada dependiente de finanzas personales. Patrón análogo a
//  `GroupsOnboardingLogic`.
//

import Foundation

enum GroupsOnlyVisibilityPolicy {

    /// Temas seleccionables según el modo. En solo-grupos se ocultan los Pro →
    /// quedan los free; en full/completed se muestran todos (con su candado).
    static func selectableThemes(isGroupsOnlyShell: Bool) -> [AppTheme] {
        AppTheme.displayOrder.filter { !($0.isPro && isGroupsOnlyShell) }
    }

    /// Tipos de notificación visibles según el modo. En solo-grupos solo la de
    /// grupos (event-driven); el resto (recordatorios, reportes, pagos
    /// programados, custom) pertenecen a finanzas personales.
    static func visibleNotificationTypes(
        _ all: [NotificationType],
        isGroupsOnlyShell: Bool
    ) -> [NotificationType] {
        isGroupsOnlyShell ? all.filter { $0 == .groups } : all
    }
}
