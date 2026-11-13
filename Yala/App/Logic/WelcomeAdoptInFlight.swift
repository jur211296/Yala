//
//  WelcomeAdoptInFlight.swift
//  Yala
//
//  Card gd78 (13-nov, medido en el iPhone 14): cerrar Yala en pleno «Conectando con tu cuenta» dejaba el teléfono a medias.
//  `onAdoptStarted` marca el onboarding y retira el montaje neutro ANTES de conducir el traspaso, para que un cierre a mitad
//  nunca siembre el onboarding encima de una cuenta que ya existe. Pero con eso el arranque siguiente montaba el espejo de
//  iCloud: importaba el iCloud privado del aparato, exportaba a iCloud lo que hubiera en el almacén y retomaba el traspaso
//  encima de esa mezcla, con «Cancelar la activación» apagado y el cierre de sesión bloqueado.
//
//  Esta marca dice «hay una entrada a una cuenta desde la bienvenida en curso, y el par nube + espejo apagado todavía no
//  está escrito». Mientras dure:
//   - el arranque monta NEUTRO, sin espejo (`holdsNeutralMount`, leído por `SwiftDataConfiguration`): el mismo montaje
//     con el que el traspaso empezó, así que se retoma igual que si no se hubiera cerrado;
//   - el arranque vuelve a la pantalla «Conectando con tu cuenta» (`ContentView`), que retoma el traspaso y ofrece
//     «Cancelar la activación». Si consta que el traspaso no dejó nada (`WelcomeAdoptBackOut.leftNoTrace`), se deshace lo
//     que `onAdoptStarted` marcó y se vuelve a la bienvenida.
//  Lleva la foto de lo que `onAdoptStarted` cambió (`WelcomeAdoptBackOut.Snapshot`): sin ella, un «Cancelar» tras reabrir
//  no podía devolver la bienvenida, porque la foto vivía en un `@State` que el cierre se llevó.
//
//  Se retira cuando el par se escribe (el traspaso aterrizó: `settle`, que corre antes de cada montaje), cuando la persona
//  sale de la pantalla de conexión por cualquier camino, y en el borrado (`DataWipeService`).
//

import Foundation

nonisolated enum WelcomeAdoptInFlight {

    static let key = "welcome.adoptInFlight"
    static let hadCompletedOnboardingKey = "welcome.adoptInFlight.hadCompletedOnboarding"
    static let hadPrivateSessionKey = "welcome.adoptInFlight.hadPrivateSession"
    static let neutralMountArmedKey = "welcome.adoptInFlight.neutralMountArmed"
    static let freshInstallOwnsNeutralMountKey = "welcome.adoptInFlight.freshInstallOwnsNeutralMount"
    static let providerKey = "welcome.adoptInFlight.provider"

    /// Todas las keys de la marca, para el borrado.
    static let allKeys = [key, hadCompletedOnboardingKey, hadPrivateSessionKey, neutralMountArmedKey,
                          freshInstallOwnsNeutralMountKey, providerKey]

    /// La arma `onAdoptStarted` con la foto de ANTES del primer intento. Un «Reintentar» que vuelve a pasar por ahí no la
    /// pisa: la foto buena es la primera.
    static func arm(snapshot: WelcomeAdoptBackOut.Snapshot, provider: CloudSignInProvider?,
                    _ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(snapshot.hasCompletedOnboarding, forKey: hadCompletedOnboardingKey)
        defaults.set(snapshot.hasPrivateSession, forKey: hadPrivateSessionKey)
        defaults.set(snapshot.neutralMountArmed, forKey: neutralMountArmedKey)
        defaults.set(snapshot.freshInstallOwnsNeutralMount, forKey: freshInstallOwnsNeutralMountKey)
        if let provider {
            defaults.set(provider.rawValue, forKey: providerKey)
        } else {
            defaults.removeObject(forKey: providerKey)
        }
        defaults.set(true, forKey: key)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        for k in allKeys { defaults.removeObject(forKey: k) }
    }

    static func isArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    /// La foto que guardó `arm`. `nil` sin marca.
    static func snapshot(_ defaults: UserDefaults = .standard) -> WelcomeAdoptBackOut.Snapshot? {
        guard isArmed(defaults) else { return nil }
        return WelcomeAdoptBackOut.Snapshot(
            hasCompletedOnboarding: defaults.bool(forKey: hadCompletedOnboardingKey),
            hasPrivateSession: defaults.bool(forKey: hadPrivateSessionKey),
            neutralMountArmed: defaults.bool(forKey: neutralMountArmedKey),
            freshInstallOwnsNeutralMount: defaults.bool(forKey: freshInstallOwnsNeutralMountKey))
    }

    /// Con qué se firmó la entrada, para retomarla. `nil` si no se sabe: la pantalla retoma igual, con el de la sesión.
    static func provider(_ defaults: UserDefaults = .standard) -> CloudSignInProvider? {
        defaults.string(forKey: providerKey).flatMap(CloudSignInProvider.init(rawValue:))
    }

    /// **¿Monta neutro este arranque?** Solo con la marca puesta y el teléfono todavía en iCloud sin el apagado del espejo
    /// armado: en cuanto el traspaso escribe el par, la rama del par manda y esta queda inerte. Confinado igual que los
    /// otros neutros durables, y por lo mismo: `.cloud` sin armar es la ventana del cutover, donde el espejo tiene que
    /// montar para que el marcador exporte.
    static func holdsNeutralMount(armed: Bool, persistedMode: StorageMode, mirrorOffArmed: Bool) -> Bool {
        armed && persistedMode == .icloud && !mirrorOffArmed
    }

    static func holdsNeutralMount(_ defaults: UserDefaults = .standard) -> Bool {
        holdsNeutralMount(armed: isArmed(defaults),
                          persistedMode: StorageModePersistence.read(defaults),
                          mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults))
    }

    /// **El par escrito retira la marca.** El traspaso aterrizó: lo que queda (relanzar o no) lo decide la rama del par, y
    /// una marca superviviente decidiría el montaje el día de una «Volver a iCloud». Corre antes de cada montaje.
    static func settle(persistedMode: StorageMode, mirrorOffArmed: Bool, _ defaults: UserDefaults = .standard) {
        guard isArmed(defaults), persistedMode == .cloud, mirrorOffArmed else { return }
        clear(defaults)
    }

    /// Qué hace el arranque que encuentra la marca.
    enum RelaunchRoute: Equatable {
        /// Algo del traspaso sigue en el journal: se vuelve a «Conectando con tu cuenta», que lo retoma.
        case resume
        /// Consta que no dejó nada: se deshace lo que marcó `onAdoptStarted` y se vuelve a la bienvenida.
        case backOut
        /// Salió y no consta que no dejara nada, o el journal no se deja leer: se retira la marca y la app sigue como antes
        /// del arreglo (review adversarial).
        case release
    }

    /// Se deshace solo si el traspaso SALIÓ (su techo o un «Cancelar» que aterrizó: `failedRollback` o una marca de salida)
    /// y consta que no dejó nada (`WelcomeAdoptBackOut.leftNoTrace`). Todo lo demás retoma: un journal ilegible, algo en
    /// vuelo, y también `notStarted` sin nada apuntado, que es un cierre antes del claim con la persona ya habiendo dicho
    /// «Cargar mis datos y entrar» (la pantalla vuelve a pedirlo con la sesión que quedó).
    ///
    /// Review adversarial: «salió» es que el journal ya no tiene nada en vuelo (`notStarted` sin el efecto con una marca de
    /// salida, o `failedRollback`), y una salida que no se puede deshacer libera la marca en vez de retomar: retomar volvía
    /// a reclamar la cuenta sola. Con el journal ilegible tampoco se retoma: la pantalla no tenía salida.
    static func relaunchRoute(
        journaledPhase: MigrationPhase, adoptEffectJournaled: Bool, journalUnreadable: Bool,
        adoptClaimExit: AdoptClaimExit?, hasLocalData: Bool
    ) -> RelaunchRoute {
        guard !journalUnreadable else { return .release }
        let exited = !adoptEffectJournaled
            && (journaledPhase == .failedRollback || (journaledPhase == .notStarted && adoptClaimExit != nil))
        guard exited else { return .resume }
        return WelcomeAdoptBackOut.leftNoTrace(
            journaledPhase: journaledPhase, adoptEffectJournaled: adoptEffectJournaled,
            journalUnreadable: journalUnreadable, adoptClaimExit: adoptClaimExit,
            hasLocalData: hasLocalData) ? .backOut : .release
    }
}

// MARK: - Card 285z · cancelar el paso a medias desde la puerta de la bienvenida

/// **Opción A de Jürgen (2026-11-13): un paso de datos a medias de otro intento se deshace y se entra limpio.** Lo ofrece la
/// puerta de la bienvenida cuando su vuelta al neutro se para por `migrationInFlight`. Solo si cancelar es seguro —el mismo
/// criterio que «Cancelar la activación» en Almacenamiento (`canCancelMigration`)— y el teléfono todavía no escribió el par
/// nube + espejo apagado: con el par escrito el paso ya hizo lo irreversible y no se cancela.
@MainActor
enum WelcomeStaleMigrationCancel {

    /// Cuánto espera la puerta a que el «sí» aterrice antes de volver a medir. Si el runner está en una pasada larga, la
    /// puerta vuelve a enseñar el aviso con el botón, en vez de girar sin fin.
    static let maxWaitSeconds = 60

    static func offers(canCancelMigration: Bool, journalUnreadable: Bool,
                       persistedMode: StorageMode, mirrorOffArmed: Bool) -> Bool {
        canCancelMigration && !journalUnreadable && persistedMode == .icloud && !mirrorOffArmed
    }

    static func offers(controller: CloudMigrationController?) -> Bool {
        guard let controller else { return false }
        return offers(canCancelMigration: controller.canCancelMigration,
                      journalUnreadable: controller.isJournalUnreadable,
                      persistedMode: StorageModePersistence.read(),
                      mirrorOffArmed: StorageModePersistence.isMirrorOffArmed())
    }

    /// ¿Aterrizó? El journal ya no tiene nada en vuelo: `notStarted` sin el efecto pendiente, o la salida a `failedRollback`.
    static func landed(journaledPhase: MigrationPhase, adoptEffectJournaled: Bool, journalUnreadable: Bool) -> Bool {
        guard !journalUnreadable, !adoptEffectJournaled else { return false }
        return journaledPhase == .notStarted || journaledPhase == .failedRollback
    }
}
