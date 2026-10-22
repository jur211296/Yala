//
//  ContentViewReadinessLogicTests.swift
//  YalaTests
//
//  Pure-logic, no context, no singletons. Safe under parallel test execution.
//

import Foundation
import Testing
@testable import Yala

@Suite("ContentViewReadinessLogic")
struct ContentViewReadinessLogicTests {

    /// Builder con defaults limpios — varía solo las flags relevantes por test.
    private func make(
        forceUpdateRequired: Bool = false,
        isSplashDismissed: Bool = true,
        isBootstrapSettled: Bool = true,
        isWipingData: Bool = false,
        showOnboarding: Bool = false,
        showWelcomeFlow: Bool = false,
        showLanguageSelection: Bool = false,
        showWelcomeRestore: Bool = false,
        showInviteRecovery: Bool = false,
        showWelcomeCloudSignIn: Bool = false,
        showSignOutRelaunch: Bool = false,
        showFreshStartWipeAlert: Bool = false,
        showFreshStartWipeFailedAlert: Bool = false,
        showRemoteWipeAlert: Bool = false,
        showICloudRestartAlert: Bool = false,
        hasActiveInviteError: Bool = false,
        hasActiveGroupSyncError: Bool = false,
        hasActiveInboxAlert: Bool = false,
        showGroupInviteOnboarding: Bool = false,
        showGroupsConsent: Bool = false,
        showGroupsSignIn: Bool = false,
        showGroupsAccountIsCompleteBlock: Bool = false,
        showGroupsOrganizerName: Bool = false,
        showGroupsEducational: Bool = false,
        showFullModeActivation: Bool = false,
        showProTrialOffer: Bool = false,
        showWhatsNew: Bool = false,
        showSyncSettingsSheet: Bool = false,
        isMainTabModalVisible: Bool = false,
        showLateICloudNotice: Bool = false,
        appleIDCloseNoticePending: Bool = false,
        isSignOutWorking: Bool = false,
        isSignOutBlocked: Bool = false
    ) -> ShellReadinessState {
        ShellReadinessState(
            forceUpdateRequired: forceUpdateRequired,
            isSplashDismissed: isSplashDismissed,
            isBootstrapSettled: isBootstrapSettled,
            isWipingData: isWipingData,
            showOnboarding: showOnboarding, showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection, showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            showSignOutRelaunch: showSignOutRelaunch,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: showFreshStartWipeFailedAlert,
            showLateICloudNotice: showLateICloudNotice,
            showRemoteWipeAlert: showRemoteWipeAlert, showICloudRestartAlert: showICloudRestartAlert,
            appleIDCloseNoticePending: appleIDCloseNoticePending,
            isSignOutWorking: isSignOutWorking,
            isSignOutBlocked: isSignOutBlocked,
            hasActiveInviteError: hasActiveInviteError,
            hasActiveGroupSyncError: hasActiveGroupSyncError,
            hasActiveInboxAlert: hasActiveInboxAlert, showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupsConsent: showGroupsConsent, showGroupsSignIn: showGroupsSignIn,
            showGroupsAccountIsCompleteBlock: showGroupsAccountIsCompleteBlock,
            showGroupsOrganizerName: showGroupsOrganizerName,
            showGroupsEducational: showGroupsEducational,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer, showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            isMainTabModalVisible: isMainTabModalVisible
        )
    }

    @Test func allClean_isReady() {
        #expect(ContentViewReadinessLogic.isReady(state: make()))
        #expect(ContentViewReadinessLogic.blocker(state: make()) == nil)
    }

    // G4-invites (A2): los 2 sheets del flujo backend bloquean el drain mientras están arriba.

    @Test func groupsConsent_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showGroupsConsent: true)) == "groupsConsent")
        #expect(!ContentViewReadinessLogic.isReady(state: make(showGroupsConsent: true)))
    }

    @Test func groupsSignIn_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showGroupsSignIn: true)) == "groupsSignIn")
        #expect(!ContentViewReadinessLogic.isReady(state: make(showGroupsSignIn: true)))
    }

    /// **Bloque [I]** · el bloqueo «esa cuenta ya tiene Yala completo». Es el que MÁS lo necesita de los
    /// cuatro hermanos de Grupos: lo presenta el `onDismiss` del sheet de sign-in, o sea el instante exacto
    /// en el que el gate se despierta y el drain busca a quién montar. Sin blocker, el intent siguiente se
    /// monta encima y SwiftUI descarta uno de los dos en silencio, con el intent ya consumido.
    @Test func groupsAccountIsCompleteBlock_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showGroupsAccountIsCompleteBlock: true)) == "groupsAccountIsCompleteBlock")
        #expect(!ContentViewReadinessLogic.isReady(
            state: make(showGroupsAccountIsCompleteBlock: true)))
    }

    /// Tampoco es cadena welcome: un intent que la supersede no puede tumbarlo. Mismo trato que sus tres
    /// hermanos — y aquí importa más, porque tumbarlo dejaría entrar a la cuenta que se acaba de rechazar.
    @Test func groupsAccountIsCompleteBlock_isNotTearableWelcomeChain() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showGroupsAccountIsCompleteBlock: true)))
    }

    /// C2 · el educativo es el PRIMER escalón de la rama del organizador, y su cover cuelga del mismo anchor.
    /// Que bloquee no es defensa genérica: el paso SIGUIENTE de la cadena es `GroupsSignInView`, un sheet
    /// de ESTE anchor, así que sin blocker el drain lo montaría encima del educativo aún puesto — y SwiftUI
    /// descarta la segunda presentación en silencio, dejando el intent ya consumido.
    @Test func groupsEducational_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showGroupsEducational: true)) == "groupsEducational")
        #expect(!ContentViewReadinessLogic.isReady(state: make(showGroupsEducational: true)))
    }

    /// El educativo NO es de la cadena welcome: un intent que la supersede (invite/reconnect) no puede
    /// cerrarlo por su cuenta. Es el mismo trato que sus hermanos de Grupos.
    @Test func groupsEducational_isNotTearableWelcomeChain() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showGroupsEducational: true)))
    }

    @Test func groupsSheets_areNotTearableWelcomeChain() {
        // Un sheet del flujo backend arriba NO es cadena welcome — jamás se tumba por un
        // intent superseding (se retiene, molde welcomeCloudSignIn).
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showGroupsConsent: true)))
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showGroupsSignIn: true)))
    }

    // H4: los 2 blockers nuevos del cierre de sesión / sign-in de nube.

    @Test func welcomeCloudSignIn_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showWelcomeCloudSignIn: true)) == "welcomeCloudSignIn")
    }

    @Test func welcomeCloudSignIn_isNotTearableWelcomeChain() {
        // El adopt en vuelo NO se tumba por un intent superseding — se retiene.
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showWelcomeCloudSignIn: true)))
    }

    @Test func signOutRelaunch_blocks_aboveEverythingButWipe() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showSignOutRelaunch: true)) == "signOutRelaunch")
        // Solo wipingData lo supera en severidad.
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isWipingData: true, showSignOutRelaunch: true)) == "wipingData")
        // Gana incluso al splash (terminal: nada presenta debajo).
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isSplashDismissed: false, showSignOutRelaunch: true)) == "signOutRelaunch")
    }

    @Test func splashStillUp_notReady() {
        let s = make(isSplashDismissed: false)
        #expect(!ContentViewReadinessLogic.isReady(state: s))
        #expect(ContentViewReadinessLogic.blocker(state: s) == "splash")
    }

    // Cover pegado (2026-07-28): con el anchor LIBRE pero el arranque en curso, presentar
    // deja el cover montado para siempre y la app deja de responder a los taps.

    @Test func bootstrapNotSettled_blocks_evenWithAnchorFree() {
        // Todo limpio salvo el arranque: el anchor está libre y aun así NO se drena.
        let s = make(isBootstrapSettled: false)
        #expect(!ContentViewReadinessLogic.isReady(state: s))
        #expect(ContentViewReadinessLogic.blocker(state: s) == "bootstrapPending")
    }

    @Test func bootstrapNotSettled_isNotRedundantWithSplash() {
        // El splash se va por su propio reloj sin esperar al bootstrap — la ventana entre
        // ambos es justo donde el cover se quedaba pegado.
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isSplashDismissed: false, isBootstrapSettled: false)) == "splash")
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isSplashDismissed: true, isBootstrapSettled: false)) == "bootstrapPending")
        // Y cede ante todo lo terminal (mismo tier que el splash).
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isBootstrapSettled: false, isWipingData: true)) == "wipingData")
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isBootstrapSettled: false, showSignOutRelaunch: true)) == "signOutRelaunch")
    }

    @Test func bootstrapNotSettled_isNotTearableWelcomeChain() {
        // Un intent superseding NO puede tumbar la cadena welcome mientras el arranque sigue:
        // cerrarla solo adelantaría la presentación a la ventana que este blocker protege.
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(isBootstrapSettled: false, showWelcomeFlow: true)))
    }

    @Test func bootstrapSettled_releasesTheQueue() {
        // Liberado el arranque, la matriz vuelve a depender solo del anchor.
        #expect(ContentViewReadinessLogic.isReady(state: make(isBootstrapSettled: true)))
    }

    @Test func remoteWipeAlert_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showRemoteWipeAlert: true)) == "remoteWipeAlert")
    }

    @Test func iCloudRestartAlert_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showICloudRestartAlert: true)) == "iCloudRestartAlert")
    }

    @Test func freshStartWipeAlert_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showFreshStartWipeAlert: true)) == "freshStartWipeAlert")
    }

    /// El alert de «no pudimos borrar tus datos»: mientras la persona lo lee, nada del router puede
    /// presentarse sobre el mismo anchor.
    @Test func freshStartWipeFailedAlert_blocks() {
        #expect(
            ContentViewReadinessLogic.blocker(state: make(showFreshStartWipeFailedAlert: true))
                == "freshStartWipeFailedAlert")
    }

    @Test func languageSelection_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showLanguageSelection: true)) == "languageSelection")
    }

    @Test func welcomeFlow_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showWelcomeFlow: true)) == "welcomeFlow")
    }

    @Test func welcomeRestore_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showWelcomeRestore: true)) == "welcomeRestore")
    }

    @Test func inviteRecovery_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showInviteRecovery: true)) == "inviteRecovery")
    }

    @Test func onboarding_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showOnboarding: true)) == "onboarding")
    }

    @Test func fullModeActivation_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showFullModeActivation: true)) == "fullModeActivation")
    }

    @Test func groupsInviteEducational_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showGroupInviteOnboarding: true)) == "groupInviteOnboarding")
    }

    @Test func activeInboxAlert_blocks_rootCauseOfBug() {
        #expect(ContentViewReadinessLogic.blocker(state: make(hasActiveInboxAlert: true)) == "activeInboxAlert")
    }

    // MARK: - Blockers añadidos tras el bug del paywall (matriz completa)

    @Test func inviteError_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(hasActiveInviteError: true)) == "inviteError")
    }

    @Test func groupSyncError_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(hasActiveGroupSyncError: true)) == "groupSyncError")
    }

    @Test func proTrialOffer_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showProTrialOffer: true)) == "proTrialOffer")
    }

    @Test func whatsNew_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showWhatsNew: true)) == "whatsNew")
    }

    @Test func syncSettingsSheet_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showSyncSettingsSheet: true)) == "syncSettingsSheet")
    }

    // Cross-node: sheet de MainTabView visible → el shell no presenta encima.
    @Test func mainTabModal_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(isMainTabModalVisible: true)) == "mainTabModal")
    }

    // Los dos alerts de grupos ya no pueden coexistir: el primero bloquea el
    // drain del segundo (serialización que resuelve el "alert tragado").
    @Test func inviteErrorPlusGroupSyncError_firstWins() {
        let s = make(hasActiveInviteError: true, hasActiveGroupSyncError: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "inviteError")
        #expect(!ContentViewReadinessLogic.isReady(state: s))
    }

    // MARK: - Prioridad (orden documentado de severidad)

    @Test func forceUpdate_blocks_andIsNotReady() {
        let s = make(forceUpdateRequired: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "forceUpdate")
        #expect(!ContentViewReadinessLogic.isReady(state: s))
    }

    @Test func forceUpdate_priorityWinsOverWipe() {
        // El forzado es el estado más terminal: trumpea incluso el wipe en curso.
        let s = make(forceUpdateRequired: true, isSplashDismissed: false, isWipingData: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "forceUpdate")
    }

    @Test func wipingData_priorityWinsOverEverything() {
        let s = make(
            isSplashDismissed: false, isWipingData: true,
            showOnboarding: true, showWelcomeFlow: true, showLanguageSelection: true,
            showWelcomeRestore: true, showInviteRecovery: true, showFreshStartWipeAlert: true,
            showRemoteWipeAlert: true, showICloudRestartAlert: true,
            hasActiveInviteError: true, hasActiveGroupSyncError: true,
            hasActiveInboxAlert: true, showGroupInviteOnboarding: true,
            showFullModeActivation: true, showProTrialOffer: true, showWhatsNew: true,
            showSyncSettingsSheet: true
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "wipingData")
    }

    @Test func remoteWipeAlert_winsOverInviteError() {
        let s = make(showRemoteWipeAlert: true, hasActiveInviteError: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "remoteWipeAlert")
    }

    @Test func inviteError_winsOverProTrialOffer() {
        let s = make(hasActiveInviteError: true, showProTrialOffer: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "inviteError")
    }

    // MARK: - isBlockedSolelyByWelcomeChain (B4-04)

    // Cada cover de la cadena welcome, en solitario → SÍ es teardown-elegible.
    @Test func welcomeFlowOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true)))
    }

    @Test func welcomeRestoreOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeRestore: true)))
    }

    @Test func inviteRecoveryOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showInviteRecovery: true)))
    }

    @Test func languageSelectionOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showLanguageSelection: true)))
    }

    // Estado limpio → no hay blocker → nada que cerrar.
    @Test func cleanState_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make()))
    }

    // onboarding NO es de la cadena welcome (excluido a propósito).
    @Test func onboardingOnly_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showOnboarding: true)))
    }

    // Blockers de mayor prioridad que sobreviven al clear → NO teardown
    // (preserva la protección anti-"inbox alert tardío" y los gates de sistema).
    @Test func welcomePlusSplash_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(isSplashDismissed: false, showWelcomeFlow: true)))
    }

    @Test func welcomePlusFreshStartAlert_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, showFreshStartWipeAlert: true)))
    }

    // welcomeFlow es el blocker de mayor prioridad, pero limpiar la cadena deja
    // el inbox alert vivo → NO teardown (el caso que motivó el readiness gate).
    @Test func welcomePlusActiveInboxAlert_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, hasActiveInboxAlert: true)))
    }

    // onboarding sobrevive al clear de la cadena welcome → NO teardown.
    @Test func welcomePlusOnboarding_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showOnboarding: true, showWelcomeFlow: true)))
    }

    // Los blockers nuevos también sobreviven al clear de la cadena welcome →
    // un intent superseding NO tumba el welcome con un sheet/alert nuevo encima.
    @Test func welcomePlusProTrialOffer_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, showProTrialOffer: true)))
    }

    @Test func welcomePlusInviteError_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, hasActiveInviteError: true)))
    }

    // MARK: - Un intent superseding no deja el cierre de sesión sin dueño

    // Ticket `superseding-intent-can-strand-the-sign-out-coordinator`. La vuelta al neutro de la puerta de Grupos es un
    // step del Welcome: si el intent que supersede la cadena la derriba, el step se desmonta y el coordinador se queda
    // sin nadie que lo mire — y `signOut` empieza con `guard phase == .idle`, así que Ajustes vuelve mudo.

    @Test func signOutBlocked_keepsEveryWelcomeCoverFromBeingTornDown() {
        // El «espera agotada» de la puerta se enseña DENTRO del Welcome: derribarlo es dejar el `.blocked` huérfano.
        // Los cuatro covers derribables, uno a uno: el guard va antes de mirar cuál es el blocker.
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showWelcomeFlow: true, isSignOutBlocked: true)))
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showWelcomeRestore: true, isSignOutBlocked: true)))
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showInviteRecovery: true, isSignOutBlocked: true)))
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showLanguageSelection: true, isSignOutBlocked: true)))
    }

    @Test func signOutBlocked_isNotABlocker() {
        // La mitad que impide «arreglarlo» subiendo `.blocked` a la matriz: un bloqueo puede quedarse puesto, y
        // retener el router con él lo dejaría muerto el resto del proceso. Solo cambia el derribo, no el blocker.
        #expect(ContentViewReadinessLogic.isReady(state: make(isSignOutBlocked: true)))
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showWelcomeFlow: true, isSignOutBlocked: true)) == "welcomeFlow")
    }

    @Test func signOutWorking_keepsTheWelcomeChainFromBeingTornDown() {
        // La otra mitad de la ventana: mientras la espera corre, el desmontaje cancela su `.task` y la deja en un
        // `.blocked` sin dueño — o, pasado `armAfterCredentials`, con la sesión soltada y sin borrado armado. Lo
        // cubren DOS cosas: `signOutWorking` va por delante de la cadena en `blocker()`, y aunque bajara por debajo
        // de `welcomeFlow` la copia limpia seguiría sin estar lista (medido: ese mutante sale verde, y es
        // equivalente). Lo que este test caza es QUITAR el término de `blocker()`: entonces la copia limpia sí
        // estaría lista y el Welcome se derribaría con el cierre corriendo.
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showWelcomeFlow: true, isSignOutWorking: true)))
    }

    @Test func welcomeChainCleared_keepsTheSignOutTerms() {
        // La copia que usa el derribo no puede perder los dos términos del cierre: con cualquiera en `false`, el
        // `isReady` de la copia diría que limpiar la cadena basta.
        let cleared = make(showWelcomeFlow: true, isSignOutWorking: true, isSignOutBlocked: true)
            .withWelcomeChainCleared()
        #expect(cleared.isSignOutBlocked)
        #expect(cleared.isSignOutWorking)
        #expect(!cleared.showWelcomeFlow)
    }

    // MARK: - Cierre por cambio de Apple ID (2026-09-14)

    @Test func appleIDCloseNotice_blocksDrain() {
        // Sin esta aserción, borrar la línea del blocker sale VERDE: dentro de la hoja corre un cierre de
        // sesión que borra lo local, y su fase de bloqueo es la única pantalla que lo enseña. Un intent
        // presentado debajo se la comería en el peor momento.
        let state = make(appleIDCloseNoticePending: true)
        #expect(!ContentViewReadinessLogic.isReady(state: state))
        #expect(ContentViewReadinessLogic.blocker(state: state) == "appleIDCloseNotice")
    }

    @Test func signOutWorking_blocksDrain() {
        // La CONDICIÓN VIVA, que es la que cubre la ventana real: el gesto que pidió el cierre puede haber
        // bajado su flag en el tap y el coordinador tarda segundos en llegar a su fase terminal. Entre esos
        // dos instantes el router drenaría lo que tuviera en cola y montaría una presentación en el mismo
        // anchor donde va a aterrizar el cover terminal del cierre.
        let state = make(isSignOutWorking: true)
        #expect(!ContentViewReadinessLogic.isReady(state: state))
        #expect(ContentViewReadinessLogic.blocker(state: state) == "signOutWorking")
    }

    @Test func appleIDCloseNotice_andSignOutWorking_areIndependent() {
        // El control en la dirección contraria: ninguno de los dos implica al otro, y con los dos en
        // `false` la matriz tiene que seguir dejando drenar — si no, la aserción de arriba pasaría por
        // un blocker ajeno y no mediría la línea nueva.
        #expect(ContentViewReadinessLogic.isReady(state: make()))
    }
}

/// **El cableado del término en `ContentView`**, por source-scan: la matriz pura no ve de dónde sale cada campo, y un
/// `isSignOutBlocked: false` en el snapshot dejaría verdes los tests de arriba con el bug vivo.
@Suite("ContentView · el cierre bloqueado no se queda sin dueño")
struct SignOutBlockedOwnershipWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Texto sin comentarios —también los de cola— y con los espacios colapsados a uno.
    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// El cuerpo entre llaves balanceadas que abre la primera `{` tras `marker`, sin las llaves de fuera.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let tail = source[start.upperBound...]
        let open = try #require(tail.firstIndex(of: "{"), "sin llave tras el marcador: \(marker)")
        var depth = 0
        var index = open
        while index < tail.endIndex {
            if tail[index] == "{" { depth += 1 }
            if tail[index] == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            index = tail.index(after: index)
        }
        return String(tail[tail.index(after: open)..<index]).trimmingCharacters(in: .whitespaces)
    }

    @Test func snapshot_readsTheBlockedPhaseOfTheCoordinator() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")
        let snapshot = try Self.body(of: "private func currentShellReadinessState() -> ShellReadinessState", in: vista)
        #expect(snapshot.contains("isSignOutBlocked: signOutIsBlocked,"))
        // El cuerpo ENTERO, no un `contains`: una condición antepuesta o un `case` más estrecho también contendría
        // el literal.
        let getter = try Self.body(of: "private var signOutIsBlocked: Bool", in: vista)
        #expect(getter == "if case .blocked = CloudSessionSignOut.shared.phase { return true } return false")
    }

    @Test func phaseChange_rePeeksTheQueueWhileTheShellIsCovered() throws {
        // Un intent que supersede el Welcome y llega con el cierre bloqueado espera en la cola. Al reconocer el
        // bloqueo la fase vuelve a `.idle` sin bumpear la revisión, así que sin este re-peek la invitación no se
        // presentaba hasta el siguiente intent: el deadlock B4-04, en la salida del bloqueo.
        let vista = try Self.code("Yala/App/ContentView.swift")
        #expect(vista.contains(
            ".onChange(of: CloudSessionSignOut.shared.phase) { _, _ in signOutPhaseChanged() }"))
        let cambio = try Self.body(of: "private func signOutPhaseChanged()", in: vista)
        #expect(cambio == "updateContentViewReadiness() "
            + "if ContentViewReadinessLogic.blocker(state: currentShellReadinessState()) != nil { "
            + "drainContentViewIntents() }")
    }

    @Test func teardown_asksTheGuardWithTheLiveSnapshot() throws {
        // El derribo tiene que seguir preguntando a la función que lleva el guard, y con el snapshot vivo.
        let vista = try Self.code("Yala/App/ContentView.swift")
        let drain = try Self.body(of: "private func drainContentViewIntents()", in: vista)
        #expect(drain.contains("next.supersedesWelcomeChain, "
            + "ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: currentShellReadinessState()) { "
            + "dismissWelcomeChainForSupersedingIntent(for: next.id)"))
    }
}
