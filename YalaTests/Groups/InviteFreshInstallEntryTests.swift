//
//  InviteFreshInstallEntryTests.swift
//  YalaTests / Groups
//
//  QA guiado del 2026-10-19 (card `tablero-unirse-por-enlace-en-una-instalacion-nue-t2q8`): en una instalación nueva,
//  entrar por un enlace de invitación con una cuenta de la nube no puede bloquear por los datos privados del iCloud del
//  aparato, igual que «Ya tengo una cuenta». Dos tickets, uno por causa medida:
//   · `invite-on-a-fresh-install-mounts-the-icloud-mirror-after-a-relaunch` — el neutro del primer arranque dura un proceso.
//   · `invite-sign-in-with-a-complete-account-blocks-on-its-own-groups` — el canal de Grupos bajaba los grupos de la cuenta
//     antes de que el guard cross-cuenta contara.
//

import Foundation
import Testing

@testable import Yala

@Suite("Invitación en una instalación nueva · las dos puertas deciden igual")
struct InviteFreshInstallEntryTests {

    private typealias Mount = SwiftDataConfiguration.PersonalStoreDecision

    // MARK: - El neutro aguanta un relanzamiento

    @Test("Instalación nueva, montaje neutro, sin elegir nada: el enlace arma el neutro durable")
    func freshNeutralMount_armsTheDurableNeutral() {
        #expect(GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
            mounted: .neutralNoMirror, hasCompletedPersonalOnboarding: false, hasShownWelcomeChooser: false))
    }

    @Test("Controles: con el espejo montado, con el onboarding hecho o con algo elegido, no arma nada")
    func controls_neverArmOutsideAFreshUnchosenNeutral() {
        // El espejo ya montado no tiene neutro que conservar: ahí decide la puerta del invitado (vuelta al neutro).
        #expect(!GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
            mounted: .iCloudMirror, hasCompletedPersonalOnboarding: false, hasShownWelcomeChooser: false))
        #expect(!GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
            mounted: .localNoMirror, hasCompletedPersonalOnboarding: false, hasShownWelcomeChooser: false))
        #expect(!GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
            mounted: .cloudMirrorOff, hasCompletedPersonalOnboarding: false, hasShownWelcomeChooser: false))
        // Quien tiene su sesión privada (u otra elección) monta lo que su elección pide: un enlace no se la cambia.
        #expect(!GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
            mounted: .neutralNoMirror, hasCompletedPersonalOnboarding: true, hasShownWelcomeChooser: false))
        #expect(!GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
            mounted: .neutralNoMirror, hasCompletedPersonalOnboarding: false, hasShownWelcomeChooser: true))
    }

    @Test("MUTACIÓN: con el neutro armado, el SEGUNDO arranque (store ya creado) sigue neutro; sin armar, adjunta el espejo")
    func secondLaunch_staysNeutralOnlyWithTheArm() {
        let defaults = makeIsolatedDefaults(prefix: "invite.neutral")
        // Segundo proceso: el primero creó el archivo del store, así que ya no es «instalación nueva».
        let fresh = SwiftDataConfiguration.isFreshInstallForNeutralMount(
            personalStoreFileExists: true, persistedMode: .icloud, mirrorOffArmed: false, hasShownWelcomeChooser: false)
        #expect(!fresh)

        func secondMount() -> Mount {
            SwiftDataConfiguration.personalStoreDecision(
                storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true, freshInstall: fresh,
                neutralDurable: SwiftDataConfiguration.shouldMountNeutralDurable(defaults))
        }
        // Control: el arranque viejo, sin el arma, adjuntaba el espejo del iCloud del aparato.
        #expect(secondMount() == .iCloudMirror)

        StorageModePersistence.armNeutralMountIfUnarmed(defaults)
        #expect(secondMount() == .neutralNoMirror)

        // Y caduca sola en cuanto la persona elige en el Welcome (el anti-bucle del neutro del cierre de sesión).
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        #expect(secondMount() == .iCloudMirror)
    }

    @Test("Armar desde el enlace no le quita el neutro a su dueño (cierre de sesión o borrado del corpus)")
    func armIfUnarmed_doesNotTouchAnOwnedArm() {
        let defaults = makeIsolatedDefaults(prefix: "invite.neutral.owner")
        defaults.set(true, forKey: StorageModePersistence.neutralMountArmedKey)
        defaults.set(true, forKey: StorageModePersistence.icloudCorpusWipeOwnsNeutralMountKey)
        StorageModePersistence.armNeutralMountIfUnarmed(defaults)
        #expect(defaults.bool(forKey: StorageModePersistence.icloudCorpusWipeOwnsNeutralMountKey),
                "la marca de quién lo armó sigue: desarmar aquel borrado puede seguir llevándoselo")
        #expect(StorageModePersistence.isNeutralMountArmed(defaults))
    }

    // MARK: - El canal de Grupos no baja nada antes del guard

    @Test("Con una cuenta completa, la hoja de Grupos NO arranca el canal antes del guard; con las demás, sí")
    func groupsChannel_startsAtSignInExceptForACompleteAccount() {
        #expect(!GroupsSignInChannelStartLogic.startsChannelAtSignIn(.adoptAsCompleteAndOpenGroups))
        #expect(!GroupsSignInChannelStartLogic.startsChannelAtSignIn(.blockedAccountIsComplete))
        // Controles: el comportamiento viejo era el correcto para quien se queda en Grupos.
        #expect(GroupsSignInChannelStartLogic.startsChannelAtSignIn(.continueGroupsSetup))
        #expect(GroupsSignInChannelStartLogic.startsChannelAtSignIn(.associateGroupsAccount))
        #expect(GroupsSignInChannelStartLogic.startsChannelAtSignIn(nil))
    }

    // MARK: - Las dos puertas

    /// La celda del QA: instalación nueva, montaje neutro, nada personal y nada bajado todavía. Por la puerta del Welcome
    /// («Ya tengo una cuenta») el guard deja entrar; por la del enlace, la puerta del invitado deja seguir y —con el canal
    /// de Grupos sin arrancar antes de él— el guard ve el mismo store vacío y deja entrar igual.
    @Test("Instalación nueva por el Welcome y por el enlace: las dos dejan entrar a la cuenta de la nube")
    func bothDoors_letTheCloudAccountIn() {
        // Puerta del Welcome: nada en el store cuando el guard cuenta.
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: false, sameAccountClaimExists: false, restoreInProgress: false) == .proceed)
        // Puerta del enlace: primero la del invitado…
        #expect(GroupInviteNeutralGateLogic.decide(
            hasCompletedPersonalOnboarding: false, hasExistingData: false, mountAttachesMirror: false,
            personalDataLivesInLiveCloudAccount: false, signUpStartedOnCleanStore: false) == .proceed)
        // …y con una cuenta completa el canal no baja grupos antes del guard, así que el guard cuenta lo mismo.
        let canalArrancado = GroupsSignInChannelStartLogic.startsChannelAtSignIn(.adoptAsCompleteAndOpenGroups)
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: canalArrancado, sameAccountClaimExists: false, restoreInProgress: false) == .proceed)
        // Control: datos de verdad de otra persona siguen bloqueando por las dos puertas.
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false, restoreInProgress: false) == .blockedForeignData)
    }
}

@Suite("Invitación en una instalación nueva · cableado (source-scan)")
struct InviteFreshInstallEntryWiringTests {

    private static func code(_ path: String) throws -> [String] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    @Test func groupsSheet_startsTheChannelOnlyThroughTheDecision() throws {
        let lines = try Self.code("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        let starts = lines.indices.filter { lines[$0].contains("GroupsSyncClient.shared.startIfEligible(") }
        #expect(starts.count == 1)
        guard let i = starts.first else { return }
        #expect(lines[i - 1] == "if GroupsSignInChannelStartLogic.startsChannelAtSignIn(destino) {")
    }

    @Test func inviteEntry_armsTheDurableNeutralThroughTheDecision() throws {
        let lines = try Self.code("Yala/App/Services/GroupBackendInviteEntryHandler.swift").joined(separator: "\n")
        #expect(lines.contains("""
            armInviteTap(groupID: groupID)
            if GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
            mounted: SwiftDataConfiguration.personalStoreMountedDecision,
            hasCompletedPersonalOnboarding: UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
            hasShownWelcomeChooser: UserDefaults.standard.bool(forKey: "hasShownWelcomeChooser")) {
            StorageModePersistence.armNeutralMountIfUnarmed()
            }
            """))
    }
}
