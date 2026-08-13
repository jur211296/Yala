//
//  ShellDataAlertsModifier.swift
//  Yala
//
//  Los cuatro alerts de DATOS del shell — wipe remoto detectado, cambio de cuenta iCloud, «empiezo de cero»
//  del Welcome y la oferta de restaurar de un returning user con un link de invitación.
//
//  **Extraídos del `body` de `ContentView` por PRESUPUESTO DEL TYPE-CHECKER, y la cifra está medida:** con
//  ellos dentro, el getter de `body` tardaba **591 s** en type-checkear
//  (`-warn-long-function-bodies=800`) y la compilación moría con «unable to type-check this expression in
//  reasonable time». Es el mismo motivo por el que ya existen `WelcomeFlowModifier`,
//  `GroupsBackendInviteModifier`, `GroupInviteModifier` y sus tres vecinos: la cadena de ese `body` está
//  saturada, y cualquier cosa que se le añada la tumba.
//
//  **Movimiento MECÁNICO: no cambia una sola decisión.** Los cuerpos de los cuatro alerts son literales a
//  los que había en `ContentView`, incluidos sus comentarios; lo único nuevo son los `@Binding` y los dos
//  closures (`onCancelWipeGrace`, `onReEmitInviteAfterRestore`) que reemplazan accesos directos a estado
//  privado de la vista.
//

import SwiftData
import SwiftUI

struct ShellDataAlertsModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Binding var showRemoteWipeAlert: Bool
    @Binding var showICloudRestartAlert: Bool
    @Binding var showFreshStartWipeAlert: Bool
    /// El wipe de cualquiera de los DOS caminos de «empiezo de cero» lanzó. Se presenta en vez de
    /// navegar al onboarding: la app llevaba mintiendo sobre un borrado que no ocurrió.
    @Binding var showFreshStartWipeFailedAlert: Bool
    @Binding var showRestoreOffer: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var hasExistingData: Bool
    @Binding var hasPersonalData: Bool
    @Binding var showWelcomeFlow: Bool
    @Binding var showOnboarding: Bool
    @Binding var showWelcomeRestore: Bool
    @Binding var welcomeFlowInitialStep: WelcomeFlowStep
    /// El `wipeGraceTask` es `@State` privado de `ContentView` y no puede viajar por `@Binding`: los dos
    /// wipes DELIBERADOS tienen que cancelar esa gracia antes de bajar `hasPersonalData`, o el true→false
    /// se lee como wipe REMOTO y apila un alert sobre el onboarding que ellos mismos están abriendo.
    var onCancelWipeGrace: () -> Void
    var onReEmitInviteAfterRestore: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(L10n.iCloud.remoteWipeTitle, isPresented: $showRemoteWipeAlert) {
                Button(L10n.iCloud.remoteWipeConfirm, role: .destructive) {
                    // Reset seed guards so onboarding can re-create data. El centinela de categorías
                    // va por `CategorySeedSentinel.currentKey`: está namespaceado por store (personal
                    // vs `YalaModel-UITest`) y el literal suelto apuntaría al del otro proceso.
                    UserDefaults.standard.removeObject(forKey: CategorySeedSentinel.currentKey)
                    UserDefaults.standard.removeObject(forKey: "notificationsSeeded")
                    hasCompletedOnboarding = false
                }
                Button(L10n.iCloud.remoteWipeCancel, role: .cancel) {}
            } message: {
                Text(L10n.iCloud.remoteWipeMessage)
            }
            .alert(L10n.iCloud.mismatchTitle, isPresented: $showICloudRestartAlert) {
                Button(L10n.iCloud.mismatchAction) {}
            } message: {
                Text(L10n.iCloud.mismatchMessage)
            }
            .alert(L10n.Welcome.FreshStart.alertTitle, isPresented: $showFreshStartWipeAlert) {
                Button(L10n.Welcome.FreshStart.alertConfirm, role: .destructive) {
                    do {
                        try DataWipeService.wipeAllUserData(
                            in: modelContext,
                            broadcastSignal: false
                        )
                        // La limpieza de prefs residuales vive AQUÍ y no en el disparador del alert:
                        // corriendo antes del `if`, «Cancelar» no la deshacía y el usuario perdía
                        // `userName` y `defaultCurrencyCode` por preguntar. Se limpia cuando se
                        // BORRA. Va DESPUÉS del wipe para que un wipe que lanza no se lleve por
                        // delante las prefs de unos datos que siguen ahí.
                        OnboardingResetHelper.clearResidualPreferencesForFreshStart()
                        // Handover: «empiezo de cero» es la frontera de OTRO usuario en este
                        // dispositivo, no un vaciado del mismo. El dominio Grupos, que sobrevive al
                        // wipe por diseño, se purga LOCALMENTE aquí — si no, el usuario nuevo hereda
                        // los grupos del anterior (mismo Apple ID ⇒ ninguna señal de identidad los
                        // distingue) y el bridge le mete sus gastos en Panel, Inbox y presupuestos.
                        try DataWipeService.wipeLocalGroupsDomain(in: modelContext)
                        hasExistingData = false
                        // El wipe es DELIBERADO: cancelar la gracia antes de bajar la señal, para que
                        // el true→false no se lea como wipe remoto y se apile un alert sobre el
                        // onboarding que este mismo camino está abriendo.
                        onCancelWipeGrace()
                        hasPersonalData = false
                        // La navegación al onboarding cuelga del camino que SÍ borró. Vivía fuera
                        // del `do/catch` y corría igual cuando el wipe lanzaba: la app metía a la
                        // persona en un onboarding «de cero» sobre sus datos intactos, sin decir
                        // una palabra.
                        showWelcomeFlow = false
                        showOnboarding = true
                    } catch {
                        // Canario FUERA de `#if DEBUG` a propósito: este fallo era invisible en
                        // producción. Sin PII — el detalle es de qué alert vino.
                        MetricsService.canary(.freshStartWipeFailed, detail: "welcomeFreshStart")
                        showFreshStartWipeFailedAlert = true
                    }
                }
                // Cancel: user queda en el Chooser (showWelcomeFlow sigue true) —
                // puede elegir Restore/Invite o re-tap "Soy nuevo".
                Button(L10n.Action.cancel, role: .cancel) {}
                    .tint(.primary)  // A11Y-DM: el indigo global se pierde sobre el alert del Welcome oscuro
            } message: {
                Text(L10n.Welcome.FreshStart.alertMessage)
            }
            // Parte F: oferta para un returning user con datos al abrir un link de invitación.
            .alert(L10n.Welcome.OfferRestore.title, isPresented: $showRestoreOffer) {
                Button(L10n.Welcome.OfferRestore.loadData) {
                    // Cargar datos: el intent de invitación lo conserva su propio store; tras
                    // restaurar se re-emite (reEmitInviteAfterRestore en onContinue/onComplete).
                    showRestoreOffer = false
                    showWelcomeRestore = true
                }
                Button(L10n.Welcome.OfferRestore.startFresh, role: .destructive) {
                    // Empezar de cero: wipe CON señal (lastWipeTimestamp) para que el re-emit
                    // vea wipe>onboarding → mini-onboarding de grupos (no vuelve a ofrecer).
                    showRestoreOffer = false
                    do {
                        try DataWipeService.wipeAllUserData(in: modelContext)
                        // Misma frontera de usuario que el alert de arriba (ver su nota): esto también
                        // es «empiezo de cero», no un vaciado del mismo usuario. Residual conocido de
                        // ESTE camino: la invitación abre el dominio Grupos (`groupsBetaUnlocked`) en
                        // cuanto se acepta el enlace, así que el gate del bridge queda abierto y un
                        // re-fetch de las zonas del Apple ID puede devolver los grupos del usuario
                        // anterior. Cerrarlo exige el sello de corpus (diferido en el ticket).
                        try DataWipeService.wipeLocalGroupsDomain(in: modelContext)
                        hasExistingData = false
                        // Mismo racional que el fresh-start de arriba: wipe deliberado ⇒ cancelar la
                        // gracia antes de bajar la señal personal.
                        onCancelWipeGrace()
                        hasPersonalData = false
                        // Igual que el alert de arriba: seguir adelante solo si el borrado ocurrió.
                        // El re-emit de la invitación asume un corpus limpio (mira wipe>onboarding
                        // para no volver a ofrecer restaurar), así que dispararlo tras un wipe que
                        // lanzó deja al invitado en el mini-onboarding con los datos del anterior.
                        onReEmitInviteAfterRestore()
                    } catch {
                        MetricsService.canary(.freshStartWipeFailed, detail: "offerRestore")
                        showFreshStartWipeFailedAlert = true
                    }
                }
                Button(L10n.Action.cancel, role: .cancel) {
                    showRestoreOffer = false
                    // Decisión consciente: volver al Chooser (el invite sigue en el store).
                    if !hasCompletedOnboarding {
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                }
            } message: {
                Text(L10n.Welcome.OfferRestore.message)
            }
            // El wipe lanzó. Un solo alert para los DOS caminos que borran: lo que la persona
            // necesita saber es idéntico —sus datos siguen aquí y no la hemos movido de sitio— y el
            // canario ya distingue de cuál vino. Sin acción destructiva: el reintento es cerrar y
            // volver a abrir, porque un segundo wipe sobre el mismo store fallaría igual.
            .alert(
                L10n.Welcome.FreshStart.failedTitle,
                isPresented: $showFreshStartWipeFailedAlert
            ) {
                Button(L10n.Common.ok, role: .cancel) {}
                    .tint(.primary)  // A11Y-DM: el indigo global se pierde sobre el Welcome oscuro
            } message: {
                Text(L10n.Welcome.FreshStart.failedMessage)
            }
    }
}
