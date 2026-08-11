//
//  WelcomeMirrorRelaunchLogic.swift
//  Yala
//
//  R2 del relanzamiento cero · la OTRA mitad del mount neutro.
//
//  El chip mueve el relanzamiento de sitio, no lo elimina. La regla madre de la Opción C (decisión del
//  owner, 2026-08-10) es:
//
//      El relanzamiento sobrevive si y solo si hay que ENCENDER el mirror de CloudKit.
//
//  Con el primer arranque montando el store personal NEUTRO (`cloudKitDatabase: .none` explícito), elegir
//  la nube deja de necesitarlo —el store montado ya ES el que el par `.cloud` + `mirrorOffArmed` pide— y en
//  cambio los caminos que viven DEL mirror (el onboarding privado y el restore de iCloud) sí lo necesitan:
//  `personalConfiguration` se evalúa UNA vez por proceso, así que adjuntar `NSPersistentCloudKitContainer`
//  a un store ya montado no es posible sin un proceso nuevo.
//
//  QUÉ NO ES ESTE FICHERO: no es un remount in-process (eso es la Opción B, cuyo bloqueante está MEDIDO y
//  documentado en el spec §1.9/§1.10 — dos containers vivos sobre el mismo archivo no lanzan, coexisten, y
//  el modo de fallo es una app que se ve VACÍA). Aquí solo se decide si hay que pedirle al usuario que
//  reabra, y se recuerda a dónde iba.
//

import Foundation

// MARK: - La decisión

/// ¿Hay que interponer un relanzamiento entre la elección del Welcome y su destino?
nonisolated enum WelcomeMirrorRelaunchLogic {

    /// A dónde va el usuario tras el Welcome. Es el conjunto EXACTO de salidas del chooser (más la del
    /// alert «Detectamos tu cuenta», que comparte destino con restaurar), no una taxonomía general: cada
    /// caso existe porque hay un callback que lo produce.
    ///
    /// `String` + `CaseIterable`: el rawValue es lo que viaja en `UserDefaults` para sobrevivir al propio
    /// relanzamiento, y `allCases` es lo que obliga a que una salida nueva del Welcome declare de qué lado
    /// cae — el mismo mecanismo con el que R1 dejó las tablas del testigo de mount.
    enum Destination: String, CaseIterable, Equatable {
        /// «Soy nuevo» → privacidad total. **Es el bypass de producción**: con el percent remoto de la
        /// elección nube en 0, el sub-chooser no se muestra y todo usuario nuevo llega aquí.
        case privateOnboarding
        /// «Ya tengo una cuenta» → restaurar de iCloud, y también «Cargar mis datos» del alert del Hero.
        case restoreICloud
        /// Recuperar una invitación de grupo desde el Welcome.
        case inviteRecovery
        /// «Soy nuevo» → cuenta en la nube (alta born-cloud).
        case cloudAccount
        /// «Ya tengo una cuenta» → iniciar sesión en la cuenta nube (re-entrada/adopt), en cualquiera de
        /// sus dos proveedores y también cuando encamina el faro.
        case cloudSignIn
        /// G3 · «Vengo por un grupo» → «Crear mi primer grupo»: el alta del ORGANIZADOR (sign-in de
        /// grupos → consent → nombre → formulario). Solo se alcanza con la puerta ya confirmada abierta.
        case groupsOrganizer
    }

    /// ¿Este destino necesita que el mirror de CloudKit esté ADJUNTO al store personal?
    ///
    /// Las dos filas `false` son las del Modo Nube, y no lo necesitan por la misma razón: su store es
    /// `cloudKitDatabase: .none`, que es exactamente lo que el mount neutro ya montó.
    ///
    ///  · `restoreICloud` es el caso que NO admite matices: `RestoreProgressView` cuenta filas del
    ///    `modelContext` esperando la quiescencia del import de CloudKit (spec §1.5). Sin mirror no hay
    ///    import, así que la pantalla agotaría su timeout de 90 s y le diría al usuario que su cuenta está
    ///    vacía — que es peor que pedirle que reabra.
    ///  · `privateOnboarding` lo necesita para que lo que el usuario cree en su primera sesión se espeje.
    ///    Que un mirror adjuntado en un arranque POSTERIOR exporte lo escrito en la ventana neutra es
    ///    plausible pero **NO está medido** (spec §8), y el primer corpus de un usuario no es el sitio para
    ///    apostar a un inferido.
    ///  · `inviteRecovery` no necesita el mirror para su propio trabajo —el CKShare va por el container de
    ///    Grupos— pero su destino es usar la app con datos personales, así que cae del mismo lado que el
    ///    onboarding privado. Sesgo deliberado: pedir un relanzamiento de más cuesta una pantalla; de menos,
    ///    una sesión entera sin espejo.
    ///  · `groupsOrganizer` (G3) cae con las del Modo Nube y **no con `inviteRecovery`**, aunque las dos
    ///    hablen de grupos: aquella recupera un CKShare y desemboca en usar la app con datos personales;
    ///    esta va por el BACKEND (store de Grupos con `cloudKitDatabase: .none`) y su alta es solo-grupos,
    ///    que por definición no crea corpus personal que espejar. Pedirle un relanzamiento sería cobrarle
    ///    una pantalla por un mirror que su camino no usa.
    static func requiresMirror(_ destination: Destination) -> Bool {
        switch destination {
        case .privateOnboarding, .restoreICloud, .inviteRecovery:
            return true
        case .cloudAccount, .cloudSignIn, .groupsOrganizer:
            return false
        }
    }

    /// El predicado completo. Dos términos, y el segundo es DELIBERADAMENTE estrecho.
    ///
    /// **Se compara contra `.neutralNoMirror` y NO contra `!attachesCloudKitMirror`**, aunque el eje diga lo
    /// mismo para este caso: los otros dos mounts sin mirror (`cloudMirrorOff`, `secondaryCloudSession`) son
    /// devices que YA están en modo nube, donde este Welcome no se presenta y donde ofrecer un
    /// «reabre la app para encender iCloud» sería sencillamente falso. El mount neutro es el único que abre
    /// esta ventana, y es el único que la cierra.
    static func shouldRelaunch(
        destination: Destination,
        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision
    ) -> Bool {
        requiresMirror(destination) && mountedDecision == .neutralNoMirror
    }
}

// MARK: - La intención, que tiene que sobrevivir al relanzamiento

/// Dónde se guarda el destino elegido mientras el usuario cierra y reabre la app.
///
/// **Por qué es DURABLE y no `@State`:** el relanzamiento mata el proceso por definición. Sin esto, el
/// usuario que tapea «Restaurar de iCloud», reabre la app y aterriza en el onboarding normal —porque
/// `hasShownWelcomeChooser` ya quedó `true`— con su elección perdida y sin forma obvia de repetirla.
///
/// **Sin TTL, y con consumo one-shot.** Caducarlo no tiene semántica útil (el destino sigue siendo el que
/// el usuario pidió aunque tarde un día en reabrir) y dejarlo puesto sí la tiene mala: se retira en el
/// mismo momento en que se lee, así que un segundo arranque no vuelve a encaminar a ningún sitio.
nonisolated enum WelcomePendingDestinationStore {

    static let key = "welcome.pendingMirrorRelaunchDestination"

    static func set(_ destination: WelcomeMirrorRelaunchLogic.Destination,
                    defaults: UserDefaults = .standard) {
        defaults.set(destination.rawValue, forKey: key)
    }

    /// Lee SIN consumir (para los tests y para cualquier lector que no encamine).
    static func peek(_ defaults: UserDefaults = .standard) -> WelcomeMirrorRelaunchLogic.Destination? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return WelcomeMirrorRelaunchLogic.Destination(rawValue: raw)
    }

    /// Lee y RETIRA. Es lo que usa el encaminamiento del arranque: un destino consumido no puede volver a
    /// secuestrar la pantalla inicial. Retira la key también cuando el rawValue es basura (build anterior,
    /// caso renombrado) — si no, quedaría un residuo que nadie puede consumir.
    static func consume(_ defaults: UserDefaults = .standard) -> WelcomeMirrorRelaunchLogic.Destination? {
        let pending = peek(defaults)
        defaults.removeObject(forKey: key)
        return pending
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
