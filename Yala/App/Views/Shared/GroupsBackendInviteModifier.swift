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

    /// One-shots de resultado del sheet: se arman en el callback de éxito y se consumen en
    /// `onDismiss` (dismiss sin éxito = cancel ⇒ sin continuación).
    @State private var signInAuthenticated = false
    @State private var consentAccepted = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showGroupsSignIn, onDismiss: {
                guard signInAuthenticated else { return }  // cancel → sin continuación
                signInAuthenticated = false
                continueFlow()
            }) {
                GroupsSignInView {
                    signInAuthenticated = true
                    showGroupsSignIn = false
                    // H-2026-07-18-4: un sign-in solo-grupos IN-SESSION no arrancaba el canal (startIfEligible
                    // solo corría en cold boot) → arrancarlo aquí cubre crear-grupo / invite / futuro CTA del
                    // empty state. D8-safe por el guard de mount-mismatch; no-op temprano con el flag OFF.
                    GroupsSyncClient.shared.startIfEligible(context: modelContext, trigger: "post-sign-in")
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupsConsent, onDismiss: {
                guard consentAccepted else { return }  // cancel → sin continuación
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

    private func continueFlow() {
        guard let zone = pendingGroupsJoinZone else { return }
        Task { @MainActor in
            await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
        }
    }
}
