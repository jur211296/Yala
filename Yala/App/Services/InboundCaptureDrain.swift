//
//  InboundCaptureDrain.swift
//  Yala
//
//  El ÚNICO sitio que convierte las capturas que esperan en el App Group —gastos de Apple Pay, dictados de
//  Siri y los «Ya lo pagué» del widget de Pagos planificados— en borradores o registros del store personal. Lo llaman el arranque, la vuelta a primer plano, el final de una
//  ráfaga de cambios remotos y el cierre de una sesión privada.
//
//  ## Por qué un solo sitio
//
//  Con el borrado de cierre ARMADO el store está condenado: el arranque siguiente borra sus archivos y
//  purga las colas (`AppGroupInboundPurge`). Drenar en esa ventana escribe en un store que nadie va a subir
//  (ticket `private-exit-loses-unmaterialized-inbound-captures`). Hasta el 2026-09-26 solo
//  `handleBecameActive` lo miraba; el final de la ráfaga de cambios remotos drenaba igual, y desde el paso 9
//  eso era alcanzable en la privada. El guard vive AQUÍ, dentro del escritor, para que un llamador nuevo no
//  pueda olvidarlo: un source-scan fija que nadie más llama a `processPending`.
//
//  Las imágenes compartidas NO pasan por aquí: no se convierten solas en borrador (necesitan a la persona,
//  el análisis y su consentimiento), así que no hay nada que drenar.
//

import Foundation
import SwiftData

@MainActor
enum InboundCaptureDrain {

    /// Materializa las colas de Apple Pay y Siri. Devuelve cuántos borradores creó.
    ///
    /// **Con el borrado de cierre armado no toca nada**: las colas se quedan para la purga del arranque, que
    /// es la frontera de privacidad entre cuentas.
    ///
    /// **Sin sesión privada, Apple Pay y Siri esperan en el App Group** (ticket
    /// `apple-pay-capture-in-a-groups-only-session-has-no-personal-inbox`). Desde el encargo S11e (2026-10-27) los dos
    /// intents no encolan en «Solo grupos» (`GroupsOnlyIntentGate`), pero lo que ya esperaba —encolado antes de quedarse
    /// en solo grupos, o por un build anterior— se materializaba como borrador de un store personal sin cuentas ni
    /// Bandeja. Ahora se queda en la cola y se convierte en borrador cuando la persona activa Yala completo. Es un gate de
    /// DATOS, así que lee el eje (`PrivateSessionMark`), no la shell: con sesión privada y «Solo grupos» elegido el store
    /// personal es real y se materializa como siempre (el aviso de la Bandeja ya espera, `PersonalRemindersPause`).
    ///
    /// Los parámetros existen para los tests; en producción se usan los valores por defecto.
    @discardableResult
    static func drain(
        context: ModelContext,
        wipeArmed: Bool = StorageModePersistence.isSignOutWipeArmed(),
        hasPrivateSession: Bool = PrivateSessionMark.hasPrivateSession(),
        applePay: @MainActor (ModelContext) -> Int = { ApplePayDraftService.processPending(context: $0) },
        siri: @MainActor (ModelContext) -> Int = { SiriDraftService.processPending(context: $0) },
        widgetPaid: @MainActor (ModelContext) -> Int = { ScheduledPaymentPayNow.processWidgetPaidRequests(context: $0) }
    ) -> Int {
        guard !wipeArmed else { return 0 }
        let applePayCreated = hasPrivateSession ? applePay(context) : 0
        let siriCreated = hasPrivateSession ? siri(context) : 0
        // «Ya lo pagué» del widget de Pagos planificados: el registro con la lógica de «Apuntarlo ahora».
        let widgetPaidCreated = widgetPaid(context)
        return applePayCreated + siriCreated + widgetPaidCreated
    }

    /// Cuántas capturas de Apple Pay y Siri esperan todavía en el App Group. Las colas son inyectables para
    /// los tests; en producción, las del App Group.
    static func queuedCount(
        applePayDefaults: UserDefaults? = ApplePayPendingStore.appGroupDefaults,
        siriDefaults: UserDefaults? = SiriPendingStore.appGroupDefaults
    ) -> Int {
        ApplePayPendingStore.peekAll(defaults: applePayDefaults).count
            + SiriPendingStore.peekAll(defaults: siriDefaults).count
    }

    /// La pasada del cierre privado: materializa y dice qué quedó en cola, para que el recuento lo vea
    /// (`PrivateSignOutExportGateLogic.pendingCountMaterializingInbound`). `created` > 0 = el store cambió;
    /// `stillQueued` son las capturas que no se pudieron materializar (import activo, o `save()` fallido).
    static func forSignOut(
        context: ModelContext,
        drain: @MainActor (ModelContext) -> Int = { InboundCaptureDrain.drain(context: $0) },
        queued: @MainActor () -> Int = { InboundCaptureDrain.queuedCount() }
    ) -> (created: Int, stillQueued: Int) {
        let created = drain(context)
        return (created, queued())
    }
}
