//
//  StorageMigrationSignInLogic.swift
//  Yala
//
//  Guard R9 «una cuenta, una identidad» en la ENTRADA de migración/adopt de Almacenamiento
//  (bug C-7 de la auditoría de escenarios, 2026-07-27).
//
//  El hallazgo: `StorageSettingsView` presentaba el chooser Apple|Google SIN condición y
//  `CloudMigrationController.startMigration` llamaba `signIn(with:)` SIN mirar la sesión viva,
//  así que un usuario con sus grupos en la cuenta A podía firmar la migración personal con la
//  cuenta B. Resultado: datos personales en una cuenta y grupos en otra —contra el copy que
//  promete lo contrario (`groups.signin.accountNote`) y contra el invariante R9 del diseño.
//
//  La regla es la que el repo ya aplica en las OTRAS cuatro entradas a la sesión de nube:
//  con sesión viva NO se re-pregunta el método. Precedentes:
//   - `CloudMigrationController.signInToResumeSync` — «el método NO se elige: es determinista.
//     Ofrecer chooser aquí invitaría al mismatch R9».
//   - `GroupsSignInView` §16d — belt `onAppear` que auto-cierra con sesión viva.
//   - `GroupCreateRoutingLogic` / `GroupBackendInviteEntryLogic` — `hasSession` es la 1ª rama.
//   - `WelcomeCloudSignInView.runSignInFlow` — `if !hasSession { signIn(with:) }`.
//
//  Consumo: `StorageSettingsView` (decide si presenta `StorageSignInChooserView`) y el belt
//  `onAppear` del propio chooser. El controller conserva ADEMÁS su guard de sesión: la decisión
//  vive en el productor, pero la máquina jamás re-firma con sesión viva llegue por donde llegue.
//

import Foundation

nonisolated enum StorageMigrationSignInLogic {

    enum Decision: Equatable {
        /// Hay sesión de nube viva ⇒ la migración la usa TAL CUAL: ni chooser ni auth nueva.
        /// `provider` es el método de esa sesión (`storedProvider()`), solo para el copy —
        /// `nil` con la key perdida (residual documentado del claim): se reusa igual, porque
        /// la sesión es la autoridad y el método es cosmético.
        case reuseLiveSession(provider: CloudSignInProvider?)
        /// Sin sesión ⇒ el chooser se comporta como siempre (elección libre Apple|Google).
        case askProvider
        /// ADOPT en un segundo device y la sesión viva NO es la cuenta que migró este corpus (el
        /// faro del device nombra otra). Ni reusar (adoptaría bajo la cuenta equivocada y
        /// `writeBeacon` reescribiría el faro) ni ofrecer chooser (con sesión viva el belt de la
        /// máquina la reusaría igual): hay que salir de esta cuenta primero.
        case blockedOtherAccount(knownProvider: CloudSignInProvider?)
    }

    /// Reglas EN ORDEN:
    /// 1. `!hasSession` → `.askProvider`. Es la primera cuenta de este device: elección libre,
    ///    byte-idéntico al comportamiento anterior al fix.
    /// 2. ADOPT + faro con hash + sesión con OTRO hash → `.blockedOtherAccount`. La copia de la
    ///    nube pertenece a la cuenta del faro; adoptarla desde otra mezclaría dos identidades y
    ///    dejaría el faro del device apuntando a la equivocada. Solo aplica al adopt: en la
    ///    migración normal el corpus es local y de quien está dentro, no hay cuenta "esperada".
    /// 3. `hasSession` → `.reuseLiveSession`. JAMÁS re-preguntar: firmar de nuevo permitiría
    ///    aterrizar en OTRA cuenta y `signIn(with:)` sobrescribe la sesión en silencio (nuevo
    ///    `sub`, nuevo `keyProvider`, y el canal de Grupos —que lee `currentUserID` vivo— pasa
    ///    a operar bajo la cuenta nueva sin un solo evento).
    /// 4. El `provider` acompaña el veredicto solo si es un método CONOCIDO del wire; un valor
    ///    desconocido se trata como `nil` (copy genérico) — nunca se interpola un rawValue crudo.
    ///
    /// - Parameters:
    ///   - isAdopt: la card es de ADOPT (el mirror trajo el marcador de un líder).
    ///   - beaconAccountHash: `CloudBeacon.accountHash` — hash del `sub` que migró en este Apple ID.
    ///   - sessionAccountHash: `CloudBeacon.hash(currentUserID)` de la sesión viva.
    static func decide(
        hasSession: Bool,
        storedProvider: String?,
        isAdopt: Bool = false,
        beaconAccountHash: String? = nil,
        sessionAccountHash: String? = nil
    ) -> Decision {
        guard hasSession else { return .askProvider }
        let provider = storedProvider.flatMap(CloudSignInProvider.init(rawValue:))
        if isAdopt, let expected = beaconAccountHash, let actual = sessionAccountHash, expected != actual {
            return .blockedOtherAccount(knownProvider: provider)
        }
        return .reuseLiveSession(provider: provider)
    }

    // MARK: - Belt de la máquina

    /// Qué hace `startMigration` de verdad, una vez conocido el estado REAL de la sesión en el
    /// instante del arranque (que puede no ser el de cuando el productor decidió).
    enum Execution: Equatable {
        /// Continuar con la sesión viva, sin auth.
        case useLiveSession
        /// Autenticar con este método (no había sesión).
        case authenticate(CloudSignInProvider)
        /// El productor pidió reusar y la sesión ya no sirve (expiró, la cerraron, o su refresh token
        /// murió) → fallar honesto a `notStarted`. JAMÁS avanzar la máquina sin JWT: el claim fallaría
        /// más adelante dejando el journal en una fase transicional. El usuario reintenta y el
        /// productor vuelve a decidir — para entonces el SDK ya habrá limpiado la sesión muerta y
        /// verá el chooser.
        case failNoUsableSession
    }

    /// Regla del belt (C-7): **una sesión viva y usable SIEMPRE gana**, incluso si el plan que llega
    /// dice `.signIn` — un plan obsoleto de una entrada desactualizada jamás debe disparar una auth
    /// que aterrice en otra cuenta.
    ///
    /// `sessionIsUsable` distingue «hay fila de sesión» de «esa sesión sirve»: `hasSession` mira el
    /// Keychain, pero un refresh token revocado (el usuario quitó «Iniciar sesión con Apple» en
    /// Ajustes de iOS, o cerró sesión desde otro device) lo deja `true` con la sesión muerta. Sin esta
    /// distinción la migración avanzaría a `claimingMigration` sin poder obtener un JWT.
    static func execution(for plan: Plan, sessionIsUsable: Bool) -> Execution {
        if sessionIsUsable { return .useLiveSession }
        switch plan {
        case .authenticateWith(let provider): return .authenticate(provider)
        case .reuseLiveSession:               return .failNoUsableSession
        }
    }

    /// Plan que el productor comunica a la máquina (espejo de `CloudMigrationController.SignInPlan`,
    /// aquí para poder decidir sin tocar el controller `@MainActor`).
    enum Plan: Equatable {
        case reuseLiveSession
        case authenticateWith(CloudSignInProvider)
    }
}
