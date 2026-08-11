//
//  GroupsDomainAdoptionMarker.swift
//  Yala
//
//  Escritor de la ADOPCIÓN del dominio Grupos: el acto deliberado con el que el dueño de ESTE
//  dispositivo declara que los grupos son suyos. Lo lee `GroupsDomainAdoptionLogic.isDomainOpen`
//  (vía `GroupTransactionBridge.isDomainOpenForBridge`), y solo importa en un dispositivo SELLADO
//  por «empiezo de cero».
//
//  **Por qué existe.** Hasta 2.1 el acto de adopción era teclear el código beta «1050», y quien lo
//  escribía era la pantalla del gate. Al retirar el gate (Grupos abierto para todos) ese escritor
//  desaparecía y en un dispositivo sellado cuyo dueño NUEVO abriera Grupos por el tab **ya nadie
//  escribía la key**: el bridge quedaba cerrado para él en SILENCIO, con el síntoma «mis gastos de
//  grupo no aparecen» — literalmente el falso negativo que el sello se diseñó para evitar (ver el
//  doc-comment de `isBridgeAllowed`). El acto de adopción pasa a ser ENTRAR AL TAB, que es lo que
//  el código beta materializaba antes.
//
//  Molde y ubicación: hermano de `GroupsSignOutBannerMarker` — `defaults` inyectable para que los
//  tests no toquen `UserDefaults.standard` (escribir estas keys en el dominio real desde un test
//  cierra el bridge para las suites que se interleavan).
//

import Foundation

@MainActor
enum GroupsDomainAdoptionMarker {

    /// Registra la adopción del dominio al entrar a Grupos. Idempotente.
    ///
    /// **Guard 1 (M1) · la adopción es del DUEÑO del dispositivo, y la invitada no es él.** La key
    /// vive en el `UserDefaults.standard` COMPARTIDO —el wipe de salida de la secundaria solo repone
    /// tres flags de onboarding (`SwiftDataConfiguration.performSecondaryWipeIfArmed`) y ésta no es
    /// una de ellas—, así que sin este guard la invitada que abriera el tab Grupos dejaría
    /// `groupsBetaUnlocked = true` escrito para siempre. En el M1 típico es inocuo (el dueño no está
    /// sellado); en un dispositivo SELLADO por «empiezo de cero» **neutraliza el sello del siguiente
    /// humano** sin que nadie lo note, que es justo lo que el sello existe para impedir. Con el canal
    /// de Grupos encendido el tab es VISIBLE en secundaria (`TabBarConfiguration`, filtro condicional
    /// a `!groupsBackendEnabled`) ⇒ el camino existe hoy, no es hipotético.
    ///
    /// **Guard 2 · NO es una optimización: es lo que mantiene el seam de XCUITest sin persistir.**
    /// Bajo `-uitest`, `UITestEphemeralDefaults.applyGroupsBetaUnlocked` purga la key del disco y
    /// la aplica en el dominio de REGISTRO (volátil, muere con el proceso); `bool(forKey:)` la ve
    /// ⇒ este guard corta y no se escribe nada persistente. Un `set(true, …)` incondicional
    /// convertiría el valor volátil en permanente y dejaría Grupos adoptado para siempre en ese
    /// simulador, que es exactamente el bug que el seam cerró.
    ///
    /// El descriptor se consulta sobre el store INYECTADO (`isActive(defaults)`), no sobre
    /// `.standard`: un test que plantara el descriptor en su almacén aislado tiene que verlo, y uno
    /// que no lo plante no puede heredar el del simulador.
    static func recordEntry(_ defaults: UserDefaults = .standard) {
        guard !SecondarySessionStore.isActive(defaults) else { return }
        guard !defaults.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked) else { return }
        defaults.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
    }
}
