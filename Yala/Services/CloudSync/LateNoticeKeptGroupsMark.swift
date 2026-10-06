//
//  LateNoticeKeptGroupsMark.swift
//  Yala
//
//  **«Los grupos de este teléfono los acaba de conservar el aviso tardío para la persona que está haciendo el
//  onboarding».** Ticket `groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`.
//
//  POR QUÉ EXISTE. El aviso del espejo tardío («Encontramos datos tuyos en iCloud» → «Empezar de cero») borra lo personal
//  y CONSERVA los grupos (`ICloudWipeScope.lateNotice`), y devuelve a la persona al onboarding. Si ahí toca «Cancelar»,
//  vuelve al Welcome, y el Welcome no sabía nada de eso: contaba esos grupos como datos de OTRA persona y, al elegir «Es
//  mi primera vez → privado», le ofrecía el borrado del handover —que purga los grupos, retira la sesión de Grupos y
//  sella el dominio—. Decisión de Jürgen del 2026-10-04 (opción A): el aviso no prueba que sea otra gente, así que quien
//  acaba de conservar sus grupos no los pierde por cancelar el onboarding. Esta marca es el hecho que el Welcome lee.
//
//  DE QUIÉN ES. Se ata al `sub` de la sesión de Grupos que había al conservarlos, o a «sin sesión» si no había ninguna
//  (`noSession`). **Deja de valer cuando hay OTRA cuenta abierta**: con la misma sesión, o sin ninguna, sigue valiendo.
//  Que la sesión se vaya no prueba que haya otra persona —el guard cross-cuenta del Welcome cierra la sesión que la
//  propia persona acaba de abrir, y una sesión caducada también se va—, y perder la marca ahí devolvía justo el borrado
//  del handover que la marca existe para evitar (review adversarial del ticket). Una cuenta DISTINTA sí cambia la
//  respuesta. Equivocarse hacia «no vale» no es gratis: el Welcome vuelve a ofrecer el handover, que sella el dominio en
//  este teléfono; lo que lo frena es que la persona lo confirma.
//
//  CUÁNTO VIVE. Lo que tarda la persona en terminar el onboarding, y no más:
//    · NACE en `ContentView.performLateICloudWipe`, en la rama que conserva los grupos, ANTES de que el llamador desarme
//      el borrado: un kill entre medias reanuda el borrado y la vuelve a escribir.
//    · MUERE al completarse el onboarding (`ContentView`, en la transición; y el barrido del arranque,
//      `retireIfOnboardingCompleted`, para la que un kill dejó atrás), dentro de `DataWipeService.wipeLocalGroupsDomain`
//      (los grupos que describía ya no están) y en el borrado del cierre de sesión
//      (`SwiftDataConfiguration.performSignOutWipeIfArmed`).
//
//  DÓNDE VIVE. `UserDefaults` local, con el prefijo `cloudSync.` que el barrido de preferencias excluye: su vida la
//  deciden las retiradas de arriba, no un barrido que no sabe de ella. Nunca al iCloud-KV: es un hecho de este teléfono.
//

import Foundation

/// La marca de los grupos que el aviso tardío conservó. `nonisolated` porque la limpia también el boot-wipe pre-mount,
/// que corre fuera del main actor.
nonisolated enum LateNoticeKeptGroupsMark {

    static let key = "cloudSync.lateNoticeKeptGroupsSessionSub"

    /// Lo que se apunta cuando no había sesión de Grupos al conservar los grupos. No es un `sub` posible: los `sub` son
    /// UUID en minúsculas (`CloudAuthService.currentUserID`).
    static let noSession = "-"

    /// El `sub` de la sesión de Grupos de este proceso, o `nil` sin sesión. Inyectable para los tests.
    @MainActor static var currentSessionSubProvider: @MainActor () -> String? = { CloudAuthService.shared.currentUserID }

    /// Apunta que el aviso tardío acaba de conservar los grupos para la persona de la sesión `sessionSub`.
    static func record(sessionSub: String?, _ defaults: UserDefaults = .standard) {
        defaults.set(sessionSub ?? noSession, forKey: key)
    }

    /// La escritura de producción: la sesión viva de este proceso.
    @MainActor static func recordNow(_ defaults: UserDefaults = .standard) {
        record(sessionSub: currentSessionSubProvider(), defaults)
    }

    /// ¿Vale la marca con la sesión `currentSessionSub` delante? Ausente ⇒ `false`: sin marca, el Welcome hace lo de
    /// siempre. Sin sesión ⇒ vale. Con sesión ⇒ solo si es la que había al conservar los grupos.
    static func vouches(forCurrentSessionSub currentSessionSub: String?, _ defaults: UserDefaults = .standard) -> Bool {
        guard let recorded = defaults.string(forKey: key) else { return false }
        guard let currentSessionSub else { return true }
        return recorded == currentSessionSub
    }

    /// La lectura de producción: la sesión viva de este proceso.
    @MainActor static func vouchesNow(_ defaults: UserDefaults = .standard) -> Bool {
        vouches(forCurrentSessionSub: currentSessionSubProvider(), defaults)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// El barrido del arranque: con el onboarding completo, la marca ya no describe a nadie. Cubre la que un kill dejó
    /// entre escribirla y bajar el onboarding, o entre completarlo y la transición que la retira.
    static func retireIfOnboardingCompleted(_ defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) else { return }
        clear(defaults)
    }
}
