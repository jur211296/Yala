//
//  SharedImageRecoveryGate.swift
//  Yala
//
//  Pure-logic: ¿debe la app re-emitir un intent para presentar una imagen compartida
//  pendiente (share extension → App Group `PendingImages/`)?
//
//  El directorio App Group es una cola durable cross-launch (la imagen sobrevive al kill
//  del proceso). La app la drena en cada "ventana ready" (post-bootstrap y en cada
//  `handleBecameActive`). Pero `.presentSharedImage` es notification-like Y NO-serializable:
//  si se `submit`ea mientras la app aún no puede presentar, `RouterEntryGate` lo difiere a
//  un buffer que lo descarta en silencio (cold launch → "no hace nada"). Este gate replica
//  exactamente las condiciones de `NotificationGateLogic.shouldEnqueueNow` para asegurar que
//  el re-emit SOLO ocurra cuando el `submit` pasará el gate y encolará de verdad.
//
//  Ver `Bugs/qa_cold-launch-share-image-no-registro`.
//

import Foundation

enum SharedImageRecoveryGate {

    /// `true` → re-emite el intent de presentación (encolará vía `AppRouter`).
    /// `false` → no hacer nada; la imagen persiste en `PendingImages/` y se reintenta en la
    /// próxima ventana ready (siguiente `.active` o cold launch).
    ///
    /// Las condiciones de readiness (init + onboarding + no-lock) espejan
    /// `NotificationGateLogic.shouldEnqueueNow`: si alguna falla, `RouterEntryGate` diferiría
    /// el `.presentSharedImage` a un buffer que no lo serializa → se perdería.
    static func shouldReEmit(
        hasPendingImage: Bool,
        isInitialized: Bool,
        hasCompletedOnboarding: Bool,
        isLocked: Bool
    ) -> Bool {
        guard hasPendingImage else { return false }
        guard isInitialized else { return false }
        guard hasCompletedOnboarding else { return false }
        guard !isLocked else { return false }
        return true
    }
}
