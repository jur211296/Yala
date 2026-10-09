//
//  RemoteWipeSharedSurfaces.swift
//  Yala
//
//  Lo que sigue afirmando datos del dueño FUERA del store cuando sus filas se van por el espejo de CloudKit sin
//  que corra ningún borrado de `DataWipeService`: el snapshot del widget, el snapshot que lee Siri y los avisos que
//  el sistema tiene programados.
//
//  POR QUÉ EXISTE (ticket `after-session-redesign-review-widgets-siri-applepay-and-web-copy`). El dueño vacía sus
//  datos desde otro dispositivo; las filas desaparecen de este teléfono por el espejo y, a los 5 s, sale el aviso de
//  «Tus datos fueron eliminados de iCloud». Su «Empezar de cero» (`ContentView.startFreshAfterRemoteWipeNotice`)
//  devolvía al onboarding sin tocar nada de esto, así que la pantalla de inicio seguía pintando el saldo y los
//  últimos movimientos del dueño hasta el siguiente arranque en frío, Siri seguía ofreciendo sus subcategorías hasta
//  el siguiente primer plano, y los recordatorios y el resumen de pagos programados seguían llegando.
//
//  LA OTRA RAMA NO PASA POR AQUÍ. Cuando llega la señal (`handleRemoteWipeSignal`), el borrado orquestado ya vacía
//  el widget y el snapshot de Siri (PASO 3 de `DataWipeService.wipeAllUserData`) y cancela los avisos y reprograma
//  los de lo que sobrevive al corte. Cancelarlos otra vez desde aquí correría contra esa reprogramación y apagaría
//  los recordatorios que se quedan.
//
//  QUÉ NO TOCA, a propósito. Las colas de Apple Pay y de Siri (`AppGroupInboundPurge`) son capturas hechas EN ESTE
//  teléfono que aún no se han convertido en borrador: no son datos del dueño que se fueron. Los avisos ya
//  entregados tampoco: son historial del Centro de Notificaciones, no algo que vaya a sonar.
//

import Foundation

enum RemoteWipeSharedSurfaces {

    /// «Empezar de cero» del aviso de vaciado remoto: las filas ya no están y nada más va a limpiar.
    @MainActor
    static func purgeAfterMirrorWipe() {
        purgeAfterMirrorWipe(
            appGroup: UserDefaults(suiteName: SharedContainerService.appGroupIdentifier),
            standard: .standard,
            cancelPendingNotifications: { NotificationService.shared.cancelAllNotifications() })
    }

    /// Variante inyectable: los tests miden el resultado sobre stores aislados y un centro de avisos de mentira.
    ///
    /// - Parameters:
    ///   - appGroup: donde viven el snapshot del widget y el de Siri.
    ///   - standard: donde viven las marcas del resumen diario de pagos programados.
    ///   - cancelPendingNotifications: retira TODO lo programado en el sistema.
    @MainActor
    static func purgeAfterMirrorWipe(
        appGroup: UserDefaults?,
        standard: UserDefaults,
        cancelPendingNotifications: () -> Void
    ) {
        WidgetDataCache.clearCache(in: appGroup)
        SiriIntentContextCache.clear(defaults: appGroup)
        cancelPendingNotifications()
        // Con lo programado retirado, la marca «este día ya tiene su resumen de pagos programado» MENTIRÍA y
        // silenciaría el día entero para un pago que la persona cree después
        // (`ScheduledPaymentNotificationTracker.reconcileSummaryMarks`). SOLO esas: las de «ya avisé de este pago hoy»
        // describen avisos YA ENTREGADOS, y el aviso también sale por un hueco pasajero de CloudKit — si las filas
        // vuelven, barrerlas repetía en el siguiente primer plano los banners del día (review adversarial).
        let summaryPrefix = ScheduledPaymentNotificationTracker.summaryKeyPrefix
        for key in standard.dictionaryRepresentation().keys where key.hasPrefix(summaryPrefix) {
            standard.removeObject(forKey: key)
        }
    }
}
