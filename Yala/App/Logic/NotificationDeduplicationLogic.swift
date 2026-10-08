//
//  NotificationDeduplicationLogic.swift
//  Yala
//
//  Qué avisos junta la limpieza de duplicados del arranque (`NotificationService.deduplicateNotifications`) y
//  cuál se queda de cada grupo. Lógica pura, sin SwiftData.
//

import Foundation

enum NotificationDeduplicationLogic {

    /// Lo que la limpieza necesita saber de cada aviso.
    struct Candidate: Equatable {
        let typeRaw: String
        let isActive: Bool
    }

    /// La clave con la que la limpieza junta avisos, o `nil` si ese aviso no se junta nunca.
    ///
    /// Los avisos de sistema se siembran una vez por dispositivo (`NotificationService.seedDefaultNotificationsIfNeeded`
    /// y el onboarding), así que dos dispositivos del mismo iCloud traen cada uno el suyo: sobran todos menos uno. Un
    /// `typeRaw` que este build no conoce también se junta, porque solo puede ser un tipo de sistema de un build más
    /// nuevo.
    ///
    /// **Los recordatorios de la persona (`custom`) no se juntan nunca**, ni por tipo ni por identidad. Por tipo, la
    /// limpieza borraba todos menos uno en cada arranque (ticket `notification-dedup-deletes-all-custom-reminders-but-one`).
    /// Por identidad tampoco: un `custom` solo nace en el editor, con una fila por guardado, así que ningún camino conocido
    /// crea dos filas del mismo recordatorio; y si dos filas compartieran `id` por un colapso del UUID por defecto, serían
    /// dos recordatorios distintos. Es el mismo criterio que la clave de fusión del linaje (`LineageTwinKey.notificationFusion`).
    static func groupKey(typeRaw: String) -> String? {
        typeRaw == NotificationType.custom.rawValue ? nil : typeRaw
    }

    /// Los índices de los avisos que sobran. De cada grupo se queda uno: el primer activo, o el primero si ninguno lo está.
    static func indicesToDelete(_ candidates: [Candidate]) -> [Int] {
        var keptByKey: [String: Int] = [:]
        for (index, candidate) in candidates.enumerated() {
            guard let key = groupKey(typeRaw: candidate.typeRaw) else { continue }
            if let kept = keptByKey[key] {
                if candidate.isActive && !candidates[kept].isActive { keptByKey[key] = index }
            } else {
                keptByKey[key] = index
            }
        }
        let kept = Set(keptByKey.values)
        return candidates.indices.filter { groupKey(typeRaw: candidates[$0].typeRaw) != nil && !kept.contains($0) }
    }
}
