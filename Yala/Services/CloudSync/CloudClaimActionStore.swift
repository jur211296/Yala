//
//  CloudClaimActionStore.swift
//  Yala
//
//  Persistencia (UserDefaults, keyed por userID) del último `AccountClaimDecision.AuthAction` resuelto
//  para un usuario del Modo Nube (I14, P6). Cierra dos huecos del gate de arranque del runtime:
//
//   - `LiveCloudSessionProvider.claimAction` LEE de aquí el `AuthAction` del `currentUserID` → el gate
//     `CloudSyncRuntime.shouldStartSync(after:)` deja de recibir el `nil`-inseguro que "procede" (regla
//     C4: el runtime no debe arrancar el sync sin pasar por el contrato de claim §f.1).
//   - El guard de IDENTIDAD (AJUSTE review #1): en `.cloud`, un `currentUserID` SIN registro de claim
//     deja el runtime `.idle` (un Apple ID DISTINTO en un device migrado NO debe pushear el corpus del
//     dueño a otra cuenta). Todo camino legítimo a `.cloud` estampa el store (claim de migración o adopt).
//
//  Write-sites: (a) `MigrationWorkExecutor.performClaim` al resolver el claim de la migración; (b) el
//  flujo de adopt (`runAdoptFlow`) al decidir `routeReturningUser`; (c) `discardLastClaimStamp`, que repone el
//  sello anterior cuando «Migrar a la nube» devuelve el claim al inicio; (d) el `complete` del líder
//  (`.runLeaderReconcileFromFrozenCloudKit`), que cambia `proceedMigration` por `routeReturningUser`: la migración
//  terminó y el sello ya no puede abrir la comprobación de «Migrar» (ticket
//  `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`). `signOut` NO borra los registros
//  (keyed por userID → el re-sign-in del MISMO usuario no se bloquea; AJUSTE review #1).
//
//  Y una segunda familia de claves, que NO es un `AuthAction`: la marca del claim de «Migrar» que se quedó sin respuesta
//  (`recordMigrationClaimAttempt`, ticket `forward-migration-steps-have-no-ceiling-and-no-exit`). La escribe
//  `MigrationWorkExecutor.performClaim` antes del POST, solo en un claim de «Migrar», y la borra la respuesta de cualquier
//  claim de esa cuenta. La lee SOLO la puerta de «Migrar» (`StorageMigrationIdentityGateLogic.check`, parámetro
//  `hasUnansweredMigrationClaim`), que la trata distinto del sello. Sobrevive a `signOut` y a «Empezar desde cero» igual
//  que el sello; lo que evita que abra la cuenta de la persona anterior es esa puerta, no un borrado.
//
//  `@MainActor`: la sesión (`CloudAuthService`) que lo alimenta es main-actor-aislada.
//

import Foundation

@MainActor
final class CloudClaimActionStore {

    /// Instancia de producción (UserDefaults.standard). Los tests inyectan su propio `defaults` aislado.
    static let shared = CloudClaimActionStore()

    private let defaults: UserDefaults
    private static let prefix = "cloudSync.claimAction."

    /// `defaults` inyectable (nunca `.standard` directo en tests — regla del repo).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Registra el `AuthAction` resuelto para `userID` (idempotente — sobrescribe).
    func record(_ action: AccountClaimDecision.AuthAction, forUserID userID: String) {
        defaults.set(Self.encode(action), forKey: Self.prefix + userID)
    }

    /// El `AuthAction` registrado para `userID`, o `nil` si nunca se estampó (identidad no-claimeada).
    func action(forUserID userID: String) -> AccountClaimDecision.AuthAction? {
        guard let raw = defaults.string(forKey: Self.prefix + userID) else { return nil }
        return Self.decode(raw)
    }

    /// Borra el registro de `userID`. NO se llama en `signOut`. En producción solo lo usa
    /// `MigrationWorkExecutor.discardLastClaimStamp`, para deshacer el sello de un claim que «Migrar a la nube» devolvió
    /// al inicio cuando antes no había ninguno.
    func clear(forUserID userID: String) {
        defaults.removeObject(forKey: Self.prefix + userID)
    }

    // MARK: - La marca del claim sin respuesta (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`)

    /// Clave PROPIA y no un `AuthAction` más: el sello de arriba lo leen el gate de arranque del runtime y el Welcome
    /// (`CrossAccountEntryGuardLogic`), y un «intentado» ahí les afirmaría un claim que quizá nunca llegó. Esta marca la
    /// lee solo la puerta de «Migrar a la nube» (`CloudMigrationController.checkMigrationIdentity`).
    private static let attemptPrefix = "cloudSync.migrationClaimAttempt."

    /// Este dispositivo va a mandar un claim de migración para `userID` y todavía no sabe cómo acaba. La escribe
    /// `MigrationWorkExecutor.performClaim` ANTES del POST.
    func recordMigrationClaimAttempt(forUserID userID: String) {
        defaults.set(true, forKey: Self.attemptPrefix + userID)
    }

    /// ¿Quedó un claim de migración de este dispositivo sin respuesta para `userID`?
    func hasMigrationClaimAttempt(forUserID userID: String) -> Bool {
        defaults.bool(forKey: Self.attemptPrefix + userID)
    }

    /// El claim contestó: el desenlace ya se sabe y la marca sobra. La borra `performClaim` con cualquier `.success`.
    func clearMigrationClaimAttempt(forUserID userID: String) {
        defaults.removeObject(forKey: Self.attemptPrefix + userID)
    }

    // MARK: - Codec estable (rawValue WIRE-STABLE — persiste entre lanzamientos)

    /// Mapeo estable `AuthAction` → String. No renombrar (rompería la persistencia). `AccountClaimDecision`
    /// no es `RawRepresentable` a propósito (pure-logic sin acoplarse a storage) → el codec vive aquí.
    static func encode(_ action: AccountClaimDecision.AuthAction) -> String {
        switch action {
        case .seedBornCloud:        return "seedBornCloud"
        case .proceedMigration:     return "proceedMigration"
        case .routeReturningUser:   return "routeReturningUser"
        case .waitForLeader:        return "waitForLeader"
        case .showProviderMismatch: return "showProviderMismatch"
        }
    }

    static func decode(_ raw: String) -> AccountClaimDecision.AuthAction? {
        switch raw {
        case "seedBornCloud":        return .seedBornCloud
        case "proceedMigration":     return .proceedMigration
        case "routeReturningUser":   return .routeReturningUser
        case "waitForLeader":        return .waitForLeader
        case "showProviderMismatch": return .showProviderMismatch
        default:                     return nil
        }
    }
}
