//
//  GroupsAttestVerdictLogic.swift
//  Yala
//
//  Cuándo un teléfono que no consigue App Attest deja de oír «inténtalo en un rato» (ticket
//  `groups-phone-that-never-attests-is-told-to-retry-forever`, decisión de Jürgen del 2026-09-15).
//
//  POR QUÉ EXISTE. Desde el 2026-09-15 un 401 `yala_attest_required` es pasajero en Grupos: la sesión vale y lo que
//  falta es el token de App Attest. Para quien lo recupera en un rato es lo cierto. Para quien no lo recupera nunca era
//  un aviso eterno, y un cierre de sesión imposible si le quedaban cambios de grupos sin subir. Esta tabla separa las
//  dos poblaciones con lo único que el cliente observa sin clasificar errores de DeviceCheck que nadie ha medido:
//  cuánto tiempo, y en cuántas ocasiones distintas, lleva el servidor rechazando el attest sin aceptarlo ni una vez.
//
//  QUÉ CUENTA. En Grupos, un rechazo es un 401 `yala_attest_required` de una ruta de Grupos —push, pull o RPC—: el
//  servidor dice «red bien, sesión bien, falta attest». Sin red o con un 5xx no se produce, así que estar sin conexión no
//  acerca el veredicto, y un 200 de esas rutas borra la racha. **Desde el 2026-09-15 la racha es del teléfono y la escribe
//  también el motor personal**, que nunca manda una subida sin attest: cuenta el error de su puerta cuando habla del attest
//  (`AttestSyncGate.countsTowardAttestStreak`), y un token conseguido la borra aunque sea uno cacheado que el gateway ya
//  rechaza (`attest-session-token-rejected-by-the-gateway-stays-cached`).
//
//  QUÉ NO DECIDE. Dónde se guarda la racha lo lleva `GroupsAttestStreakStore`. Y el cierre de sesión no se fía solo de
//  ella: exige además que el ciclo que lee haya chocado con el attest —el 401 en Grupos
//  (`GroupsSyncClient.stoppedByUnavailableAttest`), la puerta en el motor personal (`CloudSyncRuntime.stoppedByUnavailableAttest`)—,
//  para que una racha vieja no disfrace un fallo de hoy que es otra cosa.
//

import Foundation

nonisolated enum GroupsAttestVerdictLogic {

    /// Los rechazos seguidos, sin un solo acierto entre medias, y desde cuándo.
    struct Streak: Codable, Equatable, Sendable {
        /// El primer rechazo de la racha, con el reloj del teléfono.
        let firstRejectedAt: Date
        /// El último rechazo que CONTÓ. Los que llegan antes de `countingInterval` no suman.
        let lastCountedAt: Date
        /// Rechazos contados, uno por `countingInterval` como mucho. Satura en `Int.max`.
        let rejections: Int
        /// El canario `groupsAttestTerminal` ya contó esta racha. Lo escribe la tienda tras avisar, y una racha
        /// nueva nace sin él.
        var terminalReported = false
    }

    /// 24 h sin un solo acierto (decisión de Jürgen, 2026-09-15). Un corte de Apple o del servidor de unas horas no
    /// llega; un teléfono que no atesta desde ayer, sí.
    static let minimumDuration: TimeInterval = 24 * 60 * 60

    /// Y al menos 3 rechazos contados: un 401 de ayer y otro de ahora no son una racha.
    static let minimumRejections = 3

    /// **Un rechazo cuenta como mucho una vez por hora.** Un solo gesto dispara ráfagas —la membresía reintenta tres
    /// veces, el cierre de sesión reintenta cada 2 s durante 45 s—, así que contar por petición cumplía el mínimo de 3
    /// en segundos y el veredicto quedaba en «un 401 de ayer y otro de ahora» (review adversarial, 2026-09-15). Por
    /// hora, los 3 son tres ocasiones distintas.
    static let countingInterval: TimeInterval = 60 * 60

    /// La racha tras un rechazo nuevo. Dentro de la misma hora que el último contado, la racha no cambia.
    ///
    /// **Un reloj que retrocede la reinicia.** Con `now` anterior al primer rechazo o al último contado no hay forma
    /// honesta de medir cuánto dura, y reiniciar solo puede retrasar el veredicto, nunca adelantarlo.
    static func recordingRejection(after previous: Streak?, now: Date) -> Streak {
        guard let previous, previous.firstRejectedAt <= now, previous.lastCountedAt <= now else {
            return Streak(firstRejectedAt: now, lastCountedAt: now, rejections: 1)
        }
        guard now.timeIntervalSince(previous.lastCountedAt) >= countingInterval else { return previous }
        let (sum, overflow) = previous.rejections.addingReportingOverflow(1)
        return Streak(firstRejectedAt: previous.firstRejectedAt, lastCountedAt: now,
                      rejections: overflow ? Int.max : sum, terminalReported: previous.terminalReported)
    }

    /// ¿Este teléfono ya no puede sincronizar grupos? Solo con las DOS condiciones a la vez: la duración y el número.
    static func isTerminal(_ streak: Streak?, now: Date) -> Bool {
        guard let streak, streak.firstRejectedAt <= now else { return false }
        return streak.rejections >= minimumRejections
            && now.timeIntervalSince(streak.firstRejectedAt) >= minimumDuration
    }

    /// ¿Hay que contar este teléfono en el canario? Una vez por racha, la primera vez que se lee terminal.
    ///
    /// **Va con su propia marca y no comparando con el rechazo anterior.** Los dos se evalúan con el mismo `now`: una
    /// racha que ya tenía sus rechazos contados y recibe otro un día después ya era terminal «antes» con ese reloj, y la
    /// comparación no avisaría nunca.
    static func shouldReportTerminal(_ streak: Streak, now: Date) -> Bool {
        !streak.terminalReported && isTerminal(streak, now: now)
    }
}
