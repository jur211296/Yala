//
//  GroupsConsentSealDoorsWiringTests.swift
//  YalaTests
//
//  Card m387 · el consentimiento de Grupos aceptado SIN sesión (paso 3 del educativo, L12-4) se sella en el punto en que
//  cada puerta da la sesión por buena, y en ningún otro: sellar en el inicio de sesión rompería el bloqueo [I] («el
//  bloqueo no escribe NADA»), porque la puerta puede rechazar la cuenta un instante después.
//
//  Es un scan de fuente a propósito: lo que se fija es DÓNDE va la llamada (detrás de qué decisión), y eso no tiene otra
//  forma de verse desde un test. Qué hace el sellado lo fija `GroupsConsentRegistrationTests`
//  (`acceptedWithoutSession_keepsItsPath_andTheAdoptionRegistersWithIt`).
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct GroupsConsentSealDoorsWiringTests {

    private static let seal = "GroupsConsentRegistrar.shared.sealAfterSessionAccepted()"

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// El código que sigue a `anchor` hasta `limit` (líneas recortadas, sin comentarios ni vacías): el tramo donde la puerta
    /// ya decidió.
    private static func stretch(_ src: String, after anchor: String, until limit: String) -> String? {
        guard let start = src.range(of: anchor) else { return nil }
        let rest = src[start.upperBound...]
        guard let end = rest.range(of: limit) else { return nil }
        return String(rest[..<end.lowerBound])
    }

    // MARK: - Bienvenida

    @Test func welcome_sealsWhenItEntersAGroupsOnlyAccount() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        let tramo = try #require(Self.stretch(
            src, after: "case .enterGroupsOnly, .enterGroupsOnlyOfferingFullActivation:", until: "onEnterGroupsOnly("))
        #expect(tramo.contains(Self.seal), "La bienvenida entra en la cuenta solo-grupos sin sellar el consentimiento")
    }

    /// El adopt no sella: su salida (cancelar, el techo, el linaje sin probar) cierra la sesión, así que hasta terminar no
    /// la ha aceptado. Al terminar relanza y sella el arranque.
    @Test func welcome_theAdoptDoesNotSeal() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        let tramo = try #require(Self.stretch(src, after: "case .blockedForeignData:", until: "await pollAdoptProgress()"))
        #expect(!tramo.contains(Self.seal), "El adopt de la bienvenida sella antes de terminar")
    }

    @Test func welcome_sealsTheCloudSignUp() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        let tramo = try #require(Self.stretch(
            src, after: "case .activateStorageAndRelaunch:", until: "service.activateBornCloudStorage("))
        #expect(tramo.contains(Self.seal), "El alta en la nube no sella el consentimiento")
        // «No encontramos una cuenta» suelta la sesión: ahí no se sella.
        let noEncontrada = try #require(Self.stretch(
            src, after: "case .discovered(.newAccount, _, _):", until: "case .unavailable(let retryable):"))
        #expect(!noEncontrada.contains(Self.seal))
    }

    // MARK: - Ajustes

    /// El adopt de Ajustes no sella, por lo mismo que el de la bienvenida.
    @Test func settings_theAdoptDoesNotSeal() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift")
        let tramo = try #require(Self.stretch(
            src, after: "r.setForwardClaimIntent(.adoptIfExisting)\nrecordAdoptSessionOwnership", until: "lastError = StorageFailureCopyLogic.settingsAdoptStoppedBeforeTheClaim"))
        #expect(!tramo.contains(Self.seal), "El adopt de Ajustes sella antes de terminar")
    }

    /// «Migrar» sella solo con el intento vivo y el claim contestado. Un claim rechazado vacía el intento y cierra
    /// la sesión que abrió (`announceForwardClaimRefusal`): ese `return` va antes y no sella.
    @Test func settings_sealsMigrateOnlyPastTheClaim() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift")
        let rechazado = try #require(Self.stretch(
            src, after: "guard migrationAttempt != nil else {", until: "}"))
        #expect(!rechazado.contains(Self.seal))
        let pasado = try #require(Self.stretch(
            src, after: "guard [.notStarted, .consent, .authenticating].contains(journaledPhase) else {", until: "return"))
        // Con el claim aparcado todavía puede rechazar la cuenta: sella solo con el claim contestado.
        #expect(pasado.contains("if journaledPhase != .claimingMigration {\n" + Self.seal + "\n}"),
                "«Migrar» sella sin mirar si el claim contestó")
    }

    @Test func settings_sealsTheSyncBannerSignInOnlyForTheOwner() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift")
        let tramo = try #require(Self.stretch(
            src, after: "signedInIsClaimed: signedIn.map", until: "case .rejectOtherAccount:"))
        #expect(tramo.contains(Self.seal), "Volver a entrar con la cuenta dueña no sella el consentimiento")
        let otra = try #require(Self.stretch(src, after: "case .rejectOtherAccount:", until: "} catch CloudAuthError.cancelled"))
        #expect(!otra.contains(Self.seal), "La cuenta rechazada del aviso de sincronización no puede sellar")
    }

    // MARK: - El bloqueo [I]

    /// Ni el inicio de sesión ni la pantalla que lo pide sellan: la cuenta puede ser la que la puerta rechaza.
    @Test func signIn_itselfNeverSeals() throws {
        for ruta in [
            "Yala/Services/CloudSync/CloudAuthService.swift",
            "Yala/App/Views/Groups/GroupsSignInView.swift",
        ] {
            let src = try Self.source(ruta)
            #expect(!src.contains("GroupsConsentRegistrar"), "\(ruta) registra el consentimiento al iniciar sesión")
        }
    }

    /// La hoja de Grupos sella detrás del bloqueo: con la cuenta rechazada vuelve antes.
    @Test func groupsSheet_sealsBehindTheBlock() throws {
        let src = try Self.source("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        let bloqueo = try #require(src.range(of: "guard destino != .blockedAccountIsComplete else { return }"))
        let sello = try #require(src.range(of: "GroupsConsentRegistrar.shared.handleSignIn()"))
        #expect(bloqueo.upperBound <= sello.lowerBound, "La hoja de Grupos sella antes de mirar el bloqueo [I]")
    }

    /// La pestaña de Grupos oye los cambios de sesión solo para repintar: con las seis páginas montadas, también oye los
    /// inicios de sesión de las demás puertas, el de la cuenta que [I] rechaza incluido.
    @Test func groupsTab_sessionNoticeOnlyRepaints() throws {
        let src = try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift")
        let aviso = try #require(Self.stretch(
            src, after: "for: CloudAuthService.sessionDidChangeNotification)) {", until: "}"))
        #expect(aviso.trimmingCharacters(in: .whitespaces) == "_ in sessionRevision &+= 1")
    }
}
