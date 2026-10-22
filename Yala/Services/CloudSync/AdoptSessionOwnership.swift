//
//  AdoptSessionOwnership.swift
//  Yala
//
//  La sesión que abrió un ADOPT, y cuándo se cierra (ticket `adopt-exit-keeps-the-session-it-opened`, decisión A de Jürgen
//  del 2026-09-23: al cancelar o al rendirse el techo, se cierra la sesión que abrió el adopt).
//
//  «Migrar a la nube» ya cerraba la suya (`CloudMigrationController.closeSessionIfOpened`), pero su testigo vive en memoria
//  (`migrationAttempt`) y el adopt no lo usa. Aquí la memoria no vale: el techo del efecto son 72 h, así que casi siempre
//  vence en el `resume` de un arranque posterior, y «Cancelar» puede llegar días después. Por eso la cuenta cuya sesión abrió
//  el intento se apunta en `UserDefaults`, sin schema nuevo.
//
//  Por qué importa: una sesión viva en un teléfono con sesión privada la registra `GroupsAssociationRegistrar` como cuenta de
//  grupos en el arranque siguiente, y quien sale de un adopt no pidió eso. Por eso el registrador tampoco registra la sesión
//  de un adopt mientras la marca la describe.
//

import Foundation

/// La cuenta cuya sesión abrió el adopt en curso, con el hash del faro (`CloudBeacon.hash`), el mismo que ata la marca del
/// adopt (`MigrationState.adoptClaimAccountHash`). `nil` = la sesión no la abrió un adopt: era la de Grupos, o no hay adopt.
///
/// **Describe UNA sesión, no una cuenta**: `CloudAuthService` la borra en cada sign-in y en cada sign-out. Sin eso, una
/// sesión de Grupos firmada después con la MISMA cuenta heredaba la marca, y la salida del adopt la cerraba.
///
/// **Se apunta ANTES de conducir el runner y se retira si la llamada no llegó al claim** (`stoppedBeforeTheClaim`).
/// Apuntada después, un kill durante la primera pasada —que dentro de un solo `submit` hace el claim y hasta el efecto—
/// dejaba el adopt sin marca, y su salida días después ya no cerraba nada. Y sin retirarla, una pasada que no llega al
/// claim (la quiescencia vence en `submit(.signInSucceeded)`) se normalizaría a `notStarted` y se leería como salida: la
/// bienvenida perdería la sesión con la que su «Retomar» vuelve a empezar.
nonisolated enum AdoptSessionOwnership {

    /// En `cloudSync.*`, como el resto del estado de la migración, y fuera de la lista de `DataWipeService.removeUserPreferenceKeys`:
    /// «Vaciar datos» no la borra a mitad de un adopt.
    static let userDefaultsKey = "cloudSync.adoptSessionAccountHash"

    static func read(_ defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: userDefaultsKey)
    }

    /// Apunta la cuenta, o borra la marca con `nil`.
    static func record(_ accountHash: String?, _ defaults: UserDefaults = .standard) {
        if let accountHash, !accountHash.isEmpty {
            defaults.set(accountHash, forKey: userDefaultsKey)
        } else {
            defaults.removeObject(forKey: userDefaultsKey)
        }
    }

    /// Qué apunta un adopt que empieza. Si abrió su sesión, esa cuenta. Si no, la marca solo sobrevive cuando ya describe la
    /// sesión viva: es la que abrió un intento anterior del mismo adopt y nadie ha firmado desde entonces (la marca se borra
    /// en cada sign-in), como un «Retomar» de la bienvenida tras relanzar. Cualquier otra se borra: no se hereda.
    static func markToRecord(
        sessionOpenedByThisAttempt: Bool, sessionAccountHash: String?, current: String?
    ) -> String? {
        guard let sessionAccountHash else { return nil }
        if sessionOpenedByThisAttempt { return sessionAccountHash }
        return current == sessionAccountHash ? current : nil
    }

    /// ¿La llamada que empezó el adopt volvió sin entrar en el claim? Entonces la marca se retira: el intento no empezó, y
    /// su `authenticating` se normalizaría a `notStarted`, que con la marca puesta se lee como salida. El adopt que terminó
    /// dentro de la misma llamada ya persistió la nube, y ahí la marca la olvida `decide`.
    static func stoppedBeforeTheClaim(
        phase: MigrationPhase, adoptEffectPending: Bool, persistedCloudMode: Bool
    ) -> Bool {
        guard !persistedCloudMode, !adoptEffectPending else { return false }
        switch phase {
        case .notStarted, .dryRun, .consent, .authenticating: return true
        default: return false
        }
    }

    enum Decision: Equatable, Sendable {
        /// Nada que hacer: no hay marca, el adopt sigue en vuelo, o no se lee la sesión.
        case keep
        /// El adopt terminó y la marca ya no describe nada, pero la sesión viva no es la que abrió: se borra la marca y la
        /// sesión se queda. Incluye el adopt que llegó a la nube, cuya sesión es ya la de la cuenta.
        case forget
        /// El adopt salió y la sesión viva es la que abrió: se cierra y se borra la marca.
        case closeSession
    }

    /// Qué hacer con la marca al mirar el journal.
    ///
    /// «Salió» son las dos formas en que un adopt acaba sin la nube, y cubren todas sus salidas: el techo de cualquier paso
    /// deja `failedRollback`, y «Cancelar» (o «Dejar de esperar») deja `notStarted` sin el efecto pendiente. `notStarted` con
    /// el efecto pendiente es el adopt esperando, no una salida, y la nube persistida es el adopt que terminó bien.
    ///
    /// Sin sesión legible no se decide: un `currentUserID` que aún no se lee (el llavero protegido en un prewarm) no es
    /// «otra sesión», y olvidar la marca ahí dejaba abierta la sesión que describía. Si de verdad no hay sesión, la marca no
    /// hace nada y la borra el siguiente sign-in.
    static func decide(
        ownedAccountHash: String?,
        sessionAccountHash: String?,
        phase: MigrationPhase,
        adoptEffectPending: Bool,
        persistedCloudMode: Bool
    ) -> Decision {
        guard let ownedAccountHash else { return .keep }
        if persistedCloudMode { return .forget }
        let exited = phase == .failedRollback || (phase == .notStarted && !adoptEffectPending)
        guard exited, let sessionAccountHash else { return .keep }
        return sessionAccountHash == ownedAccountHash ? .closeSession : .forget
    }

    /// ¿La sesión viva la abrió un adopt? El registrador de Grupos del arranque no la asocia entonces: el adopt en vuelo no
    /// pidió una cuenta de Grupos, y si sale la sesión se cierra (el cierre del arranque puede ir detrás del registrador,
    /// porque `signOut` espera antes de borrar la sesión).
    static func ownsLiveSession(sessionAccountHash: String?, _ defaults: UserDefaults = .standard) -> Bool {
        guard let sessionAccountHash, let owned = read(defaults) else { return false }
        return owned == sessionAccountHash
    }
}
