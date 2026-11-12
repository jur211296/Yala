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
//  **Y no toda caída que llega de fuera es un vaciado** (2026-10-15, `noticeDecision`): con iCloud no disponible el
//  aviso es otro, y con una importación en marcha se espera.
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

    // MARK: - Qué aviso, y cuándo (ticket `tablero-apagar-icloud-drive-hace-que-yala-diga-t-i1o5`)

    /// El aviso que toca cuando la gracia vence con los datos todavía fuera.
    enum Notice: Equatable {
        /// «Tus datos fueron eliminados de iCloud», con «Empezar de cero». Solo con iCloud disponible.
        case dataRemoved
        /// «iCloud no está disponible en este dispositivo», sin borrar nada: lo que haya en iCloud vuelve con él.
        case iCloudUnavailable
    }

    /// Lo que la gracia hace al vencer, y el drenaje al ir a enseñar el aviso.
    enum NoticeDecision: Equatable {
        case present(Notice)
        /// Hay una importación de iCloud en marcha: puede estar devolviendo las filas, o puede estar trayendo el
        /// borrado de verdad. Se espera a que se asiente y se vuelve a decidir.
        case waitForImport
    }

    /// Cuánto tiene que estar quieta la importación para darla por asentada: lo mismo que la gracia.
    static let importQuietSeconds: TimeInterval = 5

    /// Cuánto se espera, como mucho, a que termine el PRIMER import de este proceso, contado desde la caída de las
    /// filas. Más allá se decide con lo que haya: `hasCompletedFirstImport` solo se enciende con un import que termina
    /// sin error, y no se enciende con un iCloud sin nada que importar ni con uno que falla (p. ej. la zona borrada
    /// desde Ajustes › iCloud, que es justo un vaciado de verdad). Sin techo, ese vaciado se quedaba sin aviso, y en
    /// el arranque siguiente no hay caída que lo vuelva a pedir. Lo cazó la review del 15-oct.
    static let firstImportCeilingSeconds: TimeInterval = 60

    /// **Qué aviso, o si hay que esperar.** Medido en el iPhone de QA el 15-oct:
    ///
    ///  · **Con iCloud Drive apagado** iOS vacía la copia local del espejo y las filas desaparecen sin que nadie las
    ///    borrara. `iCloudSyncService` pasa a `.noAccount` sin cuenta de iCloud (`iCloudAccountPresent == false`).
    ///    **Corrección del 2026-10-24 (card n5zw):** no era iOS. Con Drive apagado el store se montaba con
    ///    `cloudKitDatabase: .automatic`, que toma el PRIMER contenedor de los entitlements: en `Yala Dev` el de
    ///    producción, así que el espejo cambiaba de contenedor y vaciaba la copia (las dos mediciones fueron en
    ///    `Yala Dev`). Desde ese día `.localNoMirror` nombra su contenedor y con Drive apagado no cae nada; la cuenta
    ///    es `iCloudSyncService.hasICloudAccount`, que con Drive apagado y CloudKit vivo dice que sí.
    ///    La otra puerta de `.noAccount` es CloudKit diciendo `notAuthenticated` (`mirrorReportedNotAuthenticated`).
    ///    En los dos casos el aviso de borrado mentía y su «Empezar de cero» mezclaba después los datos reales con
    ///    los del onboarding. Va PRIMERO: sin cuenta no hay importación que esperar.
    ///  · **Con Drive encendido otra vez** el espejo vacía y reimporta, y el aviso salió con la importación a medias
    ///    (empezó 16:52:05 UTC, aviso ~16:52:07, terminó 16:52:10 con las 34 filas). No basta con callar: un vaciado
    ///    remoto de verdad TAMBIÉN llega como importación (los borrados bajan por el espejo), así que se espera a que
    ///    se asiente y entonces se decide con lo que haya.
    ///
    /// «Asentada» es: el primer import de este proceso ya terminó, sin `.syncing(.importing)` y sin actividad de
    /// importación en los últimos `importQuietSeconds`. **El primer término cubre el hueco medido**: en el arranque
    /// con Drive recién encendido las filas cayeron ~3 s ANTES de que empezara la importación, y la gracia de 5 s
    /// apenas lo tapaba. Con el primer import pendiente no se sabe todavía qué hay en iCloud, y se espera hasta
    /// `firstImportCeilingSeconds` desde la caída (`droppedAt`). Los otros dos términos no tienen techo: los acaba un
    /// evento de importación, con o sin error.
    /// Una actividad con fecha FUTURA (el reloj se atrasó) no retiene: no hay forma de saber cuándo fue, y retener
    /// hasta que el reloj la alcance podría ser días.
    static func noticeDecision(iCloudAccountPresent: Bool, mirrorReportedNotAuthenticated: Bool,
                               firstImportCompleted: Bool, isImporting: Bool, lastImportActivityAt: Date?,
                               droppedAt: Date, now: Date) -> NoticeDecision {
        guard !iCloudUnavailable(iCloudAccountPresent: iCloudAccountPresent,
                                 mirrorReportedNotAuthenticated: mirrorReportedNotAuthenticated) else {
            return .present(.iCloudUnavailable)
        }
        if isImporting { return .waitForImport }
        if !firstImportCompleted {
            let sinceDrop = now.timeIntervalSince(droppedAt)
            if sinceDrop >= 0 && sinceDrop < firstImportCeilingSeconds { return .waitForImport }
        }
        if let last = lastImportActivityAt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed >= 0 && elapsed < importQuietSeconds { return .waitForImport }
        }
        return .present(.dataRemoved)
    }

    /// **«iCloud no está disponible»**, la misma pregunta para la gracia y para el arranque en frío: sin cuenta de iCloud
    /// (`hasICloudAccount`: ni token de Drive ni CloudKit `.available`) o con CloudKit diciendo `notAuthenticated`. Un solo predicado, o el
    /// arranque pediría un aviso que el drenaje no enseñaría.
    static func iCloudUnavailable(iCloudAccountPresent: Bool, mirrorReportedNotAuthenticated: Bool) -> Bool {
        !iCloudAccountPresent || mirrorReportedNotAuthenticated
    }

    // MARK: - El arranque en frío (card `tablero-con-icloud-drive-apagado-antes-de-abrir-n5zw`)

    /// **Si el ARRANQUE pide el aviso de «iCloud no está disponible».** Medido en el iPhone de QA el 19-oct, con `Yala Dev`:
    /// con Yala CERRADA al apagar iCloud Drive, la copia local llegaba vacía antes de que la app midiera nada (no era
    /// iOS: era el contenedor equivocado de `.automatic`, ver `noticeDecision`; desde el 2026-10-24 ya no cae nada y esto
    /// queda para el teléfono sin cuenta de iCloud). `hasPersonalData` nace en
    /// `false` y la primera medida también da `false`, así que no hay caída, la gracia no arranca y la app se quedaba
    /// vacía y muda, también al relanzar. El arranque lo pide por su cuenta con las mismas condiciones que hacen verdad
    /// el aviso: store personal vacío, onboarding hecho, una sesión de las que guardan sus datos en el iCloud del Apple ID
    /// del teléfono (el eje de la gracia) e iCloud no disponible.
    ///
    /// Con iCloud disponible no pide nada: el store vacío puede ser la importación que trae los datos, y el arranque no
    /// vio caer nada que justifique «tus datos fueron eliminados».
    static func coldStartRequestsICloudNotice(hasPersonalData: Bool, hasCompletedOnboarding: Bool,
                                              sessionObeysWipeSignal: Bool, iCloudAccountPresent: Bool,
                                              mirrorReportedNotAuthenticated: Bool) -> Bool {
        !hasPersonalData && hasCompletedOnboarding && sessionObeysWipeSignal
            && iCloudUnavailable(iCloudAccountPresent: iCloudAccountPresent,
                                 mirrorReportedNotAuthenticated: mirrorReportedNotAuthenticated)
    }

    /// **Una petición del arranque, al drenarse, solo enseña «iCloud no está disponible».** Si mientras esperaba turno
    /// iCloud volvió, la decisión de la gracia esperaría a la importación y podría acabar en el aviso de borrado; aquí no
    /// hubo caída, así que esa petición se retira sin aviso y los datos vuelven solos.
    static func coldStartDrainPresents(_ decision: NoticeDecision) -> Bool {
        decision == .present(.iCloudUnavailable)
    }

    /// **El arranque cede a la gracia cuando la caída es suya** (review del 19-oct). Si en este montaje ya se midieron
    /// filas antes de re-medir, la medida que da «vacío» es una CAÍDA y la gracia la va a pedir; si la gracia ya está
    /// armada o hay un aviso pendiente, también. Pedir los dos sacaba el mismo aviso dos veces: el segundo intent se
    /// quedaba retenido detrás del primero y salía al contestar «Entendido».
    static func coldStartDefersToTheGrace(sawRowsBeforeRemeasuring: Bool, graceArmed: Bool,
                                          noticePending: Bool) -> Bool {
        sawRowsBeforeRemeasuring || graceArmed || noticePending
    }
}

/// **El estado del arranque en frío es del PROCESO, no de un `ContentView`** (review del 19-oct). Con varias ventanas
/// —o un swap de contenedor— la líder se remonta: un `@State` moría con ella y el `ContentView` nuevo (a) volvía a pedir
/// el aviso ya contestado y (b) drenaba la petición en cola como si fuera de la gracia, que con iCloud de vuelta podía
/// acabar en «Tus datos fueron eliminados». Solo lo tocan `ContentView` y sus tests de cableado.
@MainActor
enum ColdStartICloudNotice {
    /// La petición del aviso que espera en cola la hizo el arranque: el drenaje solo enseñará «iCloud no está disponible».
    static var requestPending = false
    /// El arranque ya decidió en este proceso, pidiera o no. Las caídas posteriores son de la gracia.
    static var checkedThisProcess = false
}
