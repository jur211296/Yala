//
//  GroupsSessionHistoryMarker.swift
//  Yala
//
//  C2 · **el latch de «este dispositivo tuvo sesión de Grupos alguna vez»**, y la única señal con la que el
//  empty state puede distinguir «vuelve a tu cuenta» de «crea una cuenta».
//
//  ## Por qué NO es `GroupsSignOutBannerMarker`, que es lo que el spec proponía
//
//  El §4 del spec sugería reusarlo y pedía **medirlo antes de dar el atajo por bueno**. Medido, y no
//  sirve: aquel es un one-shot de BANNER —se arma solo en `CloudSessionSignOut.finalizeGroupsOnlyClose`, se
//  QUEMA en el `onAppear` del banner real y se DESARMA al re-firmar—, así que en cuanto el banner se
//  muestra una vez vuelve a `false` y quien SÍ tuvo cuenta leería «crea una cuenta». Y tampoco cubre el
//  cierre de sesión de nube completo, que no pasa por ese camino.
//
//  ## Monotónico a propósito: solo se ARMA
//
//  No hay `clear()`. Un latch que se pudiera apagar volvería a mentirle a quien ya tuvo cuenta, que es
//  exactamente el fallo que existe para cerrar. Y no hace falta: lo que afirma —«esta persona ya vio una
//  sesión de Grupos en este device»— no deja de ser cierto por cerrar sesión.
//
//  **La frontera de USUARIO sí lo retira, y el NAMESPACE es lo que lo decide.** Un «empiezo de cero» del
//  Welcome entrega el device a otro humano, y para él la afirmación es falsa: leería «vuelve a tu cuenta»
//  sin haber tenido ninguna. Por eso la key **NO va en `cloudSync.*`**, aunque su hermano
//  `GroupsSignOutBannerMarker` sí esté ahí: ese prefijo está **excluido a propósito** del wipe
//  (`DataWipeService.swift:462-465`, «infra del propio sign-out/wipe … JAMÁS aquí»), y meterla ahí la
//  habría hecho sobrevivir al relevo en silencio. Va en `groups.*` y la nombra
//  `removeGroupsDomainPreferenceKeys`, junto al resto del dominio.
//
//  No viaja a la nube por la razón de siempre: es un hecho del DISPOSITIVO, no de la cuenta (regla de
//  `swiftdata-cloudkit.md` §Preferencias — si el hecho es de la cuenta no va por prefs, y si es del device
//  no se sincroniza).
//
//  ## Los dos armadores, y por qué el segundo no es un cinturón
//
//  1. **El sign-in de Grupos** (`GroupsBackendInviteModifier`, closure de éxito de `GroupsSignInView`),
//     que es donde nace la sesión por las cuatro puertas.
//  2. **El `onAppear` del tab con sesión viva** (`GroupsContainerView`). No es redundancia defensiva: es lo
//     ÚNICO que cubre al parque que YA tenía sesión antes de esta versión —para quien no existe ningún
//     evento de sign-in futuro— y a quien firmó por el camino de nube completo, que no pasa por (1). Sin
//     él, todo usuario con sesión anterior a C2 que cerrara sesión leería «crea una cuenta».
//

import Foundation

nonisolated enum GroupsSessionHistoryMarker {

    /// Namespace `groups.*` y NO `cloudSync.*` — ver el encabezado: aquel está excluido del wipe a
    /// propósito y el latch tiene que morir con el handover.
    static let key = "groups.hadSessionEver"

    /// Arma el latch. Idempotente y sin vuelta atrás — ver el encabezado.
    static func markSessionSeen(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
    }

    /// `true` si este dispositivo llegó a tener sesión de Grupos alguna vez.
    static func hadSessionEver(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }
}
