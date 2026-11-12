//
//  OnboardingDefaultNotifications.swift
//  Yala
//
//  Los tipos de aviso que el alta deja creados, una vez por instalación. Sale de `OnboardingView.createDefaultNotifications`
//  para que lo compartan las dos altas —la de ocho pasos (activación de Yala completo) y la conversación de la bienvenida
//  2.3 (Y23-04)—: dos copias de la misma siembra es como divergen.
//

import Foundation
import SwiftData

enum OnboardingDefaultNotifications {
    @MainActor
    static func seedIfNeeded(in modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "notificationsSeeded") { return }
        defaults.set(true, forKey: "notificationsSeeded")

        let descriptor = FetchDescriptor<NotificationItem>()
        let existing: [NotificationItem]
        do {
            existing = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("OnboardingDefaultNotifications: Error fetching existing notifications: \(error)")
            #endif
            existing = []
        }
        let existingTypes = Set(existing.map { $0.typeRaw })

        let allDefaults = NotificationItem.createDefaults()
        var inserted = 0

        for notification in allDefaults {
            guard !existingTypes.contains(notification.typeRaw) else { continue }
            // Recordatorios/reportes nacen apagados (opt-in), pero el item de PAGOS conserva
            // su default ACTIVO (toggle honesto D2 2026-07-22): forzarlo a false aquí dejaba
            // al usuario nuevo sin ningún recordatorio de pagos hasta tocar Ajustes — y el
            // flip one-shot no lo cubre (su sentinel protege el OFF post-flip).
            if notification.notificationType != .scheduledPayments {
                notification.isActive = false
            }
            modelContext.insert(notification)
            inserted += 1
        }

        #if DEBUG
        if inserted > 0 {
            print("OnboardingDefaultNotifications: Created \(inserted) notification types (all inactive)")
        }
        #endif
    }
}
