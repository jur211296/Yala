//
//  GroupsBackendInviteModifier.swift
//  Yala
//
//  Sheets del flujo de invite BACKEND (G4-invites A2): sign-in solo-grupos y consent de grupos,
//  drenados de `.presentGroupsSignIn` / `.presentGroupsConsent` por ContentView (dueño ÚNICO del
//  anchor — jamás un segundo anchor). ViewModifier separado para el presupuesto del type-checker.
//
//  Encadenado (contrato C7): cada paso re-evalúa condiciones VIVAS — la continuación corre en
//  `onDismiss:` (la dismissal ya terminó ⇒ el siguiente sheet del MISMO anchor no se descarta) y va
//  por `GroupBackendInviteEntryHandler.continueFlow`, que re-lee el intent persistido y decide el
//  siguiente paso (consent → onboarding-fresco → join). Un cancel (toolbar/swipe) NO continúa: el
//  intent persiste en `PendingJoinStore` y el próximo trigger del reconciler re-evalúa (TTL 7d).
//
//  DARK: con `groupsBackendEnabled` OFF los intents jamás se submitean ⇒ estos sheets no se
//  presentan nunca.
//

import SwiftData
import SwiftUI

struct GroupsBackendInviteModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Binding var showGroupsConsent: Bool
    @Binding var showGroupsSignIn: Bool
    @Binding var pendingGroupsJoinZone: String?
    /// G3: la rama ORGANIZADOR del Welcome reusa estos dos sheets —este modifier es el dueño ÚNICO de su
    /// anchor y un segundo sería la regla (4) de Presentaciones— pero su continuación es otra: no hay zona
    /// a la que unirse, hay un alta que terminar. Este flag es el discriminador, y va explícito en vez de
    /// derivarse de `pendingGroupsJoinZone == nil`: ese `nil` también es el estado de «nadie lo puso».
    @Binding var groupsOrganizerFlowActive: Bool
    /// G3: el usuario canceló un sheet de la rama organizador (toolbar/swipe). El invitado puede quedarse
    /// donde está —su intent sobrevive en `PendingJoinStore` y el reconciler re-evalúa— pero el
    /// organizador acaba de SALIR del Welcome y debajo no hay shell que usar: sin esto, cancelar deja una
    /// pantalla muerta, que es lo que la invariante (2) del chip prohíbe. `ContentView` lo devuelve al
    /// step de los dos caminos.
    var onGroupsOrganizerCancelled: () -> Void

    /// One-shots de resultado del sheet: se arman en el callback de éxito y se consumen en
    /// `onDismiss` (dismiss sin éxito = cancel ⇒ sin continuación).
    @State private var signInAuthenticated = false
    @State private var consentAccepted = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showGroupsSignIn, onDismiss: {
                guard signInAuthenticated else { return handleCancel() }  // cancel → sin continuación
                signInAuthenticated = false
                continueFlow()
            }) {
                GroupsSignInView {
                    signInAuthenticated = true
                    showGroupsSignIn = false
                    // D2 (§3.3.3): re-firmar sesión de grupos DESARMA un boot-wipe de grupos colgado por un
                    // "Salir de Yala" in-session previo (`exitYalaOnThisDevice`) — sin esto, un cold boot
                    // posterior borraría los grupos recién re-sincronizados — y quema el banner de re-entrada
                    // stale. Idempotente/no-op si nada estaba armado; el sign-out normal exit(0) antes de este
                    // seam (jamás interfiere). Los otros armadores (`.groupsOnlySignOut`/borrado de cuenta)
                    // hacen relaunch inmediato ⇒ el wipe ya corrió antes de cualquier re-sign-in.
                    StorageModePersistence.clearGroupsOnlyWipeArm()
                    GroupsSignOutBannerMarker.clear()
                    // H-2026-07-18-4: un sign-in solo-grupos IN-SESSION no arrancaba el canal (startIfEligible
                    // solo corría en cold boot) → arrancarlo aquí cubre crear-grupo / invite / futuro CTA del
                    // empty state. D8-safe por el guard de mount-mismatch; no-op temprano con el flag OFF.
                    GroupsSyncClient.shared.startIfEligible(context: modelContext, trigger: "post-sign-in")
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupsConsent, onDismiss: {
                guard consentAccepted else { return handleCancel() }  // cancel → sin continuación
                consentAccepted = false
                continueFlow()
            }) {
                GroupsConsentView {
                    consentAccepted = true
                    showGroupsConsent = false
                }
                .environment(SessionState.shared)
            }
    }

    /// Cancel: para el invitado es un no-op (su intent persiste, TTL 7 d); para el organizador es la
    /// vuelta al Welcome.
    private func handleCancel() {
        guard groupsOrganizerFlowActive else { return }
        groupsOrganizerFlowActive = false
        onGroupsOrganizerCancelled()
    }

    private func continueFlow() {
        // G3 primero: la rama organizador no tiene zona, así que el `guard` de abajo la dejaría muda.
        // Vuelve al router en vez de decidir aquí — el paso se RE-DECIDE con condiciones vivas, y así la
        // presentación siguiente espera a que este sheet haya terminado de irse.
        if groupsOrganizerFlowActive {
            RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
            return
        }
        guard let zone = pendingGroupsJoinZone else { return }
        Task { @MainActor in
            await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
        }
    }
}
