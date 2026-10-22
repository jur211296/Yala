//
//  PrivateSignOutExportGateLogic.swift
//  Yala
//
//  Paso 9 del rediseño de sesiones (ADR 2026-09-09 «Sesiones — dos ejes» §5): cerrar una sesión PRIVADA
//  borra lo local y deja iCloud intacto. Para que «intacto» sea verdad, lo último que se guardó en este
//  dispositivo tiene que haber llegado a iCloud ANTES de borrar. Esta es la decisión PURA de esa espera.
//
//  ## Por qué hace falta, medido (2026-09-09)
//
//  Nadie esperaba al export: `iCloudSyncService` solo observa los eventos del espejo para pintar estado,
//  y el cierre privado de antes (`.privateReset`) no borraba nada, así que no lo necesitaba. Con el
//  borrado local, un movimiento guardado hace cinco segundos y aún no exportado se pierde para siempre.
//
//  ## El testigo, y por qué es este y no otro
//
//  «¿Llegó a iCloud lo último?» no tiene API. Lo que sí hay:
//   - el **historial de SwiftData** del store personal, que ya se lee en producción con el espejo montado
//     (el drain de Grupos y el motor de la nube), y
//   - el **inicio** de cada export del espejo (`NSPersistentCloudKitContainer.Event.startDate`).
//
//  El export arranca, recorre el historial y sube lo que encuentra. Todo cambio LOCAL confirmado antes
//  del INICIO de un export que terminó bien viajó en él; lo posterior puede no haberlo hecho. ⇒
//  **pendiente = cambios locales del historial posteriores al inicio del último export con éxito.** Cero
//  pendientes autoriza a borrar; si no, se espera.
//
//  Se descartaron, y conviene saber por qué antes de «simplificar»:
//   - `iCloudSyncService.lastSuccessfulExportDate` es el FIN del export: un save que entra DURANTE el
//     export quedaría como subido sin haberlo sido. Y vive en memoria: tras relanzar no hay nada.
//   - `MigrationWorkExecutor.isMarkerExported` es binario (no cuenta, y la decisión de Jürgen exige el
//     número) y deja una fila de marcador en iCloud por cada cierre.
//   - `CKContainer.accountStatus()` está descartado por decisión escrita (`ICloudCutoverGateLogic`,
//     `MigrationWorkExecutor`): sería una segunda verdad sobre la cuenta.
//
//  ## Lo que NO se puede medir en simulador, y a dónde falla si está mal
//
//  El espejo firma sus propias transacciones (las de importar) con autor `NSCloudKitMirroringDelegate…`
//  y se excluyen por prefijo. No hay CloudKit en simulador, así que el literal lo verifica el device-QA.
//  Si no casara, las importaciones contarían como pendientes: el cierre ESPERARÍA y acabaría ofreciendo la
//  salida avisada con un número de más — nunca borraría de menos. Es el lado seguro a propósito.
//

import Foundation

nonisolated enum PrivateSignOutExportGateLogic {

    // MARK: - ¿Hay copia en iCloud a la que esperar?

    /// Si no hay copia, no hay nada que esperar: se avisa de que no existe ninguna (decisión de Jürgen del
    /// 2026-09-09: no se bloquea, confirmación reforzada, sin export previo).
    enum CopyChannel: Equatable {
        /// Este store espeja a un iCloud que acepta exports: se espera a que llegue lo último.
        case iCloud
        /// No hay copia en ninguna parte.
        case none
    }

    /// «No hay copia» se dice solo con una PRUEBA, y hay dos:
    ///  - **El mount no espeja** (`PersonalStoreDecision.attachesCloudKitMirror == false`): este proceso no
    ///    ha subido nada a ningún sitio. Es el testigo exacto que ya usa el aviso del espejo tardío
    ///    (`ICloudPersonalCorpusProbe.mirrorWillSync`), no una segunda verdad.
    ///  - **El espejo dijo `notAuthenticated`**: CloudKit contestó que no hay cuenta.
    ///
    /// Todo lo demás cuenta como copia, y se espera al export. **Ni la falta de token ni la falta de ancla
    /// prueban nada** (review adversarial del paso 9). El token mide iCloud DRIVE —con Drive apagado falta y
    /// el espejo `.automatic` exporta igual (`swiftdata-cloudkit.md`, `ubiquityIdentityToken`)— y el ancla no
    /// existe hasta el primer export con éxito que vea esta versión. Con esos dos términos la hoja le decía
    /// «no hay copia en ninguna parte» a quien lleva años en iCloud, y el segundo gesto se saltaba la espera.
    /// Si de verdad no hay a dónde subir, la espera no confirma nada y el aviso lo dice sin inventar («no
    /// pudimos confirmar…»), con la salida de emergencia de siempre: el error cae del lado de esperar.
    ///
    /// Se decide AL TOCAR (elige la variante de la hoja) y viaja con la confirmación. La ejecución no lo
    /// recalcula a peor: si alguien confirmó con copia y la copia se fue, la espera lo bloquea y cuenta.
    static func copyChannel(mountAttachesMirror: Bool, mirrorReportedNotAuthenticated: Bool) -> CopyChannel {
        guard mountAttachesMirror, !mirrorReportedNotAuthenticated else { return .none }
        return .iCloud
    }

    // MARK: - ¿Qué cuenta como pendiente?

    /// Prefijo del autor con el que `NSPersistentCloudKitContainer` firma sus propias transacciones
    /// (`…import`, `…export`, `…setup`). Lo que el espejo escribe BAJÓ de iCloud: no está pendiente de subir.
    static let mirrorAuthorPrefix = "NSCloudKitMirroringDelegate"

    /// ¿Esta transacción del historial es un cambio LOCAL que el espejo aún podría no haber subido?
    ///
    /// El borde es `>=` a propósito: una transacción confirmada en el mismo instante en que arrancó el export
    /// pudo quedarse fuera de él, y ante la duda cuenta como pendiente (a lo sumo cuesta una espera).
    ///
    /// **Sin margen hacia atrás, y es deliberado.** Un «`>= ancla − N s`» protegería de un reloj que
    /// retrocede, pero rompe el caso normal: el export lo dispara el propio save, que queda unos
    /// milisegundos ANTES del inicio del export — con margen, el último cambio de cualquier sesión contaría
    /// como pendiente para siempre y todo cierre acabaría en la salida de emergencia. El reloj que cambia se
    /// cubre invalidando el ancla (`iCloudSyncService`, `NSSystemClockDidChange`) y, si cambió con la app
    /// cerrada, descartando el ancla que quedó en el futuro (`usableAnchor`).
    ///
    /// Sin ancla (nunca se vio un export con éxito) todo lo local cuenta aquí, y es el contador quien
    /// convierte eso en «no se puede dar un número» (`PersonalExportPendingCounter`).
    static func isPendingLocalWrite(timestamp: Date, author: String?, confirmedExportStart: Date?) -> Bool {
        if let author, author.hasPrefix(mirrorAuthorPrefix) { return false }
        guard let confirmedExportStart else { return true }
        return timestamp >= confirmedExportStart
    }

    /// Cuánto puede adelantarse el ancla al reloj antes de dejar de servir.
    static let anchorFutureTolerance: TimeInterval = 60

    /// El ancla que sirve AHORA. Una guardada en el FUTURO dice que el reloj retrocedió con la app cerrada
    /// —`NSSystemClockDidChange` solo llega a un proceso vivo—, y con ella todo cambio nuevo quedaría «antes
    /// del ancla» y contaría como subido (review adversarial del paso 9). Se trata como si no hubiera ancla:
    /// cuenta todo lo local, que es el lado seguro, y el siguiente export con éxito la reemplaza.
    static func usableAnchor(_ stored: Date?, now: Date) -> Date? {
        guard let stored, stored <= now.addingTimeInterval(anchorFutureTolerance) else { return nil }
        return stored
    }

    // MARK: - Las capturas que esperan en el App Group

    /// Una vuelta del recuento del cierre, con las capturas de Apple Pay y Siri dentro.
    ///
    /// Esas capturas esperan en el App Group hasta que la app las convierte en borrador. No están en el
    /// store, así que el historial no las ve, y el arranque siguiente las purga con el resto
    /// (`AppGroupInboundPurge`). En la privada quien vuelve suele ser la misma persona: se pierden sin que
    /// ningún aviso las nombre (ticket `private-exit-loses-unmaterialized-inbound-captures`).
    ///
    /// **Por eso el orden: primero se materializan, después se lee el historial.** Un borrador recién creado
    /// es un cambio local más, y la espera lo sube como cualquier otro. Lo que NO se pudo materializar —el
    /// import de iCloud seguía activo, o el `save()` falló— cuenta como pendiente: nunca autoriza a borrar.
    ///
    /// `historyPending` recibe si el store cambió en esta vuelta: quien cachea el recuento tiene que tirarlo.
    /// Un historial que no se pudo contar (`nil`) sigue siendo `nil`.
    @MainActor
    static func pendingCountMaterializingInbound(
        materialize: @MainActor () -> (created: Int, stillQueued: Int),
        historyPending: @MainActor (_ storeChanged: Bool) -> Int?
    ) -> Int? {
        let inbound = materialize()
        guard let history = historyPending(inbound.created > 0) else { return nil }
        return history + inbound.stillQueued
    }

    // MARK: - ¿Se puede borrar ya?

    enum Verdict: Equatable {
        /// Cero pendientes: todo lo local está en iCloud. Se puede borrar.
        case proceed
        /// Hay pendientes y queda presupuesto: se espera un poco más.
        case wait
        /// Presupuesto agotado con cambios sin confirmar. `pendingCount == nil` = no se pudo contar.
        case stalled(pendingCount: Int?)
    }

    /// La espera normal («un momento más»), en segundos. El mismo presupuesto que el cierre solo-grupos
    /// (`GroupsSignOutRetryDecision`): pasado este tiempo, el aviso cuenta lo pendiente y ofrece la salida.
    static let budgetSeconds: Double = 45
    static let pollIntervalSeconds: Double = 1

    /// Un conteo que no se pudo hacer (`nil`) NUNCA autoriza a borrar: solo el cero demostrado lo hace.
    static func verdict(pendingCount: Int?, elapsedSeconds: Double,
                        budgetSeconds: Double = budgetSeconds) -> Verdict {
        if pendingCount == 0 { return .proceed }
        return elapsedSeconds < budgetSeconds ? .wait : .stalled(pendingCount: pendingCount)
    }

    /// El bucle de la espera, con el conteo y el reloj INYECTADOS (regla del repo: ni `Date()` ni `sleep`
    /// crudos en lógica testeada). El tiempo transcurrido se suma por intervalos, así que un test lo recorre
    /// entero sin esperar. Devuelve `.proceed` o `.stalled`, nunca `.wait`.
    ///
    /// Una CANCELACIÓN devuelve `.stalled(pendingCount: nil)`: el sesgo seguro es no borrar sobre una
    /// espera que nadie terminó de mirar.
    @MainActor
    static func awaitConfirmedExport(
        budgetSeconds: Double = budgetSeconds,
        pollIntervalSeconds: Double = pollIntervalSeconds,
        pendingCount: @MainActor () -> Int?,
        onWaiting: @MainActor () -> Void = {},
        sleep: @MainActor (Double) async -> Bool
    ) async -> Verdict {
        var elapsed: Double = 0
        while true {
            let current = verdict(pendingCount: pendingCount(), elapsedSeconds: elapsed,
                                  budgetSeconds: budgetSeconds)
            switch current {
            case .proceed, .stalled:
                return current
            case .wait:
                onWaiting()
                guard await sleep(pollIntervalSeconds) else { return .stalled(pendingCount: nil) }
                elapsed += pollIntervalSeconds
            }
        }
    }
}
