//
//  AdoptOverCloudGuardLogic.swift
//  Yala
//
//  **Un teléfono que sigue en modo nube no se adopta, y «Empezar de cero» no lo deja así** (ticket
//  `adopt-over-a-device-already-in-cloud-mode-has-no-exit`, opción A de Jürgen, 13-nov-2026).
//
//  ## El hueco
//
//  «Empezar de cero» del Welcome retira la sesión en la nube y olvida los sellos del claim
//  (`CloudSessionRetirement.arm`), pero no devolvía el modo a iCloud: solo lo hace el borrado de «Cerrar sesión»
//  (`SwiftDataConfiguration.performSignOutWipeIfArmed`). Quedaba `.cloud` + `mirrorOffArmed` sin sesión. Volver a entrar
//  con la cuenta daba `existing_stable`, el Welcome arrancaba el adopt y, con el modo ya en `.cloud`, ese adopt quedaba
//  pendiente para siempre: `AdoptEffectScope.isPending` y `observeAdoptEffectFailure` excluyen `.cloud`, así que no había
//  «Cancelar» ni techo. Medido en el iPhone de Jürgen el 27-oct.
//
//  ## Las dos mitades
//
//  1. **El origen.** Un «Empezar de cero» del Welcome con el modo persistido en `.cloud` deja el teléfono como recién
//     instalado por el MISMO camino que «Cerrar sesión»: arma el borrado del arranque y lo consuma en caliente si el
//     montaje lo admite (`CloudSessionSignOut.armReturnToFreshInstallAfterWelcomeFreshStart`). Se borran los ARCHIVOS, no
//     solo las filas, y eso no es opcional: con el modo en `.icloud` sobre el archivo de la época nube, el espejo
//     reproduciría su History hacia iCloud (qa/cloud/README, hallazgo 3). El borrado ya lo pidió la persona, y este es
//     local: no toca la cuenta de la nube.
//  2. **El cinturón.** La entrada a una cuenta no adopta sobre un teléfono que ya está en `.cloud`. Con el sello de esa
//     misma cuenta (el claim de `CloudClaimActionStore` para el `userID` que acaba de firmar) sigue como hoy: es su corpus y
//     el adopt solo lo confirma. Sin el sello no hay prueba de quién es lo que hay en el teléfono: se para con la pantalla
//     del bloqueo cross-cuenta, que tiene salida al elector, y desde ahí «Empezar de cero» ya devuelve el teléfono a
//     recién instalado. Con canario (`adoptOverCloudRefused`) para ver si alguien sigue cayendo.
//

import Foundation

nonisolated enum AdoptOverCloudGuardLogic {

    /// **Mitad 1.** ¿Un «Empezar de cero» del Welcome tiene que devolver el teléfono a recién instalado en vez de abrir el
    /// onboarding? Sí con el modo persistido en `.cloud`: abrirlo ahí era hacer el onboarding privado sobre el store de la
    /// nube, sin sesión, y dejar armado el adopt sin salida.
    static func freshStartReturnsToFreshInstall(persistedMode: StorageMode) -> Bool {
        persistedMode == .cloud
    }

    /// **Mitad 2.** ¿La entrada a una cuenta desde el Welcome se para en vez de adoptar?
    ///
    /// - Parameters:
    ///   - persistedMode: `StorageModePersistence.read()`, leído en el momento de decidir.
    ///   - sameAccountClaimExists: hay sello de claim para el `userID` que acaba de firmar. **Sin valor por defecto**, como
    ///     los términos de `CrossAccountEntryGuardLogic`: un default `true` dejaría adoptar sobre la nube en un call-site
    ///     nuevo.
    static func refusesAdopt(persistedMode: StorageMode, sameAccountClaimExists: Bool) -> Bool {
        persistedMode == .cloud && !sameAccountClaimExists
    }
}
