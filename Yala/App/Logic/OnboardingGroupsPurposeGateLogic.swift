//
//  OnboardingGroupsPurposeGateLogic.swift
//  Yala
//
//  Pure decision logic del muro iCloud del SELECTOR DE PROPÓSITO del onboarding: decide si
//  elegir «Dividir gastos con amigos» (`onboarding_purpose_groups`) queda BLOQUEADA con el
//  aviso `L10n.Groups.Errors.iCloudRequired*` en vez de seleccionar `.groupsOnly`.
//
//  Es el GEMELO del gate del tab (`GroupsICloudAvailabilityGateLogic`, arreglado en `965a4d86`),
//  y la diferencia importa: aquel nunca llegó a bloquear a nadie —el flag ya cortocircuitaba su
//  call-site desde `7b5ff216`— y muere con el commit 1 de la Fase 3. Éste bloqueaba HOY, en
//  producción, sin cortocircuito de ningún tipo, y `OnboardingView.swift` NO está entre los 14
//  ficheros que ese commit borra ⇒ esta lógica se queda.
//
//  El bloqueo cerraba la ÚNICA ruta del onboarding a `.groupsOnly` (`OnboardingView:512`; las
//  otras escrituras de ese valor son `GroupsRetentionView:64`, ya post-onboarding). Un usuario
//  born-cloud sin cuenta iCloud del OS se quedaba sin salida salvo entrar por invitación
//  (`onboardingMode == .groupInvite`, que es otro flujo y no pasa por el selector).
//
//  DESDE A6 DE D-A7 el fichero decide DOS cosas sobre la misma card, y son distintas: si se
//  PINTA (`shouldShowGroupsCard`) y si tocarla queda BLOQUEADA (`shouldBlockSelection`). Viven
//  juntas a propósito — quien mañana toque una tiene la otra delante, que es exactamente el
//  olvido que se paga caro aquí.
//

import Foundation

nonisolated enum OnboardingGroupsPurposeGateLogic {

    /// Decide si BLOQUEAR la elección de «Dividir gastos con amigos» con el aviso de iCloud.
    ///
    /// - Parameters:
    ///   - isAccountAvailable: `iCloudSyncService.shared.isAccountAvailable` (token de ubiquity
    ///     en vivo). Aquí NO hay el gotcha de reactividad del gate del tab: el call-site lo lee
    ///     dentro del closure de acción de la card, que corre al TAP — no dentro de un `body`
    ///     que haya que re-evaluar. No hace falta leer `status` para registrar dependencia.
    ///   - isBackendChannelEnabled: `CloudSyncFlags.groupsBackendEnabled`. Con el canal ON el
    ///     muro se RETIRA ENTERO: Grupos dejó de vivir en CloudKit, así que la cuenta iCloud del
    ///     OS ya no es requisito y el copy del aviso —«Los grupos se sincronizan por iCloud»—
    ///     además MIENTE. Con el canal OFF (kill remoto, o producción antes del primer fetch de
    ///     `/config`) el muro sigue siendo la verdad y se conserva intacto.
    ///
    /// SIN parámetro `isUITest`, a propósito y a diferencia del gemelo. Allí la exención existe
    /// para RETIRAR el gate en los XCUITest; aquí lo tendría que CONSERVAR, y eso sería un seam
    /// que fuerza el predicado — justo lo que `.claude/rules/testing.md` prohíbe («deja CIEGOS a
    /// todos los tests que lo usan: cubren el flujo, no la decisión»). No hace falta: bajo
    /// `-uitest` el canal está SIEMPRE ON (`CloudRemoteConfig.decide` corta en `isUITestHost`
    /// devolviendo `absentDefault`, que bajo `DEV_BUILD` es `true`), así que ningún XCUITest
    /// puede alcanzar la rama del muro.
    ///
    /// La decisión vive AQUÍ y no en el `if` del call-site por la lección de `965a4d86`: aquel
    /// vivía dentro de un `@ViewBuilder` donde ningún unitario llegaba, y borrarlo dejaba la
    /// suite entera en VERDE. El `if` de `OnboardingView` es el mismo caso —dentro del `body`—,
    /// así que el predicado sube a lógica pura (tabla en tests) y el cableado lo pinnea un
    /// source-scan.
    static func shouldBlockSelection(isAccountAvailable: Bool,
                                     isBackendChannelEnabled: Bool) -> Bool {
        guard !isBackendChannelEnabled else { return false }
        return !isAccountAvailable
    }

    /// Decide si la card «Dividir gastos con amigos» (`onboarding_purpose_groups`) se PINTA.
    ///
    /// Es otra decisión que el muro de arriba, y el orden importa: primero se decide si la card
    /// existe, y solo si existe puede su tap toparse con el muro. En modo nube la card **no se
    /// pinta**, así que el muro nunca llega a evaluarse por ese camino.
    ///
    /// - Parameters:
    ///   - isInitialFlow: `mode == .initial` en `OnboardingView`. Término PREEXISTENTE, que vivía
    ///     dentro del `body`: la reutilización del flujo por `FullModeActivation` no debe poder
    ///     devolver a «solo grupos» a un `groupInvite` que acaba de activar Yala completo. Sube
    ///     aquí con A6 en vez de quedarse como un `&&` en el `if`, porque un predicado partido
    ///     entre el `body` y la lógica pura deja la mitad de la decisión sin un solo test que la
    ///     alcance — la lección de `965a4d86`, otra vez.
    ///   - storageMode: `CloudSyncFlags.storageMode`, el modo EFECTIVO (no
    ///     `StorageModePersistence.read()`): en una sesión secundaria M1 el store montado es el
    ///     secundario y lo sincroniza el motor, así que el argumento de abajo aplica igual aunque
    ///     la key persistida del dueño siga en `.icloud`.
    ///
    /// **Por qué desaparece en `.cloud`** (decisión de diseño ya tomada — cierre A4 de
    /// [[MODO-NUBE-ARQUITECTURA]] §k.7, DIFERIDOS #17): «elegí la nube para mis datos personales»
    /// + «solo quiero Grupos» es contradictorio. El modo solo-grupos NO usa el store personal, así
    /// que dejaría VACÍO el backend que el usuario acaba de estrenar. Un usuario `.cloud` que
    /// quiera Grupos entra por el tab normal, cuyo gate ya consulta el canal (C3, `965a4d86`).
    /// Se OCULTA y no se deshabilita con copy: un botón que solo sirve para explicar por qué no
    /// sirve es peor que su ausencia.
    ///
    /// **La invariante que esto NO toca, y que no puede tocar:** `OnboardingUsageMode` sigue
    /// teniendo CUATRO casos y `OnboardingPurposeSelectionLogic.selectedCard(for:)` sigue siendo
    /// TOTAL y ÚNICA. Ocultar la card no puede dejar cero marcadas porque el tap de esa card es
    /// la ÚNICA ruta del onboarding a `.groupsOnly` (el default es `.fullControl` y la migración
    /// legacy del `.task` solo produce `.expensesOnly`/`.fullControl`/`.dayToDay`) ⇒ en `.cloud`
    /// ese modo es inalcanzable desde aquí, no un estado huérfano.
    ///
    /// En `.icloud` —el 99 % del parque— el resultado es el término de siempre, palabra por
    /// palabra: el flujo queda byte-idéntico.
    static func shouldShowGroupsCard(isInitialFlow: Bool, storageMode: StorageMode) -> Bool {
        guard isInitialFlow else { return false }
        switch storageMode {
        case .icloud: return true
        case .cloud:  return false
        }
    }
}
