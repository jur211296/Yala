//
//  SettlementReminderLogic.swift
//  Yala
//
//  Pure-logic del recordatorio amable de liquidación pendiente: decide QUÉ deudas del usuario
//  llevan demasiado tiempo quietas como para merecer un nudge, y cuáles ya se avisaron hace poco.
//
//  **Por qué existe una pieza nueva y no se reusó nada.** Las notificaciones de grupo de hoy
//  (`GroupNotificationRecipientLogic`) deciden sobre un HECHO que acaba de pasar: llegó un gasto,
//  llegó una liquidación. Esta decide sobre lo que NO pasó — tiempo transcurrido sin movimiento —,
//  así que su entrada no es un record sino un intervalo, y no hay nada que compartir entre ambas
//  salvo el canal de envío.
//
//  ## Las tres decisiones que este fichero fija
//
//  1. **Solo se avisa al DEUDOR** (decisión del owner, 2026-09-06): es quien puede resolverlo, y el
//     acreedor ya lo sabe. `dueReminders` filtra por `fromMemberID == currentMemberID` y no tiene
//     ninguna rama para el otro lado — la lógica de destinatario es UNA.
//
//  2. **El reloj lo marca la ÚLTIMA ACTIVIDAD entre las dos personas, no la antigüedad de la deuda.**
//     Es lo que pide el AC («crear un gasto o liquidar, aunque sea parcialmente, resetea el
//     contador») y además es lo único derivable: un `Debt` es el neto de varios gastos y
//     liquidaciones, no una entidad con fecha de origen. Se mide POR PAR y no por grupo a propósito:
//     en un piso compartido siempre hay gastos, y medir por grupo apagaría el nudge justo donde más
//     falta hace.
//
//  3. **Sin evidencia de actividad no se avisa.** Un par sin ninguna actividad registrada
//     (`lastActivityByPair` sin entrada) se salta: no se puede afirmar «lleva tres semanas quieta»
//     sobre algo cuya última vez se desconoce. Ocurre de verdad con `SplitGroup.simplifyDebts`
//     activado, donde el acreedor puede ser alguien con quien nunca se compartió un gasto.
//

import Foundation

/// Un hecho que movió la cuenta entre dos miembros, ya reducido a su fecha.
///
/// `nonisolated` porque bajo
/// `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` un tipo sin anotar queda aislado al MainActor, y
/// `GroupSettlementReminderService.activities` —que es pura y `nonisolated`— no podría ni construirlo.
///
/// El par se guarda sin orden (`memberA`/`memberB` son intercambiables): quién pagó a quién importa
/// para el saldo, pero no para responder «¿cuándo se tocó esto por última vez?».
nonisolated struct DebtActivity: Equatable, Sendable {
    let memberA: String
    let memberB: String
    let at: Date

    init(memberA: String, memberB: String, at: Date) {
        self.memberA = memberA
        self.memberB = memberB
        self.at = at
    }
}

/// `nonisolated` por lo mismo: es lógica pura sin estado, y sus constantes se leen desde defaults de
/// parámetro (`SettlementReminderTracker.cleanupOldEntries`). **Un default de parámetro se evalúa en
/// contexto NONISOLATED**, así que una constante MainActor ahí es un warning hoy y un error en Swift 6
/// — la misma trampa que `GroupChannelFreshness.ChannelSignals.live()` documenta en su docblock.
nonisolated enum SettlementReminderLogic {

    // MARK: - Umbrales

    /// Cuánto tiempo debe llevar una deuda sin moverse antes del primer aviso.
    static let defaultStaleAfter: TimeInterval = 21 * 24 * 60 * 60   // 3 semanas

    /// Cuánto se espera entre dos avisos de LA MISMA deuda, aunque el chequeo corra a diario.
    static let defaultRateLimit: TimeInterval = 7 * 24 * 60 * 60     // 1 semana

    // MARK: - Par canónico

    /// Clave estable de un par de miembros, independiente del orden en que se nombren.
    ///
    /// Los IDs vienen todos de `SplitMember.id.uuidString` (uppercase canónico), así que el
    /// `<=` sobre String es determinista — el mismo criterio que usa `consolidateDebts` para su
    /// `PairKey`. El separador es `|` porque el UUID ya usa `-` y `Debt.id` los concatena con él.
    static func pairKey(_ first: String, _ second: String) -> String {
        first <= second ? "\(first)|\(second)" : "\(second)|\(first)"
    }

    /// Reduce las actividades a la MÁS RECIENTE de cada par, **sin dejar que ninguna caiga en el
    /// futuro**.
    ///
    /// El clamp a `now` no es defensa teórica: la fecha de un gasto y la de una liquidación las teclea
    /// el usuario en un `DatePicker` sin rango, así que un dedo gordo en el año es un input alcanzable.
    /// Y como aquí se toma el MÁXIMO, una sola fecha futura ganaría a todas las reales y dejaría el par
    /// «recién activo» hasta esa fecha: el recordatorio moriría en silencio durante años, sin ningún
    /// síntoma. Clampeado, un error de ese tipo cuesta como mucho un ciclo de umbral.
    static func lastActivityByPair(_ activities: [DebtActivity], now: Date) -> [String: Date] {
        var result: [String: Date] = [:]
        for activity in activities {
            let key = pairKey(activity.memberA, activity.memberB)
            let at = min(activity.at, now)
            if let current = result[key] {
                result[key] = max(current, at)
            } else {
                result[key] = at
            }
        }
        return result
    }

    /// ¿El aviso puede nombrar a UNA persona, o tiene que hablar en plural?
    ///
    /// Se cuentan ACREEDORES, no deudas, y la diferencia es real: deberle a la misma persona en dos
    /// monedas son DOS `Debt` —`consolidateDebts` teclea por `(memberA, memberB, divisa)`— así que
    /// contar deudas le diría «tienes cuentas pendientes con varias personas» a quien solo le debe a
    /// Ana, en un grupo que puede tener dos miembros. Vive aquí, y no en el servicio, para que el
    /// criterio se pueda pinnear sin `ModelContext`.
    static func namesASingleCreditor(_ due: [Debt]) -> Bool {
        Set(due.map(\.toMemberID)).count == 1
    }

    // MARK: - La decisión

    /// Las deudas del usuario que hoy merecen un recordatorio, de la más quieta a la menos.
    ///
    /// - Parameters:
    ///   - debts: deudas ya consolidadas del grupo (con o sin simplificar — lo decide el caller
    ///     según `SplitGroup.simplifyDebts`, para que el aviso diga lo mismo que la pantalla).
    ///   - currentMemberID: mi `SplitMember.id` en ESA zona. `nil` ⇒ ninguna (no sé quién soy;
    ///     el mismo `.skip` conservador de `GroupNotificationRecipientLogic`).
    ///   - lastActivityByPair: salida de `lastActivityByPair(_:)`.
    ///   - lastNotifiedByDebt: por `Debt.id`, cuándo se avisó por última vez de esa deuda.
    ///   - now: inyectado para que el test no dependa del reloj.
    ///
    /// El orden de salida es determinista (actividad más antigua primero, y `Debt.id` como
    /// desempate) porque el caller manda UNA notificación por grupo y elige la primera: sin orden
    /// estable, dos corridas con los mismos datos nombrarían a personas distintas.
    static func dueReminders(
        debts: [Debt],
        currentMemberID: String?,
        lastActivityByPair: [String: Date],
        lastNotifiedByDebt: [String: Date],
        now: Date,
        staleAfter: TimeInterval = defaultStaleAfter,
        rateLimit: TimeInterval = defaultRateLimit
    ) -> [Debt] {
        guard let me = currentMemberID else { return [] }

        let due = debts.compactMap { debt -> (debt: Debt, activity: Date)? in
            // Solo al deudor: la decisión del owner, y la única rama de destinatario que existe.
            guard debt.fromMemberID == me else { return nil }
            guard debt.amount > 0 else { return nil }
            // Sin evidencia de actividad no se puede afirmar antigüedad (ver cabecera, punto 3).
            guard let activity = lastActivityByPair[pairKey(debt.fromMemberID, debt.toMemberID)] else { return nil }
            guard now.timeIntervalSince(activity) >= staleAfter else { return nil }
            if let notified = lastNotifiedByDebt[debt.id],
               now.timeIntervalSince(notified) < rateLimit {
                return nil
            }
            return (debt, activity)
        }

        return due
            .sorted { ($0.activity, $0.debt.id) < ($1.activity, $1.debt.id) }
            .map(\.debt)
    }
}
