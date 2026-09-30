//
//  RemoteWipeGraceLogic.swift
//  Yala
//
//  **Qué hace `ContentView` cuando `hasPersonalData` cambia, y cómo distingue un borrado HECHO AQUÍ de uno
//  que llega de otro dispositivo** (ticket `wipe-data-does-not-cancel-the-remote-wipe-grace`).
//
//  La caída `true → false` arranca una gracia de 5 s; si los datos siguen sin estar al vencer, se pide el aviso
//  «tus datos fueron eliminados de iCloud». Es para el vaciado REMOTO, y un borrado deliberado de este teléfono
//  no debe encenderla.
//
//  **Por qué no basta con cancelar la gracia antes de borrar**, que es lo que hacían los cuatro borrados
//  deliberados hasta hoy: la tarea la crea el `onChange` en el render SIGUIENTE a la caída, cuando el `cancel()`
//  ya pasó. Los cuatro se salvaban por otra cosa —bajan `hasCompletedOnboarding` y el guard cierra solo—. Los dos
//  que lo REPONEN no tenían esa suerte: «Vaciar datos» en solo-grupos (`applyWipeLanding(.groupsShell)`) y el
//  restore remoto con el onboarding ya hecho en otro dispositivo (`performLocalWipeForRemoteSync`, rama
//  `skipOnboarding`). Con el guard abierto, la gracia arrancaba y el aviso salía a los cinco segundos.
//
//  **Y la caída no llega cuando borras**: `wipeAllUserData` no bumpea `dataVersion`, así que `hasPersonalData`
//  se quedaba en `true` hasta el siguiente bump de quien fuera. Por eso el borrado deliberado RE-MIDE en su misma
//  vuelta del main actor (`settleAfterDeliberateWipe`) y deja armada la absorción de esa caída.
//

import Foundation

nonisolated struct RemoteWipeGraceLogic: Equatable {

    /// Lo que `ContentView` hace con una transición de `hasPersonalData`.
    enum Reaction: Equatable {
        /// Los datos desaparecieron sin que nadie de este teléfono los borrara: cuenta atrás de 5 s.
        case startGrace
        /// Los datos volvieron: la gracia pendiente, si la hay, sobra.
        case cancelGrace
        /// La caída la provocó un borrado deliberado de este teléfono: no hay nada que anunciar.
        case absorbDeliberateDrop
        /// Ni una cosa ni otra (sin onboarding, o con la activación en pantalla).
        case ignore
    }

    /// Armada tras un borrado deliberado cuya medida dio «sin datos». Vale para UNA caída.
    private(set) var absorbsNextDrop = false

    /// **El asentamiento del borrado deliberado**: se llama con la medida VIVA tomada justo después de borrar, en
    /// la misma vuelta del main actor.
    ///
    /// Si la medida dice que los datos siguen —el borrado lanzó antes de tocar nada, o el fetch falló cerrado—,
    /// no se arma nada: la siguiente caída sería otra cosa. Si dice que no están, la caída que viene es la de este
    /// borrado, y hay que absorberla.
    ///
    /// **Por qué la absorción no caduca por tiempo.** Si `hasPersonalData` ya valía `false`, no llega ninguna caída
    /// y la marca se queda puesta. Es inofensivo: para que haya otra caída, antes tiene que haber una subida, y la
    /// subida la desarma (`personalDataChanged`).
    mutating func settleAfterDeliberateWipe(measuredPersonalData: Bool) {
        absorbsNextDrop = !measuredPersonalData
    }

    /// La reacción a una transición de `hasPersonalData`. **Toda transición desarma la absorción**, en cualquier
    /// sentido: la absorbe si es la caída que esperaba, y si es una subida, la caída que esperaba ya no va a llegar.
    ///
    /// La absorción va DELANTE de los guards de la gracia a propósito: absorber es decir «esta caída no es un
    /// vaciado remoto», y eso es verdad con o sin onboarding.
    mutating func personalDataChanged(from wasPresent: Bool, to isPresent: Bool,
                                      hasCompletedOnboarding: Bool,
                                      isShowingFullModeActivation: Bool) -> Reaction {
        let absorbs = absorbsNextDrop
        absorbsNextDrop = false
        if wasPresent && !isPresent {
            if absorbs { return .absorbDeliberateDrop }
            return hasCompletedOnboarding && !isShowingFullModeActivation ? .startGrace : .ignore
        }
        if !wasPresent && isPresent { return .cancelGrace }
        return .ignore
    }
}
