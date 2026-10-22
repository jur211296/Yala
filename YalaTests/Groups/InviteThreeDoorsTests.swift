//
//  InviteThreeDoorsTests.swift
//  YalaTests / Groups
//
//  Unirse por enlace en una instalación nueva, por las TRES puertas (card t2q8, vuelta del QA guiado del TF19,
//  2026-10-20): el enlace directo, la bienvenida › «Vengo por un grupo › Tengo una invitación» y el relanzamiento a
//  mitad del recorrido. El #566 arregló la primera; las otras dos seguían pidiendo «Antes de unirte, este teléfono queda
//  en blanco».
//
//  Cada puerta se recorre como una secuencia de lo que el teléfono ESCRIBE (marcas, chooser, store) con las decisiones
//  puras de producción en cada paso: la tabla de montajes, el portal del Welcome, el arma del neutro duradero, la marca de
//  grupos del sign-in, la marca del alta sobre un store limpio y la puerta del invitado. Las dos causas medidas:
//   (a) el portal pedía el espejo para `.inviteRecovery` y marcaba el chooser: un relanzamiento montaba el iCloud;
//   (b) el CTA siembra las categorías del invitado y la puerta, justo después, las contaba como de otra persona.
//

import Foundation
import Testing

@testable import Yala

@Suite("Unirse por enlace · las tres puertas (t2q8)")
@MainActor
struct InviteThreeDoorsTests {

    typealias Decision = SwiftDataConfiguration.PersonalStoreDecision

    /// Lo que un teléfono recién instalado tiene escrito a lo largo del recorrido del invitado.
    @MainActor struct Phone {
        var storeFileExists = false
        var chooserMarked = false
        var neutralArmed = false
        var groupsOnlyArmed = false
        var onboardingDone = false
        var personalRows = false          // categorías propias
        var groupRows = false             // `SplitGroup` bajados
        var groupsVouched = false         // `LateNoticeKeptGroupsMark`, atada a la sesión de quien entra
        var signUpOnCleanStore = false    // `PendingJoinEntry.signUpOnCleanStoreAt`

        /// La tabla de montajes de producción, con el par de storage virgen (`.icloud` sin armar).
        var mount: Decision {
            let fresh = SwiftDataConfiguration.isFreshInstallForNeutralMount(
                personalStoreFileExists: storeFileExists, persistedMode: .icloud,
                mirrorOffArmed: false, hasShownWelcomeChooser: chooserMarked)
            let durable = SwiftDataConfiguration.shouldMountNeutralDurable(
                neutralMountArmed: neutralArmed, hasShownWelcomeChooser: chooserMarked,
                groupsOnlySessionArmed: groupsOnlyArmed, persistedMode: .icloud, mirrorOffArmed: false)
            return SwiftDataConfiguration.personalStoreDecision(
                storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
                freshInstall: fresh, neutralDurable: durable)
        }

        /// El detector del Welcome que alimenta la puerta (`checkHasWelcomeDeviceData`).
        var welcomeSeesData: Bool {
            WelcomeKeptGroupsLogic.deviceDataForWelcome(
                hasPersonalData: personalRows, hasGroupsData: groupRows, groupsKeptForThisPerson: groupsVouched)
        }

        /// La puerta del invitado con los términos de producción.
        func gate(mounted: Decision) -> GroupInviteNeutralGateLogic.Decision {
            GroupInviteNeutralGateLogic.decide(
                hasCompletedPersonalOnboarding: onboardingDone,
                hasExistingData: welcomeSeesData,
                mountAttachesMirror: mounted.attachesCloudKitMirror,
                personalDataLivesInLiveCloudAccount: false,
                signUpStartedOnCleanStore: signUpOnCleanStore)
        }

        // MARK: Los pasos

        /// Un arranque: el montaje crea el archivo del store. Devuelve lo que montó.
        mutating func launch() -> Decision {
            let mounted = mount
            storeFileExists = true
            return mounted
        }

        /// El enlace llega (`persistIntent`).
        mutating func linkArrives(mounted: Decision) {
            if GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry(
                mounted: mounted, hasCompletedPersonalOnboarding: onboardingDone, hasShownWelcomeChooser: chooserMarked) {
                neutralArmed = true
            }
        }

        /// Firma con una cuenta solo-grupos en la hoja de Grupos; el canal arranca y baja sus grupos.
        mutating func signInGroupsOnly(withMark: Bool = true) {
            if withMark, GroupInviteNeutralGateLogic.vouchesForGroupsAtSignIn(
                sessionOpenedHere: true, hasCompletedPersonalOnboarding: onboardingDone,
                channelStartsAtSignIn: GroupsSignInChannelStartLogic.startsChannelAtSignIn(.enterGroupsOnly)),
               LateNoticeKeptGroupsMark.shouldRecordAtGroupsEntry(localGroupCount: groupRows ? 1 : 0) {
                groupsVouched = true
            }
            groupRows = true
        }

        /// El CTA «Unirme al grupo» de la hoja (`performSilentSetup`), y su `drive(.userAction)`.
        mutating func joinTap(mounted: Decision, withCleanMark: Bool = true) -> GroupInviteNeutralGateLogic.Decision {
            if withCleanMark, GroupInviteNeutralGateLogic.marksSignUpOnCleanStore(
                hasExistingData: welcomeSeesData, mountAttachesMirror: mounted.attachesCloudKitMirror) {
                signUpOnCleanStore = true
            }
            groupsOnlyArmed = true      // paso 0
            personalRows = true         // paso 4: las categorías del invitado
            return gate(mounted: mounted)
        }
    }

    // MARK: - Puerta 1 · el enlace directo

    @Test func enlaceDirecto_elJoinSale_ySobreviveUnRelanzamiento() {
        var phone = Phone()
        let first = phone.launch()
        #expect(first == .neutralNoMirror)
        phone.linkArrives(mounted: first)
        #expect(phone.gate(mounted: first) == .proceed)
        phone.signInGroupsOnly()
        #expect(phone.joinTap(mounted: first) == .proceed, "el CTA no puede bloquear su propio alta")

        let second = phone.launch()
        #expect(second == .neutralNoMirror)
        #expect(phone.gate(mounted: second) == .proceed)
    }

    /// Control: sin la marca del alta, las categorías que siembra el propio CTA bloquean el join en el acto. Es lo que
    /// dejaba «Conectando con tu grupo…» para siempre.
    @Test func enlaceDirecto_sinLaMarcaDelAlta_elCTASeBloqueaASiMismo() {
        var phone = Phone()
        let first = phone.launch()
        phone.linkArrives(mounted: first)
        phone.signInGroupsOnly()
        #expect(phone.joinTap(mounted: first, withCleanMark: false) == .returnsToNeutral)
    }

    // MARK: - Puerta 2 · la bienvenida › «Tengo una invitación»

    @Test func bienvenida_tengoUnaInvitacion_noRelanza_yElNeutroAguanta() {
        var phone = Phone()
        let first = phone.launch()
        // «Tengo una invitación» sale por el portal: ya no pide el espejo, así que no hay relanzamiento.
        #expect(!WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: .inviteRecovery, mountedDecision: first))
        // Y no marca el chooser (`onSelectBranch(.invite)`): el enlace pegado arma el neutro duradero.
        phone.linkArrives(mounted: first)
        #expect(phone.neutralArmed)
        phone.signInGroupsOnly()
        #expect(phone.joinTap(mounted: first) == .proceed)

        let second = phone.launch()
        #expect(second == .neutralNoMirror)
        #expect(phone.gate(mounted: second) == .proceed)
    }

    /// Control: el recorrido de antes (relanzar para el espejo y marcar el chooser) montaba el iCloud del aparato en el
    /// arranque siguiente, y la puerta pedía dejar el teléfono en blanco.
    @Test func bienvenida_conElRecorridoViejo_montabaElEspejo() {
        var phone = Phone()
        _ = phone.launch()
        phone.chooserMarked = true                   // `onNeedsMirrorRelaunch` / `onSelectBranch` viejos
        let second = phone.launch()
        #expect(second == .iCloudMirror)
        phone.linkArrives(mounted: second)
        #expect(!phone.neutralArmed)
        #expect(phone.gate(mounted: second) == .returnsToNeutral)
    }

    // MARK: - Puerta 3 · el relanzamiento a mitad

    /// En «Conectando con tu grupo…» Yala se cierra del todo y se vuelve a abrir el enlace.
    @Test func relanzamientoTrasElCTA_sigueSinPedirBorrar() {
        var phone = Phone()
        let first = phone.launch()
        phone.linkArrives(mounted: first)
        phone.signInGroupsOnly()
        _ = phone.joinTap(mounted: first)

        let second = phone.launch()
        phone.linkArrives(mounted: second)
        #expect(second == .neutralNoMirror)
        #expect(phone.gate(mounted: second) == .proceed)
    }

    /// Relanzamiento entre firmar y el CTA: los grupos que bajó el canal son de quien entra.
    @Test func relanzamientoAntesDelCTA_losGruposPropiosNoBloquean() {
        var phone = Phone()
        let first = phone.launch()
        phone.linkArrives(mounted: first)
        phone.signInGroupsOnly()

        let second = phone.launch()
        #expect(second == .neutralNoMirror)
        #expect(phone.gate(mounted: second) == .proceed)
        #expect(phone.joinTap(mounted: second) == .proceed)
    }

    /// Control: sin la marca del sign-in, esos mismos grupos bloqueaban.
    @Test func relanzamientoAntesDelCTA_sinLaMarcaDelSignIn_bloqueaba() {
        var phone = Phone()
        let first = phone.launch()
        phone.linkArrives(mounted: first)
        phone.signInGroupsOnly(withMark: false)
        let second = phone.launch()
        #expect(phone.gate(mounted: second) == .returnsToNeutral)
    }

    // MARK: - Lo que la puerta sigue protegiendo

    /// El corpus de OTRA persona sigue bloqueando: con datos antes del CTA, la marca del alta no se apunta.
    @Test func corpusDeOtraPersona_sigueBloqueando() {
        // Montaje neutro (lo deja un cierre de sesión a medias, por ejemplo): solo el término del corpus decide.
        var phone = Phone(storeFileExists: true, neutralArmed: true, personalRows: true)
        let mounted = phone.launch()
        #expect(mounted == .neutralNoMirror)
        #expect(phone.gate(mounted: mounted) == .returnsToNeutral)
        // Aunque llegara al CTA, la marca no se apuntaría.
        #expect(!GroupInviteNeutralGateLogic.marksSignUpOnCleanStore(hasExistingData: true, mountAttachesMirror: false))
        _ = phone.joinTap(mounted: mounted)
        #expect(!phone.signUpOnCleanStore)
        #expect(phone.gate(mounted: mounted) == .returnsToNeutral)
    }

    /// El espejo montado manda siempre, con marca o sin ella.
    @Test func conElEspejoMontado_lasMarcasNoAbren() {
        let phone = Phone(storeFileExists: true, groupsVouched: true, signUpOnCleanStore: true)
        #expect(phone.gate(mounted: .iCloudMirror) == .returnsToNeutral)
        #expect(phone.gate(mounted: .localNoMirror) == .returnsToNeutral)
        #expect(!GroupInviteNeutralGateLogic.marksSignUpOnCleanStore(hasExistingData: false, mountAttachesMirror: true))
    }

    /// La marca de grupos del sign-in solo la escribe una sesión abierta AQUÍ, en un teléfono sin onboarding y con el
    /// canal arrancando al firmar (no con una cuenta completa).
    @Test func laMarcaDelSignIn_tieneSusTresCondiciones() {
        typealias G = GroupInviteNeutralGateLogic
        #expect(G.vouchesForGroupsAtSignIn(sessionOpenedHere: true, hasCompletedPersonalOnboarding: false, channelStartsAtSignIn: true))
        #expect(!G.vouchesForGroupsAtSignIn(sessionOpenedHere: false, hasCompletedPersonalOnboarding: false, channelStartsAtSignIn: true))
        #expect(!G.vouchesForGroupsAtSignIn(sessionOpenedHere: true, hasCompletedPersonalOnboarding: true, channelStartsAtSignIn: true))
        #expect(!G.vouchesForGroupsAtSignIn(sessionOpenedHere: true, hasCompletedPersonalOnboarding: false, channelStartsAtSignIn: false))
        // Con una cuenta completa el canal no arranca al firmar.
        #expect(!GroupsSignInChannelStartLogic.startsChannelAtSignIn(.adoptAsCompleteAndOpenGroups))
    }
}

// MARK: - La marca del alta vive en el intent

@Suite("Unirse por enlace · la marca del alta en el intent (t2q8)", .serialized)
@MainActor
struct InviteSignUpCleanStoreMarkTests {

    private func withIsolatedStore(_ body: () throws -> Void) rethrows {
        let previous = PendingJoinStore.defaults
        let suite = "test.pendingJoins.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("No se pudo crear el UserDefaults aislado")
            return
        }
        PendingJoinStore.defaults = defaults
        defer {
            PendingJoinStore.defaults = previous
            defaults.removePersistentDomain(forName: suite)
        }
        try body()
    }

    @Test func seApuntaUnaVez_ySoloConIntent() {
        withIsolatedStore {
            PendingJoinStore.markSignUpStartedOnCleanStore(zoneName: "g-sin-intent")
            #expect(PendingJoinStore.entry(zoneName: "g-sin-intent") == nil)

            PendingJoinStore.save(PendingJoinEntry(zoneName: "g", zoneOwnerName: "", backendGroupID: "g", inviteToken: "t"))
            #expect(PendingJoinStore.entry(zoneName: "g")?.signUpStartedOnCleanStore == false)

            let first = Date(timeIntervalSince1970: 1_000)
            PendingJoinStore.markSignUpStartedOnCleanStore(zoneName: "g", at: first)
            PendingJoinStore.markSignUpStartedOnCleanStore(zoneName: "g", at: Date(timeIntervalSince1970: 2_000))
            #expect(PendingJoinStore.entry(zoneName: "g")?.signUpOnCleanStoreAt == first)

            // Y muere con el intent.
            PendingJoinStore.clear(zoneName: "g")
            #expect(PendingJoinStore.entry(zoneName: "g") == nil)
        }
    }

    /// Un intent escrito por la versión anterior (sin el campo) decodifica sin la marca: el lado que no abre nada.
    @Test func unIntentViejo_decodificaSinLaMarca() throws {
        let json = #"{"zoneName":"g","zoneOwnerName":"","createdAt":0,"backendGroupID":"g","inviteToken":"t"}"#
        let entry = try JSONDecoder().decode(PendingJoinEntry.self, from: Data(json.utf8))
        #expect(entry.signUpOnCleanStoreAt == nil)
        #expect(!entry.signUpStartedOnCleanStore)
    }
}
