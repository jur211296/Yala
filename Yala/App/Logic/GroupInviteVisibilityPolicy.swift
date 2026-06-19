//
//  GroupInviteVisibilityPolicy.swift
//  Yala
//
//  Pure decision logic para qué opciones de Perfil/Ajustes ve un usuario en modo
//  solo-grupos (`OnboardingMode.groupInvite`). Centraliza las reglas de filtrado
//  que consumen ProfileView, ThemeSettingsView y NotificationsSettingsView para
//  tener una sola fuente de verdad y tests sin SwiftData ni UI (sin flake R8).
//
//  Criterio: en solo-grupos no se muestra nada Pro (no hay venta de Pro en ese
//  modo) ni nada dependiente de finanzas personales. Patrón análogo a
//  `GroupsOnboardingLogic`.
//

import Foundation

enum GroupInviteVisibilityPolicy {

    /// Temas seleccionables según el modo. En solo-grupos se ocultan los Pro →
    /// quedan los free; en full/completed se muestran todos (con su candado).
    static func selectableThemes(isGroupInvite: Bool) -> [AppTheme] {
        AppTheme.displayOrder.filter { !($0.isPro && isGroupInvite) }
    }

    /// Tipos de notificación visibles según el modo. En solo-grupos solo la de
    /// grupos (event-driven); el resto (recordatorios, reportes, pagos
    /// programados, custom) pertenecen a finanzas personales.
    static func visibleNotificationTypes(
        _ all: [NotificationType],
        isGroupInvite: Bool
    ) -> [NotificationType] {
        isGroupInvite ? all.filter { $0 == .groups } : all
    }
}
