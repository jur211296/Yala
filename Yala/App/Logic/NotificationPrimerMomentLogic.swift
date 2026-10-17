//
//  NotificationPrimerMomentLogic.swift
//  Yala
//
//  CUÁNDO se pide permiso para las notificaciones (UX 2.2 · L5-14, decisión de Jürgen: opción A).
//
//  Hasta 2.2 se pedía encima de la pantalla de éxito del TERCER registro, sin relación con lo que se acababa de
//  hacer, y prometía recordatorios de pagos y alertas de presupuesto a quien no tenía ninguno: el «Ahora no» salía
//  por reflejo y solía ser para siempre. Ahora se pide en contexto, con el beneficio de ese momento:
//
//   1. **Al guardar el primer pago planificado** — «¿Te avisamos antes de cada pago?».
//   2. **Al encender la alerta de un presupuesto** — «¿Te avisamos cuando te acerques al límite?».
//   3. **El tercer registro queda de respaldo** si no pasó antes ninguno de los dos.
//
//  Es UN solo aviso para los tres momentos: el primero que llega lo gasta (`hasSeenNotificationPrimer`), y solo
//  se enseña si el sistema todavía no preguntó (`.notDetermined`). Si iOS ya tiene respuesta, el aviso no
//  serviría de nada: el diálogo del sistema no vuelve a salir.
//

import Foundation
import UserNotifications

/// El momento en que se pide el permiso: decide el título y el beneficio que enseña la hoja.
nonisolated enum NotificationPrimerContext: Equatable {
    /// Respaldo: tercer registro guardado.
    case records
    /// Primer pago planificado guardado.
    case scheduledPayment
    /// Alerta de un presupuesto encendida.
    case budgetAlert
}

nonisolated enum NotificationPrimerMomentLogic {

    /// Registros guardados a partir de los cuales sale el respaldo.
    static let recordsThreshold = 3

    /// Si este momento puede pedir el permiso, antes de preguntar al sistema.
    ///
    /// - Parameters:
    ///   - hasSeen: el aviso ya salió (o ya se decidió no enseñarlo) en otro momento.
    ///   - savedRecords: `transactionsSavedCount`; solo cuenta para el respaldo.
    static func isMoment(_ context: NotificationPrimerContext, hasSeen: Bool, savedRecords: Int) -> Bool {
        guard !hasSeen else { return false }
        switch context {
        case .records: return savedRecords >= recordsThreshold
        case .scheduledPayment, .budgetAlert: return true
        }
    }

    /// Con el momento ya decidido, si se enseña: solo si iOS aún no preguntó.
    static func shouldPresent(authorization: UNAuthorizationStatus) -> Bool {
        authorization == .notDetermined
    }
}

/// El lado con efectos: lee y quema el one-shot y pregunta al sistema.
@MainActor
enum NotificationPrimerMoments {

    static let seenKey = "hasSeenNotificationPrimer"
    static let savedRecordsKey = "transactionsSavedCount"

    /// Si hay que enseñar la hoja ahora. Quema el one-shot en cuanto el momento llega, se enseñe o no (como hacía
    /// el respaldo del tercer registro): si iOS ya tiene respuesta, no hay nada que volver a pedir.
    ///
    /// Los dos momentos en contexto no salen en XCUITest: los flujos de pagos y presupuestos que ya prueban otras
    /// cosas se toparían con la hoja. El respaldo se queda como estaba.
    static func claim(_ context: NotificationPrimerContext) async -> Bool {
        if context != .records, UITestHooks.isActive { return false }
        let defaults = UserDefaults.standard
        guard NotificationPrimerMomentLogic.isMoment(
            context,
            hasSeen: defaults.bool(forKey: seenKey),
            savedRecords: defaults.integer(forKey: savedRecordsKey)
        ) else { return false }
        let status = await NotificationService.shared.checkPermissionStatus()
        defaults.set(true, forKey: seenKey)
        return NotificationPrimerMomentLogic.shouldPresent(authorization: status)
    }
}
