//
//  SharedImageRecoveryGate.swift
//  Yala
//
//  Pure-logic: ¿debe la app re-emitir un intent para presentar una imagen compartida
//  pendiente (share extension → App Group `PendingImages/`)?
//
//  El directorio App Group es una cola durable cross-launch (la imagen sobrevive al kill
//  del proceso). La app la drena en cada "ventana ready" (post-bootstrap y en cada
//  `handleBecameActive`). `.presentSharedImage` es notification-like: si se `submit`ea mientras la
//  app aún no puede presentar, `RouterEntryGate` lo difiere. Hasta el 2026-10-10 el buffer lo
//  descartaba en silencio (cold launch → "no hace nada"); hoy guarda su ruta. Este gate sigue
//  replicando las condiciones de `NotificationGateLogic.shouldEnqueueNow`: re-emitir contra un gate
//  que va a diferir solo apilaría entradas en el buffer.
//
//  Ver `Bugs/qa_cold-launch-share-image-no-registro`.
//

import Foundation

enum SharedImageRecoveryGate {

    /// `true` → re-emite el intent de presentación (encolará vía `AppRouter`).
    /// `false` → no hacer nada; la imagen persiste en `PendingImages/` y se reintenta en la
    /// próxima ventana ready (siguiente `.active` o cold launch).
    ///
    /// Las condiciones de readiness (init + onboarding) espejan
    /// `NotificationGateLogic.shouldEnqueueNow`: si alguna falla, `RouterEntryGate` diferiría
    /// el `.presentSharedImage` en vez de encolarlo.
    /// - Parameter isHeldForProGate: hay una tanda retenida mientras «Función Pro» está abierta
    ///   (`SharedImageProGateHold`). Re-emitirla sacaría otra vez la puerta encima de la que ya está: al volver de la
    ///   hoja de compra de la App Store la app pasa por `.active`.
    static func shouldReEmit(
        hasPendingImage: Bool,
        isInitialized: Bool,
        hasCompletedOnboarding: Bool,
        isHeldForProGate: Bool
    ) -> Bool {
        guard hasPendingImage else { return false }
        guard !isHeldForProGate else { return false }
        guard isInitialized else { return false }
        guard hasCompletedOnboarding else { return false }
        return true
    }
}

/// La tanda compartida que chocó con «Función Pro» (card fazw, ticket `shared-receipt-is-dropped-when-it-hits-the-pro-gate`).
///
/// Hasta el 2026-10-25 la puerta la descartaba al instante, y si la persona compraba ahí, «Comenzar» abría el registro
/// por imagen vacío: tenía que volver a compartir la foto. Ahora se retiene mientras la hoja está abierta: comprar abre
/// el registro por imagen con ella; cerrar sin comprar la descarta, como antes. Vive en el proceso, no en disco: si la
/// app muere con la hoja abierta, la foto sigue en `PendingImages/` y el arranque siguiente vuelve a preguntar, que es
/// lo que pasa con cualquier foto compartida que no llegó a abrirse.
@MainActor
enum SharedImageProGateHold {

    private(set) static var heldURL: URL?

    static var isHolding: Bool { heldURL != nil }

    static func hold(_ url: URL) {
        heldURL = url
    }

    /// Se compró: la foto retenida pasa al registro por imagen. `nil` si la hoja no venía de una foto compartida.
    static func takeForUnlock() -> URL? {
        defer { heldURL = nil }
        return heldURL
    }

    /// Se cerró sin comprar: la tanda se descarta, como antes de retenerla.
    static func discard(removeBatch: ((URL) -> Void)? = nil) {
        guard let url = heldURL else { return }
        heldURL = nil
        if let removeBatch {
            removeBatch(url)
        } else {
            SharedContainerService.removePendingImageBatch(containing: url)
        }
    }
}
