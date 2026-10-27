//
//  GroupsOnlyViewMark.swift
//  Yala
//
//  «Solo grupos» elegido por quien YA tiene Yala completo (card p0iu, decisión de Jürgen del 2026-10-26).
//
//  **Es un estado de VISTA, no de sesión.** El eje 1 (`PrivateSessionMark`) sigue encendido: los datos personales,
//  su espejo y el bridge de Grupos siguen vivos debajo. Esta marca solo cambia lo que la shell enseña
//  (`ShellModeLogic`) y pausa los avisos que hablarían de pantallas ocultas (`PersonalRemindersPause`).
//  Apagar la sesión privada para conseguir lo mismo armaría el montaje neutro y el bridge de solo-grupos.
//
//  **Del teléfono, no del Apple ID:** vive en `UserDefaults.standard` y no va al iCloud-KV. El iPad de la misma
//  persona puede seguir en completo. Y por eso la pausa no toca `NotificationItem.isActive`, que sí viaja.
//
//  **Muere con la sesión privada** (`PrivateSessionMark.set(false)` / `clear()`): sin vida personal no hay nada
//  que ocultar, y una marca huérfana dejaría en solo grupos a quien active Yala completo después.
//

import Foundation

nonisolated enum GroupsOnlyViewMark {
    static let userDefaultsKey = "usageMode.groupsOnlyView"

    /// `true` solo si la persona eligió «Solo grupos» sobre una sesión privada viva.
    static func isOn(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: userDefaultsKey)
    }

    static func set(_ value: Bool, _ defaults: UserDefaults = .standard) {
        if value {
            defaults.set(true, forKey: userDefaultsKey)
        } else {
            defaults.removeObject(forKey: userDefaultsKey)
        }
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}

/// **La pausa de los avisos personales mientras dura «Solo grupos»** (decisión 2 de Jürgen, 2026-10-26).
///
/// Una sola pregunta, leída por cada productor de avisos personales —recordatorios, informes, pagos programados y su
/// tarjeta, alertas de presupuesto personal— y por la creación de borradores de pagos programados. Los avisos de grupos
/// no la leen. Volver a Yala completo la levanta y `UsageModeService` reprograma lo pausado.
nonisolated enum PersonalRemindersPause {
    static func isPaused(_ defaults: UserDefaults = .standard) -> Bool {
        GroupsOnlyViewMark.isOn(defaults)
    }
}
